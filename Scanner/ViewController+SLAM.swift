/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import AVFoundation
import Structure
import UIKit

extension ViewController {
  // MARK: - Utilities

  func deltaRotationAngleBetweenPoses(inDegrees previousPose: GLKMatrix4, newPose: GLKMatrix4) -> Float {
    let deltaPose = GLKMatrix4Multiply(newPose, // Transpose is equivalent to inverse since we will only use the rotation part.
                                       GLKMatrix4Transpose(previousPose))

    // Get the rotation component of the delta pose
    let deltaRotationAsQuaternion = GLKQuaternionMakeWithMatrix4(deltaPose)

    // Get the angle of the rotation
    let angleInDegree: Float = GLKQuaternionAngle(deltaRotationAsQuaternion) / .pi * 180

    return angleInDegree
  }

  func computeTrackerMessage(_ hints: STTrackerHints) -> String? {
    if hints.trackerIsLost {
      return "Tracking Lost! Please Realign or Press Reset."
    }

    if hints.modelOutOfView {
      return "Please put the model back in view."
    }

    if hints.sceneIsTooClose {
      return "Too close to the scene! Please step back."
    }

    return nil
  }

  // MARK: - SLAM

  func setupSLAM() {
    if slamState.initialized {
      return
    }

    // Initialize the scene.
    slamState.scene = STScene()

      NSLog("ObjectScanning Tracker is selected")

      // Initialize the camera pose tracker.
      let trackerOptions = [
        kSTTrackerTypeKey: dynamicOptions.depthAndColorTrackerIsOn ? NSNumber(value: STTrackerType.depthAndColorBased.rawValue) : NSNumber(value: STTrackerType.depthBased.rawValue),
        kSTTrackerTrackAgainstModelKey: NSNumber(value: true) /* tracking against the model is much better for close range scanning. */,
        kSTTrackerQualityKey: NSNumber(value: STTrackerQuality.accurate.rawValue),
        kSTTrackerBackgroundProcessingEnabledKey: NSNumber(value: true),
        kSTTrackerSceneTypeKey: NSNumber(value: STTrackerSceneType.object.rawValue),
        kSTTrackerLegacyKey: NSNumber(value: true)
      ]

      // Initialize the camera pose tracker.
      if let scene = slamState.scene {
        slamState.tracker = STTracker(scene: scene, options: trackerOptions)
      }

    // The mapper will be initialized when we start scanning.

    // Setup the cube placement initializer.
    if fixedCubePosition {
      slamState.cameraPoseInitializer = STCameraPoseInitializer(volumeSizeInMeters: options.volumeSizeInMeters.toGLK(), options: [
        kSTCameraPoseInitializerStrategyKey: NSNumber(value: STCameraPoseInitializerStrategy.gravityAlignedAtVolumeCenter.rawValue)
      ])
    } else {
      slamState.cameraPoseInitializer = STCameraPoseInitializer(volumeSizeInMeters: options.volumeSizeInMeters.toGLK(), options: [
        kSTCameraPoseInitializerStrategyKey: NSNumber(value: STCameraPoseInitializerStrategy.tableTopCube.rawValue)
      ])
    }

    // Set up the initial volume size.
    adjustVolumeSize(options.volumeSizeInMeters)

    // Start with cube placement mode
    enterCubePlacementState()

    let keyframeManagerOptions = [
      kSTKeyFrameManagerMaxSizeKey: NSNumber(value: options.maxNumKeyFrames),
      kSTKeyFrameManagerMaxDeltaTranslationKey: NSNumber(value: options.maxKeyFrameTranslation),
      kSTKeyFrameManagerMaxDeltaRotationKey: NSNumber(value: options.maxKeyFrameRotation)
    ]

    slamState.keyFrameManager = STKeyFrameManager(options: keyframeManagerOptions)

    depthAsRgbaVisualizer = STDepthToRgba(options: [
      kSTDepthToRgbaStrategyKey: NSNumber(value: STDepthToRgbaStrategy.gray.rawValue)
    ])

    slamState.initialized = true
  }

  func resetSLAM() {
    slamState.prevFrameTimeStamp = -1.0
    slamState.mapper?.reset()
    slamState.tracker?.reset()
    slamState.scene?.clear()
    slamState.keyFrameManager?.clear()

    enterCubePlacementState()
  }

  func clearSLAM() {
    slamState.initialized = false
    slamState.scene = nil
    slamState.tracker = nil
    slamState.mapper = nil
    slamState.keyFrameManager = nil
  }

