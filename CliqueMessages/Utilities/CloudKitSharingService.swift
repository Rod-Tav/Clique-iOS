//
//  CloudKitSharingService.swift
//  CliqueMessages
//
//  Manages CloudKit shared zones for Cloud Cliques.
//

import CloudKit

final class CloudKitSharingService {
    static let shared = CloudKitSharingService()

    private let container = CKContainer(identifier: "iCloud.com.cliquellc.clique")

    private init() {}

    /// Creates a shared zone for a clique and returns the CKShare.
    func createSharedZone(cliqueId: String) async throws -> CKShare {
        let zoneID = CKRecordZone.ID(zoneName: SyncConfiguration.zoneName(for: cliqueId), ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)

        let database = container.privateCloudDatabase
        _ = try await database.save(zone)

        let share = CKShare(rootRecord: CKRecord(recordType: "CliqueZone", recordID: CKRecord.ID(recordName: "root", zoneID: zoneID)))
        share[CKShare.SystemFieldKey.title] = "Clique: \(cliqueId)" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = CKShare.ParticipantPermission.readWrite.rawValue as CKRecordValue

        let operation = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: share)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }
}
