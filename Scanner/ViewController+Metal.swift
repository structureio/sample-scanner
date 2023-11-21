/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import CoreVideo
import Accelerate
import MetalKit
import Structure
import StructureKit

extension ViewController {

  func renderWithMetal(for depthFrame: STDepthFrame, colorFrameOrNil colorFrame: STColorFrame?) {

    if let colorFrame = colorFrame {
      // Render the color image and depth
      metalData.update(colorFrame: colorFrame)
      metalData.update(depthFrame: depthFrame.registered(to: colorFrame))
    } else {
      metalData.update(depthFrame: depthFrame)
    }

    switch slamState.scannerState {
    case ScannerState.cubePlacement:

      if slamState.cameraPoseInitializer!.lastOutput.hasValidPose.boolValue {
        var depthCameraPose = slamState.initialDepthCameraPose

        var cameraViewpoint: GLKMatrix4

        if useColorCamera {
          // Make sure the viewpoint is always to color camera one, even if not using registered depth.
          let iOSColorFromDepthExtrinsics = depthFrame.iOSColorFromDepthExtrinsics()
          if fixedCubePosition {
            depthCameraPose = GLKMatrix4Multiply(slamState.cameraPoseInitializer!.lastOutput.cameraPose, iOSColorFromDepthExtrinsics)
            // colorCameraPoseInWorld
            cameraViewpoint = GLKMatrix4Multiply(depthCameraPose, GLKMatrix4Invert(iOSColorFromDepthExtrinsics, nil))
            // Translate using cube distance
            cameraViewpoint = GLKMatrix4Translate(cameraViewpoint, 0, 0, -options.cubeDistanceValue)
            slamState.cameraPose = GLKMatrix4Multiply(cameraViewpoint, iOSColorFromDepthExtrinsics)
          } else {
            // colorCameraPoseInWorld
            cameraViewpoint = GLKMatrix4Multiply(depthCameraPose, GLKMatrix4Invert(iOSColorFromDepthExtrinsics, nil))
          }
        } else {
          cameraViewpoint = depthCameraPose
        }

        metalData.update(cameraPose: float4x4(cameraViewpoint))

      }

    case ScannerState.scanning:

      var depthCameraPose = GLKMatrix4Identity

      if dynamicOptions.stSlamManagerIsSelected {
        depthCameraPose = slamState.lssTracker!.lastFrameCameraPose()
      } else {
        depthCameraPose = slamState.tracker!.lastFrameCameraPose()
      }

      var cameraViewpoint: GLKMatrix4
      if useColorCamera {
        // If we want to use the color camera viewpoint, and are not using registered depth, then
        // we need to deduce the color camera pose from the depth camera pose.
        let iOSColorFromDepthExtrinsic = depthFrame.iOSColorFromDepthExtrinsics()

        // colorCameraPoseInWorld
        cameraViewpoint = GLKMatrix4Multiply(depthCameraPose, GLKMatrix4Invert(iOSColorFromDepthExtrinsic, nil))
      } else {
        cameraViewpoint = depthCameraPose
      }

      metalData.update(cameraPose: float4x4(cameraViewpoint))
      // Visualize the mesh combined with color-frame and depth-frame
      if let mesh = slamState.scene?.lockAndGetMesh() {
        metalData.update(mesh: mesh)
        slamState.scene?.unlockMesh()
      }

    // MeshViewerController handles this.
    case ScannerState.viewing:
      break
    default:
      break
    }
  }
}
