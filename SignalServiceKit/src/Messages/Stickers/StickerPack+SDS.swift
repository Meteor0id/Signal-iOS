//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDBCipher
import SignalCoreKit

// NOTE: This file is generated by /Scripts/sds_codegen/sds_generate.py.
// Do not manually edit it, instead run `sds_codegen.sh`.

// MARK: - Record

public struct StickerPackRecord: SDSRecord {
    public var tableMetadata: SDSTableMetadata {
        return StickerPackSerializer.table
    }

    public static let databaseTableName: String = StickerPackSerializer.table.tableName

    public var id: Int64?

    // This defines all of the columns used in the table
    // where this model (and any subclasses) are persisted.
    public let recordType: SDSRecordType
    public let uniqueId: String

    // Base class properties
    public let author: String?
    public let cover: Data
    public let dateCreated: Date
    public let info: Data
    public let isInstalled: Bool
    public let items: Data
    public let title: String?

    public enum CodingKeys: String, CodingKey, ColumnExpression, CaseIterable {
        case id
        case recordType
        case uniqueId
        case author
        case cover
        case dateCreated
        case info
        case isInstalled
        case items
        case title
    }

    public static func columnName(_ column: StickerPackRecord.CodingKeys, fullyQualified: Bool = false) -> String {
        return fullyQualified ? "\(databaseTableName).\(column.rawValue)" : column.rawValue
    }
}

// MARK: - Row Initializer

public extension StickerPackRecord {
    static var databaseSelection: [SQLSelectable] {
        return CodingKeys.allCases
    }

    init(row: Row) {
        id = row[0]
        recordType = row[1]
        uniqueId = row[2]
        author = row[3]
        cover = row[4]
        dateCreated = row[5]
        info = row[6]
        isInstalled = row[7]
        items = row[8]
        title = row[9]
    }
}

// MARK: - StringInterpolation

public extension String.StringInterpolation {
    mutating func appendInterpolation(stickerPackColumn column: StickerPackRecord.CodingKeys) {
        appendLiteral(StickerPackRecord.columnName(column))
    }
    mutating func appendInterpolation(stickerPackColumnFullyQualified column: StickerPackRecord.CodingKeys) {
        appendLiteral(StickerPackRecord.columnName(column, fullyQualified: true))
    }
}

// MARK: - Deserialization

// TODO: Rework metadata to not include, for example, columns, column indices.
extension StickerPack {
    // This method defines how to deserialize a model, given a
    // database row.  The recordType column is used to determine
    // the corresponding model class.
    class func fromRecord(_ record: StickerPackRecord) throws -> StickerPack {

        guard let recordId = record.id else {
            throw SDSError.invalidValue
        }

        switch record.recordType {
        case .stickerPack:

            let uniqueId: String = record.uniqueId
            let author: String? = record.author
            let coverSerialized: Data = record.cover
            let cover: StickerPackItem = try SDSDeserialization.unarchive(coverSerialized, name: "cover")
            let dateCreated: Date = record.dateCreated
            let infoSerialized: Data = record.info
            let info: StickerPackInfo = try SDSDeserialization.unarchive(infoSerialized, name: "info")
            let isInstalled: Bool = record.isInstalled
            let itemsSerialized: Data = record.items
            let items: [StickerPackItem] = try SDSDeserialization.unarchive(itemsSerialized, name: "items")
            let title: String? = record.title

            return StickerPack(uniqueId: uniqueId,
                               author: author,
                               cover: cover,
                               dateCreated: dateCreated,
                               info: info,
                               isInstalled: isInstalled,
                               items: items,
                               title: title)

        default:
            owsFailDebug("Unexpected record type: \(record.recordType)")
            throw SDSError.invalidValue
        }
    }
}

// MARK: - SDSModel

extension StickerPack: SDSModel {
    public var serializer: SDSSerializer {
        // Any subclass can be cast to it's superclass,
        // so the order of this switch statement matters.
        // We need to do a "depth first" search by type.
        switch self {
        default:
            return StickerPackSerializer(model: self)
        }
    }

    public func asRecord() throws -> SDSRecord {
        return try serializer.asRecord()
    }

    public var sdsTableName: String {
        return StickerPackRecord.databaseTableName
    }

    public static var table: SDSTableMetadata {
        return StickerPackSerializer.table
    }
}

// MARK: - Table Metadata

extension StickerPackSerializer {

