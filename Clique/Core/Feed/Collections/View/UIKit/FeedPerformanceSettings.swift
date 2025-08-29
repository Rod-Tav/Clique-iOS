//
//  FeedPerformanceSettings.swift
//  Clique
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI

struct FeedPerformanceSettings: View {
    @AppStorage("useUIKitFeed") private var useUIKitFeed: Bool = false
    @AppStorage("feedLayoutStyle") private var feedLayoutStyle: String = "single"
    
    var body: some View {
        Section("Feed Performance") {
            Toggle("Use Optimized Scrolling", isOn: $useUIKitFeed)
                .font(.footnote)
            
            Text("Enable UICollectionView for smoother scrolling with large image grids")
                .font(.caption2)
                .textSecondary()
            
            if useUIKitFeed {
                Picker("Layout Style", selection: $feedLayoutStyle) {
                    Text("Single Column").tag("single")
                    Text("Two Column").tag("double")
                    Text("Three Column").tag("triple")
                }
                .font(.footnote)
                .pickerStyle(.segmented)
                
                Text("Grid layout for denser content display")
                    .font(.caption2)
                    .textSecondary()
            }
        }
    }
}

// MARK: - Layout Style Helper
extension HomeFeedCompositionalLayout.LayoutStyle {
    init(from string: String) {
        switch string {
        case "double":
            self = .twoColumn
        case "triple":
            self = .threeColumn
        default:
            self = .singleColumn
        }
    }
}