//
//  CustomImagePicker.swift
//  Clique
//
//  Created by Rod Tavangar on 6/29/24.
//

import SwiftUI
import PhotosUI

enum Crop: Equatable {
    case circle
    case cliquePfp
    case banner(width: CGFloat)
    case custom(CGSize)
    
    var size: CGSize {
        switch self {
        case .circle:
            return .init(width: 300, height: 300)
        case .cliquePfp:
            return .init(width: 200, height: 200)
        case .banner(let width):
            return .init(width: width, height: width / Constants.expandedBannerRatio)
        case .custom(let cGSize):
            return cGSize
        }
    }
}

// MARK: - View Extensions
extension View {
    @ViewBuilder
    func cropImagePicker(type: Crop, show: Binding<Bool>, croppedUIImage: Binding<UIImage?>) -> some View {
        CustomImagePicker(type: type, show: show, croppedUIImage: croppedUIImage) {
            self
        }
    }
    
    /// - For Making it Simple and easy to use
    @ViewBuilder
    func frame(_ size: CGSize) -> some View {
        self
            .frame(width: size.width, height: size.height)
    }
    
    /// - Haptic Feedback
    func haptics(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - CustomImagePicker
fileprivate struct CustomImagePicker<Content: View>: View {
    var content: Content
    var type: Crop
    @Binding var show: Bool
    @Binding var croppedUIImage: UIImage?
    
    init(type: Crop, show: Binding<Bool>, croppedUIImage: Binding<UIImage?>, @ViewBuilder content: @escaping () -> Content) {
        self.content = content()
        self._show = show
        self._croppedUIImage = croppedUIImage
        self.type = type
    }
    
    /// View Properties
    @State private var photosItem: PhotosPickerItem?
    @State private var selectedUIImage: UIImage?
    @State private var showCropView: Bool = false
    
    var body: some View {
        content
            .onChange(of: show) { _, newValue in
                if newValue {
                    showCropView = false
                    photosItem = nil
                }
            }
            .photosPicker(
                isPresented: $show,
                selection: $photosItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: photosItem) { _, newValue in
                if let newValue {
                    showCropView = true // Show crop view right away
                    Task {
                        if let imageData = try await newValue.loadTransferable(type: Data.self),
                           let image = UIImage(data: imageData) {
                            DispatchQueue.main.async {
                                selectedUIImage = image // Load image in background
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCropView, onDismiss: {
                selectedUIImage = nil
                photosItem = nil
            }) {
                CropView(crop: type, image: selectedUIImage) { croppedUIImage, _ in
                    if let croppedUIImage {
                        self.croppedUIImage = croppedUIImage
                    }
                    showCropView = false
                }
            }
    }
}

struct CropView: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 0
    @State private var offset: CGSize = .zero
    @State private var lastStoredOffset: CGSize = .zero
    @GestureState private var isInteracting: Bool = false
    
    let crop: Crop
    let image: UIImage?
    let onCrop: (UIImage?, Bool) -> ()
    
    var body: some View {
        Group {
            if let image {
                ImageView()
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 16) {
                            Button {
                                dismiss()
                            } label: {
                                IconImage("x-icon", color: .theme.white, size: 32)
                            }
                            
                            Button {
                                /// Converting View to Image (Native iOS 16+)
                                let renderer = ImageRenderer(content: ImageView(true))
                                renderer.scale = displayScale
                                
                                if let uiImage = renderer.uiImage?.withoutAlpha() {
                                    onCrop(uiImage, true)
                                } else {
                                    onCrop(nil, false)
                                }
                                
                                dismiss()
                            } label: {
                                IconImage("check", color: .theme.white, size: 32)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(x: -8, y: 40)
                    }
            } else {
                VStack {
                    Text("Downloading from iCloud...")
                        .font(.callout)
                        .foregroundStyle(Color.theme.shadesWhite95)
                    
                    CliqueProgressView(forceLight: true)
                }
            }
        }
        .infiniteFrame()
        .background (
            Color.theme.black
                .ignoresSafeArea()
                .opacity(0.95)
                .onTapGesture {
                    dismiss()
                }
        )
    }
    
    private func cropTheImageWithImageViewSize() -> UIImage? {
        if let inputImage = image {
            
            let imsize = inputImage.size
            let scale = max(inputImage.size.width / crop.size.width,
                            inputImage.size.height / crop.size.height)
            let zoomScale = self.scale
            //        print("imageView size:\(size), image size:\(imsize), aspectScale:\(scale),zoomScale:\(zoomScale)，currentPostion:\(dragAmount)")
            let currentPositionWidth = self.offset.width * scale
            let currentPositionHeight = self.offset.height * scale
            
            let croppedImsize = CGSize(width: (self.crop.size.width * scale) / zoomScale, height: (self.crop.size.height * scale) / zoomScale)
            
            let xOffset = (( imsize.width - croppedImsize.width) / 2.0) - (currentPositionWidth / zoomScale)
            let yOffset = (( imsize.height - croppedImsize.height) / 2.0) - (currentPositionHeight / zoomScale)
            let croppedImrect = CGRect(x: xOffset, y: yOffset, width: croppedImsize.width, height: croppedImsize.height)
            
            //        print("croppedImsize:\(croppedImsize),croppedImrect:\(croppedImrect)")
            if let cropped = inputImage.cgImage?.cropping(to: croppedImrect) {
                return UIImage(cgImage: cropped)
            }
        }
        return nil
    }
    
    /// - Image View
    @ViewBuilder
    func ImageView(_ hideGrids: Bool = false) -> some View {
        let cropSize = crop.size
        GeometryReader {
            let size = $0.size
            
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(content: {
                        GeometryReader { proxy in
                            let rect = proxy.frame(in: .named("CROPVIEW"))
                            
                            Color.clear
                                .onChange(of: isInteracting) { oldValue, newValue in
                                    /// - true Dragging
                                    /// - false Stopped Dragging
                                    /// With the Help of GemoetryReader
                                    /// We can now read the minX,Y and maxX,Y of the Image
                                    if !newValue {
                                        /// - Storing Last Offset
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if rect.minX > 0 {
                                                /// - Resetting to Last Location
                                                offset.width = (offset.width - rect.minX)
                                                haptics(.medium)
                                            }
                                            if rect.minY > 0 {
                                                /// - Resetting to Last Location
                                                offset.height = (offset.height - rect.minY)
                                                haptics(.medium)
                                            }
                                            
                                            /// - Doing the Same for maxX,Y
                                            if rect.maxX < size.width {
                                                /// - Resetting to Last Location
                                                offset.width = (rect.minX - offset.width)
                                                haptics(.medium)
                                            }
                                            
                                            if rect.maxY < size.height {
                                                /// - Resetting to Last Location
                                                offset.height = (rect.minY - offset.height)
                                                haptics(.medium)
                                            }
                                        }
                                        lastStoredOffset = offset
                                    }
                                }
                        }
                    })
                    .frame(size)
                    .onChange(of: isInteracting) { oldValue, newValue in
                        /// - true Dragging
                        /// - false Stopped Dragging
                        if !newValue {
                            /// - Storing Last Offset
                            lastStoredOffset = offset
                        }
                    }
            }
        }
        .scaleEffect(scale)
        .offset(offset)
        .overlay(content: {
            /// We Don't Need Grid View for Cropped Image
//            if !hideGrids && crop != .circle && crop != .roundedSquare {
//                Grids()
//            }
        })
        .coordinateSpace(name: "CROPVIEW")
        .gesture(
            DragGesture()
                .updating($isInteracting, body: { _, out, _ in
                    out = true
                }).onChanged({ value in
                    let translation = value.translation
                    offset = CGSize(width: translation.width + lastStoredOffset.width, height: translation.height + lastStoredOffset.height)
                })
        )
        .gesture(
            MagnifyGesture()
                .updating($isInteracting, body: { _, out, _ in
                    out = true
                }).onChanged({ value in
                    let updatedScale = value.magnification + lastScale
                    /// - Limiting Beyond 1
                    scale = (updatedScale < 1 ? 1 : updatedScale)
                }).onEnded({ value in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if scale < 1 {
                            scale = 1
                            lastScale = 0
                        } else {
                            lastScale = scale - 1
                        }
                    }
                })
        )
        .frame(cropSize)
        .clipShape(RoundedRectangle(cornerRadius: crop == .circle ? cropSize.height : crop == .cliquePfp ? 32 : 0))
    }
    
    /// - Grids
    @ViewBuilder
    func Grids() -> some View {
        ZStack {
            HStack {
                ForEach(1...5, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.7))
                        .frame(width: 1)
                        .frame(maxWidth: .infinity)
                }
            }
            
            HStack {
                ForEach(1...8, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.7))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

#Preview {
    CropView(crop: .cliquePfp, image: UIImage(named: "rod-pp")) { _, _ in }
}
