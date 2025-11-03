# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Clique iOS Codebase Documentation

## Project Overview

**Clique** is a group-based photo sharing iOS app built with modern SwiftUI patterns.

- **Platform**: iOS 17+
- **Language**: Swift 6
- **UI Framework**: SwiftUI with @Observable pattern
- **Architecture**: MVVM with feature-based organization
- **Key Features**: Photo sharing within groups (cliques), collections, social features

## File Organization and Structure

### Feature-Based Architecture
```
Clique/
├── App/                    # App initialization, root views
├── Authentication/         # Auth flow (View/, ViewModel/)
├── Components/            # Reusable UI components
│   ├── Simple/           # Basic components
│   └── Advanced/         # Complex components
├── Core/                  # Main feature modules
│   ├── Feed/             # Feed features
│   │   ├── Collections/  # (View/, ViewModel/, Components/)
│   │   └── Flicks/       # (View/, ViewModel/)
│   ├── Profile/          # Profile features
│   │   ├── User/         # (View/, ViewModel/, Tabs/)
│   │   └── Clique/       # (View/, ViewModel/, Tabs/)
│   ├── Create/           # Photo creation flow
│   ├── Collection/       # Collection management
│   ├── Comments/         # Comment system
│   └── Search/           # Search functionality
├── Model/                 # Data layer
│   ├── DTOs/            # Data transfer objects
│   └── Stores/          # Observable stores
├── Services/             # API services
└── Utils/               # Utilities, coordinators
```

### Consistent Folder Pattern
Every feature follows: `Feature/View/` and `Feature/ViewModel/`
- Nested features maintain this pattern (e.g., `Profile/User/Tabs/Collections/View/`)
- Components specific to a feature go in `Feature/View/Components/`
- Helpers go in `Feature/Helpers/`

## Navigation Architecture

### Core Navigation System

#### NavigationStack Foundation
- Uses SwiftUI's `NavigationStack` with **type-safe value-based navigation**
- Two custom wrappers:
  - `TabNavigationStack`: Includes `.rootNavigationDestinations()` for global navigation
  - `CreateNavigationStack`: No root destinations (prevents conflicts)
- **CRITICAL**: Never nest NavigationStacks - causes NavigationRequestObserver errors

#### Scroll State Management
- `HeaderPageScrollView` tracks scrolling state via `AppCoordinator.isHeaderPageScrolling`
- Child views should disable navigation during scrolling to prevent accidental navigation
- Pattern: `.disabled(appCoordinator.isHeaderPageScrolling)` on NavigationLinks

#### TabViewCoordinator
Central navigation coordinator managing:
```swift
var flicksNavigationPath = NavigationPath()      // Flicks feed tab
var collectionsNavigationPath = NavigationPath()  // Collections tab
var searchNavigationPath = NavigationPath()       // Search tab
var profileNavigationPath = NavigationPath()      // Profile tab
var createNavigationPath = NavigationPath()       // Create flow
```

Key methods:
- `navigate(to:)` - Appends to current tab's path
- `clearPath()` - Clears current tab's navigation
- `selectTab(_:)` - Handles tab selection with smart behavior

#### NavigationDestinationsModifier
Global navigation destinations in `Helpers/NavigationDestinationsModifier.swift`:
```swift
.navigationDestination(for: User.self) { user in UserProfileTabsView(userId: user.id) }
.navigationDestination(for: Clique.self) { clique in CliqueProfileView(cid: clique.id) }
.navigationDestination(for: ClCollection.self) { collection in CollectionMainView(...) }
.navigationDestination(for: String.self) { /* Special destinations */ }
.navigationDestination(for: AlbumDestination.self) { /* Photo albums */ }
```

#### Navigation Patterns
1. **Value-based navigation**: `NavigationLink(value: user)` or `path.append(user)`
2. **Domain models as values**: Pass actual models, not IDs or strings
3. **Backward navigation**: Use `@Environment(\.dismiss)`
4. **Tab behavior**: Tapping active tab scrolls to top or pops stack
5. **Create flow**: Special handling for camera/library modes

