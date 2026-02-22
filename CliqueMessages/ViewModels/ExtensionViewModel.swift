//
//  ExtensionViewModel.swift
//  CliqueMessages
//
//  View model for the Clique iMessage extension
//

import Foundation
import Messages


/// Navigation states for the iMessage extension
enum ExtensionNavigationState: Equatable {
    case cliqueList
    case collectionList
    case flickGrid
    case createClique
}

/// View model managing state for the Clique iMessage extension
///
/// This view model coordinates the extension's UI state, authentication,
/// API data fetching, and navigation flow. It fetches data from the API
/// with fresh presigned URLs, falling back to cache for offline access.
@Observable
final class ExtensionViewModel {

    // MARK: - Presentation & Navigation

    /// Current presentation style (compact vs expanded)
    var presentationStyle: MSMessagesAppPresentationStyle = .compact

    /// Current navigation state within the extension
    var navigationState: ExtensionNavigationState = .cliqueList

    /// Navigation stack for back navigation
    private var navigationStack: [ExtensionNavigationState] = []

    // MARK: - Authentication

    /// Whether the user is authenticated (from SharedAuthStorage)
    var isAuthenticated: Bool = false

    // MARK: - Data State

    /// All cliques available to the user
    var cliques: [CachedClique] = []

    /// Currently selected clique
    var selectedClique: CachedClique?

    /// Collections for the currently selected clique
    var collectionsForClique: [CachedCollection] = []

    /// Currently selected collection
    var selectedCollection: CachedCollection?

    /// Flicks for the currently selected collection
    var flicks: [CachedFlick] = []

    // MARK: - Chat Context

    /// Chat key for the current iMessage conversation
    var chatKey: String?

    /// Clique linked to the current chat (if any)
    var linkedClique: CachedClique?

    /// Pending clique to navigate to after expansion (set from compact view)
    var pendingCliqueSelection: CachedClique?

    // MARK: - UI State

    /// Whether data is currently loading
    var isLoading: Bool = false

    /// Error message to display (if any)
    var errorMessage: String?

    /// Whether a flick is currently being sent
    var isSendingFlick: Bool = false

    // MARK: - Message Sending

    /// Callback to send an MSMessage (set by MessagesViewController)
    var sendMessageHandler: ((MSMessage) -> Void)?

    /// Callback to insert a direct image attachment (set by MessagesViewController)
    var insertAttachmentHandler: ((URL, String) -> Void)?

    /// Callback to dismiss the extension after sending
    var dismissHandler: (() -> Void)?

    /// Callback to open a URL in the main app (set by MessagesViewController)
    var openURLHandler: ((URL) -> Void)?

    // MARK: - Dependencies

    private let authStorage = SharedAuthStorage()
    private let cacheManager = ExtensionCacheManager.shared
    private let apiClient = ExtensionAPIClient()

    // MARK: - Initialization

    init() {
        checkAuthenticationState()
    }

    // MARK: - Public Methods

    /// Loads initial data including authentication state and cliques
    /// Fetches from API first, falls back to cache if API fails
    func loadInitialData() {
        isLoading = true
        errorMessage = nil

        // Check authentication
        checkAuthenticationState()

        // Fetch cliques from API (async)
        Task {
            await fetchCliquesFromAPI()
        }
    }

    /// Fetches cliques from API, falls back to cache on failure
    @MainActor
    private func fetchCliquesFromAPI() async {
        do {
            print("ExtensionViewModel: Fetching cliques from API...")
            let apiCliques = try await apiClient.fetchCliques()
            cliques = apiCliques
            print("ExtensionViewModel: Loaded \(cliques.count) cliques from API")
            for clique in cliques.prefix(3) {
                print("  - \(clique.name): thumbUrl=\(clique.thumbUrl.prefix(60))...")
            }

            // Sort cliques by most recently updated
            cliques.sort { $0.updatedAt > $1.updatedAt }

            // Update cache with fresh data
            cacheManager.saveCliques(cliques)

        } catch {
            print("ExtensionViewModel: API fetch failed: \(error), falling back to cache")

            // Fall back to cache
            cliques = cacheManager.loadCliques()
            print("ExtensionViewModel: Loaded \(cliques.count) cliques from cache (fallback)")

            // Sort cliques by most recently updated
            cliques.sort { $0.updatedAt > $1.updatedAt }

            // Show error only if we have no data at all
            if cliques.isEmpty {
                errorMessage = "Could not load cliques. Please open the Clique app first."
            }
        }

        // Check if we have a chat key and find linked clique
        if chatKey != nil {
            linkedClique = cliques.first { _ in
                // Future: Check if clique is linked to this chat
                false
            }
        }

        isLoading = false
    }

    /// Selects a clique and loads its collections
    ///
    /// - Parameter clique: The clique to select
    func selectClique(_ clique: CachedClique) {
        selectedClique = clique
        selectedCollection = nil
        flicks = []

        loadCollections(for: clique)
        navigate(to: .collectionList)
    }

