//
//  PhotosTabView.swift
//  Clique
//
//  iOS 26 Liquid Glass TabView container with Library and Albums tabs.
//

import SwiftUI

@available(iOS 26, *)
struct LibraryTabView: View {
    @State var sharedData = SharedAlbumsData()
    @State var tabViewCoordinator = TabViewCoordinator()
    @State var activityStore = SharedAlbumActivityStore()
    @State var cloudCliquesStore = CloudCliquesStore()

    var body: some View {
        TabView {
            Tab("Library", systemImage: "photo.on.rectangle") {
                NavigationStack {
                    SharedLibraryGridView()
                }
            }

            Tab("Collections", systemImage: "rectangle.stack") {
                NavigationStack {
                    SharedAlbumsListView()
                }
            }

            Tab("Legacy", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    LegacyCollectionsView()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(sharedData)
        .environment(tabViewCoordinator)
        .environment(activityStore)
        .environment(cloudCliquesStore)
    }
}
