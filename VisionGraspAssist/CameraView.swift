//
//  CameraView.swift
//  VisionGraspAssist
//
//  Created by Vincent Tsang on 22/3/2026.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {

    func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        return view
    }

    func updateUIView(_ uiView: CameraUIView, context: Context) {
        // No need to update
    }
}

// MARK: - UIKit View
final class CameraUIView: UIView {

    private let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCamera() {
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            print("❌ Cannot get camera")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("❌ Camera input error:", error)
            return
        }

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
