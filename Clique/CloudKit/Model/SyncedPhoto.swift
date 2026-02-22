import CloudKit
import Foundation

/// A photo record synced via CloudKit, representing a single media item within a clique.
struct SyncedPhoto: Identifiable, Codable, Sendable {
    let id: String                    // CKRecord.ID.recordName
    let cliqueId: String
    let ownerUserId: String
    let ownerUsername: String
    var thumbnailData: Data?          // cached CKAsset locally
    let mediaType: String             // "PHOTO", "LIVE", "VIDEO"
    let captureDate: Date
    var userModificationDate: Date
    var lastKnownRecordData: Data?    // encoded CKRecord system fields for conflict resolution
    var syncState: SyncState = .synced

    enum SyncState: String, Codable, Sendable {
        case pending, syncing, synced, failed
    }

    // MARK: - CKRecord Field Keys

    static let recordType = "SyncedPhoto"

    private enum FieldKey {
        static let cliqueId = "cliqueId"
        static let ownerUserId = "ownerUserId"
        static let ownerUsername = "ownerUsername"
        static let thumbnail = "thumbnail"
        static let mediaType = "mediaType"
        static let captureDate = "captureDate"
        static let userModificationDate = "userModificationDate"
    }

    // MARK: - CKRecord Population

    /// Populates a CKRecord with all syncable fields from this photo.
    func populateRecord(_ record: inout CKRecord) {
        record[FieldKey.cliqueId] = cliqueId as CKRecordValue
        record[FieldKey.ownerUserId] = ownerUserId as CKRecordValue
        record[FieldKey.ownerUsername] = ownerUsername as CKRecordValue
        record[FieldKey.mediaType] = mediaType as CKRecordValue
        record[FieldKey.captureDate] = captureDate as CKRecordValue
        record[FieldKey.userModificationDate] = userModificationDate as CKRecordValue

        if let thumbnailData {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".jpg")
            try? thumbnailData.write(to: tempURL)
            record[FieldKey.thumbnail] = CKAsset(fileURL: tempURL)
        }
    }

    // MARK: - Server Record Merge

    /// Merges fields from a server CKRecord into this photo (server-wins strategy).
    mutating func mergeFromServerRecord(_ record: CKRecord) {
        if let data = record[FieldKey.ownerUserId] as? String {
            // ownerUserId is let, so we only read it for verification
            assert(data == ownerUserId || ownerUserId.isEmpty)
        }

        userModificationDate = record[FieldKey.userModificationDate] as? Date ?? userModificationDate

        if let asset = record[FieldKey.thumbnail] as? CKAsset,
           let fileURL = asset.fileURL,
           let data = try? Data(contentsOf: fileURL) {
            thumbnailData = data
        }

        lastKnownRecordData = Self.encodeSystemFields(of: record)
        syncState = .synced
    }

    // MARK: - System Fields Encoding

    /// Encodes a CKRecord's system fields for later conflict resolution.
    static func encodeSystemFields(of record: CKRecord) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: record, requiringSecureCoding: true)
    }

    /// Decodes system fields to recreate a CKRecord skeleton for updates.
    static func decodeSystemFields(from data: Data) -> CKRecord? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.self, from: data)
    }
}
