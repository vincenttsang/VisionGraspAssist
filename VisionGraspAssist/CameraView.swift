//
//  CameraView.swift
//  VisionGraspAssist
//
//  Created by Vincent Tsang on 22/3/2026.
//

import SwiftUI
import AVFoundation
import Vision
import CoreML

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
        private let handPoseRequest: VNDetectHumanHandPoseRequest
        private let objectRequest: VNCoreMLRequest
        weak var parentView: CameraUIView?
        // 儲存最新狀態（image space, UIKit coordinates）
        private var currentHandPoint: CGPoint?
        private var currentObjectRect: CGRect?
        
        // Guidance state
        enum GuidanceState {
            case guiding
            case grasped
        }

        private var guidanceState: GuidanceState = .guiding

        // 穩定計數
        private var readyFrameCount: Int = 0

        init(parent: CameraView) {
            self.parent = parent
            // Hand Pose
            handPoseRequest = VNDetectHumanHandPoseRequest()

            // Object Detection
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let model = try! VNCoreMLModel(for: MobileNetV2_SSDLite(configuration: config).model)
            objectRequest = VNCoreMLRequest(model: model)
            objectRequest.imageCropAndScaleOption = .scaleFill
            
            super.init()
        }
        
        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            do {
                try handler.perform([handPoseRequest, objectRequest])
                if let results = objectRequest.results as? [VNRecognizedObjectObservation],
                   let best = results.first,
                   best.confidence > 0.5 {

                    // normalized bounding box
                    let box = best.boundingBox

                    DispatchQueue.main.async {
                        if let view = self.parentView {
                            let size = view.bounds.size

                            // Vision → UIKit 座標轉換
                            let rect = CGRect(
                                x: box.origin.x * size.width,
                                y: (1 - box.origin.y - box.height) * size.height,
                                width: box.width * size.width,
                                height: box.height * size.height
                            )
                            
                            
                            let objectCenter = CGPoint(
                                x: rect.midX,
                                y: rect.midY
                            )
                            
                            let label = best.labels.first?.identifier ?? "unknown"
                            print("📦 Object:", label, objectCenter)
                            
                            self.currentObjectRect = rect
                            view.drawObjectBox(rect)
                        }
                    }
                }
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
                                
                                self.currentHandPoint = point
                                cameraView.drawHandPoint(point)
                            }
                        }
                    }
                }
            } catch {
                print("Vision error: \(error)")
            }
            
            if let handPoint = currentHandPoint,
               let objectRect = currentObjectRect {
                if let guidance = computeGuidance(
                    handPoint: handPoint,
                    objectRect: objectRect
                ) {
                    print("🧭 Guidance:", guidance)
                }
            }
        }
        
        /// Computes guidance instruction based on hand–object spatial relation.
        /// Returns nil if no instruction should be given.
        func computeGuidance(
            handPoint: CGPoint,
            objectRect: CGRect
        ) -> String? {

            // -------------------------------------------------
            // 解法 3：如果已抓取，永遠保持靜默
            // -------------------------------------------------
            if guidanceState == .grasped {
                return nil
            }

            // -------------------------------------------------
            // 解法 1：手進入物體範圍 → 視為已抓取
            // -------------------------------------------------
            let expandedRect = objectRect.insetBy(dx: -20, dy: -20)
            if expandedRect.contains(handPoint) {
                guidanceState = .grasped
                print("✅ GuidanceState → grasped")
                return nil
            }

            // -------------------------------------------------
            // 基本幾何關係
            // -------------------------------------------------
            let objectCenter = CGPoint(
                x: objectRect.midX,
                y: objectRect.midY
            )

            let dx = handPoint.x - objectCenter.x
            let dy = handPoint.y - objectCenter.y

            let tolerance: CGFloat = 30

            // -------------------------------------------------
            // 水平 / 垂直優先對齊
            // -------------------------------------------------
            if dx < -tolerance {
                readyFrameCount = 0
                return "向右移動"
            }

            if dx > tolerance {
                readyFrameCount = 0
                return "向左移動"
            }

            if dy < -tolerance {
                readyFrameCount = 0
                return "向下移動"
            }

            if dy > tolerance {
                readyFrameCount = 0
                return "向上移動"
            }

            // -------------------------------------------------
            // 距離判斷（解法 2：穩定條件）
            // -------------------------------------------------
            let distance = hypot(dx, dy)
            let readyDistance: CGFloat = 60

            if distance < readyDistance {
                readyFrameCount += 1
            } else {
                readyFrameCount = 0
                return "向前靠近"
            }

            // 需要連續 N 幀才視為 ready
            if readyFrameCount >= 5 {
                return "停，可以抓取"
            }

            return nil
        }
    }
}

// MARK: - UIKit View
final class CameraUIView: UIView {
    private let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let handLayer = CAShapeLayer()
    private let objectLayer = CAShapeLayer()

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

        // Preview Layer
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        
        // Object Layer
        objectLayer.strokeColor = UIColor.green.cgColor
        objectLayer.lineWidth = 3
        objectLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(objectLayer)
        
        // Hand Layer
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
    
    func drawObjectBox(_ rect: CGRect) {
        DispatchQueue.main.async {
            let path = UIBezierPath(rect: rect)
            self.objectLayer.path = path.cgPath
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
