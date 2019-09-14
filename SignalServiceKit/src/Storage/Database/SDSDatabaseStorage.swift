//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDBCipher

@objc
public class SDSDatabaseStorage: SDSTransactable {

    @objc
    public static var shared: SDSDatabaseStorage {
        return SSKEnvironment.shared.databaseStorage
    }

    static public var shouldLogDBQueries: Bool = true

    private var hasPendingCrossProcessWrite = false

    private let crossProcess = SDSCrossProcess()

    // MARK: - Initialization / Setup

    @objc
    public var yapPrimaryStorage: OWSPrimaryStorage {
        return yapStorage.storage
    }

    lazy var yapStorage = type(of: self).createYapStorage()

    private var _grdbStorage: GRDBDatabaseStorageAdapter?

    @objc
    public var grdbStorage: GRDBDatabaseStorageAdapter {
        if let storage = _grdbStorage {
            return storage
        } else {
            let storage = createGrdbStorage()
            _grdbStorage = storage
            return storage
        }
    }

    @objc
    internal func clearGRDBStorageForTests() {
        _grdbStorage = nil
    }

    @objc
    override init() {
        super.init()

        addObservers()
    }

    private func addObservers() {
        // Cross process writes
        if useGRDB {
            crossProcess.callback = { [weak self] in
                DispatchQueue.main.async {
                    self?.handleCrossProcessWrite()
                }
            }

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(didBecomeActive),
                                                   name: UIApplication.didBecomeActiveNotification,
                                                   object: nil)
        }
    }

    deinit {
        Logger.verbose("")

        NotificationCenter.default.removeObserver(self)
    }

    func createGrdbStorage() -> GRDBDatabaseStorageAdapter {
        assert(self.useGRDB || CurrentAppContext().isRunningTests)

        let baseDir: URL

        if FeatureFlags.grdbMigratesFreshDBEveryLaunch {
            baseDir = URL(fileURLWithPath: OWSFileSystem.appSharedDataDirectoryPath(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        } else {
            baseDir = URL(fileURLWithPath: OWSFileSystem.appSharedDataDirectoryPath(), isDirectory: true)
        }
        let dbDir: URL = baseDir.appendingPathComponent("grdb_database", isDirectory: true)

        // crash if we can't read the DB.
        return try! GRDBDatabaseStorageAdapter(dbDir: dbDir)
    }

    class func createYapStorage() -> YAPDBStorageAdapter {
        let yapPrimaryStorage = OWSPrimaryStorage.init(storage: ())
        return YAPDBStorageAdapter(storage: yapPrimaryStorage)
    }

    // MARK: -

    var useGRDB: Bool = FeatureFlags.useGRDB

    @objc
    public func newDatabaseQueue() -> SDSAnyDatabaseQueue {
        if useGRDB {
            return grdbStorage.newDatabaseQueue().asAnyQueue(crossProcess: crossProcess)
        } else {
            return yapStorage.newDatabaseQueue().asAnyQueue(crossProcess: crossProcess)
        }
    }

    // GRDB TODO: add read/write flavors
    public func uiReadThrows(block: @escaping (SDSAnyReadTransaction) throws -> Void) throws {
        if useGRDB {
            try grdbStorage.uiReadThrows { transaction in
                try autoreleasepool {
                    try block(transaction.asAnyRead)
                }
            }
        } else {
            try yapStorage.uiReadThrows { transaction in
                try block(transaction.asAnyRead)
            }
        }
    }

    @objc
    public func uiRead(block: @escaping (SDSAnyReadTransaction) -> Void) {
        if useGRDB {
            do {
                try grdbStorage.uiRead { transaction in
                    block(transaction.asAnyRead)
                }
            } catch {
                owsFail("error: \(error)")
            }
        } else {
            yapStorage.uiRead { transaction in
                block(transaction.asAnyRead)
            }
        }
    }

    @objc
    public override func read(block: @escaping (SDSAnyReadTransaction) -> Void) {
        if useGRDB {
            do {
                try grdbStorage.read { transaction in
                    block(transaction.asAnyRead)
                }
            } catch {
                owsFail("error: \(error)")
            }
        } else {
            yapStorage.read { transaction in
                block(transaction.asAnyRead)
            }
        }
    }

    @objc
    public override func write(block: @escaping (SDSAnyWriteTransaction) -> Void) {
        if useGRDB {
            do {
                try grdbStorage.write { transaction in
                    block(transaction.asAnyWrite)
                }
            } catch {
                owsFail("error: \(error)")
            }
        } else {
            yapStorage.write { transaction in
                block(transaction.asAnyWrite)
            }
        }

        crossProcess.notifyChangedAsync()
    }

    // MARK: - Value Methods

    public func uiReadReturningResult<T>(block: @escaping (SDSAnyReadTransaction) -> T) -> T {
        var value: T!
        uiRead { (transaction) in
            value = block(transaction)
        }
        return value
    }

    public func readReturningResult<T>(block: @escaping (SDSAnyReadTransaction) -> T) -> T {
        var value: T!
        read { (transaction) in
            value = block(transaction)
        }
        return value
    }

    public func writeReturningResult<T>(block: @escaping (SDSAnyWriteTransaction) -> T) -> T {
        var value: T!
        write { (transaction) in
            value = block(transaction)
        }
        return value
    }

    // MARK: - Touch

    @objc(touchInteraction:transaction:)
    public func touch(interaction: TSInteraction, transaction: SDSAnyWriteTransaction) {
        switch transaction.writeTransaction {
        case .yapWrite(let yap):
            let uniqueId = interaction.uniqueId
            yap.touchObject(forKey: uniqueId, inCollection: TSInteraction.collection())
        case .grdbWrite(let grdb):
            guard let conversationViewDatabaseObserver = grdbStorage.conversationViewDatabaseObserver else {
                if AppReadiness.isAppReady() {
                    owsFailDebug("conversationViewDatabaseObserver was unexpectedly nil")
                }
                return
            }
            conversationViewDatabaseObserver.touch(interaction: interaction, transaction: grdb)
        }
    }

    @objc(touchThread:transaction:)
    public func touch(thread: TSThread, transaction: SDSAnyWriteTransaction) {
        switch transaction.writeTransaction {
        case .yapWrite(let yap):
            let uniqueId = thread.uniqueId
            yap.touchObject(forKey: uniqueId, inCollection: TSThread.collection())
        case .grdbWrite(let grdb):
            guard let homeViewDatabaseObserver = grdbStorage.homeViewDatabaseObserver else {
                if AppReadiness.isAppReady() {
                    owsFailDebug("homeViewDatabaseObserver was unexpectedly nil")
                }
                return
            }
            homeViewDatabaseObserver.touch(thread: thread, transaction: grdb)
        }
    }

    @objc(touchThreadId:transaction:)
    public func touch(threadId: String, transaction: SDSAnyWriteTransaction) {
        switch transaction.writeTransaction {
        case .yapWrite(let yap):
            yap.touchObject(forKey: threadId, inCollection: TSThread.collection())
        case .grdbWrite(let grdb):
            guard let homeViewDatabaseObserver = grdbStorage.homeViewDatabaseObserver else {
                if AppReadiness.isAppReady() {
                    owsFailDebug("homeViewDatabaseObserver was unexpectedly nil")
                }
                return
            }
            homeViewDatabaseObserver.touch(threadId: threadId, transaction: grdb)
        }
    }

    // MARK: - Cross Process Notifications

    private func handleCrossProcessWrite() {
        AssertIsOnMainThread()

        Logger.info("")

        guard CurrentAppContext().isMainApp else {
            return
        }

        //
        if CurrentAppContext().isMainAppAndActive {
            // If already active, update immediately.
            postCrossProcessNotification()
        } else {
            // If not active, set flag to update when we become active.
            hasPendingCrossProcessWrite = true
        }
    }

    @objc func didBecomeActive() {
        AssertIsOnMainThread()

        guard hasPendingCrossProcessWrite else {
            return
        }
        hasPendingCrossProcessWrite = false

        postCrossProcessNotification()
    }

    @objc
    public static let didReceiveCrossProcessNotification = Notification.Name("didReceiveCrossProcessNotification")

    private func postCrossProcessNotification() {
        Logger.info("")

        // TODO: The observers of this notification will inevitably do
        //       expensive work.  It'd be nice to only fire this event
        //       if this had any effect, if the state of the database
        //       has changed.
        //
        //       In the meantime, most (all?) cross process write notifications
        //       will be delivered to the main app while it is inactive. By
        //       de-bouncing notifications while inactive and only updating
        //       once when we become active, we should be able to effectively
        //       skip most of the perf cost.
        NotificationCenter.default.postNotificationNameAsync(SDSDatabaseStorage.didReceiveCrossProcessNotification, object: nil)
    }

    // MARK: - Misc.

    @objc
    public func logFileSizes() {
        Logger.info("Database : \(databaseFileSize)")
        Logger.info("\t WAL file size: \(databaseWALFileSize)")
        Logger.info("\t SHM file size: \(databaseSHMFileSize)")
    }
}

// MARK: -

protocol SDSDatabaseStorageAdapter {
    associatedtype ReadTransaction
    associatedtype WriteTransaction
    func uiRead(block: @escaping (ReadTransaction) -> Void) throws
    func read(block: @escaping (ReadTransaction) -> Void) throws
    func write(block: @escaping (WriteTransaction) -> Void) throws
}

// MARK: -

struct YAPDBStorageAdapter {
    let storage: OWSPrimaryStorage
}

// MARK: -

extension YAPDBStorageAdapter: SDSDatabaseStorageAdapter {
    func uiReadThrows(block: @escaping (YapDatabaseReadTransaction) throws -> Void) throws {
        var errorToRaise: Error?
        storage.uiDatabaseConnection.read { yapTransaction in
            do {
                try block(yapTransaction)
            } catch {
                errorToRaise = error
            }
        }
        if let error = errorToRaise {
            throw error
        }
    }

    func uiRead(block: @escaping (YapDatabaseReadTransaction) -> Void) {
        storage.uiDatabaseConnection.read { yapTransaction in
            block(yapTransaction)
        }
    }

    func read(block: @escaping (YapDatabaseReadTransaction) -> Void) {
        storage.dbReadConnection.read { yapTransaction in
            block(yapTransaction)
        }
    }

    func write(block: @escaping (YapDatabaseReadWriteTransaction) -> Void) {
        storage.dbReadWriteConnection.readWrite { yapTransaction in
            block(yapTransaction)
        }
    }

    func newDatabaseQueue() -> YAPDBDatabaseQueue {
        return YAPDBDatabaseQueue(databaseConnection: storage.newDatabaseConnection())
    }
}

// MARK: -

@objc
public class GRDBDatabaseStorageAdapter: NSObject {

    private let dbURL: URL

    private let keyServiceName: String = "TSKeyChainService"
    private let keyName: String = "OWSDatabaseCipherKeySpec"

    private let storage: GRDBStorage

    public var pool: DatabasePool {
        return storage.pool
    }

    init(dbDir: URL) throws {
        OWSFileSystem.ensureDirectoryExists(dbDir.path)

        dbURL = dbDir.appendingPathComponent("signal.sqlite", isDirectory: false)
        storage = try GRDBStorage(dbURL: dbURL, keyServiceName: keyServiceName, keyName: keyName)

        super.init()

        // Schema migrations are currently simple and fast. If they grow to become long-running,
        // we'll want to ensure that it doesn't block app launch to avoid 0x8badfood.
        try migrator.migrate(pool)

        AppReadiness.runNowOrWhenAppWillBecomeReady {
            BenchEventStart(title: "GRDB Setup", eventId: "GRDB Setup")
            defer { BenchEventComplete(eventId: "GRDB Setup") }
            do {
                try self.setup()
                try self.setupUIDatabase()
            } catch {
                owsFail("unable to setup database: \(error)")
            }
        }
    }

    func newDatabaseQueue() -> GRDBDatabaseQueue {
        return GRDBDatabaseQueue(storageAdapter: self)
    }

    public func add(function: DatabaseFunction) {
        pool.add(function: function)
    }

    lazy var migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("create initial schema") { db in
            try SDSKeyValueStore.table.createTable(database: db)

            try TSThreadSerializer.table.createTable(database: db)
            try TSInteractionSerializer.table.createTable(database: db)
            try StickerPackSerializer.table.createTable(database: db)
            try InstalledStickerSerializer.table.createTable(database: db)
            try KnownStickerPackSerializer.table.createTable(database: db)
            try TSAttachmentSerializer.table.createTable(database: db)
            try SSKJobRecordSerializer.table.createTable(database: db)
            try OWSMessageContentJobSerializer.table.createTable(database: db)
            try OWSRecipientIdentitySerializer.table.createTable(database: db)
            try ExperienceUpgradeSerializer.table.createTable(database: db)
            try OWSDisappearingMessagesConfigurationSerializer.table.createTable(database: db)
            try SignalRecipientSerializer.table.createTable(database: db)
            try SignalAccountSerializer.table.createTable(database: db)
            try OWSUserProfileSerializer.table.createTable(database: db)
            try TSRecipientReadReceiptSerializer.table.createTable(database: db)
            try OWSLinkedDeviceReadReceiptSerializer.table.createTable(database: db)
            try OWSDeviceSerializer.table.createTable(database: db)
            try OWSContactQuerySerializer.table.createTable(database: db)

            try db.create(index: "index_interactions_on_id_and_threadUniqueId",
                          on: InteractionRecord.databaseTableName,
                          columns: [
                            InteractionRecord.columnName(.id),
                            InteractionRecord.columnName(.threadUniqueId)
                ])
            try db.create(index: "index_interactions_on_id_and_timestamp",
                          on: InteractionRecord.databaseTableName,
                          columns: [
                            InteractionRecord.columnName(.id),
                            InteractionRecord.columnName(.timestamp)
                ])
            try db.create(index: "index_jobs_on_label",
                          on: JobRecordRecord.databaseTableName,
                          columns: [JobRecordRecord.columnName(.label)])
            try db.create(index: "index_interactions_on_view_once",
                          on: InteractionRecord.databaseTableName,
                          columns: [
                            InteractionRecord.columnName(.isViewOnceMessage),
                            InteractionRecord.columnName(.isViewOnceComplete)
                ])
            try db.create(index: "index_key_value_store_on_collection_and_key",
                          on: SDSKeyValueStore.table.tableName,
                          columns: [
                            SDSKeyValueStore.collectionColumn.columnName,
                            SDSKeyValueStore.keyColumn.columnName
                ])

            // Media Gallery Indices
            try db.create(index: "index_attachments_on_albumMessageId",
                          on: AttachmentRecord.databaseTableName,
                          columns: [AttachmentRecord.columnName(.albumMessageId),
                                    AttachmentRecord.columnName(.recordType)])

            try db.create(index: "index_interactions_on_uniqueId_and_threadUniqueId",
                          on: InteractionRecord.databaseTableName,
                          columns: [
                            InteractionRecord.columnName(.uniqueId),
                            InteractionRecord.columnName(.threadUniqueId)
                ])

            // Signal Account Indices
            try db.create(
                index: "index_signal_accounts_on_recipientPhoneNumber",
                on: SignalAccountRecord.databaseTableName,
                columns: [SignalAccountRecord.columnName(.recipientPhoneNumber)]
            )

            try db.create(
                index: "index_signal_accounts_on_recipientUUID",
                on: SignalAccountRecord.databaseTableName,
                columns: [SignalAccountRecord.columnName(.recipientUUID)]
            )

            // Signal Recipient Indices
            try db.create(
                index: "index_signal_recipients_on_recipientPhoneNumber",
                on: SignalRecipientRecord.databaseTableName,
                columns: [SignalRecipientRecord.columnName(.recipientPhoneNumber)]
            )

            try db.create(
                index: "index_signal_recipients_on_recipientUUID",
                on: SignalRecipientRecord.databaseTableName,
                columns: [SignalRecipientRecord.columnName(.recipientUUID)]
            )

            // Thread Indices
            try db.create(
                index: "index_thread_on_contactPhoneNumber",
                on: ThreadRecord.databaseTableName,
                columns: [ThreadRecord.columnName(.contactPhoneNumber)]
            )

            try db.create(
                index: "index_tsthread_on_contactUUID",
                on: ThreadRecord.databaseTableName,
                columns: [ThreadRecord.columnName(.contactUUID)]
            )

            // User Profile
            try db.create(
                index: "index_user_profiles_on_recipientPhoneNumber",
                on: UserProfileRecord.databaseTableName,
                columns: [UserProfileRecord.columnName(.recipientPhoneNumber)]
            )

            try db.create(
                index: "index_user_profiles_on_recipientUUID",
                on: UserProfileRecord.databaseTableName,
                columns: [UserProfileRecord.columnName(.recipientUUID)]
            )

            // Linked Device Read Receipts
            try db.create(
                index: "index_linkedDeviceReadReceipt_on_senderPhoneNumberAndTimestamp",
                on: LinkedDeviceReadReceiptRecord.databaseTableName,
                columns: [LinkedDeviceReadReceiptRecord.columnName(.senderPhoneNumber), LinkedDeviceReadReceiptRecord.columnName(.messageIdTimestamp)]
            )

            try db.create(
                index: "index_linkedDeviceReadReceipt_on_senderUUIDAndTimestamp",
                on: LinkedDeviceReadReceiptRecord.databaseTableName,
                columns: [LinkedDeviceReadReceiptRecord.columnName(.senderUUID), LinkedDeviceReadReceiptRecord.columnName(.messageIdTimestamp)]
            )

            // Interaction Finder
            try db.create(index: "index_interactions_on_timestamp_sourceDeviceId_and_authorUUID",
                          on: InteractionRecord.databaseTableName,
                          columns: [
                            InteractionRecord.columnName(.timestamp),
                            InteractionRecord.columnName(.sourceDeviceId),
                            InteractionRecord.columnName(.authorUUID)
                ])

            try db.create(index: "index_interactions_on_timestamp_sourceDeviceId_and_authorPhoneNumber",
                          on: InteractionRecord.databaseTableName,
                          columns: [
                            InteractionRecord.columnName(.timestamp),
                            InteractionRecord.columnName(.sourceDeviceId),
                            InteractionRecord.columnName(.authorPhoneNumber)
                ])
            try db.create(index: "index_interactions_on_threadUniqueId_and_read",
                          on: InteractionRecord.databaseTableName,
                          columns: [
                            InteractionRecord.columnName(.threadUniqueId),
                            InteractionRecord.columnName(.read)
                ])

            // ContactQuery
            try db.create(index: "index_contact_queries_on_lastQueried",
                          on: ContactQueryRecord.databaseTableName,
                          columns: [
                            ContactQueryRecord.columnName(.lastQueried)
                ])

            try GRDBFullTextSearchFinder.createTables(database: db)
        }
        return migrator
    }()

    // MARK: - Database Snapshot

    private var latestSnapshot: DatabaseSnapshot! {
        return uiDatabaseObserver!.latestSnapshot
    }

    @objc
    public private(set) var uiDatabaseObserver: UIDatabaseObserver?

    @objc
    public private(set) var homeViewDatabaseObserver: HomeViewDatabaseObserver?

    @objc
    public private(set) var conversationViewDatabaseObserver: ConversationViewDatabaseObserver?

    @objc
    public private(set) var mediaGalleryDatabaseObserver: MediaGalleryDatabaseObserver?

    @objc
    public func setupUIDatabase() throws {
        // UIDatabaseObserver is a general purpose observer, whose delegates
        // are notified when things change, but are not given any specific details
        // about the changes.
        let uiDatabaseObserver = try UIDatabaseObserver(pool: pool)
        self.uiDatabaseObserver = uiDatabaseObserver

        // HomeViewDatabaseObserver is built on top of UIDatabaseObserver
        // but includes the details necessary for rendering collection view
        // batch updates.
        let homeViewDatabaseObserver = HomeViewDatabaseObserver()
        self.homeViewDatabaseObserver = homeViewDatabaseObserver
        uiDatabaseObserver.appendSnapshotDelegate(homeViewDatabaseObserver)

        // ConversationViewDatabaseObserver is built on top of UIDatabaseObserver
        // but includes the details necessary for rendering collection view
        // batch updates.
        let conversationViewDatabaseObserver = ConversationViewDatabaseObserver()
        self.conversationViewDatabaseObserver = conversationViewDatabaseObserver
        uiDatabaseObserver.appendSnapshotDelegate(conversationViewDatabaseObserver)

        // MediaGalleryDatabaseObserver is built on top of UIDatabaseObserver
        // but includes the details necessary for rendering collection view
        // batch updates.
        let mediaGalleryDatabaseObserver = MediaGalleryDatabaseObserver()
        self.mediaGalleryDatabaseObserver = mediaGalleryDatabaseObserver
        uiDatabaseObserver.appendSnapshotDelegate(mediaGalleryDatabaseObserver)

        return try pool.write { db in
            db.add(transactionObserver: homeViewDatabaseObserver, extent: Database.TransactionObservationExtent.observerLifetime)
            db.add(transactionObserver: conversationViewDatabaseObserver, extent: Database.TransactionObservationExtent.observerLifetime)
            db.add(transactionObserver: mediaGalleryDatabaseObserver, extent: Database.TransactionObservationExtent.observerLifetime)
        }
    }

    func testing_tearDownUIDatabase() {
        // UIDatabaseObserver is a general purpose observer, whose delegates
        // are notified when things change, but are not given any specific details
        // about the changes.
        self.uiDatabaseObserver = nil
        self.homeViewDatabaseObserver = nil
        self.conversationViewDatabaseObserver = nil
        self.mediaGalleryDatabaseObserver = nil
    }

    func setup() throws {
        GRDBMediaGalleryFinder.setup(storage: self)
    }
}

