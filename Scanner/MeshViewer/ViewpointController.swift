/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import MetalKit

// Helper functions
func nowInSeconds() -> Double {
  var timebase = mach_timebase_info_data_t()
  mach_timebase_info(&timebase)
  let newTime: UInt64 = mach_absolute_time()
  return (Double(newTime) * Double(timebase.numer)) / (Double(timebase.denom) * 1e9)
}

class ViewpointController: NSObject {
  // Projection matrix before starting user interaction.
  private var referenceProjectionMatrix: float4x4 = .identity

  // Centroid of the mesh.
  private var meshCenter: vector_float3 = .init(0, 0, 0)
  private var meshSize: vector_float3 = .init(0, 0, 0)

  // Scale management
  private var scaleWhenPinchGestureBegan: Float = 1.0
  private var currentScale: Float = 1.0

  // ModelView rotation.
  private var lastModelViewRotationUpdateTimestamp: Double = 0
  private var oneFingerPanWhenGestureBegan: vector_float2 = .init(0, 0)
  private var modelViewRotationWhenPanGestureBegan: float4x4 = .identity
  private var modelViewRotation: float4x4 = .identity

  private var modelViewRotationVelocity: vector_float2 = .init(0, 0) // expressed in terms of touch coordinates.

  // Rotation speed will slow down with time.
  private var velocitiesDampingRatio: vector_float2 = .init(0.95, 0.95)

  // Translation in screen space.
  private var twoFingersPanWhenGestureBegan: vector_float2 = .init(0, 0)
  private var meshCenterOnScreenWhenPanGestureBegan: vector_float2 = .init(0, 0)

  private var screenSize: vector_float2 = .init(0, 0)
  private var screenCenter: vector_float2 = .init(0, 0)
  private var meshCenterOnScreen: vector_float2 = .init(0, 0)

  private var cameraOrProjectionChangedSinceLastUpdate: Bool = false

  override init() {
    super.init()
    reset()
  }

  func reset() {
    cameraOrProjectionChangedSinceLastUpdate = false
    scaleWhenPinchGestureBegan = 1
    currentScale = 1
    screenCenter = screenSize * 0.5
    meshCenterOnScreen = screenSize * 0.5
    modelViewRotationWhenPanGestureBegan = float4x4.identity
    modelViewRotation = float4x4.identity
    velocitiesDampingRatio = vector_float2(0.95, 0.95)
    modelViewRotationVelocity = vector_float2(0, 0)
  }

  func setScreenSize(screenSizeX: Float, screenSizeY: Float) {
    screenSize = vector_float2(screenSizeX, screenSizeY)
    screenCenter = screenSize * 0.5
    meshCenterOnScreen = screenSize * 0.5
  }

  func setCameraProjection(_ projRt: float4x4) {
    referenceProjectionMatrix = projRt
    cameraOrProjectionChangedSinceLastUpdate = true
  }

  func setMeshCenter(_ center: vector_float3, _ size: vector_float3) {
    meshCenter = center
    meshSize = size
    cameraOrProjectionChangedSinceLastUpdate = true
  }

  // Scale Gesture Control
  internal func onPinchGestureBegan(_ scale: Float) {
    scaleWhenPinchGestureBegan = currentScale / scale
  }

  internal func onPinchGestureChanged(_ scale: Float) {
    currentScale = scale * scaleWhenPinchGestureBegan
    cameraOrProjectionChangedSinceLastUpdate = true
  }

  // 3D modelView rotation gesture control.
  internal func onOneFingerPanBegan(_ touch: vector_float2) {
    modelViewRotationWhenPanGestureBegan = modelViewRotation
    oneFingerPanWhenGestureBegan = touch
  }

  internal func onOneFingerPanChanged(_ touch: vector_float2) {
    let distMoved = touch - oneFingerPanWhenGestureBegan
    let spinDegree = -distMoved / 300

    let rotX = float4x4.makeRotationX(-spinDegree.y)
    let rotY = float4x4.makeRotationY(spinDegree.x)

    modelViewRotation = rotX * rotY * modelViewRotationWhenPanGestureBegan
    cameraOrProjectionChangedSinceLastUpdate = true
  }

