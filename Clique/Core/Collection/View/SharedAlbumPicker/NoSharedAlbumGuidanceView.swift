//
//  NoSharedAlbumGuidanceView.swift
//  Clique
//
//  Step-by-step guidance for creating a Shared Album in the Photos app.
//

import SwiftUI

@available(iOS 26, *)
struct NoSharedAlbumGuidanceView: View {
    @Environment(\.openURL) private var openURL

    private let steps = [
        "Open the Photos app",
        "Go to Albums tab",
        "Tap the + button",
        "Choose \"New Shared Album\"",
        "Name it after your collection",
        "Invite your clique members",
        "Come back here and link it"
    ]

    var body: some View {
        VStack(spacing: 20) {
            icon
            title
            stepList
            openPhotosButton
            tip
        }
        .padding(20)
    }

    // MARK: - Subviews

    private var icon: some View {
        Image(systemName: "rectangle.stack.badge.plus")
            .font(.system(size: 36))
            .foregroundStyle(Color.theme.iconSecondary)
    }

    private var title: some View {
        Text("Create a Shared Album")
            .font(.headline)
            .textPrimary()
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.theme.textSecondary)
                        .frame(width: 22, alignment: .trailing)

                    Text(step)
                        .font(.subheadline)
                        .foregroundStyle(Color.theme.textSecondary)
                }
            }
        }
    }

    private var openPhotosButton: some View {
        Button {
            if let url = URL(string: "photos-redirect://") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                Text("Open Photos")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.accentColor, in: .capsule)
        }
        .padding(.top, 4)
    }

    private var tip: some View {
        Text("Invite the same people in your clique so everyone can contribute photos.")
            .font(.caption)
            .foregroundStyle(Color.theme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }
}
