//
//  ViewController.swift
//  FaceDetectionSystem
//
//  Created by Hana Azizah on 21/02/24.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    // MARK: - Variables
    
    private var drawings: [CAShapeLayer] = []
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let captureSession = AVCaptureSession()
    
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        addCameraInput()
        showCameraFeed()
        
        getCameraFrames()
//        captureSession.startRunning()
        DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer.frame = view.frame
    }

    // MARK: - Helper Function
    
    private func addCameraInput() {
        
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .front)
            .devices.first else {
                fatalError("No Camera detected. Please use real camera, not a simulator.")
        }
        
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        captureSession.addInput(cameraInput)
    }
    
    private func showCameraFeed() {
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
    }
    
    private func getCameraFrames() {
        videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        
        captureSession.addOutput(videoDataOutput)
        
        guard let connection = videoDataOutput.connection(with: .video) else {
//        guard videoDataOutput.connection(with: .video) != nil else {
            return
        }
        
    }
    
    private func detectFace(image: CVPixelBuffer) {
        
        let faceDetectionRequest = VNDetectFaceLandmarksRequest { vnRequest, error in
            DispatchQueue.main.async {
                if let results = vnRequest.results as? [VNFaceObservation], results.count > 0 {
                    print("Detected \(results.count) faces!")
                    self.handleFaceDetectionResults(observedFaces: results)
                } else {
                    print("No face detected")
                    self.clearDrawings()
                }
            }
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
        
    }
    
    private func handleFaceDetectionResults(observedFaces: [VNFaceObservation]) {
        clearDrawings()
        
        let facesBoundingBoxes: [CAShapeLayer] = observedFaces.map({ (observedFace: VNFaceObservation) ->
            CAShapeLayer in
            
            let faceBoundingBoxOnScreen = previewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
            let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
            let faceBoundingBoxShape = CAShapeLayer()
            
            faceBoundingBoxShape.path = faceBoundingBoxPath
            faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
            faceBoundingBoxShape.strokeColor = UIColor.green.cgColor
            
            return faceBoundingBoxShape
        })
        
        facesBoundingBoxes.forEach { faceBoundingBox in
            view.layer.addSublayer(faceBoundingBox)
            drawings = facesBoundingBoxes
        }
    }
    
    private func clearDrawings() {
        drawings.forEach({drawing in drawing.removeFromSuperlayer()})
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("Received a frame")
        
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("Unable to get image from the sample buffer")
            return
        }
        
        detectFace(image: frame)
    }
}
