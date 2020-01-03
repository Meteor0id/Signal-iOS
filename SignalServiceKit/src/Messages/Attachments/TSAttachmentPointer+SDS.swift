//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB
import SignalCoreKit

// NOTE: This file is generated by /Scripts/sds_codegen/sds_generate.py.
// Do not manually edit it, instead run `sds_codegen.sh`.

// MARK: - Typed Convenience Methods

@objc
public extension TSAttachmentPointer {
    // NOTE: This method will fail if the object has unexpected type.
    class func anyFetchAttachmentPointer(uniqueId: String,
                                   transaction: SDSAnyReadTransaction) -> TSAttachmentPointer? {
        assert(uniqueId.count > 0)

        guard let object = anyFetch(uniqueId: uniqueId,
                                    transaction: transaction) else {
                                        return nil
        }
        guard let instance = object as? TSAttachmentPointer else {
            owsFailDebug("Object has unexpected type: \(type(of: object))")
            return nil
        }
        return instance
    }

    // NOTE: This method will fail if the object has unexpected type.
    func anyUpdateAttachmentPointer(transaction: SDSAnyWriteTransaction, block: (TSAttachmentPointer) -> Void) {
        anyUpdate(transaction: transaction) { (object) in
            guard let instance = object as? TSAttachmentPointer else {
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
class TSAttachmentPointerSerializer: SDSSerializer {

    private let model: TSAttachmentPointer
    public required init(model: TSAttachmentPointer) {
        self.model = model
    }

    // MARK: - Record

    func asRecord() throws -> SDSRecord {
        let id: Int64? = model.grdbId?.int64Value

        let recordType: SDSRecordType = .attachmentPointer
        let uniqueId: String = model.uniqueId

        // Properties
        let albumMessageId: String? = model.albumMessageId
        let attachmentType: TSAttachmentType = model.attachmentType
        let blurHash: String? = model.blurHash
        let byteCount: UInt32 = model.byteCount
        let caption: String? = model.caption
        let contentType: String = model.contentType
        let encryptionKey: Data? = model.encryptionKey
        let serverId: UInt64 = model.serverId
        let sourceFilename: String? = model.sourceFilename
        let cachedAudioDurationSeconds: Double? = nil
        let cachedImageHeight: Double? = nil
        let cachedImageWidth: Double? = nil
        let creationTimestamp: Double? = nil
        let digest: Data? = model.digest
        let isUploaded: Bool? = nil
        let isValidImageCached: Bool? = nil
        let isValidVideoCached: Bool? = nil
        let lazyRestoreFragmentId: String? = model.lazyRestoreFragmentId
        let localRelativeFilePath: String? = nil
        let mediaSize: Data? = optionalArchive(model.mediaSize)
        let pointerType: TSAttachmentPointerType? = model.pointerType
        let state: TSAttachmentPointerState? = model.state

        return AttachmentRecord(delegate: model, id: id, recordType: recordType, uniqueId: uniqueId, albumMessageId: albumMessageId, attachmentType: attachmentType, blurHash: blurHash, byteCount: byteCount, caption: caption, contentType: contentType, encryptionKey: encryptionKey, serverId: serverId, sourceFilename: sourceFilename, cachedAudioDurationSeconds: cachedAudioDurationSeconds, cachedImageHeight: cachedImageHeight, cachedImageWidth: cachedImageWidth, creationTimestamp: creationTimestamp, digest: digest, isUploaded: isUploaded, isValidImageCached: isValidImageCached, isValidVideoCached: isValidVideoCached, lazyRestoreFragmentId: lazyRestoreFragmentId, localRelativeFilePath: localRelativeFilePath, mediaSize: mediaSize, pointerType: pointerType, state: state)
    }
}
