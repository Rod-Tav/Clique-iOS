//
//  Camera.swift
//  Clique
//
//  Created by Rod Tavangar on 3/9/25.
//

import AVFoundation
import CoreImage
import UIKit
import os.log

class Camera: NSObject {
    private let captureSession = AVCaptureSession()
    private var isCaptureSessionConfigured = false
    private var deviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var sessionQueue: DispatchQueue!
    
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.captureDevice else { return }

            do {
                try device.lockForConfiguration()
                let maxZoom = device.activeFormat.videoMaxZoomFactor
                let clampedFactor = max(1.0, min(factor, maxZoom)) // Clamp properly
                device.videoZoomFactor = clampedFactor
                logger.debug("Zoom set to: \(clampedFactor)")
                device.unlockForConfiguration()
            } catch {
                logger.error("Failed to lock device for zoom: \(error.localizedDescription)")
            }
        }
    }
    
    var maxZoomFactor: CGFloat {
        captureDevice?.activeFormat.videoMaxZoomFactor ?? 5.0 // Default to 5x if unknown
    }

    var preferredZoomLevels: [CGFloat] {
        guard let device = captureDevice else { return [1.0] }
        
        let maxZoom = device.activeFormat.videoMaxZoomFactor
        var levels: [CGFloat] = [1.0] // Always include 1x
        
        if device.position == .front {
            // Front camera zoom options (some front cameras have 0.5x wide)
            if maxZoom >= 0.5 {
                levels.insert(0.5, at: 0) // Add 0.5x if supported
            }
        } else {
            // Back camera zoom options
            if maxZoom >= 2.0 {
                levels.append(2.0)
            }
            if maxZoom >= 5.0 {
                levels.append(5.0)
            } else if maxZoom >= 3.0 {
                levels.append(3.0)
            }
        }
        
        return levels
    }
    
    var maxAvailableZoom: CGFloat {
        captureDevice?.activeFormat.videoMaxZoomFactor ?? 5.0
    }
    
    private var multiCamera: AVCaptureDevice? {
        allCaptureDevices.first(where: {
            ($0.deviceType == .builtInDualCamera ||
             $0.deviceType == .builtInTripleCamera ||
             $0.deviceType == .builtInDualWideCamera) &&
            $0.position == .back
        })
    }
    
    private var wideAngleCamera: AVCaptureDevice? {
        allCaptureDevices.first(where: { $0.deviceType == .builtInWideAngleCamera && $0.position == .back })
    }
    
    private var telephotoCamera: AVCaptureDevice? {
        allCaptureDevices.first(where: { $0.deviceType == .builtInTelephotoCamera && $0.position == .back })
    }

    private var ultraWideCamera: AVCaptureDevice? {
        allCaptureDevices.first(where: { $0.deviceType == .builtInUltraWideCamera && $0.position == .back })
    }
    
    func switchToLensFor(zoomLevel: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.captureDevice else { return }
            
            do {
                try device.lockForConfiguration()
                let maxZoom = device.activeFormat.videoMaxZoomFactor
                
                var clampedZoom: CGFloat = zoomLevel
                
                if device.position == .front {
                    // ✅ Normalize for front camera
                    // Treat 0.5x as 1.0 (default wide)
                    // Treat 1x as 1.2 (or higher based on experimentation)
                    if zoomLevel == 0.5 {
                        clampedZoom = 1.0 // Wide mode (default)
                    } else if zoomLevel == 1.0 {
                        clampedZoom = min(maxZoom, 1.2) // Slight zoom-in, adjust as needed
                    }
                } else {
                    // Back camera: keep regular clamping
                    clampedZoom = min(max(1.0, zoomLevel), maxZoom)
                }
                
                device.videoZoomFactor = clampedZoom
                logger.debug("Set zoom to \(clampedZoom) on \(device.localizedName)")
                device.unlockForConfiguration()
            } catch {
                logger.error("Failed to set zoom: \(error.localizedDescription)")
            }
        }
    }
    
    private var allCaptureDevices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera, .builtInDualWideCamera], mediaType: .video, position: .unspecified).devices
    }
    
    private var frontCaptureDevices: [AVCaptureDevice] {
        allCaptureDevices
            .filter { $0.position == .front }
    }
    
    private var backCaptureDevices: [AVCaptureDevice] {
        allCaptureDevices
            .filter { $0.position == .back }
    }
    
    private var captureDevices: [AVCaptureDevice] {
        var devices = [AVCaptureDevice]()
//        #if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
//        devices += allCaptureDevices
//        #else
        if let backDevice = backCaptureDevices.first {
            devices += [backDevice]
        }
        if let frontDevice = frontCaptureDevices.first {
            devices += [frontDevice]
        }
//        #endif
        return devices
    }
    
    private var availableCaptureDevices: [AVCaptureDevice] {
        captureDevices
            .filter( { $0.isConnected } )
            .filter( { !$0.isSuspended } )
    }
    
    private var captureDevice: AVCaptureDevice? {
        didSet {
            guard let captureDevice = captureDevice else { return }
//            logger.debug("Using capture device: \(captureDevice.localizedName)")
            sessionQueue.async {
                self.updateSessionForCaptureDevice(captureDevice)
            }
        }
    }
    
    var isRunning: Bool {
        captureSession.isRunning
    }
    
    var isUsingFrontCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return frontCaptureDevices.contains(captureDevice)
    }
    
    var isUsingBackCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return backCaptureDevices.contains(captureDevice)
    }

    private var addToPhotoStream: ((UIImage) -> Void)?
    
    private var addToPreviewStream: ((CIImage) -> Void)?
    
    var isPreviewPaused = false
    
    lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                }
            }
        }
    }()
    
    lazy var photoStream: AsyncStream<UIImage> = {
        AsyncStream { continuation in
            addToPhotoStream = { image in
                continuation.yield(image)
            }
        }
    }()
        
    override init() {
        super.init()
        initialize()
    }
    
    private func logAvailableCameras() {
        for device in allCaptureDevices {
            logger.debug("Device: \(device.localizedName), Type: \(device.deviceType.rawValue), Max Zoom: \(device.activeFormat.videoMaxZoomFactor)")
        }
    }
    
    private func initialize() {
//        logAvailableCameras()
        sessionQueue = DispatchQueue(label: "session queue")
        
        if let captureDevice = multiCamera ?? wideAngleCamera ?? availableCaptureDevices.first {
            self.captureDevice = captureDevice
//            self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            self.previewLayer?.videoGravity = .resizeAspectFill
            
            self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: captureDevice, previewLayer: previewLayer)
        }
    }
    
    private func configureCaptureSession(completionHandler: (_ success: Bool) -> Void) {
        
        var success = false
        
        self.captureSession.beginConfiguration()
        
        defer {
            self.captureSession.commitConfiguration()
            completionHandler(success)
        }
        
        guard
            let captureDevice = captureDevice,
            let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        else {
            logger.error("Failed to obtain video input.")
            return
        }
        
        let photoOutput = AVCapturePhotoOutput()
                        
        captureSession.sessionPreset = AVCaptureSession.Preset.photo

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
  
        guard captureSession.canAddInput(deviceInput) else {
            logger.error("Unable to add device input to capture session.")
            return
        }
        guard captureSession.canAddOutput(photoOutput) else {
            logger.error("Unable to add photo output to capture session.")
            return
        }
        guard captureSession.canAddOutput(videoOutput) else {
            logger.error("Unable to add video output to capture session.")
            return
        }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoOutput)
        
        self.deviceInput = deviceInput
        self.photoOutput = photoOutput
        self.videoOutput = videoOutput
        
        if let maxResolution = captureDevice.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            photoOutput.maxPhotoDimensions = maxResolution
        }
        photoOutput.maxPhotoQualityPrioritization = .quality
        
        updateVideoOutputConnection()
        
        isCaptureSessionConfigured = true
        
        success = true
    }
    
    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            logger.debug("Camera access authorized.")
            return true
            
        case .notDetermined:
            logger.debug("Camera access not determined.")
            sessionQueue.suspend()
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            sessionQueue.resume()
            return granted
            
        case .denied, .restricted:
            logger.debug("Camera access denied or restricted.")
            await presentSettingsAlert()
            return false
            
        @unknown default:
            return false
        }
    }
    
    @MainActor private func presentSettingsAlert() async {
        guard let topController = UIWindow.current?.rootViewController else { return }
        
        let alert = UIAlertController(
            title: "Camera Access Needed",
            message: "Please enable camera access in Settings to use this feature.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }))
        
        topController.present(alert, animated: true)
    }
    
    private func deviceInputFor(device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let error {
            logger.error("Error getting capture device input: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice) {
        guard isCaptureSessionConfigured else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        for input in captureSession.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                captureSession.removeInput(deviceInput)
            }
        }
        
        if let deviceInput = deviceInputFor(device: captureDevice) {
            if !captureSession.inputs.contains(deviceInput), captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
        }
        
        updateVideoOutputConnection()
    }
    
    private func updateVideoOutputConnection() {
        guard let videoOutput = videoOutput, let videoOutputConnection = videoOutput.connection(with: .video) else { return }
        
        if videoOutputConnection.isVideoMirroringSupported {
            videoOutputConnection.isVideoMirrored = isUsingFrontCaptureDevice
        }
    }
    
    private func videoRotationAngle(for deviceOrientation: UIDeviceOrientation) -> Float64 {
        switch deviceOrientation {
        case .portrait:
            return 0
        case .landscapeLeft:
            return 270 // Rotate the video when device is landscape left
        case .portraitUpsideDown:
            return 180
        case .landscapeRight:
            return 90 // Rotate the video when device is landscape right
        default:
            return 0 // Fallback to portrait
        }
    }
    
    func stopObservingDeviceOrientation() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    func start() async {
        let authorized = await checkAuthorization()
        guard authorized else {
            logger.error("Camera access was not authorized.")
            return
        }
        
        await UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(updateForDeviceOrientation), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async {
                    print("✅ Starting capture session")
                    self.captureSession.startRunning()
                }
            }
            return
        }
        
        sessionQueue.async {
            self.configureCaptureSession { success in
                if success {
                    print("✅ Capture session configured successfully")
                    self.captureSession.startRunning()
                } else {
                    print("❌ Failed to configure capture session")
                }
            }
        }
    }
    
    func stop() {
        guard isCaptureSessionConfigured else { return }
        
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
        
        stopObservingDeviceOrientation()
    }
    
    func switchCaptureDevice() {
        if let captureDevice = captureDevice, let index = availableCaptureDevices.firstIndex(of: captureDevice) {
            let nextIndex = (index + 1) % availableCaptureDevices.count
            self.captureDevice = availableCaptureDevices[nextIndex]
        } else {
            self.captureDevice = AVCaptureDevice.default(for: .video)
        }
    }

    private var deviceOrientation: UIDeviceOrientation {
        var orientation = UIDevice.current.orientation
        if orientation == UIDeviceOrientation.unknown {
            orientation = UIScreen.main.orientation
        }
        return orientation
    }
    
    var onDeviceOrientationChange: ((UIDeviceOrientation) -> Void)?
    
    @objc
    func updateForDeviceOrientation() {
        print("🔄 Device rotated to: \(deviceOrientation)")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.updateVideoOutputConnection()
        }

        // Call DataModel observer (if set)
        onDeviceOrientationChange?(deviceOrientation)
    }
    
    func takePhoto(flashMode: AVCaptureDevice.FlashMode) {
        guard let photoOutput = self.photoOutput else { return }
        
        sessionQueue.async {
            var photoSettings = AVCapturePhotoSettings()
            
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            photoSettings.flashMode = flashMode // ✅ Use passed-in flash mode
            
            if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
            }
            
            photoSettings.photoQualityPrioritization = .balanced
            
            if let photoOutputVideoConnection = photoOutput.connection(with: .video), let rotationCoordinator = self.rotationCoordinator {
                let videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
                photoOutputVideoConnection.videoRotationAngle = videoRotationAngle
            }
            
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}