    // This defines all of the columns used in the table
    // where this model (and any subclasses) are persisted.
    static let idColumn = SDSColumnMetadata(columnName: "id", columnType: .primaryKey, columnIndex: 0)
    static let recordTypeColumn = SDSColumnMetadata(columnName: "recordType", columnType: .int64, columnIndex: 1)
    static let uniqueIdColumn = SDSColumnMetadata(columnName: "uniqueId", columnType: .unicodeString, columnIndex: 2)
    // Base class properties
    static let authorColumn = SDSColumnMetadata(columnName: "author", columnType: .unicodeString, isOptional: true, columnIndex: 3)
    static let coverColumn = SDSColumnMetadata(columnName: "cover", columnType: .blob, columnIndex: 4)
    static let dateCreatedColumn = SDSColumnMetadata(columnName: "dateCreated", columnType: .int64, columnIndex: 5)
    static let infoColumn = SDSColumnMetadata(columnName: "info", columnType: .blob, columnIndex: 6)
    static let isInstalledColumn = SDSColumnMetadata(columnName: "isInstalled", columnType: .int, columnIndex: 7)
    static let itemsColumn = SDSColumnMetadata(columnName: "items", columnType: .blob, columnIndex: 8)
    static let titleColumn = SDSColumnMetadata(columnName: "title", columnType: .unicodeString, isOptional: true, columnIndex: 9)

    // TODO: We should decide on a naming convention for
    //       tables that store models.
    public static let table = SDSTableMetadata(collection: StickerPack.collection(),
                                               tableName: "model_StickerPack",
                                               columns: [
        idColumn,
        recordTypeColumn,
        uniqueIdColumn,
        authorColumn,
        coverColumn,
        dateCreatedColumn,
        infoColumn,
        isInstalledColumn,
        itemsColumn,
        titleColumn
        ])
}

// MARK: - Save/Remove/Update

@objc
public extension StickerPack {
    func anyInsert(transaction: SDSAnyWriteTransaction) {
        sdsSave(saveMode: .insert, transaction: transaction)
    }

    // This method is private; we should never use it directly.
    // Instead, use anyUpdate(transaction:block:), so that we
    // use the "update with" pattern.
    private func anyUpdate(transaction: SDSAnyWriteTransaction) {
        sdsSave(saveMode: .update, transaction: transaction)
    }

    @available(*, deprecated, message: "Use anyInsert() or anyUpdate() instead.")
    func anyUpsert(transaction: SDSAnyWriteTransaction) {
        let isInserting: Bool
        if StickerPack.anyFetch(uniqueId: uniqueId, transaction: transaction) != nil {
            isInserting = false
        } else {
            isInserting = true
        }
        sdsSave(saveMode: isInserting ? .insert : .update, transaction: transaction)
    }

    // This method is used by "updateWith..." methods.
    //
    // This model may be updated from many threads. We don't want to save
    // our local copy (this instance) since it may be out of date.  We also
    // want to avoid re-saving a model that has been deleted.  Therefore, we
    // use "updateWith..." methods to:
    //
    // a) Update a property of this instance.
    // b) If a copy of this model exists in the database, load an up-to-date copy,
    //    and update and save that copy.
    // b) If a copy of this model _DOES NOT_ exist in the database, do _NOT_ save
    //    this local instance.
    //
    // After "updateWith...":
    //
    // a) Any copy of this model in the database will have been updated.
    // b) The local property on this instance will always have been updated.
    // c) Other properties on this instance may be out of date.
    //
    // All mutable properties of this class have been made read-only to
    // prevent accidentally modifying them directly.
    //
    // This isn't a perfect arrangement, but in practice this will prevent
    // data loss and will resolve all known issues.
    func anyUpdate(transaction: SDSAnyWriteTransaction, block: (StickerPack) -> Void) {

        block(self)

        guard let dbCopy = type(of: self).anyFetch(uniqueId: uniqueId,
                                                   transaction: transaction) else {
            return
        }

        // Don't apply the block twice to the same instance.
        // It's at least unnecessary and actually wrong for some blocks.
        // e.g. `block: { $0 in $0.someField++ }`
        if dbCopy !== self {
            block(dbCopy)
        }

        dbCopy.anyUpdate(transaction: transaction)
    }

    func anyRemove(transaction: SDSAnyWriteTransaction) {
        sdsRemove(transaction: transaction)
    }

    func anyReload(transaction: SDSAnyReadTransaction) {
        anyReload(transaction: transaction, ignoreMissing: false)
    }

    func anyReload(transaction: SDSAnyReadTransaction, ignoreMissing: Bool) {
        guard let latestVersion = type(of: self).anyFetch(uniqueId: uniqueId, transaction: transaction) else {
            if !ignoreMissing {
                owsFailDebug("`latest` was unexpectedly nil")
            }
            return
        }

        setValuesForKeys(latestVersion.dictionaryValue)
    }
}

