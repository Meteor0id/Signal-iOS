//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDBCipher
import SignalCoreKit

// NOTE: This file is generated by /Scripts/sds_codegen/sds_generate.py.
// Do not manually edit it, instead run `sds_codegen.sh`.

// MARK: - Typed Convenience Methods

@objc
public extension TSGroupThread {
    // NOTE: This method will fail if the object has unexpected type.
    class func anyFetchGroupThread(uniqueId: String,
                                   transaction: SDSAnyReadTransaction) -> TSGroupThread? {
        assert(uniqueId.count > 0)

        guard let object = anyFetch(uniqueId: uniqueId,
                                    transaction: transaction) else {
                                        return nil
        }
        guard let instance = object as? TSGroupThread else {
            owsFailDebug("Object has unexpected type: \(type(of: object))")
            return nil
        }
        return instance
    }

    // NOTE: This method will fail if the object has unexpected type.
    func anyUpdateGroupThread(transaction: SDSAnyWriteTransaction, block: (TSGroupThread) -> Void) {
        anyUpdate(transaction: transaction) { (object) in
            guard let instance = object as? TSGroupThread else {
                owsFailDebug("Object has unexpected type: \(type(of: object))")
                return
            }
            block(instance)
        }
    }
}

// MARK: - SDSSerializer

// The SDSSerializer protocol specifies how to insert and update the
// row that corresponds to this model.
class TSGroupThreadSerializer: SDSSerializer {

    private let model: TSGroupThread
    public required init(model: TSGroupThread) {
        self.model = model
    }

    // MARK: - Record

    func asRecord() throws -> SDSRecord {
        let id: Int64? = nil

        let recordType: SDSRecordType = .groupThread
        let uniqueId: String = model.uniqueId

        // Base class properties
        let archivalDate: Date? = model.archivalDate
        let archivedAsOfMessageSortId: UInt64? = archiveOptionalNSNumber(model.archivedAsOfMessageSortId, conversion: { $0.uint64Value })
        let conversationColorName: String = model.conversationColorName.rawValue
        let creationDate: Date? = model.creationDate
        let isArchivedByLegacyTimestampForSorting: Bool = model.isArchivedByLegacyTimestampForSorting
        let lastMessageDate: Date? = model.lastMessageDate
        let messageDraft: String? = model.messageDraft
        let mutedUntilDate: Date? = model.mutedUntilDate
        let shouldThreadBeVisible: Bool = model.shouldThreadBeVisible

        // Subclass properties
        let contactPhoneNumber: String? = nil
        let contactThreadSchemaVersion: UInt? = nil
        let contactUUID: String? = nil
        let groupModel: Data? = optionalArchive(model.groupModel)
        let hasDismissedOffers: Bool? = nil

        return ThreadRecord(id: id, recordType: recordType, uniqueId: uniqueId, archivalDate: archivalDate, archivedAsOfMessageSortId: archivedAsOfMessageSortId, conversationColorName: conversationColorName, creationDate: creationDate, isArchivedByLegacyTimestampForSorting: isArchivedByLegacyTimestampForSorting, lastMessageDate: lastMessageDate, messageDraft: messageDraft, mutedUntilDate: mutedUntilDate, shouldThreadBeVisible: shouldThreadBeVisible, contactPhoneNumber: contactPhoneNumber, contactThreadSchemaVersion: contactThreadSchemaVersion, contactUUID: contactUUID, groupModel: groupModel, hasDismissedOffers: hasDismissedOffers)
    }
}