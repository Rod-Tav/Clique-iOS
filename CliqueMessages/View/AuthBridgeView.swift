//
//  AuthBridgeView.swift
//  CliqueMessages
//
//  Shown when the user has not signed into the main Clique app yet.
//

import SwiftUI

struct AuthBridgeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Open Clique to connect")
                .font(.headline)

            Text("Sign in to the Clique app first to create Cloud Cliques")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