// MARK: - StickerPackCursor

@objc
public class StickerPackCursor: NSObject {
    private let cursor: RecordCursor<StickerPackRecord>?

    init(cursor: RecordCursor<StickerPackRecord>?) {
        self.cursor = cursor
    }

    public func next() throws -> StickerPack? {
        guard let cursor = cursor else {
            return nil
        }
        guard let record = try cursor.next() else {
            return nil
        }
        return try StickerPack.fromRecord(record)
    }

    public func all() throws -> [StickerPack] {
        var result = [StickerPack]()
        while true {
            guard let model = try next() else {
                break
            }
            result.append(model)
        }
        return result
    }
}

// MARK: - Obj-C Fetch

// TODO: We may eventually want to define some combination of:
//
// * fetchCursor, fetchOne, fetchAll, etc. (ala GRDB)
// * Optional "where clause" parameters for filtering.
// * Async flavors with completions.
//
// TODO: I've defined flavors that take a read transaction.
//       Or we might take a "connection" if we end up having that class.
@objc
public extension StickerPack {
    class func grdbFetchCursor(transaction: GRDBReadTransaction) -> StickerPackCursor {
        let database = transaction.database
        do {
            let cursor = try StickerPackRecord.fetchCursor(database)
            return StickerPackCursor(cursor: cursor)
        } catch {
            owsFailDebug("Read failed: \(error)")
            return StickerPackCursor(cursor: nil)
        }
    }

    // Fetches a single model by "unique id".
    class func anyFetch(uniqueId: String,
                        transaction: SDSAnyReadTransaction) -> StickerPack? {
        assert(uniqueId.count > 0)

        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            return StickerPack.ydb_fetch(uniqueId: uniqueId, transaction: ydbTransaction)
        case .grdbRead(let grdbTransaction):
            let sql = "SELECT * FROM \(StickerPackRecord.databaseTableName) WHERE \(stickerPackColumn: .uniqueId) = ?"
            return grdbFetchOne(sql: sql, arguments: [uniqueId], transaction: grdbTransaction)
        }
    }

    // Traverses all records.
    // Records are not visited in any particular order.
    // Traversal aborts if the visitor returns false.
    class func anyEnumerate(transaction: SDSAnyReadTransaction, block: @escaping (StickerPack, UnsafeMutablePointer<ObjCBool>) -> Void) {
        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            StickerPack.ydb_enumerateCollectionObjects(with: ydbTransaction) { (object, stop) in
                guard let value = object as? StickerPack else {
                    owsFailDebug("unexpected object: \(type(of: object))")
                    return
                }
                block(value, stop)
            }
        case .grdbRead(let grdbTransaction):
            do {
                let cursor = StickerPack.grdbFetchCursor(transaction: grdbTransaction)
                var stop: ObjCBool = false
                while let value = try cursor.next() {
                    block(value, &stop)
                    guard !stop.boolValue else {
                        break
                    }
                }
            } catch let error {
                owsFailDebug("Couldn't fetch models: \(error)")
            }
        }
    }

    // Traverses all records' unique ids.
    // Records are not visited in any particular order.
    // Traversal aborts if the visitor returns false.
    class func anyEnumerateUniqueIds(transaction: SDSAnyReadTransaction, block: @escaping (String, UnsafeMutablePointer<ObjCBool>) -> Void) {
        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            ydbTransaction.enumerateKeys(inCollection: StickerPack.collection()) { (uniqueId, stop) in
                block(uniqueId, stop)
            }
        case .grdbRead(let grdbTransaction):
            grdbEnumerateUniqueIds(transaction: grdbTransaction,
                                   sql: """
                    SELECT \(stickerPackColumn: .uniqueId)
                    FROM \(StickerPackRecord.databaseTableName)
                """,
                block: block)
        }
    }

    // Does not order the results.
    class func anyFetchAll(transaction: SDSAnyReadTransaction) -> [StickerPack] {
        var result = [StickerPack]()
        anyEnumerate(transaction: transaction) { (model, _) in
            result.append(model)
        }
        return result
    }

    // Does not order the results.
    class func anyAllUniqueIds(transaction: SDSAnyReadTransaction) -> [String] {
        var result = [String]()
        anyEnumerateUniqueIds(transaction: transaction) { (uniqueId, _) in
            result.append(uniqueId)
        }
        return result
    }

    class func anyCount(transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            return ydbTransaction.numberOfKeys(inCollection: StickerPack.collection())
        case .grdbRead(let grdbTransaction):
            return StickerPackRecord.ows_fetchCount(grdbTransaction.database)
        }
    }

    // WARNING: Do not use this method for any models which do cleanup
    //          in their anyWillRemove(), anyDidRemove() methods.
    class func anyRemoveAllWithoutInstantation(transaction: SDSAnyWriteTransaction) {
        switch transaction.writeTransaction {
        case .yapWrite(let ydbTransaction):
            ydbTransaction.removeAllObjects(inCollection: StickerPack.collection())
        case .grdbWrite(let grdbTransaction):
            do {
                try StickerPackRecord.deleteAll(grdbTransaction.database)
            } catch {
                owsFailDebug("deleteAll() failed: \(error)")
            }
        }

        if shouldBeIndexedForFTS {
            FullTextSearchFinder.allModelsWereRemoved(collection: collection(), transaction: transaction)
        }
    }

    class func anyRemoveAllWithInstantation(transaction: SDSAnyWriteTransaction) {
        // To avoid mutationDuringEnumerationException, we need
        // to remove the instances outside the enumeration.
        let uniqueIds = anyAllUniqueIds(transaction: transaction)
        for uniqueId in uniqueIds {
            guard let instance = anyFetch(uniqueId: uniqueId, transaction: transaction) else {
                owsFailDebug("Missing instance.")
                continue
            }
            instance.anyRemove(transaction: transaction)
        }

        if shouldBeIndexedForFTS {
            FullTextSearchFinder.allModelsWereRemoved(collection: collection(), transaction: transaction)
        }
    }

    class func anyExists(uniqueId: String,
                        transaction: SDSAnyReadTransaction) -> Bool {
        assert(uniqueId.count > 0)

        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            return ydbTransaction.hasObject(forKey: uniqueId, inCollection: StickerPack.collection())
        case .grdbRead(let grdbTransaction):
            let sql = "SELECT EXISTS ( SELECT 1 FROM \(StickerPackRecord.databaseTableName) WHERE \(stickerPackColumn: .uniqueId) = ? )"
            let arguments: StatementArguments = [uniqueId]
            return try! Bool.fetchOne(grdbTransaction.database, sql: sql, arguments: arguments) ?? false
        }
    }
}

