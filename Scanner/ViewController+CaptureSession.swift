/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import AVFoundation
import Structure
import UIKit

struct FormatDescription: Hashable, CustomStringConvertible {
  var width: Int32
  var height: Int32
  var maxFps: Double
  var binning: Bool
  var arkitFormat: ARConfiguration.VideoFormat?

  static var VGA: FormatDescription { FormatDescription(width: 640, height: 480, maxFps: 30, binning: false) }

  // Hashable
  func hash(into hasher: inout Hasher) {
    hasher.combine(width)
    hasher.combine(height)
    hasher.combine(maxFps)
    hasher.combine(binning)
  }

  // CustomStringConvertible
  var description: String {
    if binning {
      return String("\(width)x\(height)@\(maxFps) binned")
    } else {
      return String("\(width)x\(height)@\(maxFps)")
    }
  }
}

extension ViewController: STCaptureSessionDelegate {
  // MARK: - Capture Session Setup

  func getColorAVFormats(
    _ videoDevice: AVCaptureDevice, ratio: Float = 0.75, minFps: Double = 30, depthCompatible: Bool = true
  ) -> [FormatDescription] {
    let eps: Float = 1e-5
    let filtered: [AVCaptureDevice.Format] = videoDevice.formats.filter {
      let dims = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
      let frameRatio = Float(dims.height) / Float(dims.width)
      let ratioOk = ratio == 0 || abs(frameRatio - ratio) < eps
      return CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        && (abs(Float(dims.height) / Float(dims.width) - ratio) < eps) // 4x3 ratio
        && ratioOk
        && $0.videoSupportedFrameRateRanges[0].maxFrameRate >= minFps
    }

    let sorted = filtered.sorted { first, second in
      CMVideoFormatDescriptionGetDimensions(first.formatDescription).width
        > CMVideoFormatDescriptionGetDimensions(second.formatDescription).width
    }

    return sorted.map { format in
      let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
      return FormatDescription(
        width: dims.width, height: dims.height, maxFps: format.videoSupportedFrameRateRanges[0].maxFrameRate,
        binning: format.isVideoBinned)
    }
  }

  func setupCaptureSession() {
    // Clear / reset the capture session if it already exists
    if captureSession == nil {
      // Create an STCaptureSession instance
      captureSession = STCaptureSession.new()

      // Enable the following line and comment the above out to playback occ
      // _captureSession = [STCaptureSession
      // newCaptureSessionFromOccFile:@"[AppDocuments]/SN98802_Warm_2020-10-13_13-20-09.occ"];
      // Create an STCaptureSession instance

    } else {
      captureSession!.streamingEnabled = false
    }

    guard let captureSession = captureSession else { return }

    guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }

    var supportedResolution = FormatDescription.VGA

    // Get all valid 4:3 formats
    let availableResolutions = getColorAVFormats(backCamera, ratio: 0.75)

    // Try to find a high-quality resolution that is NOT 4K (e.g., between 720p and 1080p/1440p). Anything above width 2000 is usually overkill and may cause battery drain issues.
    if let bestChoice = availableResolutions.first(where: { $0.width <= 1920 && $0.width >= 1280 }) {
      supportedResolution = bestChoice
    }
    // If nothing found in that "sweet spot", just take the highest available resolution.
    else if let highestFallback = availableResolutions.first {
      supportedResolution = highestFallback
    }

    let sensorConfig = [
      kSTCaptureSessionOptionColorResolutionKey: [supportedResolution.width, supportedResolution.height],
      kSTCaptureSessionOptionDepthFrameResolutionKey: NSNumber(value: dynamicOptions.depthResolution.rawValue),
      kSTCaptureSessionOptionColorMaxFPSKey: supportedResolution.maxFps,
      kSTCaptureSessionOptionDepthSensorEnabledKey: NSNumber(value: true),
      kSTCaptureSessionOptionUseAppleCoreMotionKey: NSNumber(value: true),
      kSTCaptureSessionOptionDepthStreamPresetKey: NSNumber(value: dynamicOptions.depthStreamPreset.rawValue),
      kSTCaptureSessionOptionSimulateRealtimePlaybackKey: NSNumber(value: true),
      kSTCaptureSessionOptionDepthSearchWindowKey: [NSNumber(value: depthWindowSearchWidth), NSNumber(value: depthWindowSearchHeight)],
      kSTCaptureSessionOptionST01CompatibilityKey: st01CompatibilityMode
    ] as [String: Any]