// MARK: -

extension GRDBDatabaseStorageAdapter: SDSDatabaseStorageAdapter {

    // TODO readThrows/writeThrows flavors
    public func uiReadThrows(block: @escaping (GRDBReadTransaction) throws -> Void) rethrows {
        AssertIsOnMainThread()
        try latestSnapshot.read { database in
            try autoreleasepool {
                try block(GRDBReadTransaction(database: database))
            }
        }
    }

    public func readReturningResultThrows<T>(block: @escaping (GRDBReadTransaction) throws -> T) throws -> T {
        AssertIsOnMainThread()
        return try pool.read { database in
            try autoreleasepool {
                return try block(GRDBReadTransaction(database: database))
            }
        }
    }

    @objc
    public func uiRead(block: @escaping (GRDBReadTransaction) -> Void) throws {
        AssertIsOnMainThread()
        latestSnapshot.read { database in
            autoreleasepool {
                block(GRDBReadTransaction(database: database))
            }
        }
    }

    @objc
    public func read(block: @escaping (GRDBReadTransaction) -> Void) throws {
        try pool.read { database in
            autoreleasepool {
                block(GRDBReadTransaction(database: database))
            }
        }
    }

    @objc
    public func write(block: @escaping (GRDBWriteTransaction) -> Void) throws {
        var transaction: GRDBWriteTransaction!
        try pool.write { database in
            autoreleasepool {
                transaction = GRDBWriteTransaction(database: database)
                block(transaction)
            }
        }
        for (queue, block) in transaction.completions {
            queue.async(execute: block)
        }
    }
}

