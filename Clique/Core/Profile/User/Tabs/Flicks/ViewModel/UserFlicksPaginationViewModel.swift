import Foundation

@Observable final class UserFlicksPaginationViewModel: PaginationViewModel {
    typealias Item = CollectionImage
    typealias Input = EmptyPaginationFetchInput

    var items: [CollectionImage] = []
    var page: Int = 0
    var size: Int { 20 }
    var done: Bool = false
    var refreshing: Bool = false

    var fetchFunction: (EmptyPaginationFetchInput) async throws -> [CollectionImage]

    init(_ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ userStore: UserStore) {
        self.fetchFunction = { input in
            let response = try await UserFlicksService.getUserFlicks(
                page: input.page,
                size: input.size
            )

            // Map DTOs to domain models
            let images = response.flicks.compactMap { dto -> CollectionImage? in
                // Parse date
                let formatter = ISO8601DateFormatter()
                guard let dateCreated = formatter.date(from: dto.dateCreated) else {
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
                    username: dto.username,
                    phoneNumber: "",
                    bio: dto.bio ?? "",
                    firstName: dto.firstName,
                    lastName: dto.lastName,
                    profilePic: nil,
                    visibility: .pub,
                    followStatus: .none,
                    creation: Date(),
                    followersCount: 0,
                    followingCount: 0,
                    cliqueCount: 0
                )

                // Map media type
                let mediaType: MediaType = switch dto.mediaType {
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
                    numLikes: dto.likeTotal,
                    numComments: dto.commentCount,
                    hasLiked: false
                )
            }

            // Update stores
            await userStore.updateUsers(images.compactMap { $0.owner })
            await collectionImageStore.updateImages(images)

            // Update done status
            self.done = !response.hasMore

            return images
        }
    }

    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        EmptyPaginationFetchInput(page: page, size: size)
    }
}
