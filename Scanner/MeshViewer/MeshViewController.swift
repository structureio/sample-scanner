/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import GLKit
import ImageIO
import MessageUI
import MetalKit
import Structure
import StructureKit
import UIKit

@objc protocol MeshViewDelegate: NSObjectProtocol {
  func meshViewWillDismiss()
  func meshViewDidDismiss()
  @discardableResult func meshViewDidRequestColorizing(_ mesh: STMesh, previewCompletionHandler: @escaping () -> Void, enhancedCompletionHandler: @escaping () -> Void) -> Bool
}

@objcMembers
public class MeshViewController: UIViewController, UIGestureRecognizerDelegate {
  @IBOutlet var displayControl: UISegmentedControl!
  @IBOutlet var meshViewerMessageLabel: UILabel!
  @IBOutlet var mtkView: MTKView!
  private var displayLink: CADisplayLink?

  private var mtkRenderer: MetalMeshRenderer!

  private var viewpointController: ViewpointController = .init()
  var mailViewController: MFMailComposeViewController?
  private var modelViewMatrixBeforeUserInteractions: float4x4?
  private var projectionMatrixBeforeUserInteractions: float4x4?

  var _mesh: STMesh? // swiftlint:disable:this identifier_name
  var mesh: STMesh! {
    get {
      return _mesh
    }
    set {
      _mesh = newValue
      if let mesh = _mesh {
        mtkRenderer.updateMesh(mesh: mesh)
        trySwitchToColorRenderingMode()
        needsDisplay = true
      }
    }
  }

  weak var delegate: MeshViewDelegate?

  // force the view to redraw.
  var needsDisplay: Bool = true
  var colorEnabled: Bool = true

  override public func viewDidLoad() {
    super.viewDidLoad()

    setupMetal()

    let font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: font]
    displayControl.setTitleTextAttributes(attributes, for: .normal)

    viewpointController.setScreenSize(screenSizeX: Float(mtkView.frame.size.width), screenSizeY: Float(mtkView.frame.size.height))