  internal func onOneFingerPanEnded(_ vel: vector_float2) {
    modelViewRotationVelocity = vel
    lastModelViewRotationUpdateTimestamp = nowInSeconds()
  }

  // Screen-space translation gesture control.
  internal func onTwoFingersPanBegan(_ touch: vector_float2) {
    twoFingersPanWhenGestureBegan = touch
    meshCenterOnScreenWhenPanGestureBegan = meshCenterOnScreen
  }

  internal func onTwoFingersPanChanged(_ touch: vector_float2) {
    meshCenterOnScreen = touch - twoFingersPanWhenGestureBegan + meshCenterOnScreenWhenPanGestureBegan
    cameraOrProjectionChangedSinceLastUpdate = true
  }

  internal func onTwoFingersPanEnded(_ vel: vector_float2) {}

  internal func onTouchBegan() {
    // Stop the current animations when the user touches the screen.
    modelViewRotationVelocity = vector_float2(0, 0)
  }

  // ModelView matrix in OpenGL space.
  internal func currentGLModelViewMatrix() -> float4x4 {
    let meshCenterToOrigin = float4x4.makeTranslation(-meshCenter.x, -meshCenter.y, -meshCenter.z)

    // We'll put the object at some distance(Putting it too close clips the mesh)
    let originToVirtualViewpoint = float4x4.makeTranslation(0, 0, max(0.5, 3 * meshSize.z))

    var modelView = originToVirtualViewpoint
    modelView *= modelViewRotation

    // will apply the rotation around the mesh center.
    modelView *= meshCenterToOrigin
    return modelView
  }

  // Projection matrix in OpenGL space.
  internal func currentGLProjectionMatrix() -> float4x4 {
    // The scale is directly applied to the reference projection matrix.
    let scale = float4x4.makeScale(currentScale, currentScale, 1)

    // Since the translation is done in screen space, it's also applied to the projection matrix directly.
    let centerTranslation: float4x4 = currentProjectionCenterTranslation()

    return centerTranslation * scale * referenceProjectionMatrix
  }

  internal func update() -> Bool {
    var viewpointChanged = cameraOrProjectionChangedSinceLastUpdate

    // Modelview rotation animation.
    if length(modelViewRotationVelocity) > 1e-5 {
      let nowSec = nowInSeconds()
      let elapsedSec = nowSec - lastModelViewRotationUpdateTimestamp
      lastModelViewRotationUpdateTimestamp = nowSec

      let distMoved = modelViewRotationVelocity * Float(elapsedSec)
      let spinDegree = -distMoved / 300

      let rotX = float4x4.makeRotationX(-spinDegree.y)
      let rotY = float4x4.makeRotationY(spinDegree.x)
      modelViewRotation = rotX * rotY * modelViewRotation

      // Slow down the velocities.
      let resX = modelViewRotationVelocity.x * velocitiesDampingRatio.x
      let resY = modelViewRotationVelocity.y * velocitiesDampingRatio.y

      modelViewRotationVelocity = vector_float2(resX, resY)

      // Make sure we stop animating and taking resources when it became too small.
      if abs(modelViewRotationVelocity.x) < 1 {
        modelViewRotationVelocity = vector_float2(0, modelViewRotationVelocity.y)
      }

      if abs(modelViewRotationVelocity.y) < 1 {
        modelViewRotationVelocity = vector_float2(modelViewRotationVelocity.x, 0)
      }

      viewpointChanged = true
    }

    cameraOrProjectionChangedSinceLastUpdate = false
    return viewpointChanged
  }

  internal func currentProjectionCenterTranslation() -> float4x4 {
    let deltaFromScreenCenter = screenCenter - meshCenterOnScreen
    return float4x4.makeTranslation(-deltaFromScreenCenter.x / screenCenter.x, deltaFromScreenCenter.y / screenCenter.y, 0)
  }
}