extension UIImage {
    func fixedOrientationMirrored() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move origin to middle
        context.translateBy(x: self.size.width, y: 0)
        // Flip horizontally
        context.scaleBy(x: -1.0, y: 1.0)
        
        // Draw original image in the flipped context
        self.draw(in: CGRect(origin: .zero, size: self.size))
        
        // Get new image from context
        let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return flippedImage ?? self
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("✅ Photo delegate called")
        if let error = error {
            logger.error("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        if let data = photo.fileDataRepresentation(), var image = UIImage(data: data) {
            print("✅ Photo converted to UIImage")

            // ✅ Flip image if using front camera, but do NOT affect orientation metadata
            if isUsingFrontCaptureDevice {
                image = image.fixedOrientationMirrored()
            }

            addToPhotoStream?(image) // ✅ Pass final (properly flipped) image
        } else {
            logger.error("Failed to convert AVCapturePhoto to UIImage")
        }
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
        if let rotationCoordinator = rotationCoordinator {
            let videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
            if connection.isVideoRotationAngleSupported(videoRotationAngle) {
                connection.videoRotationAngle = videoRotationAngle
            }
        }
        
        addToPreviewStream?(CIImage(cvPixelBuffer: pixelBuffer))
    }
}

fileprivate extension UIScreen {

    var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeRight //.landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeLeft //.landscapeRight
        } else {
            return .unknown
        }
    }
}

fileprivate let logger = Logger(subsystem: "com.apple.swiftplaygroundscontent.capturingphotos", category: "Camera")


extension Camera: @unchecked Sendable {} // Capture of ‘self’ with non-sendable type ‘Camera’ in a `@Sendable` closure
