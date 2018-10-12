//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSOutgoingReceiptManager.h"
#import "AppReadiness.h"
#import "OWSMessageSender.h"
#import "OWSPrimaryStorage.h"
#import "OWSReceiptsForSenderMessage.h"
#import "SSKEnvironment.h"
#import "TSContactThread.h"
#import "TSYapDatabaseObject.h"
#import <Reachability/Reachability.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OWSReceiptType) {
    OWSReceiptType_Delivery,
    OWSReceiptType_Read,
};

NSString *const kOutgoingDeliveryReceiptManagerCollection = @"kOutgoingDeliveryReceiptManagerCollection";
NSString *const kOutgoingReadReceiptManagerCollection = @"kOutgoingReadReceiptManagerCollection";

@interface OWSOutgoingReceiptManager ()

@property (nonatomic, readonly) YapDatabaseConnection *dbConnection;

@property (nonatomic) Reachability *reachability;

// This property should only be accessed on the serialQueue.
@property (nonatomic) BOOL isProcessing;

@end

#pragma mark -

@implementation OWSOutgoingReceiptManager

+ (instancetype)sharedManager
{
    OWSAssert(SSKEnvironment.shared.outgoingReceiptManager);

    return SSKEnvironment.shared.outgoingReceiptManager;
}

- (instancetype)initWithPrimaryStorage:(OWSPrimaryStorage *)primaryStorage
{
    self = [super init];

    if (!self) {
        return self;
    }

    self.reachability = [Reachability reachabilityForInternetConnection];

    _dbConnection = primaryStorage.newDatabaseConnection;

    OWSSingletonAssert();

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged)
                                                 name:kReachabilityChangedNotification
                                               object:nil];

    // Start processing.
    [AppReadiness runNowOrWhenAppIsReady:^{
        [self scheduleProcessing];
    }];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Dependencies

- (OWSMessageSender *)messageSender
{
    OWSAssertDebug(SSKEnvironment.shared.messageSender);

    return SSKEnvironment.shared.messageSender;
}

#pragma mark -

- (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t _serialQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _serialQueue = dispatch_queue_create("org.whispersystems.outgoingReceipts", DISPATCH_QUEUE_SERIAL);
    });

    return _serialQueue;
}

// Schedules a processing pass, unless one is already scheduled.
- (void)scheduleProcessing
{
    OWSAssertDebug(AppReadiness.isAppReady);

    dispatch_async(self.serialQueue, ^{
        if (self.isProcessing) {
            return;
        }

        self.isProcessing = YES;

        [self process];
    });
}

- (void)process
{
    OWSLogVerbose(@"Processing outbound receipts.");

    if (!self.reachability.isReachable) {
        // No network availability; abort.
        self.isProcessing = NO;
        return;
    }

    NSMutableArray<AnyPromise *> *sendPromises = [NSMutableArray array];
    [sendPromises addObjectsFromArray:[self sendReceiptsForCollection:kOutgoingDeliveryReceiptManagerCollection
                                                          receiptType:OWSReceiptType_Delivery]];
    [sendPromises addObjectsFromArray:[self sendReceiptsForCollection:kOutgoingReadReceiptManagerCollection
                                                          receiptType:OWSReceiptType_Read]];

    if (sendPromises.count < 1) {
        // No work to do; abort.
        self.isProcessing = NO;
        return;
    }

    AnyPromise *completionPromise = PMKJoin(sendPromises);
    completionPromise.always(^() {
        // Wait N seconds before conducting another pass.
        // This allows time for a batch to accumulate.
        //
        // We want a value high enough to allow us to effectively de-duplicate
        // receipts without being so high that we incur so much latency that
        // the user notices.
        const CGFloat kProcessingFrequencySeconds = 3.f;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kProcessingFrequencySeconds * NSEC_PER_SEC)),
            self.serialQueue,
            ^{
                [self process];
            });
    });
    [completionPromise retainUntilComplete];
}