## Pagination System

### PaginationViewModel Protocol
Elegant abstraction for all paginated content:
```swift
protocol PaginationViewModel: AnyObject, Observable {
    associatedtype Item      // The model type (e.g., FeedItem)
    associatedtype Input     // API input parameters
    
    var items: [Item] { get set }
    var done: Bool { get set }
    var refreshing: Bool { get set }
    var page: Int { get set }
    var size: Int { get }
    var fetchFunction: (Input) async throws -> [Item] { get }
    
    func makeInput(page: Int, size: Int) -> Input
}
```

### Current Implementation Pattern
Each paginated view requires:

1. **State Variables** (in the view):
```swift
@State private var listState: ListState = .loading
@State private var paginationState: AdvancedListPaginationState = .idle
@State private var isScrollAtBottom: Bool = false
```

2. **Update Function**:
```swift
func updateItems(_ operation: PaginationOperationType) async {
    await PaginationHelper.updateItems(
        operation,
        viewModel: paginationViewModel,
        listState: $listState,
        paginationState: $paginationState,
        isScrollAtBottom: $isScrollAtBottom
    )
}
```

3. **AdvancedList Integration**:
```swift
AdvancedList(viewModel.items, /* ... */)
    .pagination(.init(type: .lastItem, shouldLoadNextPage: { 
        Task { await updateItems(.loadNextPage) } 
    }))
```

### Input Types
Strongly-typed pagination inputs:
- `EmptyPaginationFetchInput` - Just page/size
- `UserPaginationFetchInput` - uid + page/size
- `SearchPaginationFetchInput` - query + page/size
- `CommentsPaginationFetchInput` - parentTypeId + page/size

### Future Improvement
The repetitive state variables and update function will be abstracted into a reusable component, eliminating boilerplate in each view.

## DTO and Service Layer

### Service Architecture
All API calls go through service classes in `Services/`:
- `UserService` - User operations, search, follow/unfollow
- `CliqueService` - Clique management
- `CollectionService` - Collection CRUD
- `FeedService` - Feed data
- `CommentService` - Comments and replies
- `AuthService` - Authentication

### OpenAPI Integration
1. **Source**: `openapi.yaml` defines the API specification
2. **Generation**: Swift OpenAPI Generator creates type-safe client
3. **Namespace**: Generated types under `Components.Schemas`
4. **ClientManager**: Centralized API client with auth middleware

### DTO Pattern
Clean separation between API and domain:
```swift
// API Response (generated)
Components.Schemas.User

// Domain Model
User

// Mapping (in DTOs/UserDTO.swift)
func mapToUser(_ dto: Components.Schemas.User) -> User
```

### Service Pattern Example
```swift
extension UserService {
    static func fetchUser(_ input: Components.Schemas.GetUserRequestBody) async throws -> User {
        let response = try await ClientManager.shared.getUser(body: input)
        switch response {
        case .ok(let body):
            switch body {
            case .json(let data):
                return mapToUser(data.user)
            }
        // Error handling...
        }
    }
}
```

## State Management

### Observable Stores
Modern @Observable pattern for shared state:
- `UserStore` - User data, relationships, current user
- `CliqueStore` - Clique information and members
- `CollectionStore` - Collections and metadata
- `CollectionImageStore` - Individual images
- `CommentStore` - Comments and replies

### Store Features
1. **Smart URL updating**: Checks expiration before updating S3 URLs
2. **Partial updates**: Only update changed properties to prevent UI refreshes
3. **Relationship management**: Automatic relationship updates
4. **Environment injection**: Access via `@Environment` throughout app

### AppCoordinator
Global state coordination with triggers:
- `triggerRefreshHomeFeed`
- `triggerRefreshFlicksFeed`
- `triggerScrollToTop`
- Background refresh management
- `isHeaderPageScrolling` - Tracks scroll state for navigation control
- `lookingAtUserProfileFromCollectionDetail` - Context for navigation behavior

## Code Style and Patterns

