/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import AVFoundation
import Structure
import UIKit

extension ViewController: STCaptureSessionDelegate {
  // MARK: - Capture Session Setup

  func videoDeviceSupportsHighResColor() -> Bool {
    // High Resolution Color format is width 2592, height 1936.
    // Most recent devices support this format at 30 FPS.
    // However, older devices may only support this format at a lower framerate.
    // In your Structure Sensor is on firmware 2.0+, it supports depth capture at FPS of 24.

    let testVideoDevice = AVCaptureDevice.default(for: .video)
    if testVideoDevice == nil {
      fatalError("No video device")
    }

    for format in testVideoDevice?.formats ?? [] {
      let firstFrameRateRange = format.videoSupportedFrameRateRanges[0]

      let formatMinFps = firstFrameRateRange.minFrameRate
      let formatMaxFps = firstFrameRateRange.maxFrameRate

      if (formatMaxFps < 15) /* Max framerate too low. */ || (formatMinFps > 30) /* Min framerate too high. */ || (formatMaxFps == 24 && formatMinFps > 15) /* We can neither do the 24 FPS max framerate, nor fall back to 15. */ {
        continue
      }

      let videoFormatDesc = format.formatDescription
      let fourCharCode = CMFormatDescriptionGetMediaSubType(videoFormatDesc)

      let formatDims = CMVideoFormatDescriptionGetDimensions(videoFormatDesc)

      if formatDims.width != 2592 {
        continue
      }

      if formatDims.height != 1936 {
        continue
      }

      if format.isVideoBinned {
        continue
      }

      // we only support full range YCbCr for now
      if fourCharCode != 875704422 {
        continue
      }

      // All requirements met.
      return true
    }

    // No acceptable high-res format was found.
    return false
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

    var resolution = dynamicOptions.highResColoring ? STCaptureSessionColorResolution.resolution2592x1936 : STCaptureSessionColorResolution.resolution640x480

    if !videoDeviceSupportsHighResColor() {
      print("Device does not support high resolution color mode!")
      resolution = STCaptureSessionColorResolution.resolution640x480
    }

    let sensorConfig = [
      kSTCaptureSessionOptionColorResolutionKey: NSNumber(value: resolution.rawValue),
      kSTCaptureSessionOptionDepthFrameResolutionKey: NSNumber(value: dynamicOptions.depthResolution.rawValue),
      kSTCaptureSessionOptionColorMaxFPSKey: NSNumber(value: 30.0),
      kSTCaptureSessionOptionDepthSensorEnabledKey: NSNumber(value: true),
      kSTCaptureSessionOptionUseAppleCoreMotionKey: NSNumber(value: true),
      kSTCaptureSessionOptionDepthStreamPresetKey: NSNumber(value: dynamicOptions.depthStreamPreset.rawValue),
      kSTCaptureSessionOptionSimulateRealtimePlaybackKey: NSNumber(value: true),
      kSTCaptureSessionOptionDepthSearchWindowKey: [NSNumber(value: depthWindowSearchWidth), NSNumber(value: depthWindowSearchHeight)],
      kSTCaptureSessionOptionST01CompatibilityKey: st01CompatibilityMode
    ] as [String: Any]

    // Set the lens detector off, and default lens state as "non-WVL" mode
    captureSession.lens = STLens.normal
    captureSession.lensDetection = STLensDetectorState.off

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
