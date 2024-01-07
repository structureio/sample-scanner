/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import AVFoundation
import GLKit
import MetalKit
import Structure
import UIKit

// MARK: - ViewController Setup

@objcMembers
class ViewController: UIViewController, STBackgroundTaskDelegate, MeshViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, UIGestureRecognizerDelegate {
  var batteryLevelCheckTimer: Timer?
  var lastBatteryLevelState: BatteryLevelState = .full

  var slamState = SlamData()
  var options = Options()
  var metalData: MetalData!

  var dynamicOptions = DynamicOptions()
  // Manages the app status messages.
  var appStatus = AppStatus()
  // Most recent gravity vector from IMU.
  var lastGravity = GLKVector3Make(-1.0, 0.0, 0.0)
  // Scale of the scanning volume.
  var volumeScale = PinchScaleState()
  // Mesh viewer controllers.
  var meshViewController: MeshViewController?
  // Structure Sensor controller.
  var captureSession: STCaptureSession!

  var naiveColorizeTask: STBackgroundTask?
  var enhancedColorizeTask: STBackgroundTask?
  var depthAsRgbaVisualizer: STDepthToRgba?
  var useColorCamera: Bool = true
  var timeTagOnOcc: String = ""
  var enableDepthWindowOverride: Bool = false
  var alignCubeWithCamera: Bool = false
  var fixedCubePosition: Bool = false
  var initialBoxDistance: Float = 0.65
  var initialVolumeSize: vector_float3 = .init(0.5, 0.5, 0.5)
  var depthWindowSearchWidth: Float = 15
  var depthWindowSearchHeight: Float = 11
  var runDepthRefinement: Bool = false
  var settingsPopupView: SettingsPopupView?
  var calibrationOverlay: CalibrationOverlay?

  @IBOutlet var mtkView: MTKView!
  @IBOutlet var appStatusMessageLabel: UILabel!
  @IBOutlet var scanButton: UIButton!
  @IBOutlet var resetButton: UIButton!
  @IBOutlet var doneButton: UIButton!
  @IBOutlet var trackingLostLabel: UILabel!

  @IBOutlet var firmwareUpdateView: UIView!
  @IBOutlet var structureAppIcon: UIImageView!
  @IBOutlet var updateNowButton: UIButton!
//    @IBOutlet weak var poweredByStructureButton: UIButton!
  @IBOutlet var batteryView: UIView!
  @IBOutlet var batteryImageView: UIImageView!
  @IBOutlet var batterySensorLabel: UILabel!
  @IBOutlet var sensorRequiredImageView: UIImageView!
  @IBOutlet var alignCubeWithCameraSwitch: UISwitch!
  @IBOutlet var fixedCubeDistanceSwitch: UISwitch!
  @IBOutlet var boxDistanceLabel: UILabel!
  @IBOutlet var boxSizeLabel: UILabel!
  @IBOutlet var fixedCubeDistanceLabel: UILabel!
  @IBOutlet var alignCubeWithCameraLabel: UILabel!

  func keep(inRange value: Float, minValue: Float, maxValue: Float) -> Float {
    if value.isNaN {
      return minValue
    }

    if value > maxValue {
      return maxValue
    }

    if value < minValue {
      return minValue
    }

    return value
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    DispatchQueue(label: "license.validation", qos: .userInitiated).async {
      // Enter license key here(see the readme "Build Process" section)
      let status = STLicenseManager.unlock(withKey: licenseKey, shouldRefresh: false)
      if status != .valid {
        print("Error: No license!")
      }
    }
    let defaults = UserDefaults.standard

    alignCubeWithCamera = defaults.bool(forKey: "alignCubeWithCamera")
    fixedCubePosition = defaults.bool(forKey: "fixedCubePostion")
    enableDepthWindowOverride = defaults.bool(forKey: "enableWindowOverride")
    runDepthRefinement = defaults.bool(forKey: "enableDepthRefinement")
    alignCubeWithCameraSwitch.isOn = !alignCubeWithCamera
    fixedCubeDistanceSwitch.isOn = fixedCubePosition
    if enableDepthWindowOverride {
      depthWindowSearchWidth = defaults.float(forKey: "depthWindowSearchWidth")
      depthWindowSearchHeight = defaults.float(forKey: "depthWindowSearchHeight")
    }

    setupMetal()
    setupGestures()
    setupCaptureSession()

    setupSLAM()

    // Later, we’ll set this true if we have a device-specific calibration
    useColorCamera = true

    // Make sure we get notified when the app becomes active to start/restore the sensor state if necessary.
    NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

    initializeDynamicOptions()
    enterCubePlacementState()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    updateViewsWithSensorStatus()

    // We will connect to the sensor when we receive appDidBecomeActive.
  }