### File Organization for Views
Split complex views into two files:
1. **`ViewName.swift`** - Contains the view structure with `@ViewBuilder` functions
2. **`ViewNameFunctions.swift`** - Contains business logic and helper functions

Example:
```
CollectionPhotosPicker/
├── CollectionPhotosPicker.swift       # UI structure
└── CollectionPhotosPickerFunctions.swift  # Logic
```

### Property Access Modifiers
Don't use `private` on properties that need to be accessed from the companion functions file:
```swift
// ✅ Correct
@Environment(\.dismiss) var dismiss
@Environment(CreateViewModel.self) var viewModel
@State var isProcessing: Bool = false
let imageManager = PHCachingImageManager()

// ❌ Avoid (unless truly private to single file)
@State private var localOnlyState: Bool = false
```

### View Organization Pattern
Break complex views into computed properties, using functions only when parameters are needed:
```swift
struct SomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            topBar
            contentArea
            bottomSection
        }
    }
    
    // Use computed properties for views without parameters
    private var topBar: some View {
        // View content here
    }
    
    private var contentArea: some View {
        // View content here
    }
    
    // Use functions only when parameters are needed
    private func userRow(_ user: User) -> some View {
        // View with parameter
    }
    
    // Use @ViewBuilder only when required (if/else, switch, etc.)
    @ViewBuilder private var conditionalView: some View {
        if someCondition {
            ViewA()
        } else {
            ViewB()
        }
    }
}
```

### Property Organization Order
1. `@Environment` properties
2. `@State` properties
3. `@Binding` properties
4. Constants (`let`)
5. Computed properties

### State Variable Organization
Group related state, especially "show" booleans:
```swift
// MARK: - State
@State var selectedTab: Tab = .flicks
@State var isLoading: Bool = false

// MARK: - Show States
@State var showAddFriendsSheet: Bool = false
@State var showCommentSheet: Bool = false
@State var showLikedMembers: Bool = false
```

### Init Methods - Swift 6 Best Practices
**IMPORTANT**: Do NOT write unnecessary init methods for structs. Swift 6 automatically synthesizes memberwise initializers.

#### When to OMIT init (let Swift handle it):
```swift
// ✅ CORRECT - No init needed
struct IconImage: View {
    let name: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(name).icon(color: color, size: size)
    }
}

// Usage: IconImage(name: "arrow-left", color: .theme.white, size: 24)
```

#### When to ADD init (custom logic required):
```swift
// ✅ CORRECT - Default parameter values (NO init needed, use var)
struct DateLabel: View {
    let date: Date
    var format: DateFormat = .full  // var with default (Swift auto-generates init param)
    var textColor: Color = .white   // var with default (Swift auto-generates init param)

    var body: some View { /* ... */ }
}
// Usage: DateLabel(date: myDate) or DateLabel(date: myDate, format: .short)

// ✅ Init needed - custom initialization logic
struct MyView: View {
    let userId: String
    @State private var viewModel: UserViewModel

    init(userId: String) {
        self.userId = userId
        self._viewModel = State(initialValue: UserViewModel(userId: userId))
    }
}

// ✅ Init needed - @ViewBuilder closures
struct Container<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}
```

#### Key Rules:
1. **Structs with only stored properties** → NO init (Swift auto-generates)
2. **Default parameter values** → Use `var` with default on property (NOT `let`), NO init needed
3. **@State/@Binding initialization** → Keep init (requires custom logic)
4. **@ViewBuilder closures** → Keep init (requires escaping closure handling)
5. **Custom logic/validation** → Keep init (transformation, computed values, etc.)

**CRITICAL**: Properties with default values MUST use `var` not `let` for Swift to generate init parameters:
```swift
// ✅ CORRECT - var allows Swift to generate optional init parameter
var uploadStatus: UploadStatus? = nil

// ❌ WRONG - let with default makes property non-overridable, no init parameter generated
let uploadStatus: UploadStatus? = nil
```

### Complex View Decomposition
For complex views with multiple sections, use computed properties:
```swift
private var picker: some View {
    VStack(spacing: 0) {
        tabPickerBar
        tabs
    }
}

private var tabPickerBar: some View { 
    // Tab picker implementation
}

private var tabs: some View { 
    // Tabs implementation
}
```

