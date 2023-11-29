/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import Foundation
import Structure

enum BatteryLevelState: Int {
  case full = 0
  case medium
  case low
  case unknown
}

enum ScannerState: Int {
  // Defining the volume to scan
  case cubePlacement = 0
  // Scanning
  case scanning
  // Visualizing the mesh
  case viewing
  case numStates
}

enum SensorStatus: Int {
  case fine = 0
  case needsUserToConnect
  case needsUserToCharge
  case isWakingUp
}

enum AppOrientation {
  case portrait
  case landscape
}

struct DynamicOptions {
  var depthAndColorTrackerIsOn: Bool = true
  var highResColoring: Bool = true
  var improvedMapperIsOn: Bool = true
  var highResMapping: Bool = true

  var depthStreamPreset: STCaptureSessionPreset = .default
  var depthResolution: STCaptureSessionDepthFrameResolution = .resolution640x480
}

// Volume resolution in meters
class Options {
  // The initial scanning volume size will be 0.5 x 0.5 x 0.5 meters
  // (X is left-right, Y is up-down, Z is forward-back)
  var volumeSizeInMeters = vector_float3(0.5, 0.5, 0.5)

  // The maximum number of keyframes saved in keyFrameManager
  var maxNumKeyFrames: Int = 48

  // Colorizer quality
  var colorizerQuality: STColorizerQuality = .highQuality

  // Take a new keyframe in the rotation difference is higher than 30 degrees.
  var maxKeyFrameRotation = 30 * (Float.pi / 180) // 30 degrees

  // Take a new keyframe if the translation difference is higher than 30 cm.
  var maxKeyFrameTranslation: Float = 0.3 // 30cm

  // Threshold to consider that the rotation motion was small enough for a frame to be accepted
  // as a keyframe. This avoids capturing keyframes with strong motion blur / rolling shutter.
  // It is measured in In degrees per second.
  var maxKeyframeRotationSpeed: Float = 3

  // Whether to enable an expensive per-frame depth accuracy refinement.
  // Note: this option requires useHardwareRegisteredDepth to be set to false.
  var applyExpensiveCorrectionToDepth: Bool = true

  // Whether the colorizer should try harder to preserve appearance of the first keyframe.
  // Recommended for face scans.
  var prioritizeFirstFrameColor: Bool = true

  // Target number of faces of the final textured mesh.
  var colorizerTargetNumFaces: Int = 50000

  // Focus position for the color camera (between 0 and 1). Must remain fixed one depth streaming
  // has started when using hardware registered depth.
  var lensPosition: Float = 0.75

  var cubeDistanceValue: Float = 0.65

  let appOrientation: AppOrientation = .landscape

  var drawCubeWithOccluson: Bool = true
}

// SLAM-related members.
struct SlamData {
  var initialized = false
  var showingMemoryWarning = false
  var prevFrameTimeStamp: TimeInterval = -1
  var scene: STScene?
  var tracker: STTracker?
  var mapper: STMapper?
  var cameraPoseInitializer: STCameraPoseInitializer?
  var initialDepthCameraPose: GLKMatrix4 = GLKMatrix4Identity
  var cubePose: GLKMatrix4 = GLKMatrix4Identity
  var keyFrameManager: STKeyFrameManager?
  var scannerState: ScannerState = .cubePlacement

  var cameraPose: GLKMatrix4 = GLKMatrix4Identity
}

// Utility struct to manage a gesture-based scale.
struct PinchScaleState {
  var currentScale: CGFloat = 1
  var initialPinchScale: CGFloat = 1
}

struct AppStatus {
  var pleaseConnectSensorMessage = "Please connect Structure Sensor."
  var pleaseChargeSensorMessage = "Please charge Structure Sensor."
  var needColorCameraAccessMessage = "This app requires camera access to capture color.\nAllow access by going to Settings → Privacy → Camera."
  var needLicenseMessage = "This app requires Structure SDK license."
  var needCalibratedColorCameraMessage = "This app requires an iOS device with a supported bracket."
  var finalizingMeshMessage = "Finalizing model..."
  var sensorIsWakingUpMessage = "Sensor is initializing. Please wait..."

  // Structure Sensor status.
  var sensorStatus: SensorStatus = .fine

  // Whether iOS camera access was granted by the user.
  var colorCameraIsAuthorized = true

  // Whether there is currently a message to show.
  var needsDisplayOfStatusMessage = false

  // Flag to disable entirely status message display.
  var statusMessageDisabled = false
}