  func appDidBecomeActive() {
    // Try to connect to the Structure Sensor and stream if necessary.
    if currentStateNeedsSensor() {
      captureSession.streamingEnabled = true
    }

    // Abort the current scan if we were still scanning before going into background since we
    // are not likely to recover well.
    if slamState.scannerState == .scanning {
      resetButtonPressed(self)
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()

    respondToMemoryWarning()
  }

  func initializeDynamicOptions() {
    settingsPopupView = SettingsPopupView(settingsPopupViewDelegate: self)
    if let settingsPopupView = settingsPopupView {
      view.addSubview(settingsPopupView)
    }
    if let settingsPopupView = settingsPopupView {
      view.addConstraints([
        NSLayoutConstraint(item: settingsPopupView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 20.0),
        // Pin to left of view, with offset
        NSLayoutConstraint(item: settingsPopupView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 30.0)
      ])
    }
  }

  func setupGestures() {
    // Register pinch gesture for volume scale adjustment.
    let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchGesture(_:)))
    view.addGestureRecognizer(pinchGesture)

    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
    view.addGestureRecognizer(panGesture)

    let tapToStructureIO = UITapGestureRecognizer(target: self, action: #selector(onTapSensorRequiedImageView))
    sensorRequiredImageView.addGestureRecognizer(tapToStructureIO)
    sensorRequiredImageView.isUserInteractionEnabled = true
  }

  // Make sure the status bar is disabled
  override var prefersStatusBarHidden: Bool {
    return true
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "segueToMesh" {

      slamState.mapper!.finalizeTriangleMesh()

      meshViewController = segue.destination as? MeshViewController
      meshViewController?.delegate = self
      meshViewController?.modalPresentationStyle = .fullScreen

      guard let mesh = slamState.scene?.lockAndGetMesh() else { return }
      slamState.scene?.unlockMesh()
      meshViewController?.colorEnabled = useColorCamera
      meshViewController?._mesh = mesh
      meshViewController?.setCameraProjectionMatrix(metalData.depthCameraGLProjectionMatrix)

      // Sample a few points to estimate the volume center
      var totalNumVertices: Int32 = 0
      for itr in 0 ..< mesh.numberOfMeshes() {
        totalNumVertices += mesh.number(ofMeshVertices: itr)
      }

      guard let (min, max) = mesh.bbox() else {
        showAlert(title: "Error!!!", message: "Invalid mesh.")
        return
      }
      let volumeCenter = (min + max) / 2
      let size = max - min

      meshViewController?.resetMeshCenter(volumeCenter, size)
    }
  }

  func enterCubePlacementState() {
    // Switch to the Scan button.
    scanButton.isHidden = false
    doneButton.isHidden = true
    resetButton.isHidden = true

    // We'll enable the button only after we get some initial pose.
    scanButton.isEnabled = false

    // Cannot be lost in cube placement mode.
    trackingLostLabel.isHidden = true

    // Make labels and buttons visible
    fixedCubeDistanceSwitch.isHidden = false
    fixedCubeDistanceLabel.isHidden = fixedCubeDistanceSwitch.isHidden
    alignCubeWithCameraSwitch.isHidden = false
    alignCubeWithCameraLabel.isHidden = alignCubeWithCameraSwitch.isHidden
    boxSizeLabel.isHidden = false

    boxDistanceLabel.isHidden = !fixedCubePosition
    boxDistanceLabel.text = String.localizedStringWithFormat("Distance %1.2f m", options.cubeDistanceValue)

    alignCubeWithCameraSwitch.isHidden = false
    boxSizeLabel.text = String.localizedStringWithFormat("Size %1.2f m", Float(options.volumeSizeInMeters.x) * Float(volumeScale.currentScale))

    settingsPopupView?.enableAllSettingsDuringCubePlacement()

    captureSession.streamingEnabled = true
    captureSession.properties = STCaptureSessionPropertiesSetColorCameraAutoExposureISOAndWhiteBalance()

    slamState.scannerState = ScannerState.cubePlacement

    updateIdleTimer()

    renderingSettingsDidChange()
  }

