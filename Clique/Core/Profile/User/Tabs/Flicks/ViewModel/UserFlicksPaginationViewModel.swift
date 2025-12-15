import Foundation

// MARK: - Array Extension for Chunking

extension Array {
    /// Splits the array into chunks of the specified size
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Date Section Model

/// Represents a group of flicks from the same day
struct FlickDateSection: Identifiable {
    let date: Date
    let items: [UserFlickItem]
    let formattedDate: String
    let countText: String

    var id: Date { date }

    init(date: Date, items: [UserFlickItem]) {
        self.date = date
        self.items = items
        self.formattedDate = formatDateMMMMdYYYY(date)
        self.countText = items.count == 1 ? "1 Flick" : "\(items.count) Flicks"
    }
}

/// Flat row item for single-container scrolling (avoids nested lazy containers)
enum FlickRowItem: Identifiable {
    case header(FlickDateSection)
    case imageRow(id: String, items: [UserFlickItem])

    var id: String {
        switch self {
        case .header(let section):
            return "header-\(section.date.timeIntervalSince1970)"
        case .imageRow(let id, _):
            return id
        }
    }
}

@Observable final class UserFlicksPaginationViewModel: PaginationViewModel {
    typealias Item = UserFlickItem
    typealias Input = EmptyPaginationFetchInput

    var items: [UserFlickItem] = []
    var page: Int = 0
    var size: Int { 20 }
    var done: Bool = false
    var refreshing: Bool = false

    // Thread-safe refresh properties (required by PaginationViewModel protocol)
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?

    var fetchFunction: (EmptyPaginationFetchInput) async throws -> [UserFlickItem]

    /// Groups all flicks by date, sorted newest-first
    var groupedByDate: [FlickDateSection] {
        let calendar = Calendar.current

        // Group by start of day - extract flick date from UserFlickItem
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.flick.date)
        }

        // Convert to sections and sort by date descending
        return grouped.map { date, items in
            FlickDateSection(date: date, items: items.sorted { $0.flick.date > $1.flick.date })
        }
        .sorted { $0.date > $1.date }
    }

    /// Converts sections to flat rows for single-container scrolling
    /// Order: section divider first, then images
    func flatRows(from sections: [FlickDateSection], columns: Int) -> [FlickRowItem] {
        var rows: [FlickRowItem] = []
        for section in sections {
            // Section divider before images
            rows.append(.header(section))
            // Image rows
            let chunks = section.items.chunked(into: columns)
            for (index, chunk) in chunks.enumerated() {
                let rowId = "row-\(section.date.timeIntervalSince1970)-\(index)"
                rows.append(.imageRow(id: rowId, items: chunk))
            }
        }
        return rows
    }

    init(_ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ userStore: UserStore) {
        self.fetchFunction = { input in
            print("🔵 [UserFlicksVM] Fetching page \(input.page), size \(input.size)")

            let response = try await UserFlicksService.getUserFlicks(
                page: input.page,
                size: input.size
            )
            print("🟢 [UserFlicksVM] Got \(response.flicks.count) flicks from API")

            // Map DTOs to domain models
            var skippedCount = 0
            let userFlickItems = response.flicks.compactMap { dto -> UserFlickItem? in
                // Parse date (with fractional seconds support for .000Z format)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                guard let dateCreated = formatter.date(from: dto.dateCreated) else {
                    print("🟡 [UserFlicksVM] Skipping flick \(dto.collectionItemId) - invalid date: \(dto.dateCreated)")
                    skippedCount += 1
                    return nil
                }

                // Map media URLs
                let mediaUrls: MediaUrls? = if dto.photoId != nil {
                    MediaUrls(
                        url: dto.photoPath,
                        medQualityUrl: dto.photoMedPath,
                        lowQualityUrl: dto.photoLowPath
                    )
                } else {
                    nil
                }

                let videoUrls: MediaUrls? = if dto.videoId != nil {
                    MediaUrls(
                        url: dto.videoPath,
                        medQualityUrl: dto.videoMedPath,
                        lowQualityUrl: dto.videoLowPath
                    )
                } else {
                    nil
                }

                // Map user
                let owner = User(
                    id: dto.userId,
                    firstname: dto.firstName ?? "",
                    lastname: dto.lastName ?? "",
                    number: "",
                    username: dto.username ?? "",
                    profilePic: nil,
                    bio: dto.bio ?? ""
                )

                // Map media type
                let mediaType: MediaType = switch dto.mediaType ?? 0 {
                case 0: .PHOTO
                case 1: .LIVE
                case 2: .VIDEO
                default: .PHOTO
                }

                let flick = CollectionImage(
                    id: dto.collectionItemId,
                    owner: owner,
                    imageUrl: mediaUrls,
                    videoUrls: videoUrls,
                    mediaType: mediaType,
                    uploadStatus: .COMPLETED,
                    date: dateCreated,
                    numLikes: dto.likeTotal ?? 0,
                    numComments: dto.commentCount ?? 0,
                    hasLiked: false
                )

                // Return UserFlickItem with collection/clique context preserved
                return UserFlickItem(
                    flick: flick,
                    collectionId: dto.collectionId,
                    collectionName: dto.collectionName,
                    cliqueId: dto.cliqueId
                )
            }

            print("🟢 [UserFlicksVM] Mapped \(userFlickItems.count) items (skipped \(skippedCount))")

            // Update stores
            let images = userFlickItems.map { $0.flick }
            await userStore.updateUsers(images.compactMap { $0.owner })
            await collectionImageStore.updateImages(images)

            // Update done status
            self.done = !response.hasMore
            print("🟢 [UserFlicksVM] Done: \(self.done), hasMore: \(response.hasMore)")

            return userFlickItems
        }
    }

    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        EmptyPaginationFetchInput(page: page, size: size)
    }
}