- (NSArray<AnyPromise *> *)sendReceiptsForCollection:(NSString *)collection receiptType:(OWSReceiptType)receiptType
{

    NSMutableDictionary<NSString *, NSSet<NSNumber *> *> *queuedReceiptMap = [NSMutableDictionary new];
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:collection
                                              usingBlock:^(NSString *key, id object, BOOL *stop) {
                                                  NSString *recipientId = key;
                                                  NSSet<NSNumber *> *timestamps = object;
                                                  queuedReceiptMap[recipientId] = [timestamps copy];
                                              }];
    }];

    NSMutableArray<AnyPromise *> *sendPromises = [NSMutableArray array];

    for (NSString *recipientId in queuedReceiptMap) {
        NSSet<NSNumber *> *timestamps = queuedReceiptMap[recipientId];
        if (timestamps.count < 1) {
            OWSFailDebug(@"Missing timestamps.");
            continue;
        }

        TSThread *thread = [TSContactThread getOrCreateThreadWithContactId:recipientId];
        OWSReceiptsForSenderMessage *message;
        NSString *receiptName;
        switch (receiptType) {
            case OWSReceiptType_Delivery:
                message =
                    [OWSReceiptsForSenderMessage deliveryReceiptsForSenderMessageWithThread:thread
                                                                          messageTimestamps:timestamps.allObjects];
                receiptName = @"Delivery";
                break;
            case OWSReceiptType_Read:
                message = [OWSReceiptsForSenderMessage readReceiptsForSenderMessageWithThread:thread
                                                                            messageTimestamps:timestamps.allObjects];
                receiptName = @"Read";
                break;
        }

        AnyPromise *sendPromise = [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
            [self.messageSender enqueueMessage:message
                success:^{
                    OWSLogInfo(
                        @"Successfully sent %lu %@ receipts to sender.", (unsigned long)timestamps.count, receiptName);

                    [self dequeueReceiptsWithRecipientId:recipientId timestamps:timestamps collection:collection];

                    // The value doesn't matter, we just need any non-NSError value.
                    resolve(@(1));
                }
                failure:^(NSError *error) {
                    OWSLogError(@"Failed to send %@ receipts to sender with error: %@", receiptName, error);

                    resolve(error);
                }];
        }];
        [sendPromises addObject:sendPromise];
    }

    return [sendPromises copy];
}

- (void)enqueueDeliveryReceiptForEnvelope:(SSKProtoEnvelope *)envelope
{
    [self enqueueReceiptWithRecipientId:envelope.source
                              timestamp:envelope.timestamp
                             collection:kOutgoingDeliveryReceiptManagerCollection];
}

- (void)enqueueReadReceiptForEnvelope:(NSString *)messageAuthorId timestamp:(uint64_t)timestamp
{
    [self enqueueReceiptWithRecipientId:messageAuthorId
                              timestamp:timestamp
                             collection:kOutgoingReadReceiptManagerCollection];
}

- (void)enqueueReceiptWithRecipientId:(NSString *)recipientId
                            timestamp:(uint64_t)timestamp
                           collection:(NSString *)collection
{

    if (recipientId.length < 1) {
        OWSFailDebug(@"Invalid recipient id.");
        return;
    }
    if (timestamp < 1) {
        OWSFailDebug(@"Invalid timestamp.");
        return;
    }
    dispatch_async(self.serialQueue, ^{
        [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            NSSet<NSNumber *> *_Nullable oldTimestamps = [transaction objectForKey:recipientId inCollection:collection];
            NSMutableSet<NSNumber *> *newTimestamps
                = (oldTimestamps ? [oldTimestamps mutableCopy] : [NSMutableSet new]);
            [newTimestamps addObject:@(timestamp)];

            [transaction setObject:newTimestamps forKey:recipientId inCollection:collection];
        }];

        [self scheduleProcessing];
    });
}

- (void)dequeueReceiptsWithRecipientId:(NSString *)recipientId
                            timestamps:(NSSet<NSNumber *> *)timestamps
                            collection:(NSString *)collection
{
    if (recipientId.length < 1) {
        OWSFailDebug(@"Invalid recipient id.");
        return;
    }
    if (timestamps.count < 1) {
        OWSFailDebug(@"Invalid timestamps.");
        return;
    }
    dispatch_async(self.serialQueue, ^{
        [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            NSSet<NSNumber *> *_Nullable oldTimestamps = [transaction objectForKey:recipientId inCollection:collection];
            NSMutableSet<NSNumber *> *newTimestamps
                = (oldTimestamps ? [oldTimestamps mutableCopy] : [NSMutableSet new]);
            [newTimestamps minusSet:timestamps];

            if (newTimestamps.count > 0) {
                [transaction setObject:newTimestamps forKey:recipientId inCollection:collection];
            } else {
                [transaction removeObjectForKey:recipientId inCollection:collection];
            }
        }];
    });
}

- (void)reachabilityChanged
{
    OWSAssertIsOnMainThread();

    [self scheduleProcessing];
}

@end

NS_ASSUME_NONNULL_END
