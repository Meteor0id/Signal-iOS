//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import "SSKMessageSenderJobRecord.h"
#import "TSOutgoingMessage.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SSKMessageSenderJobRecord

#pragma mark

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (nullable instancetype)initWithMessage:(TSOutgoingMessage *)message
               removeMessageAfterSending:(BOOL)removeMessageAfterSending
                                   label:(NSString *)label
                             transaction:(SDSAnyReadTransaction *)transaction
                                   error:(NSError **)outError
{
    self = [super initWithLabel:label];
    if (!self) {
        return self;
    }

    if (message.shouldBeSaved) {
        _messageId = message.uniqueId;
        OWSAssertDebug(_messageId.length > 0);
        BOOL isSaved = [TSInteraction anyExistsWithUniqueId:_messageId transaction:transaction];
        if (!isSaved) {
            *outError = [NSError errorWithDomain:SSKJobRecordErrorDomain
                                            code:JobRecordError_AssertionError
                                        userInfo:@{ NSDebugDescriptionErrorKey : @"message wasn't saved" }];
            return nil;
        }
        _invisibleMessage = nil;
    } else {
        _messageId = nil;
        _invisibleMessage = message;
    }

    _removeMessageAfterSending = removeMessageAfterSending;
    _threadId = message.uniqueThreadId;

    return self;
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
                    failureCount:(NSUInteger)failureCount
                           label:(NSString *)label
                          sortId:(unsigned long long)sortId
                          status:(SSKJobRecordStatus)status
                invisibleMessage:(nullable TSOutgoingMessage *)invisibleMessage
                       messageId:(nullable NSString *)messageId
       removeMessageAfterSending:(BOOL)removeMessageAfterSending
                        threadId:(nullable NSString *)threadId
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId
                      failureCount:failureCount
                             label:label
                            sortId:sortId
                            status:status];

    if (!self) {
        return self;
    }

    _invisibleMessage = invisibleMessage;
    _messageId = messageId;
    _removeMessageAfterSending = removeMessageAfterSending;
    _threadId = threadId;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

@end

NS_ASSUME_NONNULL_END