  func setupMapper() {
    if slamState.mapper != nil {
      slamState.mapper = nil // make sure we first remove a previous mapper.
    }

    // Here, we set a larger volume bounds size when mapping in high resolution.
    let mediumResolutionVolumeBounds: Float = 256
    let highResolutionVolumeBounds: Float = 300

    var voxelSizeInMeters = options.volumeSizeInMeters.x / (dynamicOptions.highResMapping ? highResolutionVolumeBounds : mediumResolutionVolumeBounds)

    // Avoid voxels that are too small - these become too noisy.
    voxelSizeInMeters = keep(inRange: voxelSizeInMeters, minValue: 0.002, maxValue: 0.2)

    // Compute the volume bounds in voxels, as a multiple of the volume resolution.
    var volumeBounds = GLKVector3()
    volumeBounds.x = roundf(options.volumeSizeInMeters.x / voxelSizeInMeters)
    volumeBounds.y = roundf(options.volumeSizeInMeters.y / voxelSizeInMeters)
    volumeBounds.z = roundf(options.volumeSizeInMeters.z / voxelSizeInMeters)

    print(String(format: "[Mapper] volumeSize (m): %f %f %f volumeBounds: %.0f %.0f %.0f (resolution=%f m)", options.volumeSizeInMeters.x, options.volumeSizeInMeters.y, options.volumeSizeInMeters.z, volumeBounds.x, volumeBounds.y, volumeBounds.z, voxelSizeInMeters))

    let mapperOptions = [
      kSTMapperLegacyKey: NSNumber(value: !dynamicOptions.improvedMapperIsOn),
      kSTMapperVolumeResolutionKey: NSNumber(value: voxelSizeInMeters),
      kSTMapperVolumeBoundsKey: [NSNumber(value: volumeBounds.x), NSNumber(value: volumeBounds.y), NSNumber(value: volumeBounds.z)],
      kSTMapperVolumeHasSupportPlaneKey: NSNumber(value: slamState.cameraPoseInitializer!.lastOutput.hasSupportPlane.boolValue),
      kSTMapperEnableLiveWireFrameKey: NSNumber(value: false)
    ] as [String: Any]
    if let scene = slamState.scene {
      slamState.mapper = STMapper(scene: scene, options: mapperOptions)
    }
  }

  // Set up SLAM related objects.
  func maybeAddKeyframe(with depthFrame: STDepthFrame, colorFrame: STColorFrame?, depthCameraPoseBeforeTracking: GLKMatrix4) -> String? {
    if colorFrame == nil {
      return nil // nothing to do
    }

    var depthCameraPoseAfterTracking = GLKMatrix4Identity

    depthCameraPoseAfterTracking = slamState.tracker!.lastFrameCameraPose()

    // Make sure the pose is in color camera coordinates in case we are not using registered depth.
    let iOSColorFromDepthExtrinsic = depthFrame.iOSColorFromDepthExtrinsics()
    let colorCameraPoseAfterTracking = GLKMatrix4Multiply(depthCameraPoseAfterTracking, GLKMatrix4Invert(iOSColorFromDepthExtrinsic, nil))

    var showHoldDeviceStill = false

    // Check if the viewpoint has moved enough to add a new keyframe
    // OR if we don't have a keyframe yet
    if slamState.keyFrameManager!.wouldBeNewKeyframe(withColorCameraPose: colorCameraPoseAfterTracking) {
      let isFirstFrame = slamState.prevFrameTimeStamp < 0.0
      var canAddKeyframe = false

      if isFirstFrame {
        canAddKeyframe = true
      } else {
        var deltaAngularSpeedInDegreesPerSecond = Float.greatestFiniteMagnitude
        let deltaSeconds: TimeInterval = depthFrame.timestamp - slamState.prevFrameTimeStamp
        deltaAngularSpeedInDegreesPerSecond = deltaRotationAngleBetweenPoses(inDegrees: depthCameraPoseBeforeTracking, newPose: depthCameraPoseAfterTracking) / Float(deltaSeconds)

        // If the camera moved too much since the last frame, we will likely end up
        // with motion blur and rolling shutter, especially in case of rotation. This
        // checks aims at not grabbing keyframes in that case.
        if deltaAngularSpeedInDegreesPerSecond < options.maxKeyframeRotationSpeed {
          canAddKeyframe = true
        }
      }

      if canAddKeyframe {
        slamState.keyFrameManager!.processKeyFrameCandidate(withColorCameraPose: colorCameraPoseAfterTracking, colorFrame: colorFrame, depthFrame: nil) // Spare the depth frame memory, since we do not need it in keyframes.
      } else {
        // Moving too fast. Hint the user to slow down to capture a keyframe
        // without rolling shutter and motion blur.
        showHoldDeviceStill = true
      }
    }

    if showHoldDeviceStill {
      return "Please hold still so we can capture a keyframe..."
    }

    return nil
  }

