//
//  ShareCollectionButton.swift
//  Clique
//
//  Created by Claude Code
//

import SwiftUI

/// Menu button for sharing a collection via deep link
struct ShareCollectionButton: View {
    let collectionId: String
    let collectionName: String?
    let collectionDescription: String?

    var body: some View {
        ShareLink(
            item: "clique://collection/\(collectionId)",
            preview: SharePreview(collectionName ?? "Collection")
        ) {
            Text("Share Collection")
            Image("share")
                .color(.theme.iconPrimary)
        }
    }
}

#Preview("With Name and Description") {
    Menu {
        ShareCollectionButton(
            collectionId: "abc-123",
            collectionName: "Summer Trip",
            collectionDescription: "Photos from our summer vacation"
        )
    } label: {
        Text("Menu")
    }
}

#Preview("Nil Collection Name") {
    Menu {
        ShareCollectionButton(
            collectionId: "abc-123",
            collectionName: nil,
            collectionDescription: "Photos from our summer vacation"
        )
    } label: {
        Text("Menu")
    }
}

#Preview("Nil Description") {
    Menu {
        ShareCollectionButton(
            collectionId: "abc-123",
            collectionName: "Summer Trip",
            collectionDescription: nil
        )
    } label: {
        Text("Menu")
    }
}

#Preview("Long Collection Name") {
    Menu {
        ShareCollectionButton(
            collectionId: "abc-123",
            collectionName: "An Extremely Long Collection Name That Tests Text Truncation",
            collectionDescription: "Testing how the share preview handles very long names"
        )
    } label: {
        Text("Menu")
    }
}