  func enterScanningState() {
    // This can happen if the UI did not get updated quickly enough.
    if !slamState.cameraPoseInitializer!.lastOutput.hasValidPose.boolValue {
      print("Warning: not accepting to enter into scanning state since the initial pose is not valid.")
      return
    }

    // Switch to the Done button.
    scanButton.isHidden = true
    doneButton.isHidden = false
    resetButton.isHidden = false

    settingsPopupView?.disableNonDynamicSettingsDuringScanning()

    // Prepare the mapper for the new scan.
    setupMapper()

    if fixedCubePosition {
      slamState.tracker!.initialCameraPose = slamState.cameraPose
    } else {
      slamState.tracker!.initialCameraPose = slamState.initialDepthCameraPose
    }

    // We will lock exposure during scanning to ensure better coloring.
    captureSession.properties = STCaptureSessionPropertiesLockAllColorCameraPropertiesToCurrent()

    slamState.scannerState = ScannerState.scanning

    renderingSettingsDidChange()
  }

  func enterViewingState() {
    // Cannot be lost in view mode.
    hideTrackingErrorMessage()

    appStatus.statusMessageDisabled = true
    updateViewsWithSensorStatus()

    // Hide the Scan/Done/Reset button.
    scanButton.isHidden = true
    doneButton.isHidden = true
    resetButton.isHidden = true

    captureSession.streamingEnabled = false

    performSegue(withIdentifier: "segueToMesh", sender: nil)

    slamState.scannerState = ScannerState.viewing

    updateIdleTimer()

    renderingSettingsDidChange()
  }

  func currentStateNeedsSensor() -> Bool {
    switch slamState.scannerState {
    // Initialization and scanning need the sensor.
    case ScannerState.cubePlacement, ScannerState.scanning:
      return true
    // Other states don't need the sensor.
    default:
      return false
    }
  }

  func processDeviceMotion(_ motion: CMDeviceMotion) {
    if slamState.scannerState == .cubePlacement {
      if alignCubeWithCamera {
        // no gravity in cube
        lastGravity = GLKVector3Make(-1.0, 0.0, 0.0)
      } else {
        // Update our gravity vector, it will be used by the cube placement initializer.
        lastGravity = GLKVector3Make(Float(motion.gravity.x), Float(motion.gravity.y), Float(motion.gravity.z))
      }
    }

    if slamState.scannerState == .cubePlacement || slamState.scannerState == .scanning {
      // The tracker is more robust to fast moves if we feed it with motion data.
      slamState.tracker?.updateCameraPose(with: motion)
    }
  }

  // MARK: - UI Callbacks

  func onSLAMOptionsChanged() {
    // A full reset to force a creation of a new tracker.
    resetSLAM()
    clearSLAM()
    setupSLAM()

    // Restore the volume size cleared by the full reset.
    adjustVolumeSize(options.volumeSizeInMeters)
  }

  func adjustVolumeSize(_ volumeSize: vector_float3) {
    var volume = volumeSize
    // Make sure the volume size remains between 10 centimeters and 3 meters.
    volume.x = keep(inRange: volume.x, minValue: 0.1, maxValue: 3.0)
    volume.y = keep(inRange: volume.y, minValue: 0.1, maxValue: 3.0)
    volume.z = keep(inRange: volume.z, minValue: 0.1, maxValue: 3.0)

    boxSizeLabel.text = String.localizedStringWithFormat("Size %1.2f m", volume.x)

    options.volumeSizeInMeters = volume
    slamState.cameraPoseInitializer!.volumeSizeInMeters = volume.toGLK()
  }