    // Set ourself as the delegate to receive sensor data.
    captureSession.delegate = self
    captureSession.startMonitoring(options: sensorConfig)
  }

  func isStructureConnected() -> Bool {
    return captureSession!.sensorMode.rawValue > STCaptureSessionSensorMode.notConnected.rawValue
  }

  // MARK: - STCaptureSession delegate methods

  func captureSession(_ captureSession: STCaptureSession, colorCameraDidEnter mode: STCaptureSessionColorCameraMode) {
    switch mode {
    case STCaptureSessionColorCameraMode.permissionDenied, STCaptureSessionColorCameraMode.ready:
      break
    case STCaptureSessionColorCameraMode.unknown:
      break
    default:
      // throw an exception
      fatalError("The color camera has entered an unknown state.")
    }
    updateViewsWithSensorStatus()
  }

  func captureSession(_ captureSession: STCaptureSession, sensorDidEnter mode: STCaptureSessionSensorMode) {
    switch mode {
    case STCaptureSessionSensorMode.ready, STCaptureSessionSensorMode.wakingUp, STCaptureSessionSensorMode.standby, STCaptureSessionSensorMode.notConnected, STCaptureSessionSensorMode.batteryDepleted:
      break
    // Fall through intentional
    case STCaptureSessionSensorMode.unknown:
      break
    default:
      // throw an exception
      fatalError("The sensor has entered an unknown mode.")
    }
    updateViewsWithSensorStatus()
  }

  func captureSession(_ captureSession: STCaptureSession, sensorChargerStateChanged chargerState: STCaptureSessionSensorChargerState) {
    switch chargerState {
    case STCaptureSessionSensorChargerState(rawValue: 0):
      break
    case STCaptureSessionSensorChargerState.disconnected:
      // Do nothing, we only need to handle low-power notifications based on the sensor mode.
      break
    case STCaptureSessionSensorChargerState.unknown:
      fatalError("Unknown STCaptureSessionSensorChargerState!")
    default:
      fatalError("Unknown STCaptureSessionSensorChargerState!")
    }
    updateViewsWithSensorStatus()
  }

  func captureSession(_ captureSession: STCaptureSession, didStart avCaptureSession: AVCaptureSession) {
    // Initialize our default video device properties once the AVCaptureSession has been started.
    self.captureSession!.properties = STCaptureSessionPropertiesSetColorCameraAutoExposureISOAndWhiteBalance()
  }

  func captureSession(_ captureSession: STCaptureSession, didStop avCaptureSession: AVCaptureSession) {}

  func captureSession(_ captureSession: STCaptureSession, didOutputSample sample: [AnyHashable: Any], type: STCaptureSessionSampleType) {
    switch type {
    case STCaptureSessionSampleType.sensorDepthFrame:
      let depthFrame = sample[kSTCaptureSessionSampleEntryDepthFrame] as? STDepthFrame
      if slamState.initialized {
        processDepthFrame(depthFrame!, colorFrameOrNil: nil)
        // Scene rendering is triggered by new frames to avoid rendering the same view several times.
        renderWithMetal(for: depthFrame!, colorFrameOrNil: nil)
      }
    case STCaptureSessionSampleType.iosColorFrame:
      // Skipping until a pair is returned.
      break
    case STCaptureSessionSampleType.synchronizedFrames:
      let depthFrame = sample[kSTCaptureSessionSampleEntryDepthFrame] as? STDepthFrame
      let colorFrame = sample[kSTCaptureSessionSampleEntryIOSColorFrame] as? STColorFrame
      if slamState.initialized {
        processDepthFrame(depthFrame!, colorFrameOrNil: colorFrame)
        // Scene rendering is triggered by new frames to avoid rendering the same view several times.
        renderWithMetal(for: depthFrame!, colorFrameOrNil: colorFrame)
      }
    case STCaptureSessionSampleType.deviceMotionData:
      let deviceMotion = sample[kSTCaptureSessionSampleEntryDeviceMotionData] as? CMDeviceMotion
      processDeviceMotion(deviceMotion!)
    case STCaptureSessionSampleType.unknown:
      // throw an exception
      fatalError("Unknown STCaptureSessionSampleType!")
    default:
      print(String(format: "Skipping Capture Session sample type: %ld", type.rawValue))
    }
  }

  func captureSession(_ captureSession: STCaptureSession, onLensDetectorOutput detectedLensStatus: STDetectedLensStatus) {
    switch detectedLensStatus {
    case STDetectedLensStatus.normal:
      // Detected a WVL is not attached to the bracket.
      print("Detected that the WVL is off!")
    case STDetectedLensStatus.wideVisionLens:
      // Detected a WVL is attached to the bracket.
      print("Detected that the WVL is on!")
    case STDetectedLensStatus.performingInitialDetection:
      // Triggers immediately when detector is turned on. Can put a message here
      // showing the user that the detector is working and they need to pan the
      // camera for best results
      print("Performing initial detection!")
    case STDetectedLensStatus.unsure:
      break
    default:
      // throw an exception
      fatalError("Unknown STDetectedLensStatus!")
    }
  }
}