### Logic Separation
Keep views focused on UI, move logic to functions file:
- **View file**: UI structure, layout, styling
- **Functions file**: Data processing, API calls, business logic

### Additional Patterns
1. **Extension-based services**: Group related API calls
2. **Mock data**: Comprehensive mocks for development
3. **Custom modifiers**: Reusable view modifiers
4. **Type-safe enums**: For navigation, states, options
5. **Async/await**: Modern concurrency throughout

## UI Architecture

### Tab System
- Custom `BottomTabBar` with 5 tabs
- Each tab has independent navigation
- Create tab shows menu (Camera/Library/Create Clique)
- Smart tab selection behavior

### Component Organization
- **Simple Components**: Buttons, text fields, basic UI
- **Advanced Components**: Complex carousels, pickers, lists
- **Kingfisher Components**: Image loading with caching

### Key UI Features
- Hero image transitions
- Custom navigation animations
- Toast notification system
- Pull-to-refresh patterns
- Advanced pagination UI

### Color System
The app uses a comprehensive theming system with semantic colors:

**View Modifiers**:
- `.primaryBackground()` - Sets background to `Color.theme.surfacesBackgroundPrimary`
- `.textPrimary()` - Sets foreground style to `Color.theme.textPrimary`

**Icon Colors**:
- Always use `Color.theme.iconPrimary` for primary icons
- Use `Color.theme.iconSecondary` for secondary/inactive states

**Common Patterns**:
```swift
// Background
VStack { ... }
.primaryBackground()

// Text
Text("Title")
    .font(.callout.weight(.semibold))
    .textPrimary()

// Icons
IconImage("arrow-left", color: .theme.iconPrimary, size: 24)
```

**Important**: Never use hardcoded colors like `.theme.shadesWhite95` or `.theme.dark` for backgrounds - always use the semantic color system that adapts to light/dark mode.

## Dependencies

### Major Dependencies
- **Firebase**: Auth, messaging, analytics, crashlytics
- **Kingfisher**: Advanced image loading and caching
- **Swift OpenAPI**: Type-safe API generation
- **NavigationTransitions**: Custom navigation animations
- **AdvancedList**: Enhanced list functionality
- **TipKit**: User onboarding

### Image Management
- Kingfisher configuration for memory/disk caching
- Smart prefetching for smooth scrolling
- Memory pressure handling
- S3 URL expiration management

## Common Patterns to Follow

1. **Feature Organization**: Always use View/ and ViewModel/ folders
2. **Navigation**: Use typed values, never strings
3. **Pagination**: Implement PaginationViewModel protocol
4. **API Calls**: Always go through service layer
5. **State Management**: Use @Observable stores
6. **View Complexity**: Break down with ViewBuilder functions
7. **Async Operations**: Use async/await, not completion handlers

## Pitfalls to Avoid

1. **Navigation Issues**:
   - Never nest NavigationStacks
   - Don't use string-based navigation
   - Clear navigation paths when exiting flows

2. **State Management**:
   - Don't update navigation from multiple places
   - Avoid direct model mutations
   - Don't skip smart URL checking

3. **Performance**:
   - Always implement pagination for lists
   - Use image caching properly
   - Avoid loading full-res images in lists

4. **Code Organization**:
   - Don't put ViewModels in View files
   - Keep view bodies simple
   - Group state variables logically

## Testing Commands
- Run lint and typecheck after changes
- Commands TBD - ask user and update here

## Quick Reference

### Conditional View Modifiers
Use the `.if` modifier for conditional view modifications instead of trying to use `.apply` or other patterns:
```swift
// For iOS version checks
.if(.iOS17) { view in 
    view.someIOS17Modifier()
}
.if(!.iOS17) { view in
    view.someIOS18Modifier()
}

// For any boolean condition
.if(someCondition) { view in
    view.someModifier()
}
```

The `.iOS17` helper (from `View+Extensions.swift`) returns `true` on iOS 17, `false` on iOS 18+.