// MARK: - Swift Fetch

public extension StickerPack {
    class func grdbFetchCursor(sql: String,
                               arguments: StatementArguments = StatementArguments(),
                               transaction: GRDBReadTransaction) -> StickerPackCursor {
        do {
            let sqlRequest = SQLRequest<Void>(sql: sql, arguments: arguments, cached: true)
            let cursor = try StickerPackRecord.fetchCursor(transaction.database, sqlRequest)
            return StickerPackCursor(cursor: cursor)
        } catch {
            Logger.error("sql: \(sql)")
            owsFailDebug("Read failed: \(error)")
            return StickerPackCursor(cursor: nil)
        }
    }

    class func grdbFetchOne(sql: String,
                            arguments: StatementArguments = StatementArguments(),
                            transaction: GRDBReadTransaction) -> StickerPack? {
        assert(sql.count > 0)

        do {
            let sqlRequest = SQLRequest<Void>(sql: sql, arguments: arguments, cached: true)
            guard let record = try StickerPackRecord.fetchOne(transaction.database, sqlRequest) else {
                return nil
            }

            return try StickerPack.fromRecord(record)
        } catch {
            owsFailDebug("error: \(error)")
            return nil
        }
    }
}

// MARK: - SDSSerializer

// The SDSSerializer protocol specifies how to insert and update the
// row that corresponds to this model.
class StickerPackSerializer: SDSSerializer {

    private let model: StickerPack
    public required init(model: StickerPack) {
        self.model = model
    }

    // MARK: - Record

    func asRecord() throws -> SDSRecord {
        let id: Int64? = nil

        let recordType: SDSRecordType = .stickerPack
        let uniqueId: String = model.uniqueId

        // Base class properties
        let author: String? = model.author
        let cover: Data = requiredArchive(model.cover)
        let dateCreated: Date = model.dateCreated
        let info: Data = requiredArchive(model.info)
        let isInstalled: Bool = model.isInstalled
        let items: Data = requiredArchive(model.items)
        let title: String? = model.title

        return StickerPackRecord(id: id, recordType: recordType, uniqueId: uniqueId, author: author, cover: cover, dateCreated: dateCreated, info: info, isInstalled: isInstalled, items: items, title: title)
    }
}