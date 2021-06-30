//
//  FlutterCameraView.swift
//  flutter_camera_view
//
//  Created by 董子文 on 2021/6/28.
//

import AVFoundation
import Flutter
import UIKit
import CameraManager

class FlutterCameraView: NSObject, FlutterPlatformView {
    
    private var cameraView: UIView
    private let cameraManager: CameraManager
    private var fileURL: URL?
    private var isTakingVideo: Bool = false
    private var isTakingPicture: Bool = false
    private var channel: FlutterMethodChannel?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        cameraView = UIView();
        cameraManager = CameraManager();
        super.init()
        
        if(args is NSDictionary){
            let dict = args as! NSDictionary
            cameraManager.cameraDevice = dict.value(forKey: "facing") as! String == "FRONT" ? .front : .back
            cameraManager.cameraOutputQuality = getPresetForString(size: dict.value(forKey: "resolutionPreset") as! String)
        }
        // iOS views can be created here
        cameraManager.focusMode = .autoFocus
        cameraManager.shouldFlipFrontCameraImage = true
        
        channel = FlutterMethodChannel(name: "flutter_camera_view_channel", binaryMessenger: messenger!, codec: FlutterJSONMethodCodec.sharedInstance())
        channel!.setMethodCallHandler(handle)
        
        cameraManager.addPreviewLayerToView(cameraView)
        if (cameraManager.cameraIsReady) {
            channel!.invokeMethod("onCameraOpened", arguments: nil)
        }
    }

    func view() -> UIView {
        return cameraView
    }

    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        var dict: NSDictionary? = nil
        if (call.arguments != nil) {
            dict = (call.arguments as! NSDictionary)
        }
        switch call.method {
        case "setFacing":
            let facing: String = dict!.value(forKey: "facing") as! String
            self.cameraManager.cameraDevice = facing == "FRONT" ? .front : .back
            result(true)
        case "takePicture":
            if (errorIfCameraNotOpened(result: result)) {
                return
            }
            if (errorIfTakingVideo(result: result)) {
                return
            }
            if (errorIfTakingPicture(result: result)) {
                return
            }
            cameraManager.cameraOutputMode = .stillImage
            let file: String = dict!.value(forKey: "file") as! String
            isTakingPicture = true
            cameraManager.capturePictureWithCompletion({ image in
                switch image {
                    case .failure:
                        self.isTakingPicture = false
                        result(FlutterError.init(code: "TakePictureError", message: "Take picture failure.", details: nil))
                    case .success(let content):
                        let path = self.storeImageDataToFile(data: content.asData!, path: file)
                        self.isTakingPicture = false
                        result(path)
                }
            })
        case "startRecording":
            if (errorIfCameraNotOpened(result: result)) {
                return
            }
            if (errorIfTakingVideo(result: result)) {
                return
            }
            if (errorIfTakingPicture(result: result)) {
                return
            }
            cameraManager.cameraOutputMode = .videoWithMic
            let file: String = dict!.value(forKey: "file") as! String
            self.fileURL = URL(fileURLWithPath: file)
            self.isTakingVideo = true
            cameraManager.startRecordingVideo()
            result(true)
            onVideoRecordingStart()
        case "stopRecording":
            if (errorIfCameraNotOpened(result: result)) {
                return
            }
            cameraManager.stopVideoRecording({ (videoURL, recordError) -> Void in
                guard let videoURL = videoURL else {
                    self.isTakingVideo = false
                    //Handle error of no recorded video URL
                    result(FlutterError.init(code: "RecordedError", message: recordError?.description ?? "No recorded.", details: nil))
                    return;
                }
                do {
                    self.onVideoRecordingEnd()
                    try FileManager.default.copyItem(at: videoURL, to: self.fileURL!)
                    self.isTakingVideo = false
                    result(true)
                    self.onVideoTaken()
                }
                catch {
                    self.isTakingVideo = false
                    result(FlutterError.init(code: "RecordedError", message: recordError?.description ?? "Recorded error.", details: nil))
                }
            })
        default:
            result(nil)
        }
    }
    
    func onVideoRecordingStart() -> Void {
        channel!.invokeMethod("onVideoRecordingStart", arguments: nil)
    }
    
    func onVideoRecordingEnd() -> Void {
        channel!.invokeMethod("onVideoRecordingEnd", arguments: nil)
    }
    
    func onVideoTaken() -> Void {
        channel!.invokeMethod("onVideoTaken", arguments: nil)
    }
    
    func errorIfCameraNotOpened(result: FlutterResult) -> Bool {
        if (!cameraManager.cameraIsReady) {
            result(FlutterError.init(code: "CameraError", message: "Camera is not opened.", details: nil))
            return true
        }
        return false
    }
    
    func errorIfTakingPicture(result: FlutterResult) -> Bool {
        if (isTakingPicture) {
            result(FlutterError.init(code: "CameraError", message: "Already is taking picture.", details: nil))
            return true
        }
        return false
    }
    
    func errorIfTakingVideo(result: FlutterResult) -> Bool {
        if (isTakingVideo) {
            result(FlutterError.init(code: "CameraError", message: "Already is recording video.", details: nil))
            return true
        }
        return false
    }
    
    func imageToData(image: UIImage) -> Data? {
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            return nil
        }
        return data
    }
    
    func storeImageDataToFile(data: Data, path: String) -> String? {
        let fileURL = URL(fileURLWithPath: path)
        do {
            try data.write(to: fileURL)
            return path
        } catch {
            return nil
        }
    }
    
    func getPresetForString(size: String) -> AVCaptureSession.Preset {
        var preset: AVCaptureSession.Preset = .high
        switch size {
        case "2160p":
            let canSetPreset = cameraManager.canSetPreset(preset: .hd4K3840x2160)
            if (canSetPreset ?? false) {
                preset = .hd4K3840x2160
            } else {
                preset = getPresetForString(size: "1080p")
            }
            break;
        case "1080p":
            let canSetPreset = cameraManager.canSetPreset(preset: .hd1920x1080)
            if (canSetPreset ?? false) {
                preset = .hd1920x1080
            } else {
                preset = getPresetForString(size: "720p")
            }
            break;
        case "720p":
            let canSetPreset = cameraManager.canSetPreset(preset: .hd1280x720)
            if (canSetPreset ?? false) {
                preset = .hd1280x720
            } else {
                preset = getPresetForString(size: "540p")
            }
            break;
        case "540p":
            let canSetPreset = cameraManager.canSetPreset(preset: .iFrame960x540)
            if (canSetPreset ?? false) {
                preset = .iFrame960x540
            } else {
                preset = getPresetForString(size: "480p")
            }
            break;
        case "480p":
            let canSetPreset = cameraManager.canSetPreset(preset: .vga640x480)
            if (canSetPreset ?? false) {
                preset = .vga640x480
            } else {
                preset = .high
            }
            break;
        default:
            preset = .high
            break;
        }
        return preset;
    }
}