// MARK: -

private struct GRDBStorage {

    let pool: DatabasePool

    private let dbURL: URL
    private let configuration: Configuration

    init(dbURL: URL, keyServiceName: String, keyName: String) throws {
        self.dbURL = dbURL
        let keyspec = GRDBKeySpecSource(keyServiceName: keyServiceName, keyName: keyName)

        var configuration = Configuration()
        configuration.readonly = false
        configuration.foreignKeysEnabled = true // Default is already true
        configuration.trace = {
            if SDSDatabaseStorage.shouldLogDBQueries {
                print($0)  // Prints all SQL statements
            }
        }
        configuration.label = "Modern (GRDB) Storage"      // Useful when your app opens multiple databases
        configuration.maximumReaderCount = 10   // The default is 5
        configuration.busyMode = .callback({ (retryCount: Int) -> Bool in
            // sleep 50 milliseconds
            let millis = 50
            usleep(useconds_t(millis * 1000))

            Logger.verbose("retryCount: \(retryCount)")
            let accumulatedWait = millis * (retryCount + 1)
            if accumulatedWait > 0, (accumulatedWait % 250) == 0 {
                Logger.warn("Database busy for \(accumulatedWait)ms")
            }

            return true
        })
        configuration.passphraseBlock = { try keyspec.fetchString() }
        configuration.prepareDatabase = { (db: Database) in
            try db.execute(sql: "PRAGMA cipher_plaintext_header_size = 32")
        }
        self.configuration = configuration

        pool = try DatabasePool(path: dbURL.path, configuration: configuration)
        Logger.debug("dbURL: \(dbURL)")

        OWSFileSystem.protectFileOrFolder(atPath: dbURL.path)
    }
}

