////
////  UploadStatusOverlay.swift
////  Clique
////
////  Created by Assistant on 1/31/25.
////
//
//import SwiftUI
//
///// Overlay component that displays upload status for collection images
//struct UploadStatusOverlay: View {
//    let status: UploadStatus?
//    let onRetry: (() -> Void)?
//
//    var body: some View {
//        Group {
//            switch status {
//            case .PENDING:
//                pendingOverlay
//            case .FAILED:
//                failedOverlay
//            case .COMPLETED, .none:
//                EmptyView()
//            }
//        }
//    }
//
//    private var pendingOverlay: some View {
//        ZStack {
//            Color.black.opacity(0.3)
//            ProgressView()
//                .progressViewStyle(.circular)
//                .tint(.white)
//        }
//    }
//
//    private var failedOverlay: some View {
//        ZStack {
//            Color.red.opacity(0.3)
//            VStack(spacing: 8) {
//                Image(systemName: "exclamationmark.triangle.fill")
//                    .foregroundColor(.white)
//                    .font(.title2)
//
//                if let onRetry = onRetry {
//                    Button("Retry") {
//                        onRetry()
//                    }
//                    .buttonStyle(.bordered)
//                    .tint(.white)
//                    .controlSize(.small)
//                }
//            }
//        }
//    }
//}
//
//#Preview("Pending") {
//    Rectangle()
//        .fill(.gray)
//        .frame(width: 200, height: 200)
//        .overlay {
//            UploadStatusOverlay(status: .PENDING, onRetry: nil)
//        }
//}
//
//#Preview("Failed") {
//    Rectangle()
//        .fill(.gray)
//        .frame(width: 200, height: 200)
//        .overlay {
//            UploadStatusOverlay(status: .FAILED, onRetry: { print("Retry tapped") })
//        }
//}
//
//#Preview("Completed") {
//    Rectangle()
//        .fill(.gray)
//        .frame(width: 200, height: 200)
//        .overlay {
//            UploadStatusOverlay(status: .COMPLETED, onRetry: nil)
//        }
//}
