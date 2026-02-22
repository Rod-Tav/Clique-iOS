//
//  RecentPhotosSection.swift
//  Clique
//
//  Horizontal carousel of recent device photos with multi-select.
//

import SwiftUI
import Photos

/// A horizontal carousel section displaying the user's recent device photos.
///
/// Allows multi-selection and navigation to the Create/upload flow with
/// selected photos pre-populated.
///
/// ## States
/// - **Loading**: Shimmer placeholders while fetching assets
/// - **Access Denied**: Message with Settings link
/// - **Empty**: No photos found message
/// - **Loaded**: Scrollable carousel with selection
struct RecentPhotosSection: View {
    @Environment(TabViewCoordinator.self) internal var tabViewCoordinator

    @State var recentAssets: [PHAsset] = []
    @State var selectedAssets: Set<PHAsset> = []
    @State var pickerContext = PhotoPickerContext()
    @State var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State var isLoading: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            content
        }
        .padding(.horizontal, 16)
        .task {
            await checkPhotoAuthorization()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Recent Photos")
                .font(.subheadline.weight(.semibold))
                .textPrimary()

            Spacer()

            Button {
                tabViewCoordinator.createFlowMode = .library
                tabViewCoordinator.selectTab(.create)
            } label: {
                Text("See All")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.theme.cliquePink)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        switch authorizationStatus {
        case .authorized, .limited:
            if isLoading {
                loadingShimmer
            } else if recentAssets.isEmpty {
                emptyState
            } else {
                carousel

                if !selectedAssets.isEmpty {
                    continueButton
                }
            }
        case .denied, .restricted:
            accessDeniedView
        case .notDetermined:
            loadingShimmer
        @unknown default:
            EmptyView()
        }
    }

    // MARK: - Carousel

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(recentAssets, id: \.localIdentifier) { asset in
                    RecentPhotoCell(
                        asset: asset,
                        isSelected: selectedAssets.contains(asset),
                        thumbnail: pickerContext.thumbnailCache[asset],
                        onTap: {
                            toggleSelection(asset)
                        }
                    )
                    .task {
                        pickerContext.loadCarouselThumbnail(for: asset) { image in
                            if let image {
                                pickerContext.thumbnailCache[asset] = image
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            navigateToCreateFlow()
        } label: {
            Text("Continue (\(selectedAssets.count))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.theme.cliquePink)
                .roundCorners(10)
        }
        .padding(.top, 4)
    }

    // MARK: - Edge States

    private var loadingShimmer: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .shimmer()
                }
            }
        }
    }

    private var accessDeniedView: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .foregroundStyle(Color.theme.textSecondary)

            Text("Photo access is needed.")
                .font(.caption)
                .foregroundStyle(Color.theme.textSecondary)

            Spacer()

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.theme.cliquePink)
        }
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "photo")
                .foregroundStyle(Color.theme.textSecondary)

            Text("No recent photos found.")
                .font(.caption)
                .foregroundStyle(Color.theme.textSecondary)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func toggleSelection(_ asset: PHAsset) {
        if selectedAssets.contains(asset) {
            selectedAssets.remove(asset)
        } else {
            selectedAssets.insert(asset)
        }
    }
}