// MARK: -

private struct GRDBKeySpecSource {
    let keyServiceName: String
    let keyName: String

    func fetchString() throws -> String {
        // Use a raw key spec, where the 96 hexadecimal digits are provided
        // (i.e. 64 hex for the 256 bit key, followed by 32 hex for the 128 bit salt)
        // using explicit BLOB syntax, e.g.:
        //
        // x'98483C6EB40B6C31A448C22A66DED3B5E5E8D5119CAC8327B655C8B5C483648101010101010101010101010101010101'
        let data = try fetchData()

        // 256 bit key + 128 bit salt
        guard data.count == 48 else {
            // crash
            owsFail("unexpected keyspec length")
        }

        let passphrase = "x'\(data.hexadecimalString)'"
        return passphrase
    }

    func fetchData() throws -> Data {
        return try CurrentAppContext().keychainStorage().data(forService: keyServiceName, key: keyName)
    }
}

// MARK: -

@objc
public extension SDSDatabaseStorage {
    var databaseFileSize: UInt64 {
        if useGRDB {
            return grdbStorage.databaseFileSize
        } else {
            return OWSPrimaryStorage.shared().databaseFileSize()
        }
    }

    var databaseWALFileSize: UInt64 {
        if useGRDB {
            return grdbStorage.databaseWALFileSize
        } else {
            return OWSPrimaryStorage.shared().databaseWALFileSize()
        }
    }

    var databaseSHMFileSize: UInt64 {
        if useGRDB {
            return grdbStorage.databaseSHMFileSize
        } else {
            return OWSPrimaryStorage.shared().databaseSHMFileSize()
        }
    }
}

// MARK: -

extension GRDBDatabaseStorageAdapter {
    var databaseFileSize: UInt64 {
        guard let fileSize = OWSFileSystem.fileSize(of: dbURL) else {
            owsFailDebug("Could not determine file size.")
            return 0
        }
        return fileSize.uint64Value
    }

    var databaseWALFileSize: UInt64 {
        guard let fileSize = OWSFileSystem.fileSize(ofPath: dbURL.path + "-shm") else {
            owsFailDebug("Could not determine file size.")
            return 0
        }
        return fileSize.uint64Value
    }

    var databaseSHMFileSize: UInt64 {
        guard let fileSize = OWSFileSystem.fileSize(ofPath: dbURL.path + "-wal") else {
            owsFailDebug("Could not determine file size.")
            return 0
        }
        return fileSize.uint64Value
    }
}