    trySwitchToColorRenderingMode()
    needsDisplay = true
  }

  func setupMetal() {
    let device = MTLCreateSystemDefaultDevice()!
    mtkView.device = device

    mtkView.colorPixelFormat = .bgra8Unorm
    mtkView.depthStencilPixelFormat = .depth32Float

    mtkRenderer = MetalMeshRenderer(view: mtkView, device: device, mesh: mesh, size: view.bounds.size)
    mtkRenderer.viewpointController = viewpointController
    mtkView.delegate = mtkRenderer

    // we will trigger drawing by ourselfes
    mtkView.enableSetNeedsDisplay = false
    mtkView.isPaused = true

    // allow access to the bytes to write screenshots
    mtkView.framebufferOnly = false

    // correct the projection matrix for our viewport
    let viewportSize = view.bounds.size
    let oldProjection = projectionMatrixBeforeUserInteractions!
    let actualRatio = Float(viewportSize.height / viewportSize.width)
    let oldRatio = oldProjection.columns.0.norm() / oldProjection.columns.1.norm()
    let diff = actualRatio / oldRatio
    let newProjection = float4x4.makeScale(diff, 1.0, 1) * oldProjection
    viewpointController.setCameraProjection(newProjection)
  }

  override public func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    displayLink?.invalidate()
    displayLink = nil
  }

  override open func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    setupDisplayLynk()
  }

  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    needsDisplay = true
  }

  private func setupDisplayLynk() {
    displayLink?.invalidate()
    displayLink = nil

    displayLink = CADisplayLink(target: self, selector: #selector(MeshViewController.draw))
    displayLink!.add(to: RunLoop.main, forMode: RunLoop.Mode.common)

    viewpointController.reset()

    if !colorEnabled {
      displayControl.removeSegment(at: 2, animated: false)
    }

    displayControl.selectedSegmentIndex = 1
  }

  override public var prefersStatusBarHidden: Bool {
    return true
  }

  func setCameraProjectionMatrix(_ projection: float4x4) {
    viewpointController.setCameraProjection(projection)
    projectionMatrixBeforeUserInteractions = projection
  }

  func resetMeshCenter(_ center: vector_float3, _ size: vector_float3) {
    viewpointController.reset()
    viewpointController.setMeshCenter(center, size)
    modelViewMatrixBeforeUserInteractions = viewpointController.currentGLModelViewMatrix()
  }

  func setLabel(_ label: UILabel, enabled: Bool) {
    let whiteLightAlpha = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)

    if enabled {
      label.textColor = UIColor.white
    } else {
      label.textColor = whiteLightAlpha
    }
  }

  @IBAction func dismissView() {
    if delegate?.responds(to: #selector(ViewController.meshViewWillDismiss)) ?? false {
      delegate?.meshViewWillDismiss()
    }

    displayLink?.invalidate()
    displayLink = nil

    mesh = nil

    dismiss(animated: true) {
      if self.delegate?.responds(to: #selector(ViewController.meshViewDidDismiss)) ?? false {
        self.delegate?.meshViewDidDismiss()
        self.delegate = nil
      }
    }
  }

  @IBAction func displayControlChanged(_ sender: Any) {
    switch displayControl.selectedSegmentIndex {
    case 0 /* x-ray */:
      mtkRenderer.mode = .xray
    case 1 /* lighted-gray */:
      mtkRenderer.mode = .lightedGrey
    case 2 /* color */:
      trySwitchToColorRenderingMode()

      let meshIsColorized = mesh!.hasPerVertexColors() || mesh!.hasPerVertexUVTextureCoords()

      if !meshIsColorized {
        colorizeMesh()
      }
    default:
      break
    }

    needsDisplay = true
  }

  // MARK: - Touch & Gesture control

  @IBAction func pinchScaleGesture(_ gestureRecognizer: UIPinchGestureRecognizer) {
    // Forward to the ViewpointController.
    if gestureRecognizer.state == .began {
      viewpointController.onPinchGestureBegan(Float(gestureRecognizer.scale))
    } else if gestureRecognizer.state == .changed {
      viewpointController.onPinchGestureChanged(Float(gestureRecognizer.scale))
    }
  }

  @IBAction func oneFingerPanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
    let touchPos = gestureRecognizer.location(in: view)
    let touchVel = gestureRecognizer.velocity(in: view)
    let touchPosVec = vector_float2(Float(touchPos.x), Float(touchPos.y))
    let touchVelVec = vector_float2(Float(touchVel.x), Float(touchVel.y))

    if gestureRecognizer.state == .began {
      viewpointController.onOneFingerPanBegan(touchPosVec)
    } else if gestureRecognizer.state == .changed {
      viewpointController.onOneFingerPanChanged(touchPosVec)
    } else if gestureRecognizer.state == .ended {
      viewpointController.onOneFingerPanEnded(touchVelVec)
    }
  }

  @IBAction func twoFingersPanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
    if gestureRecognizer.numberOfTouches != 2 {
      return
    }

    let touchPos = gestureRecognizer.location(in: view)
    let touchVel = gestureRecognizer.velocity(in: view)
    let touchPosVec = vector_float2(Float(touchPos.x), Float(touchPos.y))
    let touchVelVec = vector_float2(Float(touchVel.x), Float(touchVel.y))

    if gestureRecognizer.state == .began {
      viewpointController.onTwoFingersPanBegan(touchPosVec)
    } else if gestureRecognizer.state == .changed {
      viewpointController.onTwoFingersPanChanged(touchPosVec)
    } else if gestureRecognizer.state == .ended {
      viewpointController.onTwoFingersPanEnded(touchVelVec)
    }
  }

  override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    viewpointController.onTouchBegan()
  }

  func prepareScreenShot(_ screenshotPath: URL) {
    let lastDrawableDisplayed = mtkView.currentDrawable?.texture
    if let imageRef = lastDrawableDisplayed?.toImage() {
      let uiImage = UIImage(cgImage: imageRef)
      if let data = uiImage.jpegData(compressionQuality: 0.8) {
        try? data.write(to: screenshotPath)
      }
    }
  }

  // MARK: - Rendering

  func draw() {
    let viewpointChanged = viewpointController.update()

    // If nothing changed, do not waste time and resources rendering.
    if !needsDisplay && !viewpointChanged {
      return
    }

    mtkView.draw()
    needsDisplay = false
  }

  // MARK: - UI Control

  func trySwitchToColorRenderingMode() {
    // Choose the best available color render mode, falling back to LightedGray

    // This method may be called when colorize operations complete, and will
    // switch the render mode to color, as long as the user has not changed
    // the selector.

    if displayControl.selectedSegmentIndex == 2 {
      if mesh!.hasPerVertexUVTextureCoords() {
        mtkRenderer.mode = .texture
      } else if mesh!.hasPerVertexColors() {
        mtkRenderer.mode = .vertexColor
      } else {
        mtkRenderer.mode = .lightedGrey
      }
    }
  }

  func showMeshViewerMessage(_ msg: String) {
    meshViewerMessageLabel.text = msg

    if meshViewerMessageLabel.isHidden == true {
      meshViewerMessageLabel.isHidden = false

      meshViewerMessageLabel.alpha = 0.0
      UIView.animate(withDuration: 0.5, animations: {
        self.meshViewerMessageLabel.alpha = 1.0
      })
    }
  }

  func hideMeshViewerMessage() {
    UIView.animate(withDuration: 0.5, animations: {
      self.meshViewerMessageLabel.alpha = 0.0
    }, completion: { _ in
      self.meshViewerMessageLabel.isHidden = true
    })
  }

  func colorizeMesh() {
    if let mesh = mesh {
      delegate?.meshViewDidRequestColorizing(mesh, previewCompletionHandler: {}, enhancedCompletionHandler: {
        // Hide progress bar.
        self.hideMeshViewerMessage()
      })
    }
  }

  @IBAction func emailSupport() {
    let recipientEmail = "support@structure.io"
    let subject = "Contact Us"
    let body = ""

    if MFMailComposeViewController.canSendMail() {
      mailViewController = MFMailComposeViewController()
      guard let mailVC = mailViewController else {
        showAlert(title: "ERROR!!!", message: "Failed to create the mail composer.")
        return
      }
      mailVC.mailComposeDelegate = self
      mailVC.setSubject(subject)
      mailVC.setToRecipients([recipientEmail])
      present(mailVC, animated: true)
    } else if let emailURL = createEmailUrl(recipient: recipientEmail, subject: subject, body: body) {
      UIApplication.shared.open(emailURL)
    }
  }

  @IBAction func shareMesh(sender: UIBarButtonItem) {
    guard let cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    // Setup paths and filenames.
    let zipFilename = "Model.zip"
    let zipPath = cacheDirectory.appendingPathComponent("\(zipFilename)")

    let screenshotFilename = "Preview.jpg"
    let screenshotPath = cacheDirectory.appendingPathComponent("\(screenshotFilename)")

    // Request a zipped OBJ file, potentially with embedded MTL and texture.
    let options: [AnyHashable: Any] = [
      kSTMeshWriteOptionFileFormatKey: STMeshWriteOptionFileFormat.objFileZip.rawValue,
      kSTMeshWriteOptionUseXRightYUpConventionKey: true
    ]

    guard let meshToSend = mesh else { return }

    do {
      try meshToSend.write(toFile: zipPath.path, options: options)
    } catch {
      showAlert(title: "ERROR!!!", message: "Mesh exporting failed: \(error.localizedDescription).")
      return
    }

    // Take a screenshot and save it to disk.
    prepareScreenShot(screenshotPath)

    guard let image = UIImage(contentsOfFile: screenshotPath.path) else {
      showAlert(title: "ERROR!!!", message: "Failed to create screenshot of mesh.")
      return
    }
    let meshFile = NSURL.fileURL(withPath: zipPath.path)
    let activityItems: [STKMixedActivityItemSource] = [.init(item: .image(image: image)),
                                                       .init(item: .archieve(file: meshFile))]
    let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    if UIDevice.current.userInterfaceIdiom == .pad {
      activityViewController.popoverPresentationController?.barButtonItem = sender
    }
    present(activityViewController, animated: true)
  }

  @IBAction func openDeveloperPortal(_ sender: Any) {
    UIApplication.shared.open(URL(string: "https://structure.io/developers")!)
  }
}
