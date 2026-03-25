//
//  CameraView.swift
//  VisionGraspAssist
//
//  Created by Vincent Tsang on 22/3/2026.
//

import SwiftUI
import AVFoundation
import Vision

struct CameraView: UIViewRepresentable {
    @Binding var wristLocation: String // 這是我們要更新的目標

    func makeCoordinator() -> Coordinator {
        // 將 self (即 CameraView) 傳進去，讓 Coordinator 能改到 Binding
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        context.coordinator.parentView = view
        view.setSampleBufferDelegate(context.coordinator)
        return view
    }

    func updateUIView(_ uiView: CameraUIView, context: Context) {}

    // MARK: - Coordinator
    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraView // 持有父結構的引用
        private let handPoseRequest = VNDetectHumanHandPoseRequest()
        weak var parentView: CameraUIView?

        init(parent: CameraView) {
            self.parent = parent
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            do {
                try handler.perform([handPoseRequest])
                if let observation = handPoseRequest.results?.first {
                    // 取得手腕點
                    if let wrist = try? observation.recognizedPoint(.wrist), wrist.confidence > 0.3 {
                        // 修正點：回到主線程更新 Binding
                        let normalized = wrist.location
                        
                        DispatchQueue.main.async {
                            // 透過 parent 存取 @Binding
                            self.parent.wristLocation = "X: \(String(format: "%.2f", wrist.location.x)), Y: \(String(format: "%.2f", wrist.location.y))"
                            if let cameraView = self.parentView {
                                let size = cameraView.bounds.size

                                let point = CGPoint(
                                    x: normalized.x * size.width,
                                    y: (1 - normalized.y) * size.height
                                )

                                cameraView.drawHandPoint(point)
                            }
                        }
                    }
                }
            } catch {
                print("Vision error: \(error)")
            }
        }
    }
}

// MARK: - UIKit View
final class CameraUIView: UIView {
    private let handLayer = CAShapeLayer()
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

        handLayer.fillColor = UIColor.red.cgColor
        layer.addSublayer(handLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    func drawHandPoint(_ point: CGPoint) {
        DispatchQueue.main.async {
            let radius: CGFloat = 8
            let path = UIBezierPath(
                ovalIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
            self.handLayer.path = path.cgPath
        }
    }
    
    func setSampleBufferDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]

        let queue = DispatchQueue(label: "video.frame.queue")
        output.setSampleBufferDelegate(delegate, queue: queue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
