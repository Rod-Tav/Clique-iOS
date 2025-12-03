import Foundation

@Observable final class UserFlicksPaginationViewModel: PaginationViewModel {
    typealias Item = CollectionImage
    typealias Input = EmptyPaginationFetchInput

    var items: [CollectionImage] = []
    var page: Int = 0
    var size: Int { 20 }
    var done: Bool = false
    var refreshing: Bool = false

    // Thread-safe refresh properties (required by PaginationViewModel protocol)
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?

    var fetchFunction: (EmptyPaginationFetchInput) async throws -> [CollectionImage]

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
            let images = response.flicks.compactMap { dto -> CollectionImage? in
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

                return CollectionImage(
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
            }

            print("🟢 [UserFlicksVM] Mapped \(images.count) images (skipped \(skippedCount))")

            // Update stores
            await userStore.updateUsers(images.compactMap { $0.owner })
            await collectionImageStore.updateImages(images)

            // Update done status
            self.done = !response.hasMore
            print("🟢 [UserFlicksVM] Done: \(self.done), hasMore: \(response.hasMore)")

            return images
        }
    }

    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        EmptyPaginationFetchInput(page: page, size: size)
    }
}