  func updateMeshAlpha(for poseAccuracy: STTrackerPoseAccuracy) {
    switch poseAccuracy {
    case STTrackerPoseAccuracy.high, STTrackerPoseAccuracy.approximate:
      metalData.meshRenderingAlpha = 0.8
    case STTrackerPoseAccuracy.low:
      metalData.meshRenderingAlpha = 0.4
    case STTrackerPoseAccuracy.veryLow, STTrackerPoseAccuracy.notAvailable:
      metalData.meshRenderingAlpha = 0.1
    default:
      print("STTracker unknown pose accuracy.")
    }
  }

  func processDepthFrame(_ depthFrame: STDepthFrame, colorFrameOrNil colorFrame: STColorFrame?) {
    if options.applyExpensiveCorrectionToDepth {
      depthFrame.applyExpensiveCorrection()
    }

    if runDepthRefinement {
      depthFrame.applyDepthRefinement()
    }

    switch slamState.scannerState {
    case ScannerState.cubePlacement:
      var depthFrameForCubeInitialization = depthFrame
      var depthCameraPoseInColorCoordinateFrame = GLKMatrix4Identity

      // If we are using color images but not using registered depth, then use a registered
      // version to detect the cube, otherwise the cube won't be centered on the color image,
      // but on the depth image, and thus appear shifted.
      if useColorCamera {
        let iOSColorFromDepthExtrinsic = depthFrame.iOSColorFromDepthExtrinsics()
        depthCameraPoseInColorCoordinateFrame = iOSColorFromDepthExtrinsic
        depthFrameForCubeInitialization = depthFrame.registered(to: colorFrame)
      }

      // Estimate the new scanning volume position.
      if GLKVector3Length(lastGravity) > 1e-5 {
        do {
          try slamState.cameraPoseInitializer!.updateCameraPose(withGravity: lastGravity, depthFrame: depthFrameForCubeInitialization)
          // Since we potentially detected the cube in a registered depth frame, also save the pose
          // in the original depth sensor coordinate system since this is what we'll use for SLAM
          // to get the best accuracy.
          slamState.initialDepthCameraPose = GLKMatrix4Multiply(slamState.cameraPoseInitializer!.lastOutput.cameraPose, depthCameraPoseInColorCoordinateFrame)
        } catch {
          NSLog("Camera pose initializer error.")
        }
      }

      // Enable the scan button if the pose initializer could estimate a pose.
      scanButton.isEnabled = slamState.cameraPoseInitializer!.lastOutput.hasValidPose.boolValue

    case ScannerState.scanning:
      // First try to estimate the 3D pose of the new frame.

      var trackingMessage: String?
      var keyframeMessage: String?

//            var depthCameraPoseBeforeTracking = GLKMatrix4Identity

      let depthCameraPoseBeforeTracking = slamState.tracker!.lastFrameCameraPose()

      // Integrate it into the current mesh estimate if tracking was successful.
      do {
        try slamState.tracker!.updateCameraPose(with: depthFrame, colorFrame: colorFrame)

        // Update the tracking message.
        trackingMessage = computeTrackerMessage(slamState.tracker!.trackerHints)

        // Set the mesh transparency depending on the current accuracy.
        updateMeshAlpha(for: slamState.tracker!.poseAccuracy)

        // If the tracker accuracy is high, use this frame for mapper update and maybe as a keyframe too.
        if slamState.tracker!.poseAccuracy.rawValue >= STTrackerPoseAccuracy.high.rawValue {
          slamState.mapper?.integrateDepthFrame(depthFrame, cameraPose: (slamState.tracker?.lastFrameCameraPose())!)
        }
        keyframeMessage = maybeAddKeyframe(with: depthFrame, colorFrame: colorFrame, depthCameraPoseBeforeTracking: depthCameraPoseBeforeTracking)

        // Tracking messages have higher priority.
        if trackingMessage != nil {
          showTrackingMessage(trackingMessage!)
        } else if keyframeMessage != nil {
          showTrackingMessage(keyframeMessage!)
        } else {
          hideTrackingErrorMessage()
        }
      } catch let trackingError as NSError {
        NSLog("[Structure] STTracker Error: %@.", trackingError.localizedDescription)

        trackingMessage = trackingError.localizedDescription
      }
      slamState.prevFrameTimeStamp = depthFrame.timestamp

    case ScannerState.viewing:
      // Do nothing, the MeshViewController will take care of this.
      break
    default:
      break
    }
  }
}
