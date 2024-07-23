/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import Structure
import UIKit

enum CalibrationOverlayType: Int {
  case nocalibration
  case approximate
  case strictlyRequired
}

@objc protocol CalibrationOverlayDelegate: NSObjectProtocol {
  func calibrationOverlayDidTapCalibrateButton(_ sender: CalibrationOverlay)
}

@objcMembers
class CalibrationOverlay: UIView {
  private var contentView: UIView?

  private var _overlayType: CalibrationOverlayType!
  var overlayType: CalibrationOverlayType! {
    get {
      return _overlayType
    }
    set(overlayType) {
      _overlayType = overlayType
      setup()
    }
  }

  weak var delegate: CalibrationOverlayDelegate?

  init(type overlayType: CalibrationOverlayType) {
    super.init(frame: CGRect.zero)

    self.overlayType = overlayType
    translatesAutoresizingMaskIntoConstraints = false
  }

  func frame(for overlayType: CalibrationOverlayType) {
    var height: Float = .nan
    var width: Float = .nan

    switch overlayType {
    case .nocalibration:
        width = 650.0
        height = 340.0
    case .approximate:
        width = 340.0
        height = 56.0
    case .strictlyRequired:
        width = 650.0
        height = 340.0
    }
    addConstraints([
      NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: CGFloat(width)),
      // Set full view height
      NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: CGFloat(height))
    ])
  }

  func setup() {
    frame(for: overlayType)
    contentView?.removeFromSuperview()

    contentView = UIView()
    contentView?.backgroundColor = UIColor.clear
    contentView?.translatesAutoresizingMaskIntoConstraints = false
    contentView?.clipsToBounds = false
    if let contentView = contentView {
      addSubview(contentView)
    }

    // Pinning all edges of the content view to the superview (this object)
    if let contentView = contentView {
      contentView.superview?.addConstraints([
        NSLayoutConstraint(item: contentView, attribute: .top, relatedBy: .equal, toItem: contentView.superview, attribute: .top, multiplier: 1.0, constant: 0.0),
        // Left edge
        NSLayoutConstraint(item: contentView, attribute: .left, relatedBy: .equal, toItem: contentView.superview, attribute: .left, multiplier: 1.0, constant: 0.0),
        // Right edge
        NSLayoutConstraint(item: contentView, attribute: .right, relatedBy: .equal, toItem: contentView.superview, attribute: .right, multiplier: 1.0, constant: 0.0),
        // Bottom edge
        NSLayoutConstraint(item: contentView, attribute: .bottom, relatedBy: .equal, toItem: contentView.superview, attribute: .bottom, multiplier: 1.0, constant: 0.0)
      ])
    }

    backgroundColor = UIColor(white: 0.0, alpha: 0.7)
    isUserInteractionEnabled = true

    switch overlayType {
    case .some(.nocalibration):
      fallthrough
    case .none:
        layer.cornerRadius = 12.0
        let imageView = UIImageView(image: UIImage(named: "image-wvl-calibration"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 8.0
        imageView.contentMode = .scaleAspectFit
        contentView?.addSubview(imageView)

        imageView.superview?.addConstraints([
          NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal, toItem: imageView.superview, attribute: .top, multiplier: 1.0, constant: 35.0),
          // Align the centre X axis to the superview
          NSLayoutConstraint(item: imageView, attribute: .centerX, relatedBy: .equal, toItem: imageView.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0)
        ])
        imageView.addConstraints([
          NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 90.0),
          // Set height to 90
          NSLayoutConstraint(item: imageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 90.0)
        ])

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 36.0, weight: .bold)
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.text = "Calibration Required"
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        contentView?.addSubview(titleLabel)

        // Set title height to 43
        titleLabel.addConstraint(NSLayoutConstraint(item: titleLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 43.0))
        titleLabel.superview?.addConstraints([
          NSLayoutConstraint(item: titleLabel, attribute: .centerX, relatedBy: .equal, toItem: titleLabel.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
          // Pin title to bottom of image view
          NSLayoutConstraint(item: titleLabel, attribute: .top, relatedBy: .equal, toItem: imageView, attribute: .bottom, multiplier: 1.0, constant: 25.0)
        ])

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont.systemFont(ofSize: 18.0, weight: .regular)
        messageLabel.adjustsFontSizeToFitWidth = true
        let subText = "In order to start scanning, you need to calibrate your Structure Sensor."
        let attrSub = NSMutableAttributedString(string: subText)
        let subStyle = NSMutableParagraphStyle()
        subStyle.lineSpacing = 8.0
        attrSub.addAttribute(.paragraphStyle, value: subStyle, range: NSRange(location: 0, length: subText.count))
        messageLabel.attributedText = attrSub
        messageLabel.textColor = UIColor.white
        contentView?.addSubview(messageLabel)

        messageLabel.superview?.addConstraints([
          NSLayoutConstraint(item: messageLabel, attribute: .top, relatedBy: .equal, toItem: titleLabel, attribute: .bottom, multiplier: 1.0, constant: 10.0),
          // Align message to centre of superview
          NSLayoutConstraint(item: messageLabel, attribute: .centerX, relatedBy: .equal, toItem: messageLabel.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0)
        ])
        messageLabel.addConstraints([
          NSLayoutConstraint(item: messageLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 26.0)
        ])

        let calibrateButton = UIButton(type: .custom)
        calibrateButton.translatesAutoresizingMaskIntoConstraints = false
        calibrateButton.setTitle("Calibrate Now", for: .normal)
        calibrateButton.setTitleColor(UIColor(named: "AccentColor"), for: .normal)
        calibrateButton.setTitleColor(UIColor.white.withAlphaComponent(0.76), for: .highlighted)

        calibrateButton.setBackgroundImage(image(with: UIColor.white, rect: CGRect(x: 0.0, y: 0.0, width: 260.0, height: 50.0), cornerRadius: 25.0), for: .normal)
        calibrateButton.setBackgroundImage(image(with: UIColor.lightGray, rect: CGRect(x: 0.0, y: 0.0, width: 260.0, height: 50.0), cornerRadius: 25.0), for: .highlighted)

        calibrateButton.backgroundColor = UIColor.clear
        calibrateButton.clipsToBounds = true
        calibrateButton.layer.cornerRadius = 25.0
        calibrateButton.titleLabel?.font = UIFont.systemFont(ofSize: 20.0, weight: .medium)
        calibrateButton.contentHorizontalAlignment = .center
        calibrateButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        calibrateButton.addTarget(self, action: #selector(calibrationButtonClicked(_:)), for: .touchUpInside)
        contentView?.addSubview(calibrateButton)

        calibrateButton.addConstraints([
          // Set button width to 260
          NSLayoutConstraint(item: calibrateButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 260.0),
          // Set button height to 50
          NSLayoutConstraint(item: calibrateButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 50.0)
        ])
        calibrateButton.superview?.addConstraints([
          NSLayoutConstraint(item: calibrateButton, attribute: .centerX, relatedBy: .equal, toItem: calibrateButton.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
          NSLayoutConstraint(item: calibrateButton, attribute: .top, relatedBy: .equal, toItem: messageLabel, attribute: .bottom, multiplier: 1.0, constant: 30.0)
        ])
    case .approximate:
        layer.cornerRadius = 8.0

        let imageView = UIImageView(image: UIImage(named: "image-wvl-calibration"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 8.0
        imageView.clipsToBounds = true
        contentView?.addSubview(imageView)

        imageView.superview?.addConstraints([
          NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal, toItem: imageView.superview, attribute: .top, multiplier: 1.0, constant: 4.0),
          // Pin image to leading edge of superview with offset
          NSLayoutConstraint(item: imageView, attribute: .leading, relatedBy: .equal, toItem: imageView.superview, attribute: .leading, multiplier: 1.0, constant: 4.0)
        ])
        imageView.addConstraints([
          NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 48.0),
          // Fix height to 48
          NSLayoutConstraint(item: imageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 48.0)
        ])

        let message = UILabel()
        message.translatesAutoresizingMaskIntoConstraints = false
        message.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        message.text = "Calibration needed for best results."
        message.textColor = UIColor.white
        contentView?.addSubview(message)

        message.superview?.addConstraints([
          NSLayoutConstraint(item: message, attribute: .top, relatedBy: .equal, toItem: message.superview, attribute: .top, multiplier: 1.0, constant: 4.0),
          // Pin leading edge of message to superview with offset
          NSLayoutConstraint(item: message, attribute: .leading, relatedBy: .equal, toItem: message.superview, attribute: .leading, multiplier: 1.0, constant: 64.0),
          // Pin trailing edge of message to superview with offset
          NSLayoutConstraint(item: message, attribute: .trailing, relatedBy: .equal, toItem: message.superview, attribute: .trailing, multiplier: 1.0, constant: 4.0)
        ])
        // Set height of message to 22
        message.addConstraint(NSLayoutConstraint(item: message, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 22.0))

        let calibrationButton = UIButton(type: .system)
        calibrationButton.translatesAutoresizingMaskIntoConstraints = false

        calibrationButton.setTitle("Calibrate Now", for: .normal)
        calibrationButton.tintColor = UIColor(red: 0.25, green: 0.73, blue: 0.88, alpha: 1.0)
        calibrationButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)
        calibrationButton.contentHorizontalAlignment = .left
        calibrationButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        calibrationButton.addTarget(self, action: #selector(calibrationButtonClicked(_:)), for: .touchUpInside)

        contentView?.addSubview(calibrationButton)
        calibrationButton.superview?.addConstraints([
          NSLayoutConstraint(item: calibrationButton, attribute: .top, relatedBy: .equal, toItem: message, attribute: .bottom, multiplier: 1.0, constant: 4.0),
          // Pin calibration button leading edge to leading edge of message
          NSLayoutConstraint(item: calibrationButton, attribute: .leading, relatedBy: .equal, toItem: message, attribute: .leading, multiplier: 1.0, constant: 0.0)
        ])
        // Set height of calibration button to 22
        calibrationButton.addConstraint(NSLayoutConstraint(item: calibrationButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 22.0))
    case .strictlyRequired:
        layer.cornerRadius = 12.0

        let imageView = UIImageView(image: UIImage(named: "image-wvl-calibration"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        contentView?.addSubview(imageView)

        imageView.superview?.addConstraints([
          NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal, toItem: imageView.superview, attribute: .top, multiplier: 1.0, constant: 120.0),
          // Pin image to leading edge of superview with offset
          NSLayoutConstraint(item: imageView, attribute: .leading, relatedBy: .equal, toItem: imageView.superview, attribute: .leading, multiplier: 1.0, constant: 100.0)
        ])
        imageView.addConstraints([
          NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 90.0),
          // Set image height to 90
          NSLayoutConstraint(item: imageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 90.0)
        ])

        let visualEffect = UIBlurEffect(style: .light)
        let visualEffectView = UIVisualEffectView(effect: visualEffect)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(visualEffectView)
        visualEffectView.layer.cornerRadius = 45.0
        visualEffectView.layer.masksToBounds = true
        contentView?.bringSubviewToFront(visualEffectView)

        visualEffectView.superview?.addConstraints([
          NSLayoutConstraint(item: visualEffectView, attribute: .bottom, relatedBy: .equal, toItem: imageView, attribute: .top, multiplier: 1.0, constant: 32.5),
          // Pin right of visual effect view to image view with offset
          NSLayoutConstraint(item: visualEffectView, attribute: .right, relatedBy: .equal, toItem: imageView, attribute: .left, multiplier: 1.0, constant: 35.0)
        ])

        visualEffectView.addConstraints([
          NSLayoutConstraint(item: visualEffectView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 90.0),
          // Set height to 90
          NSLayoutConstraint(item: visualEffectView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 90.0)
        ])

        let wvl = UIImageView(image: UIImage(named: "image-wvl"))
        wvl.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.contentView.addSubview(wvl)

        // Pin all edges to super view edge with one offset on the left edge
        wvl.superview?.addConstraints([
          NSLayoutConstraint(item: wvl, attribute: .top, relatedBy: .equal, toItem: wvl.superview, attribute: .top, multiplier: 1.0, constant: 0.0),
          NSLayoutConstraint(item: wvl, attribute: .left, relatedBy: .equal, toItem: wvl.superview, attribute: .left, multiplier: 1.0, constant: 5.0),
          NSLayoutConstraint(item: wvl, attribute: .bottom, relatedBy: .equal, toItem: wvl.superview, attribute: .bottom, multiplier: 1.0, constant: 0.0),
          NSLayoutConstraint(item: wvl, attribute: .right, relatedBy: .equal, toItem: wvl.superview, attribute: .right, multiplier: 1.0, constant: 0.0)
        ])

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 36.0, weight: .bold)

        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.text = "Lens Calibration Required"
        titleLabel.textColor = UIColor.white
        contentView?.addSubview(titleLabel)

        titleLabel.superview?.addConstraints([
          NSLayoutConstraint(item: titleLabel, attribute: .top, relatedBy: .equal, toItem: titleLabel.superview, attribute: .top, multiplier: 1.0, constant: 50.0),
          // Align centre X between title and superview
          NSLayoutConstraint(item: titleLabel, attribute: .leading, relatedBy: .equal, toItem: imageView, attribute: .trailing, multiplier: 1.0, constant: 22.0)
        ])
        titleLabel.addConstraints([
          NSLayoutConstraint(item: titleLabel, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 380.0),
          // Set height to 43
          NSLayoutConstraint(item: titleLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 43.0)
        ])

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont.systemFont(ofSize: 18.0, weight: .regular)
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.numberOfLines = 0
        let subText = "In order to scan with your Wide Vision Lens, you need to calibrate the lens."
        let attrSub = NSMutableAttributedString(string: subText)
        let subStyle = NSMutableParagraphStyle()
        subStyle.lineSpacing = 8.0
        attrSub.addAttribute(.paragraphStyle, value: subStyle, range: NSRange(location: 0, length: subText.count))
        messageLabel.attributedText = attrSub
        messageLabel.textColor = UIColor.white
        contentView?.addSubview(messageLabel)

        messageLabel.superview?.addConstraints([
          NSLayoutConstraint(item: messageLabel, attribute: .centerX, relatedBy: .equal, toItem: titleLabel, attribute: .centerX, multiplier: 1.0, constant: 0.0),
          // Pin message top to bottom of title with offset
          NSLayoutConstraint(item: messageLabel, attribute: .top, relatedBy: .equal, toItem: titleLabel, attribute: .bottom, multiplier: 1.0, constant: 15.0),
          // Set width of message to match title
          NSLayoutConstraint(item: messageLabel, attribute: .width, relatedBy: .equal, toItem: titleLabel, attribute: .width, multiplier: 1.0, constant: 0.0)
        ])

        let subMessageLabel = UILabel()
        subMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        subMessageLabel.font = UIFont.systemFont(ofSize: 18.0, weight: .regular)
        subMessageLabel.lineBreakMode = .byWordWrapping
        subMessageLabel.numberOfLines = 0

        let text = "(Alternatively, you may toggle off and remove your Wide Vision Lens.)"
        let attrString = NSMutableAttributedString(string: text)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8.0
        attrString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.count))
        subMessageLabel.attributedText = attrString
        subMessageLabel.textColor = #colorLiteral(red: 0.7411764706, green: 0.7411764706, blue: 0.7411764706, alpha: 1)
        contentView?.addSubview(subMessageLabel)

        subMessageLabel.superview?.addConstraints([
          NSLayoutConstraint(item: subMessageLabel, attribute: .centerX, relatedBy: .equal, toItem: messageLabel, attribute: .centerX, multiplier: 1.0, constant: 0.0),
          // Pin top edge of sub-message to bottom of message
          NSLayoutConstraint(item: subMessageLabel, attribute: .top, relatedBy: .equal, toItem: messageLabel, attribute: .bottom, multiplier: 1.0, constant: 13.0),
          // Set width of sub-message to match message
          NSLayoutConstraint(item: subMessageLabel, attribute: .width, relatedBy: .equal, toItem: messageLabel, attribute: .width, multiplier: 1.0, constant: 0.0)
        ])

        let calibrateButton = UIButton(type: .custom)
        calibrateButton.translatesAutoresizingMaskIntoConstraints = false
        calibrateButton.setTitle("Calibrate Now", for: .normal)
        calibrateButton.setTitleColor(UIColor(named: "AccentColor"), for: .normal)
        calibrateButton.setTitleColor(UIColor.white.withAlphaComponent(0.76), for: .highlighted)

        calibrateButton.setBackgroundImage(image(with: UIColor.white, rect: CGRect(x: 0.0, y: 0.0, width: 413.0, height: 50.0), cornerRadius: 25.0), for: .normal)
        calibrateButton.setBackgroundImage(image(with: UIColor.lightGray, rect: CGRect(x: 0.0, y: 0.0, width: 413.0, height: 50.0), cornerRadius: 25.0), for: .highlighted)

        calibrateButton.backgroundColor = UIColor.clear
        calibrateButton.clipsToBounds = true
        calibrateButton.layer.cornerRadius = 25.0
        calibrateButton.titleLabel?.font = UIFont.systemFont(ofSize: 20.0, weight: .medium)
        calibrateButton.contentHorizontalAlignment = .center
        calibrateButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        calibrateButton.addTarget(self, action: #selector(calibrationButtonClicked(_:)), for: .touchUpInside)
        contentView?.addSubview(calibrateButton)

        calibrateButton.superview?.addConstraints([
          NSLayoutConstraint(item: calibrateButton, attribute: .centerX, relatedBy: .equal, toItem: calibrateButton.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
          // Pin top of calibration button to bottom edge of sub-message with offset
          NSLayoutConstraint(item: calibrateButton, attribute: .top, relatedBy: .equal, toItem: subMessageLabel, attribute: .bottom, multiplier: 1.0, constant: 25.0)
        ])

        calibrateButton.addConstraints([
          NSLayoutConstraint(item: calibrateButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 260.0),
          // Set height to 50
          NSLayoutConstraint(item: calibrateButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 50.0)
        ])
    }
  }

  func image(with color: UIColor, rect: CGRect, cornerRadius: CGFloat) -> UIImage {
    UIGraphicsBeginImageContext(rect.size)
    let context = UIGraphicsGetCurrentContext()
    context?.setAllowsAntialiasing(true)
    context?.setShouldAntialias(true)

    color.setFill()

    let bezierPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
    bezierPath.fill()

    let image = UIGraphicsGetImageFromCurrentImageContext()

    context?.setAllowsAntialiasing(false)
    context?.setShouldAntialias(false)

    UIGraphicsEndImageContext()

    return image!
  }

  func calibrationButtonClicked(_ button: UIButton) {
    if delegate?.responds(to: #selector(CalibrationOverlayDelegate.calibrationOverlayDidTapCalibrateButton(_:))) ?? false {
      delegate?.calibrationOverlayDidTapCalibrateButton(self)
    } else {
      launchCalibratorAppOrGoToAppStore()
    }
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