    /// Loads collections for a specific clique
    /// Fetches from API first, falls back to cache if API fails
    ///
    /// - Parameter clique: The clique to load collections for
    func loadCollections(for clique: CachedClique) {
        isLoading = true
        errorMessage = nil

        Task {
            await fetchCollectionsFromAPI(for: clique)
        }
    }

    /// Fetches collections from API, falls back to cache on failure
    @MainActor
    private func fetchCollectionsFromAPI(for clique: CachedClique) async {
        do {
            print("ExtensionViewModel: Fetching collections from API for clique \(clique.name)...")
            let apiCollections = try await apiClient.fetchCollections(for: clique.id)
            collectionsForClique = apiCollections
            print("ExtensionViewModel: Loaded \(collectionsForClique.count) collections from API")
            for collection in collectionsForClique.prefix(3) {
                print("  - \(collection.name): thumbUrl=\(collection.thumbUrl.prefix(60))...")
            }

            // Sort collections by most recently created
            collectionsForClique.sort { $0.createdAt > $1.createdAt }

            // Update cache with fresh data
            cacheManager.saveCollections(collectionsForClique, for: clique.id)

            // Also fetch and cache flicks for this clique
            let apiFlicks = try await apiClient.fetchFlicks(for: clique.id)
            cacheManager.saveFlicks(apiFlicks, for: clique.id)
            print("ExtensionViewModel: Cached \(apiFlicks.count) flicks from API")

        } catch {
            print("ExtensionViewModel: API fetch failed: \(error), falling back to cache")

            // Fall back to cache
            collectionsForClique = cacheManager.loadCollections(for: clique.id)
            print("ExtensionViewModel: Loaded \(collectionsForClique.count) collections from cache (fallback)")

            // Sort collections by most recently created
            collectionsForClique.sort { $0.createdAt > $1.createdAt }

            // Show error only if we have no data at all
            if collectionsForClique.isEmpty {
                errorMessage = "Could not load collections. Please try again."
            }
        }

        isLoading = false
    }

    /// Selects a collection and loads its flicks
    ///
    /// - Parameter collection: The collection to select
    func selectCollection(_ collection: CachedCollection) {
        selectedCollection = collection

        loadFlicks(for: collection)
        navigate(to: .flickGrid)
    }

    /// Loads flicks for a specific collection
    /// Uses data already fetched from API when loading collections
    ///
    /// - Parameter collection: The collection to load flicks for
    func loadFlicks(for collection: CachedCollection) {
        isLoading = true
        errorMessage = nil

        Task {
            await fetchFlicksFromAPI(for: collection)
        }
    }

    /// Fetches flicks from API or cache
    @MainActor
    private func fetchFlicksFromAPI(for collection: CachedCollection) async {
        do {
            print("ExtensionViewModel: Fetching flicks from API for collection \(collection.name)...")
            let apiFlicks = try await apiClient.fetchFlicks(for: collection.cliqueId)

            // Filter flicks for this specific collection
            flicks = apiFlicks.filter { $0.collectionId == collection.id }
            print("ExtensionViewModel: Loaded \(flicks.count) flicks from API for collection")
            for flick in flicks.prefix(3) {
                print("  - flick \(flick.id.prefix(8)): thumbUrl=\(flick.thumbUrl.prefix(60))...")
            }

            // Sort flicks by most recently created
            flicks.sort { $0.createdAt > $1.createdAt }

            // Update cache with fresh data
            cacheManager.saveFlicks(apiFlicks, for: collection.cliqueId)

        } catch {
            print("ExtensionViewModel: API fetch failed: \(error), falling back to cache")

            // Fall back to cache
            let allFlicksForClique = cacheManager.loadFlicks(for: collection.cliqueId)
            flicks = allFlicksForClique.filter { $0.collectionId == collection.id }
            print("ExtensionViewModel: Loaded \(flicks.count) flicks from cache (fallback)")

            // Sort flicks by most recently created
            flicks.sort { $0.createdAt > $1.createdAt }

            // Show error only if we have no data at all
            if flicks.isEmpty {
                errorMessage = "Could not load flicks. Please try again."
            }
        }

        isLoading = false
    }

    /// Sets the chat key for the current conversation
    ///
    /// - Parameter chatKey: The unique identifier for the iMessage conversation
    func setChatKey(_ chatKey: String) {
        self.chatKey = chatKey

        // Reload data to check for linked clique
        if !cliques.isEmpty {
            loadInitialData()
        }
    }

    /// Updates the presentation style when it changes
    ///
    /// - Parameter style: The new presentation style
    func updatePresentationStyle(_ style: MSMessagesAppPresentationStyle) {
        presentationStyle = style

        // Reset navigation to clique list when collapsing
        if style == .compact {
            navigationState = .cliqueList
            navigationStack.removeAll()
            selectedClique = nil
            selectedCollection = nil
            collectionsForClique = []
            flicks = []
        }
    }

    // MARK: - Navigation Methods

    /// Navigate to a new state, pushing current state to stack
    func navigate(to state: ExtensionNavigationState) {
        navigationStack.append(navigationState)
        navigationState = state
    }