### Creating a New Feature
1. Create folder: `Core/YourFeature/`
2. Add subfolders: `View/`, `ViewModel/`
3. Follow existing patterns for file names
4. Use PaginationViewModel for lists
5. Add navigation destination if needed

### Adding Navigation
1. Define navigation model/enum
2. Add to NavigationDestinationsModifier
3. Use NavigationLink(value:) or path.append()
4. Handle in appropriate navigationDestination

### Implementing Pagination
1. Create ViewModel implementing PaginationViewModel
2. Add required state in view
3. Use PaginationHelper.updateItems
4. Integrate with AdvancedList
5. Handle loading/error states

## DocC Documentation System

### Overview
The codebase now has comprehensive DocC documentation covering all major architectural components. This documentation is designed to provide rich context for future development and AI assistance.

### Documented Architecture Components

#### **App Foundation Layer**
- **`CliqueApp.swift`**: Main app entry point with Firebase, background tasks, environment setup
- **`AppCoordinator.swift`**: Global state coordination with trigger system
- **`ContentView.swift`**: Root view routing and app state switching

#### **Core Navigation & UI**  
- **`MainTabView.swift`**: Main app container with tab management and upload coordination
- **`BottomTabBar.swift`**: Custom tab bar with enhanced interaction patterns
- **`HeaderPageScrollView.swift`**: Advanced scrolling component with synchronized behavior

#### **System Architecture**
- **`PaginationHelper.swift`**: Core pagination operations and view integration
- **`BasePaginationViewModel.swift`**: Base class for pagination implementations
- **`NavigationDestinationsModifier.swift`**: Type-safe navigation destinations
- **`TabViewCoordinator.swift`**: Central navigation coordination
- **`UserService.swift`**: User API operations with comprehensive examples
- **`UserStore.swift`**: User data management with smart caching
- **`IconImage.swift`**: Standardized icon component with design system guidance

### Documentation Features
- **Architecture Diagrams**: ASCII art showing component relationships
- **Code Examples**: Real usage patterns with syntax highlighting  
- **Cross-References**: Links between related components using `BackticksComponentName`
- **Best Practices**: Performance considerations and common patterns
- **Integration Examples**: How components work together
- **Error Handling**: Common failure cases and recovery strategies

### Using DocC Documentation
1. **View in Xcode**: Product → Build Documentation to generate and view
2. **Navigate Components**: Use Quick Help (⌥ + Click) on documented types
3. **Search Patterns**: Look for documented patterns when implementing similar features
4. **Cross-Reference**: Follow `ComponentName` links to understand relationships

### Maintaining Documentation
When adding new architectural components:

1. **Follow Established Patterns**: Use existing documentation as templates
2. **Include Examples**: Provide real usage examples with code blocks
3. **Document Integration**: Explain how new components work with existing ones
4. **Add Cross-References**: Link to related components using DocC syntax
5. **Update Architecture**: Add new components to this CLAUDE.md overview

### Documentation Standards
- **Public APIs**: All public types, methods, and properties should be documented
- **Architecture Components**: Major app infrastructure requires comprehensive docs
- **Integration Points**: Document how components connect and communicate
- **Performance Notes**: Include optimization considerations and threading requirements
- **Error Cases**: Document common failure scenarios and handling strategies

### Quick Reference for DocC Syntax
```swift
/// Brief description of the component.
///
/// Longer description with architectural context and usage patterns.
///
/// ## Key Features
/// - **Feature 1**: Description
/// - **Feature 2**: Description
///
/// ## Usage Example
/// ```swift
/// let component = Component()
/// await component.performAction()
/// ```
///
/// ## Integration
/// Works with ``RelatedComponent`` and ``AnotherComponent``.
///
/// - Parameters:
///   - param1: Description of parameter
///   - param2: Description of parameter
/// - Returns: Description of return value
/// - Throws: Description of potential errors
/// - Important: Critical information
/// - Note: Additional helpful information
```

This documentation system ensures that future development (including AI assistance) has rich context about the app's architecture, patterns, and best practices.