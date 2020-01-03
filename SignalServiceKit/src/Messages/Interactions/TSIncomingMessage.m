//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import "TSIncomingMessage.h"
#import "NSNotificationCenter+OWS.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSReadReceiptManager.h"
#import "TSAttachmentPointer.h"
#import "TSContactThread.h"
#import "TSDatabaseSecondaryIndexes.h"
#import "TSGroupThread.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSIncomingMessage ()

@property (nonatomic, getter=wasRead) BOOL read;

@property (nonatomic, nullable) NSNumber *serverTimestamp;
@property (nonatomic, readonly) NSUInteger incomingMessageSchemaVersion;

@end

#pragma mark -

const NSUInteger TSIncomingMessageSchemaVersion = 1;

@implementation TSIncomingMessage

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }

    if (_incomingMessageSchemaVersion < 1) {
        _authorPhoneNumber = [coder decodeObjectForKey:@"authorId"];
        if (_authorPhoneNumber == nil) {
            _authorPhoneNumber = [TSContactThread legacyContactPhoneNumberFromThreadId:self.uniqueThreadId];
        }
    }

    _incomingMessageSchemaVersion = TSIncomingMessageSchemaVersion;

    return self;
}

- (instancetype)initIncomingMessageWithTimestamp:(uint64_t)timestamp
                                        inThread:(TSThread *)thread
                                   authorAddress:(SignalServiceAddress *)authorAddress
                                  sourceDeviceId:(uint32_t)sourceDeviceId
                                     messageBody:(nullable NSString *)body
                                   attachmentIds:(NSArray<NSString *> *)attachmentIds
                                expiresInSeconds:(uint32_t)expiresInSeconds
                                   quotedMessage:(nullable TSQuotedMessage *)quotedMessage
                                    contactShare:(nullable OWSContact *)contactShare
                                     linkPreview:(nullable OWSLinkPreview *)linkPreview
                                  messageSticker:(nullable MessageSticker *)messageSticker
                                 serverTimestamp:(nullable NSNumber *)serverTimestamp
                                 wasReceivedByUD:(BOOL)wasReceivedByUD
                               isViewOnceMessage:(BOOL)isViewOnceMessage
{
    self = [super initMessageWithTimestamp:timestamp
                                  inThread:thread
                               messageBody:body
                             attachmentIds:attachmentIds
                          expiresInSeconds:expiresInSeconds
                           expireStartedAt:0
                             quotedMessage:quotedMessage
                              contactShare:contactShare
                               linkPreview:linkPreview
                            messageSticker:messageSticker
                         isViewOnceMessage:isViewOnceMessage];

    if (!self) {
        return self;
    }

    _authorPhoneNumber = authorAddress.phoneNumber;
    _authorUUID = authorAddress.uuidString;

    _sourceDeviceId = sourceDeviceId;
    _read = NO;
    _serverTimestamp = serverTimestamp;
    _wasReceivedByUD = wasReceivedByUD;

    _incomingMessageSchemaVersion = TSIncomingMessageSchemaVersion;

    return self;
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
             receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                          sortId:(uint64_t)sortId
                       timestamp:(uint64_t)timestamp
                  uniqueThreadId:(NSString *)uniqueThreadId
                   attachmentIds:(NSArray<NSString *> *)attachmentIds
                            body:(nullable NSString *)body
                    contactShare:(nullable OWSContact *)contactShare
                 expireStartedAt:(uint64_t)expireStartedAt
                       expiresAt:(uint64_t)expiresAt
                expiresInSeconds:(unsigned int)expiresInSeconds
              isViewOnceComplete:(BOOL)isViewOnceComplete
               isViewOnceMessage:(BOOL)isViewOnceMessage
                     linkPreview:(nullable OWSLinkPreview *)linkPreview
                  messageSticker:(nullable MessageSticker *)messageSticker
                   quotedMessage:(nullable TSQuotedMessage *)quotedMessage
    storedShouldStartExpireTimer:(BOOL)storedShouldStartExpireTimer
               authorPhoneNumber:(nullable NSString *)authorPhoneNumber
                      authorUUID:(nullable NSString *)authorUUID
                            read:(BOOL)read
                 serverTimestamp:(nullable NSNumber *)serverTimestamp
                  sourceDeviceId:(unsigned int)sourceDeviceId
                 wasReceivedByUD:(BOOL)wasReceivedByUD
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId
               receivedAtTimestamp:receivedAtTimestamp
                            sortId:sortId
                         timestamp:timestamp
                    uniqueThreadId:uniqueThreadId
                     attachmentIds:attachmentIds
                              body:body
                      contactShare:contactShare
                   expireStartedAt:expireStartedAt
                         expiresAt:expiresAt
                  expiresInSeconds:expiresInSeconds
                isViewOnceComplete:isViewOnceComplete
                 isViewOnceMessage:isViewOnceMessage
                       linkPreview:linkPreview
                    messageSticker:messageSticker
                     quotedMessage:quotedMessage
      storedShouldStartExpireTimer:storedShouldStartExpireTimer];

    if (!self) {
        return self;
    }

    _authorPhoneNumber = authorPhoneNumber;
    _authorUUID = authorUUID;
    _read = read;
    _serverTimestamp = serverTimestamp;
    _sourceDeviceId = sourceDeviceId;
    _wasReceivedByUD = wasReceivedByUD;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

