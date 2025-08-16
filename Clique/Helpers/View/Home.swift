////
////  Home.swift
////  Clique
////
////  Created by Rod Tavangar on 6/29/24.
////
//
//import SwiftUI
//
//struct Home: View {
//    /// - View Properties
//    @State private var showPicker: Bool = false
//    @State private var croppedImage: Image?
//    var body: some View {
//        NavigationStack {
//            VStack {
//                if let croppedImage {
//                    croppedImage
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: 300, height: 400)
//                } else {
//                    Text("No Image is Selected")
//                        .font(.caption)
//                        .foregroundStyle(.gray)
//                }
//            }
//            .navigationTitle("Crop Image Picker")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button {
//                        showPicker.toggle()
//                    } label: {
//                        Image(systemName: "photo.on.rectangle.angled")
//                            .font(.callout)
//                    }
//                    .tint(.black)
//                }
//            }
////            .cropImagePicker(option: .roundedSquare, show: $showPicker, croppedImage: $croppedImage)
//        }
//    }
//}
//
//#Preview {
//    Home()
//}