  @IBAction func settingsButtonPressed(_ sender: UIButton) {
    performSegue(withIdentifier: "seguetoPopoverSettings", sender: self)
  }

  @IBAction func alignCubeWithCameraDidChange(_ sender: UISwitch) {
    alignCubeWithCamera = !sender.isOn
    UserDefaults.standard.set(!sender.isOn, forKey: "alignCubeWithCamera")
    onSLAMOptionsChanged()
  }

  @IBAction func fixedCubePositionDidChange(_ sender: UISwitch) {
    fixedCubePosition = sender.isOn
    boxDistanceLabel.isHidden = !fixedCubePosition
    UserDefaults.standard.set(sender.isOn, forKey: "fixedCubePostion")
    onSLAMOptionsChanged()
  }

  @IBAction func scanButtonPressed(_ sender: Any) {
    let defaults = UserDefaults.standard
    let recordOcc = defaults.bool(forKey: "recordOcc")

    if recordOcc {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
      let currentDate = Date()
      timeTagOnOcc = formatter.string(from: currentDate)

      var occString = "[AppDocuments]/Scanner-SN"
      if let captureSession = self.captureSession {
        occString = occString.appending(captureSession.sensorSerialNumber)
        occString = occString.appending("_")
        occString = occString.appending(self.timeTagOnOcc)
        occString = occString.appending(".occ")

        let success = captureSession.occWriter.startWriting("[AppDocuments]/Scanner.occ", appendDateAndExtension: false)
        if !success {
          print("Could not properly start OCC writer.")
        }
      }
    }

    enterScanningState()
  }

  @IBAction func resetButtonPressed(_ sender: Any) {
    resetSLAM()
  }

  @IBAction func doneButtonPressed(_ sender: Any) {
    if captureSession!.occWriter.isWriting {
      let success = captureSession!.occWriter.stopWriting()
      if !success {
        fatalError("Could not properly stop OCC writer.")
      }
    }

    enterViewingState()
  }

  @IBAction func updateNowButtonPressed(_ sender: Any) {
    launchStructureAppOrGoToAppStore()
  }

  @IBAction func openDeveloperPortal(_ button: UIButton) {
    UIApplication.shared.open(URL(string: "https://structure.io/developers")!)
  }

  func onTapSensorRequiedImageView() {
    UIApplication.shared.open(URL(string: "https://structure.io/")!)
  }

  // Manages whether we can let the application sleep.
  func updateIdleTimer() {
    if isStructureConnected() && currentStateNeedsSensor() {
      // Do not let the application sleep if we are currently using the sensor data.
      UIApplication.shared.isIdleTimerDisabled = true
    } else {
      // Let the application sleep if we are only viewing the mesh or if no sensors are connected.
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }

  func showSensorRelatedViews() {
    batteryView.isHidden = false
    settingsPopupView?.isHidden = false
//        alignCubeWithCameraLabel.isHidden = false
//        fixedCubeDistanceLabel.isHidden = false
//        boxDistanceLabel.isHidden = false
//        boxSizeLabel.isHidden = false
//        alignCubeWithCameraSwitch.isHidden = false
//        fixedCubeDistanceSwitch.isHidden = false
    scanButton.isHidden = false
    firmwareUpdateView.isHidden = false
  }

  func hideSensorRelatedViews() {
    self.batteryView.isHidden = true
    settingsPopupView?.isHidden = true
//        alignCubeWithCameraLabel.isHidden = true
//        fixedCubeDistanceLabel.isHidden = true
//        boxDistanceLabel.isHidden = true
//        boxSizeLabel.isHidden = true
//        alignCubeWithCameraSwitch.isHidden = true
//        fixedCubeDistanceSwitch.isHidden = true
    scanButton.isHidden = false
    firmwareUpdateView.isHidden = true
  }

  func showTrackingMessage(_ message: String) {
    trackingLostLabel.text = message
    trackingLostLabel.isHidden = false
  }

  func hideTrackingErrorMessage() {
    trackingLostLabel.isHidden = true
  }

  func showAppStatusMessage(_ msg: String) {
    appStatus.needsDisplayOfStatusMessage = true
    view.layer.removeAllAnimations()

    appStatusMessageLabel.alpha = 0.0
    appStatusMessageLabel.text = msg
    appStatusMessageLabel.isHidden = false

    UIView.animate(withDuration: 0.5, animations: {
      self.appStatusMessageLabel.alpha = 1.0
    })
  }

  func hideAppStatusMessage() {
    appStatus.needsDisplayOfStatusMessage = false
    view.layer.removeAllAnimations()

    weak var weakSelf = self
    UIView.animate(withDuration: 0.5, animations: {
      weakSelf?.appStatusMessageLabel.alpha = 0.0
    }, completion: { _ in
      // If nobody called showAppStatusMessage before the end of the animation, do not hide it.
      if !self.appStatus.needsDisplayOfStatusMessage {
        // Could be nil if the self is released before the callback happens.
        if weakSelf != nil {
          weakSelf?.appStatusMessageLabel.isHidden = true
        }
      }
    })

    batteryLevelCheckTimer = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(batteryLevelCheckTick(_:)), userInfo: nil, repeats: true)

    batteryLevelCheckTimer?.fire()
  }

