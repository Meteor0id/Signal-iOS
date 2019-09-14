//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDBCipher

protocol SDSDatabaseQueue {
    associatedtype ReadTransaction
    associatedtype WriteTransaction
    func read(block: @escaping (ReadTransaction) -> Void)
    func write(block: @escaping (WriteTransaction) -> Void)
}

// MARK: -

// Serializes all transactions done using this queue.
@objc
public class GRDBDatabaseQueue: NSObject, SDSDatabaseQueue {
    private let storageAdapter: GRDBDatabaseStorageAdapter

    private let serialQueue = DispatchQueue(label: "org.signal.grdbDatabaseQueue")

    init(storageAdapter: GRDBDatabaseStorageAdapter) {
        self.storageAdapter = storageAdapter
    }

    @objc
    public func read(block: @escaping (GRDBReadTransaction) -> Void) {
        serialQueue.sync {
            do {
                try storageAdapter.read(block: block)
            } catch {
                owsFail("fatal error: \(error)")
            }
        }
    }

    @objc
    public func write(block: @escaping (GRDBWriteTransaction) -> Void) {
        serialQueue.sync {
            do {
                try storageAdapter.write(block: block)
            } catch {
                owsFail("fatal error: \(error)")
            }
        }
    }

    func asAnyQueue(crossProcess: SDSCrossProcess) -> SDSAnyDatabaseQueue {
        return SDSAnyDatabaseQueue(grdbDatabaseQueue: self, crossProcess: crossProcess)
    }
}

// MARK: -

class YAPDBDatabaseQueue: SDSDatabaseQueue {
    private let databaseConnection: YapDatabaseConnection

    public init(databaseConnection: YapDatabaseConnection) {
        // We use DatabaseQueue's in places where we're especially concerned
        // about data consistency. To help ensure that our instances aren't being
        // mutated elsewhere we disable object caching on the connection.
        databaseConnection.objectCacheEnabled = false
        self.databaseConnection = databaseConnection
    }

    func read(block: @escaping (YapDatabaseReadTransaction) -> Void) {
        databaseConnection.read(block)
    }

    func write(block: @escaping (YapDatabaseReadWriteTransaction) -> Void) {
        databaseConnection.readWrite(block)
    }

    func asAnyQueue(crossProcess: SDSCrossProcess) -> SDSAnyDatabaseQueue {
        return SDSAnyDatabaseQueue(yapDatabaseQueue: self, crossProcess: crossProcess)
    }
}

// MARK: -

@objc
public class SDSAnyDatabaseQueue: SDSTransactable, SDSDatabaseQueue {
    enum SomeDatabaseQueue {
        case yap(_ yapQueue: YAPDBDatabaseQueue)
        case grdb(_ grdbQueue: GRDBDatabaseQueue)
    }

    private let someDatabaseQueue: SomeDatabaseQueue

    private let crossProcess: SDSCrossProcess

    init(yapDatabaseQueue: YAPDBDatabaseQueue, crossProcess: SDSCrossProcess) {
        someDatabaseQueue = .yap(yapDatabaseQueue)

        self.crossProcess = crossProcess
    }

    init(grdbDatabaseQueue: GRDBDatabaseQueue, crossProcess: SDSCrossProcess) {
        someDatabaseQueue = .grdb(grdbDatabaseQueue)

        self.crossProcess = crossProcess
    }

    @objc
    public override func read(block: @escaping (SDSAnyReadTransaction) -> Void) {
        switch someDatabaseQueue {
        case .yap(let yapDatabaseQueue):
            yapDatabaseQueue.read { block($0.asAnyRead) }
        case .grdb(let grdbDatabaseQueue):
            grdbDatabaseQueue.read { block($0.asAnyRead) }
        }
    }

    @objc
    public override func write(block: @escaping (SDSAnyWriteTransaction) -> Void) {
        switch someDatabaseQueue {
        case .yap(let yapDatabaseQueue):
            yapDatabaseQueue.write { block($0.asAnyWrite) }
        case .grdb(let grdbDatabaseQueue):
            grdbDatabaseQueue.write { block($0.asAnyWrite) }
        }

        crossProcess.notifyChangedAsync()
    }
}
