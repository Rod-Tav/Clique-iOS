import CloudKit
import Foundation

struct SyncedAppData: Codable {
    var photos: [String: SyncedPhoto] = [:]
    var stateSerialization: CKSyncEngine.State.Serialization?
}

/// Thin forwarding delegate that breaks the self-reference cycle in init.
private final class EngineDelegate: CKSyncEngineDelegate {
    nonisolated(unsafe) weak var database: SyncedDatabase?

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
        Task { await database?.handleSyncEvent(event) }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await database?.buildNextBatch(context)
    }
}

/// Actor-isolated database that wraps CKSyncEngine to sync photos across devices.
///
/// Follows Apple's sample-cloudkit-sync-engine pattern. The actor manages all
/// local state and coordinates with CloudKit through the sync engine.
actor SyncedDatabase {

    let container: CKContainer
    let engine: CKSyncEngine
    private var appData: SyncedAppData

    /// Pending record IDs that need to be pushed to the server.
    var pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange] = []

    init(container: CKContainer = CKContainer(identifier: SyncConfiguration.containerIdentifier)) {
        self.container = container
        self.appData = CKStatePersistence.load() ?? SyncedAppData()
        let delegate = EngineDelegate()
        self.engine = CKSyncEngine(
            CKSyncEngine.Configuration(
                database: container.privateCloudDatabase,
                stateSerialization: appData.stateSerialization,
                delegate: delegate
            )
        )
        delegate.database = self
    }

    // MARK: - Public API

    /// Enqueues a photo for upload to CloudKit.
    func enqueuePhoto(_ photo: SyncedPhoto) {
        var mutablePhoto = photo
        mutablePhoto.syncState = .pending
        appData.photos[photo.id] = mutablePhoto

        let zoneID = CKRecordZone.ID(
            zoneName: SyncConfiguration.zoneName(for: photo.cliqueId),
            ownerName: CKCurrentUserDefaultName
        )
        let recordID = CKRecord.ID(recordName: photo.id, zoneID: zoneID)
        let change = CKSyncEngine.PendingRecordZoneChange.saveRecord(recordID)
        pendingRecordZoneChanges.append(change)
        engine.state.add(pendingRecordZoneChanges: [change])

        persistState()
    }

    /// Marks a photo for deletion from CloudKit.
    func deletePhoto(id: String) {
        guard let photo = appData.photos[id] else { return }

        let zoneID = CKRecordZone.ID(
            zoneName: SyncConfiguration.zoneName(for: photo.cliqueId),
            ownerName: CKCurrentUserDefaultName
        )
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let change = CKSyncEngine.PendingRecordZoneChange.deleteRecord(recordID)
        pendingRecordZoneChanges.append(change)
        engine.state.add(pendingRecordZoneChanges: [change])

        appData.photos.removeValue(forKey: id)
        persistState()
    }

    /// Triggers an immediate sync cycle.
    func triggerSync() async throws {
        try await engine.fetchChanges()
    }

    /// Returns the current set of synced photos.
    func getPhotos() -> [String: SyncedPhoto] {
        appData.photos
    }

    /// Returns photos filtered by clique ID.
    func getPhotos(for cliqueId: String) -> [SyncedPhoto] {
        appData.photos.values.filter { $0.cliqueId == cliqueId }
    }

    // MARK: - Sync Event Handling

    func handleSyncEvent(_ event: CKSyncEngine.Event) {
        switch event {
        case .stateUpdate(let stateUpdate):
            handleStateUpdate(stateUpdate)

        case .accountChange(let accountChange):
            handleAccountChange(accountChange)

        case .fetchedRecordZoneChanges(let changes):
            handleFetchedChanges(changes)

        case .sentRecordZoneChanges(let sentChanges):
            handleSentChanges(sentChanges)

        case .fetchedDatabaseChanges(let dbChanges):
            handleFetchedDatabaseChanges(dbChanges)

        case .sentDatabaseChanges:
            break

        case .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges,
             .willSendChanges, .didSendChanges, .didFetchChanges:
            break

        @unknown default:
            break
        }
    }

    func buildNextBatch(
        _ context: CKSyncEngine.SendChangesContext
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pendingChanges = pendingRecordZoneChanges.filter { change in
            scope.contains(change)
        }

        guard !pendingChanges.isEmpty else { return nil }

        let batch = await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { recordID in
            if let photo = await self.appData.photos[recordID.recordName] {
                return await self.buildRecord(for: photo)
            }
            return nil
        }

        // Clear fulfilled pending changes
        let fulfilledSet = Set(pendingChanges)
        pendingRecordZoneChanges.removeAll { fulfilledSet.contains($0) }

        return batch
    }

    // MARK: - Private Event Handlers

    private func handleStateUpdate(_ event: CKSyncEngine.Event.StateUpdate) {
        appData.stateSerialization = event.stateSerialization
        persistState()
    }

    private func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        switch event.changeType {
        case .signIn:
            break
        case .signOut, .switchAccounts:
            appData.photos.removeAll()
            persistState()
        @unknown default:
            break
        }
    }

    private func handleFetchedChanges(_ event: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        for modification in event.modifications {
            let record = modification.record
            let recordID = record.recordID

            if var existingPhoto = appData.photos[recordID.recordName] {
                // Server-wins conflict resolution using userModificationDate
                let serverDate = record["userModificationDate"] as? Date ?? Date.distantPast
                if serverDate >= existingPhoto.userModificationDate {
                    existingPhoto.mergeFromServerRecord(record)
                    appData.photos[recordID.recordName] = existingPhoto
                }
            } else {
                let photo = SyncedPhoto(
                    id: recordID.recordName,
                    cliqueId: record["cliqueId"] as? String ?? "",
                    ownerUserId: record["ownerUserId"] as? String ?? "",
                    ownerUsername: record["ownerUsername"] as? String ?? "",
                    thumbnailData: loadAssetData(record["thumbnail"] as? CKAsset),
                    mediaType: record["mediaType"] as? String ?? "PHOTO",
                    captureDate: record["captureDate"] as? Date ?? Date(),
                    userModificationDate: record["userModificationDate"] as? Date ?? Date(),
                    lastKnownRecordData: SyncedPhoto.encodeSystemFields(of: record),
                    syncState: .synced
                )
                appData.photos[photo.id] = photo
            }
        }

        for deletion in event.deletions {
            appData.photos.removeValue(forKey: deletion.recordID.recordName)
        }

        persistState()
    }

    private func handleSentChanges(_ event: CKSyncEngine.Event.SentRecordZoneChanges) {
        for savedRecord in event.savedRecords {
            let id = savedRecord.recordID.recordName
            if var photo = appData.photos[id] {
                photo.lastKnownRecordData = SyncedPhoto.encodeSystemFields(of: savedRecord)
                photo.syncState = .synced
                appData.photos[id] = photo
            }
        }

        for failedSave in event.failedRecordSaves {
            let id = failedSave.record.recordID.recordName
            let error = failedSave.error

            switch error.code {
            case .serverRecordChanged:
                if let serverRecord = error.serverRecord {
                    if var photo = appData.photos[id] {
                        photo.mergeFromServerRecord(serverRecord)
                        appData.photos[id] = photo
                    }
                }
            case .zoneNotFound:
                if var photo = appData.photos[id] {
                    photo.syncState = .failed
                    appData.photos[id] = photo
                }
            default:
                if var photo = appData.photos[id] {
                    photo.syncState = .failed
                    appData.photos[id] = photo
                }
            }
        }

        for deletedID in event.deletedRecordIDs {
            appData.photos.removeValue(forKey: deletedID.recordName)
        }

        persistState()
    }

    private func handleFetchedDatabaseChanges(_ event: CKSyncEngine.Event.FetchedDatabaseChanges) {
        for deletion in event.deletions {
            let zoneName = deletion.zoneID.zoneName
            let toRemove = appData.photos.filter { _, photo in
                SyncConfiguration.zoneName(for: photo.cliqueId) == zoneName
            }
            for key in toRemove.keys {
                appData.photos.removeValue(forKey: key)
            }
        }
        persistState()
    }

    // MARK: - Internal Helpers

    private func persistState() {
        CKStatePersistence.save(appData)
    }

    private func buildRecord(for photo: SyncedPhoto) -> CKRecord {
        let record: CKRecord

        if let data = photo.lastKnownRecordData,
           let existing = SyncedPhoto.decodeSystemFields(from: data) {
            record = existing
        } else {
            let zoneID = CKRecordZone.ID(
                zoneName: SyncConfiguration.zoneName(for: photo.cliqueId),
                ownerName: CKCurrentUserDefaultName
            )
            let recordID = CKRecord.ID(recordName: photo.id, zoneID: zoneID)
            record = CKRecord(recordType: SyncedPhoto.recordType, recordID: recordID)
        }

        var mutableRecord = record
        photo.populateRecord(&mutableRecord)
        return mutableRecord
    }

    private func loadAssetData(_ asset: CKAsset?) -> Data? {
        guard let fileURL = asset?.fileURL else { return nil }
        return try? Data(contentsOf: fileURL)
    }
}