  func updateViewsWithSensorStatus() {
    let userInstructions = captureSession.userInstructions
    let needLicense = STLicenseManager.status != .valid

    var needToConnectSensor = false
    needToConnectSensor = (userInstructions.rawValue & STCaptureSessionUserInstruction.needToConnectSensor.rawValue) != 0

    var needToChargeSensor = false
    needToChargeSensor = (userInstructions.rawValue & STCaptureSessionUserInstruction.needToChargeSensor.rawValue) != 0

    var needToAuthorizeColorCamera = false
    needToAuthorizeColorCamera = (userInstructions.rawValue & STCaptureSessionUserInstruction.needToAuthorizeColorCamera.rawValue) != 0

    var needToUpgradeFirmware = false
    needToUpgradeFirmware = (userInstructions.rawValue & STCaptureSessionUserInstruction.firmwareUpdateRequired.rawValue) != 0

    // If you don't want to display the overlay message when an approximate calibration
    // is available use `_captureSession.calibrationType >= STCalibrationTypeApproximate`
    var needToRunCalibrator = false
    needToRunCalibrator = (userInstructions.rawValue & STCaptureSessionUserInstruction.needToRunCalibrator.rawValue) != 0

    if needToConnectSensor {
      // If sensor is never connected before show sensor required banner
      if !UserDefaults.standard.hasConnectedSensorBefore {
        sensorRequiredImageView.isHidden = false
      } else {
        showAppStatusMessage(appStatus.pleaseConnectSensorMessage)
      }
      return
    }

    if captureSession.sensorMode == STCaptureSessionSensorMode.wakingUp {
      // If sensor is connected first time set the flag to true
      if !UserDefaults.standard.hasConnectedSensorBefore {
        UserDefaults.standard.hasConnectedSensorBefore = true
        sensorRequiredImageView.isHidden = true
      }
      showAppStatusMessage(appStatus.sensorIsWakingUpMessage)
      return
    }

    if needToChargeSensor {
      showAppStatusMessage(appStatus.pleaseChargeSensorMessage)
      return
    }

    if !needToRunCalibrator {
      if calibrationOverlay != nil {
        calibrationOverlay!.removeFromSuperview()
      }
    } else {
      var overlayType = CalibrationOverlayType.nocalibration
      switch captureSession!.calibrationType() {
      case STCalibrationType.none:
        scanButton.isEnabled = false
        if captureSession!.lens == STLens.wideVision {
          overlayType = CalibrationOverlayType.strictlyRequired
        }
      case STCalibrationType.approximate:
        scanButton.isEnabled = true
        overlayType = CalibrationOverlayType.approximate
      case STCalibrationType.deviceSpecific:
        // We should not ever enter this case if `needToRunCalibrator` is true
        break
      default:
        print("WARNING: Unknown calibration type returned from the capture session.")
      }

      let isIPad = UIDevice.current.userInterfaceIdiom == .pad

      calibrationOverlay = CalibrationOverlay(type: overlayType)
      view.addSubview(calibrationOverlay!)

      // Center the calibration overlay in X
      calibrationOverlay?.superview!.addConstraint(NSLayoutConstraint(item: calibrationOverlay!, attribute: .centerX, relatedBy: .equal, toItem: calibrationOverlay?.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0))

      if overlayType == CalibrationOverlayType.approximate {
        calibrationOverlay?.superview?.addConstraint(NSLayoutConstraint(item: calibrationOverlay!, attribute: .bottom, relatedBy: .equal, toItem: calibrationOverlay?.superview, attribute: .bottom, multiplier: 1.0, constant: isIPad ? -100 : -25))
      } else {
        calibrationOverlay?.superview?.addConstraint(NSLayoutConstraint(item: calibrationOverlay!, attribute: .centerY, relatedBy: .equal, toItem: calibrationOverlay?.superview, attribute: .centerY, multiplier: 1.0, constant: 0.0))
      }

      if !isIPad && overlayType != CalibrationOverlayType.approximate {
        calibrationOverlay!.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
      }

      // Color camera permission issues.
      if needToAuthorizeColorCamera {
        showAppStatusMessage(appStatus.needColorCameraAccessMessage)
        return
      }
    }

    if needLicense {
      showAppStatusMessage(appStatus.needLicenseMessage)
      return
    }

    firmwareUpdateView.isHidden = !needToUpgradeFirmware

    // If we reach this point, no status to show.
    hideAppStatusMessage()
  }