- (OWSInteractionType)interactionType
{
    return OWSInteractionType_IncomingMessage;
}

#pragma mark - OWSReadTracking

// This method will be called after every insert and update, so it needs
// to be cheap.
- (BOOL)shouldStartExpireTimer
{
    if (self.hasPerConversationExpirationStarted) {
        // Expiration already started.
        return YES;
    } else if (!self.hasPerConversationExpiration) {
        return NO;
    } else {
        return self.wasRead && [super shouldStartExpireTimer];
    }
}

- (BOOL)shouldAffectUnreadCounts
{
    return YES;
}

- (void)markAsReadNowWithSendReadReceipt:(BOOL)sendReadReceipt transaction:(SDSAnyWriteTransaction *)transaction
{
    [self markAsReadAtTimestamp:[NSDate ows_millisecondTimeStamp]
                sendReadReceipt:sendReadReceipt
                    transaction:transaction];
}

- (void)markAsReadAtTimestamp:(uint64_t)readTimestamp
              sendReadReceipt:(BOOL)sendReadReceipt
                  transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);

    if (self.read && readTimestamp >= self.expireStartedAt) {
        return;
    }

    NSTimeInterval secondsAgoRead = ((NSTimeInterval)[NSDate ows_millisecondTimeStamp] - (NSTimeInterval)readTimestamp) / 1000;
    OWSLogDebug(@"marking uniqueId: %@  which has timestamp: %llu as read: %f seconds ago",
        self.uniqueId,
        self.timestamp,
        secondsAgoRead);

    [self anyUpdateIncomingMessageWithTransaction:transaction
                                            block:^(TSIncomingMessage *message) {
                                                message.read = YES;
                                            }];

    // readTimestamp may be earlier than now, so backdate the expiration if necessary.
    [[OWSDisappearingMessagesJob sharedJob] startAnyExpirationForMessage:self
                                                     expirationStartedAt:readTimestamp
                                                             transaction:transaction];

    [transaction addCompletionWithBlock:^{
        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:kIncomingMessageMarkedAsReadNotification
                                                                 object:self];
    }];

    if (sendReadReceipt) {
        [OWSReadReceiptManager.sharedManager messageWasReadLocally:self];
    }
}

- (SignalServiceAddress *)authorAddress
{
    return [[SignalServiceAddress alloc] initWithUuidString:self.authorUUID phoneNumber:self.authorPhoneNumber];
}

@end

NS_ASSUME_NONNULL_END
