//
//  PhotosGridScrollView.swift
//  Clique
//
//  Adapted from iOS18PhotosAppUI by Balaji Venkatesh
//

import SwiftUI

struct PhotosGridScrollView: View {
    var size: CGSize
    var safeArea: EdgeInsets
    @Environment(PhotosSharedData.self) internal var sharedData
    @State private var scrollPosition: ScrollPosition = .init()

    var body: some View {
        let screenHeight = size.height + safeArea.top + safeAreaBottom
        let minimisedHeight = screenHeight * 0.4

        ScrollView(.horizontal) {
            LazyHStack(alignment: .bottom, spacing: 0) {
                gridPhotosContent
                    .frame(width: size.width)
                    .id(1)

                Group {
                    stretchableView(.blue)
                        .id(2)

                    stretchableView(.yellow)
                        .id(3)

                    stretchableView(.purple)
                        .id(4)
                }
                .frame(height: screenHeight - minimisedHeight)
            }
            .scrollTargetLayout()
            .safeAreaPadding(.bottom, safeAreaBottom + 20)
        }
        .offset(y: sharedData.canPullUp ? sharedData.photosScrollOffset : 0)
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: .init(get: {
            return sharedData.activePage
        }, set: {
            if let newValue = $0 { sharedData.activePage = newValue }
        }))
        .scrollDisabled(sharedData.isExpanded)
        .frame(height: screenHeight)
        .frame(height: screenHeight - (minimisedHeight - (minimisedHeight * sharedData.progress)), alignment: .bottom)
        .overlay(alignment: .bottom) {
            PhotosPagingIndicatorView {
                Task {
                    if sharedData.photosScrollOffset != 0 {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            scrollPosition.scrollTo(edge: .bottom)
                        }

                        try? await Task.sleep(for: .seconds(0.13))
                    }

                    withAnimation(.easeInOut(duration: 0.25)) {
                        sharedData.progress = 0
                        sharedData.isExpanded = false
                    }
                }
            }
        }
    }

    private var gridPhotosContent: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: Array(repeating: GridItem(spacing: 2), count: 3), spacing: 2) {
                ForEach(0...300, id: \.self) { _ in
                    Rectangle()
                        .fill(.red)
                        .frame(height: 120)
                }
            }
            .scrollTargetLayout()
            .padding(.top, safeArea.top + safeArea.bottom + 40)
            .visualEffect { content, proxy in
                content
                    .offset(y: sharedData.progress * -(safeAreaBottom + 20))
            }
        }
        .defaultScrollAnchor(.bottom)
        .scrollDisabled(!sharedData.isExpanded)
        .scrollPosition($scrollPosition)
        .scrollClipDisabled()
        .onScrollGeometryChange(for: CGFloat.self, of: {
            $0.contentOffset.y - $0.contentSize.height + $0.containerSize.height
        }, action: { oldValue, newValue in
            sharedData.photosScrollOffset = newValue
        })
    }

    @ViewBuilder
    private func stretchableView(_ color: Color) -> some View {
        GeometryReader {
            let minY = -sharedData.mainOffset
            let size = $0.size

            Rectangle()
                .fill(color)
                .frame(width: size.width, height: size.height + (minY > 0 ? minY : 0))
                .offset(y: (minY > 0 ? -minY : 0))
        }
        .frame(width: size.width)
    }

    var safeAreaBottom: CGFloat {
        (safeArea.bottom == 0 ? 30 : safeArea.bottom)
    }
}