  @IBAction func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
    if slamState.scannerState == .cubePlacement {
      if gestureRecognizer.state == .began {
        initialBoxDistance = options.cubeDistanceValue
      } else if gestureRecognizer.state == .changed {
        let minDist: Float = 0.10
        let maxDist: Float = 2.5
        let translation: Float = -Float(gestureRecognizer.translation(in: view).y / view.frame.size.height) * (maxDist - minDist)
        options.cubeDistanceValue = keep(inRange: initialBoxDistance + translation, minValue: minDist, maxValue: maxDist)
        boxDistanceLabel.text = String.localizedStringWithFormat("Distance %1.2f m", options.cubeDistanceValue)
      }
    }
  }

  @IBAction func pinchGesture(_ gestureRecognizer: UIPinchGestureRecognizer) {
    if gestureRecognizer.state == .began {
      if slamState.scannerState == .cubePlacement {
        volumeScale.initialPinchScale = volumeScale.currentScale / gestureRecognizer.scale
      }
      initialVolumeSize = options.volumeSizeInMeters
    } else if gestureRecognizer.state == .changed {
      if slamState.scannerState == .cubePlacement {
        // In some special conditions the gesture recognizer can send a zero initial scale.
        if !volumeScale.initialPinchScale.isNaN {
          volumeScale.currentScale = gestureRecognizer.scale * volumeScale.initialPinchScale

          // Don't let our scale multiplier become absurd
          volumeScale.currentScale = CGFloat(keep(inRange: Float(volumeScale.currentScale), minValue: 0.01, maxValue: 1000.0))

          let newVolumeSize = initialVolumeSize * Float(volumeScale.currentScale)

          adjustVolumeSize(newVolumeSize)
        }
      }
    }
  }

  // MARK: - MeshViewController delegates

  func meshViewWillDismiss() {
    // If we are running colorize work, we should cancel it.
    if naiveColorizeTask != nil {
      naiveColorizeTask?.cancel()
      naiveColorizeTask = nil
    }
    if enhancedColorizeTask != nil {
      enhancedColorizeTask?.cancel()
      enhancedColorizeTask = nil
    }

    meshViewController?.hideMeshViewerMessage()
  }

  func meshViewDidDismiss() {
    appStatus.statusMessageDisabled = false
    updateViewsWithSensorStatus()

    // Reset the tracker, mapper, etc.
    resetSLAM()
    enterCubePlacementState()
  }

  func backgroundTask(_ sender: STBackgroundTask, didUpdateProgress progress: Double) {
    if sender == naiveColorizeTask {
      DispatchQueue.main.async {
        self.meshViewController?.showMeshViewerMessage(String(format: "Processing: % 3d%%", Int(progress) * 20))
      }
    } else if sender == enhancedColorizeTask {
      DispatchQueue.main.async {
        self.meshViewController?.showMeshViewerMessage(String(format: "Processing: % 3d%%", Int(progress * 80) + 20))
      }
    }
  }

  func meshViewDidRequestColorizing(_ mesh: STMesh, previewCompletionHandler: @escaping () -> Void, enhancedCompletionHandler: @escaping () -> Void) -> Bool {
    if naiveColorizeTask != nil {
      print("Already one colorizing task running!")
      return false
    }

    do {
      naiveColorizeTask = try STColorizer.newColorizeTask(with: mesh, scene: slamState.scene, keyframes: slamState.keyFrameManager!.getKeyFrames(), completionHandler: { error in
        if error != nil {
          print("Error during colorizing: \(error!.localizedDescription)")
        } else {
          DispatchQueue.main.async {
            previewCompletionHandler()
            self.meshViewController?.mesh = mesh
            self.performEnhancedColorize(mesh, enhancedCompletionHandler: enhancedCompletionHandler)
          }
          self.naiveColorizeTask = nil
        }
      }, options: [
        kSTColorizerTypeKey: NSNumber(value: STColorizerType.perVertex.rawValue),
        kSTColorizerPrioritizeFirstFrameColorKey: NSNumber(value: options.prioritizeFirstFrameColor)
      ])
    } catch {}

    if naiveColorizeTask != nil {
      // Release the tracking and mapping resources. It will not be possible to resume a scan after this point
      slamState.mapper?.reset()
      slamState.tracker?.reset()
      naiveColorizeTask?.delegate = self
      naiveColorizeTask?.start()
      return true
    }

    return false
  }

  func performEnhancedColorize(_ mesh: STMesh, enhancedCompletionHandler: @escaping () -> Void) {
    do {
      enhancedColorizeTask = try STColorizer.newColorizeTask(with: mesh, scene: slamState.scene, keyframes: slamState.keyFrameManager!.getKeyFrames(), completionHandler: { error in
        if error != nil {
          print("Error during colorizing: \(error!.localizedDescription)")
        } else {
          DispatchQueue.main.async {
            enhancedCompletionHandler()
            self.meshViewController?.mesh = mesh
          }
          self.enhancedColorizeTask = nil
        }
      }, options: [
        kSTColorizerTypeKey: NSNumber(value: STColorizerType.textureMapForObject.rawValue),
        kSTColorizerPrioritizeFirstFrameColorKey: NSNumber(value: options.prioritizeFirstFrameColor),
        kSTColorizerQualityKey: NSNumber(value: options.colorizerQuality.rawValue),
        kSTColorizerTargetNumberOfFacesKey: NSNumber(value: options.colorizerTargetNumFaces)
      ] /* 20k faces is enough for most objects. */ )
    } catch {}

    if enhancedColorizeTask != nil {
      // We don't need the keyframes anymore now that the final colorizing task was started.
      // Clearing it now gives a chance to early release the keyframe memory when the colorizer
      // stops needing them.
      slamState.keyFrameManager!.clear()

      enhancedColorizeTask?.delegate = self
      enhancedColorizeTask?.start()
    }
  }

  func respondToMemoryWarning() {
    switch slamState.scannerState {
    case ScannerState.viewing:
      // If we are running a colorizing task, abort it
      if enhancedColorizeTask != nil && !slamState.showingMemoryWarning {
        slamState.showingMemoryWarning = true

        // stop the task
        enhancedColorizeTask?.cancel()
        enhancedColorizeTask = nil

        // hide progress bar
        meshViewController?.hideMeshViewerMessage()

        let alertCtrl = UIAlertController(title: "Memory Low", message: "Colorizing was canceled.", preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .default, handler: { _ in
          self.slamState.showingMemoryWarning = false
        })

        alertCtrl.addAction(okAction)

        // show the alert in the meshViewController
        meshViewController?.present(alertCtrl, animated: true)
      }
    case ScannerState.scanning:
      if !slamState.showingMemoryWarning {
        slamState.showingMemoryWarning = true

        let alertCtrl = UIAlertController(title: "Memory Low", message: "Scanning will be stopped to avoid loss.", preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .default, handler: { _ in
          self.slamState.showingMemoryWarning = false
          self.enterViewingState()
        })

        alertCtrl.addAction(okAction)

        // show the alert
        present(alertCtrl, animated: true)
      }
    default:
      // not much we can do here
      break
    }
  }

  func batteryLevelCheckTick(_ timer: Timer) {
    let batteryLevel = self.captureSession.sensorBatteryLevel
    let currentBatteryLevelState: BatteryLevelState = batteryLevel > 50 ? BatteryLevelState.full
      : batteryLevel > 20 ? BatteryLevelState.medium
      : batteryLevel > 0 ? BatteryLevelState.low : BatteryLevelState.unknown

    if currentBatteryLevelState != self.lastBatteryLevelState {
      self.lastBatteryLevelState = currentBatteryLevelState

      DispatchQueue.main.async { () in
        var image: UIImage?
        if self.lastBatteryLevelState == BatteryLevelState.full {
          image = UIImage(named: "icon-battery-full")
        } else if self.lastBatteryLevelState == BatteryLevelState.medium {
          image = UIImage(named: "icon-battery-half")
        } else if self.lastBatteryLevelState == BatteryLevelState.low {
          image = UIImage(named: "icon-battery-low")
        } else {
          self.batteryView.isHidden = true
        }
        self.batteryImageView.image = image

        self.batterySensorLabel.text = image == nil ? "" : "Sensor"
      }
    }
  }
}