    /// Navigate back to previous state
    func navigateBack() {
        guard let previousState = navigationStack.popLast() else {
            navigationState = .cliqueList
            return
        }

        // Clean up state when navigating back
        switch previousState {
        case .cliqueList:
            selectedClique = nil
            collectionsForClique = []
            selectedCollection = nil
            flicks = []
        case .collectionList:
            selectedCollection = nil
            flicks = []
        case .flickGrid, .createClique:
            break
        }

        navigationState = previousState
    }

    /// Resets the view model to initial state
    func reset() {
        navigationState = .cliqueList
        navigationStack.removeAll()
        selectedClique = nil
        selectedCollection = nil
        collectionsForClique = []
        flicks = []
        errorMessage = nil
    }

    // MARK: - Lifecycle Methods (called from MessagesViewController)

    /// Called when the extension is about to become active
    func willBecomeActive() {
        loadInitialData()
    }

    /// Called when the extension is about to resign active status
    func didResignActive() {
        // Perform any cleanup here
    }

    /// Handles memory warnings by clearing cached data
    func handleMemoryWarning() {
        cliques.removeAll()
        collectionsForClique.removeAll()
        flicks.removeAll()
        selectedClique = nil
        selectedCollection = nil
    }

    // MARK: - Message Interaction (called from MessagesViewController)

    /// Called when a message is selected in the conversation
    func didReceiveMessage(_ message: MSMessage) {
        // Handle message selection - could navigate to specific content
    }

    /// Called when a message is about to be sent
    func didStartSendingMessage(_ message: MSMessage) {
        // Handle message send start
    }

    /// Called when message sending is cancelled
    func didCancelSendingMessage(_ message: MSMessage) {
        // Handle message send cancellation
    }

    /// Sends a flick as an iMessage
    ///
    /// Downloads the flick thumbnail, creates an MSMessage with the image,
    /// and inserts it into the conversation.
    ///
    /// - Parameter flick: The flick to send
    func sendFlick(_ flick: CachedFlick) {
        guard !isSendingFlick else { return }
        guard let clique = selectedClique, let collection = selectedCollection else {
            errorMessage = "Missing clique or collection context"
            return
        }

        isSendingFlick = true
        errorMessage = nil

        Task {
            do {
                // Download the thumbnail image with timeout
                guard let thumbnailURL = URL(string: flick.thumbUrl) else {
                    throw FlickSendError.invalidURL
                }

                print("ExtensionViewModel: Downloading image from \(thumbnailURL.absoluteString.prefix(100))...")

                // Create URLSession with timeout
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 15
                config.timeoutIntervalForResource = 30
                let session = URLSession(configuration: config)

                let (data, response) = try await session.data(from: thumbnailURL)

                // Check HTTP status
                if let httpResponse = response as? HTTPURLResponse {
                    print("ExtensionViewModel: HTTP status \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        throw FlickSendError.httpError(statusCode: httpResponse.statusCode)
                    }
                }

                guard let image = UIImage(data: data) else {
                    throw FlickSendError.imageLoadFailed
                }

                print("ExtensionViewModel: Image loaded successfully, building message...")

                // Get current user info from cache
                let currentUser = cacheManager.loadCurrentUser()
                let senderUsername = currentUser?.username ?? "someone"

                // Build the message
                let message = MSMessageBuilder.buildFlickMessage(
                    flick: flick,
                    collection: collection,
                    clique: clique,
                    senderUsername: senderUsername,
                    thumbnail: image
                )

                // Send the message on the main thread
                await MainActor.run {
                    print("ExtensionViewModel: Inserting message...")
                    sendMessageHandler?(message)
                    isSendingFlick = false

                    // Dismiss after a short delay to show success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.dismissHandler?()
                    }
                }
            } catch {
                print("ExtensionViewModel: Send failed with error: \(error)")
                await MainActor.run {
                    isSendingFlick = false
                    if let flickError = error as? FlickSendError {
                        errorMessage = flickError.errorDescription
                    } else {
                        errorMessage = "Failed to send: URL may have expired. Re-open the main app to refresh."
                    }
                }
            }
        }
    }

    /// Errors that can occur when sending a flick
    enum FlickSendError: LocalizedError {
        case invalidURL
        case imageLoadFailed
        case httpError(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid image URL"
            case .imageLoadFailed:
                return "Could not load the image"
            case .httpError(let statusCode):
                return "HTTP error: \(statusCode)"
            }
        }
    }

    /// Called when transitioning to compact presentation
    func didTransitionToCompact() {
        // Reset navigation state when collapsing
        navigationState = .cliqueList
        navigationStack.removeAll()
        selectedClique = nil
        selectedCollection = nil
        collectionsForClique = []
        flicks = []
    }

    /// Called when transitioning to expanded presentation
    func didTransitionToExpanded() {
        // Process pending clique selection from compact view (if user tapped a clique)
        if let pendingClique = pendingCliqueSelection {
            pendingCliqueSelection = nil
            selectClique(pendingClique)
        }
        // Otherwise, stay at cliqueList showing vertical list
    }

    // MARK: - Private Methods

    /// Checks authentication state from SharedAuthStorage
    private func checkAuthenticationState() {
        isAuthenticated = authStorage.isAuthenticated
    }
}
