import CloudKit
import Foundation

/// Manages CloudKit zone sharing for collaborative clique sync.
final class CloudKitSharingService: Sendable {
    static let shared = CloudKitSharingService()
    private let container = CKContainer(identifier: SyncConfiguration.containerIdentifier)

    private init() {}

    /// Creates a shared CloudKit zone for a clique and returns the CKShare.
    ///
    /// Creates the record zone if it doesn't exist, then creates a zone-wide share.
    func createSharedZone(cliqueId: String) async throws -> CKShare {
        let zoneName = SyncConfiguration.zoneName(for: cliqueId)
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)

        // Save the zone first
        let database = container.privateCloudDatabase
        do {
            try await database.save(zone)
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Zone may already exist, which is fine
        }

        // Create a zone-wide share
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Clique: \(cliqueId)" as CKRecordValue
        share.publicPermission = .none

        let savedRecords = try await database.modifyRecords(
            saving: [share],
            deleting: [],
            savePolicy: .ifServerRecordUnchanged
        )

        // Extract the saved CKShare from the results
        for (_, result) in savedRecords.saveResults {
            if let savedRecord = try? result.get(), let savedShare = savedRecord as? CKShare {
                return savedShare
            }
        }

        return share
    }

    /// Accepts a shared zone invitation.
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        try await container.accept(metadata)
    }

    /// Checks the current iCloud account status.
    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
}