// MARK: - SettingsPopupViewDelegate

extension ViewController: SettingsPopupViewDelegate {
  func streamingSettingsDidChange(_ highResolutionColorEnabled: Bool, depthResolution: STCaptureSessionDepthFrameResolution, depthStreamPresetMode: STCaptureSessionPreset) {
    dynamicOptions.highResColoring = highResolutionColorEnabled
    dynamicOptions.depthStreamPreset = depthStreamPresetMode
    dynamicOptions.depthResolution = depthResolution
    captureSession.streamingEnabled = true
  }

  func streamingPropertiesDidChange(_ irAutoExposureEnabled: Bool, irManualExposureValue: Float, irAnalogGainValue: STCaptureSessionSensorAnalogGainMode) {
    captureSession.properties = [
      kSTCaptureSessionPropertySensorIRExposureModeKey: STCaptureSessionSensorExposureMode.autoAdjustAndLock.rawValue,
      kSTCaptureSessionPropertySensorIRExposureValueKey: NSNumber(value: irManualExposureValue),
      kSTCaptureSessionPropertySensorIRAnalogGainValueKey: NSNumber(value: irAnalogGainValue.rawValue)
    ]
  }

  func trackerSettingsDidChange(_ rgbdTrackingEnabled: Bool) {
    dynamicOptions.depthAndColorTrackerIsOn = rgbdTrackingEnabled
    onSLAMOptionsChanged()
  }

  func mapperSettingsDidChange(_ highResolutionMeshEnabled: Bool, improvedMapperEnabled: Bool) {
    dynamicOptions.highResMapping = highResolutionMeshEnabled
    dynamicOptions.improvedMapperIsOn = improvedMapperEnabled
    onSLAMOptionsChanged()
  }

  func renderingSettingsDidChange() {
    switch slamState.scannerState {
    case .cubePlacement:
      metalData.renderingOption = .cubePlacement
    case .scanning:
      metalData.renderingOption = .scanning
    case .viewing:
      metalData.renderingOption = .viewing
    case .numStates:
      break
    }
  }
}

extension ViewController {
  func setupMetal() {
    let device = MTLCreateSystemDefaultDevice()!
    mtkView.device = device
    mtkView.colorPixelFormat = .bgra8Unorm
    mtkView.depthStencilPixelFormat = .depth32Float
    metalData = MetalData(view: mtkView, device: device, options: options)

    mtkView.delegate = metalData
  }
}
