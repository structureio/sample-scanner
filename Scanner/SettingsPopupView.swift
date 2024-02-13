/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import Foundation
import Structure
import UIKit

protocol SettingsPopupViewDelegate: AnyObject {
  func streamingSettingsDidChange(_ highResolutionColorEnabled: Bool, depthResolution: STCaptureSessionDepthFrameResolution, depthStreamPresetMode: STCaptureSessionPreset)
  func streamingPropertiesDidChange(_ irAutoExposureEnabled: Bool, irManualExposureValue: Float, irAnalogGainValue: STCaptureSessionSensorAnalogGainMode)
  func trackerSettingsDidChange(_ rgbdTrackingEnabled: Bool)
  func mapperSettingsDidChange(_ highResolutionMeshEnabled: Bool, improvedMapperEnabled: Bool)
}

@objcMembers
class SettingsPopupView: UIView {
  private var settingsIcon: UIButton?
  private var settingsListModal: SettingsListModal?
  private var isSettingsListModalHidden: Bool = true
  private var widthConstraintWhenListModalIsShown: NSLayoutConstraint?
  private var heightConstraintWhenListModalIsShown: NSLayoutConstraint?
  private var widthConstraintWhenListModalIsHidden: NSLayoutConstraint?
  private var heightConstraintWhenListModalIsHidden: NSLayoutConstraint?

  init(settingsPopupViewDelegate delegate: SettingsPopupViewDelegate?) {
    super.init(frame: CGRect.zero)

    setupComponents(with: delegate)
  }

  func enableAllSettingsDuringCubePlacement() {
    settingsListModal?.enableAllSettingsDuringCubePlacement()
  }

  func disableNonDynamicSettingsDuringScanning() {
    settingsListModal?.disableNonDynamicSettingsDuringScanning()
  }

  func setupComponents(with delegate: SettingsPopupViewDelegate?) {
    // Attributes that apply to the whole content view
    backgroundColor = UIColor.clear
    translatesAutoresizingMaskIntoConstraints = false
    clipsToBounds = false

    // Settings Icon
    settingsIcon = UIButton()
    settingsIcon?.setImage(UIImage(named: "settings-icon.png"), for: .normal)
    settingsIcon?.setImage(UIImage(named: "settings-icon.png"), for: .highlighted)
    settingsIcon?.translatesAutoresizingMaskIntoConstraints = false
    settingsIcon?.contentMode = .scaleAspectFit
    settingsIcon?.addTarget(self, action: #selector(settingsIconPressed(_:)), for: .touchUpInside)
    if let settingsIcon = settingsIcon {
      addSubview(settingsIcon)
    }

    if let settingsIcon = settingsIcon {
      addConstraints([
        NSLayoutConstraint(item: settingsIcon, attribute: .top, relatedBy: .equal, toItem: settingsIcon.superview, attribute: .top, multiplier: 1.0, constant: 0.0),
        // Pin settings icon to left of superview
        NSLayoutConstraint(item: settingsIcon, attribute: .left, relatedBy: .equal, toItem: settingsIcon.superview, attribute: .left, multiplier: 1.0, constant: 0.0),
        // Set width to 45
        NSLayoutConstraint(item: settingsIcon, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 45.0),
        // Set height to 45
        NSLayoutConstraint(item: settingsIcon, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 45.0)
      ])
    }

    // Full Settings List Modal
    settingsListModal = SettingsListModal(settingsPopupViewDelegate: delegate)

    widthConstraintWhenListModalIsShown = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 450.0)

    let screenBounds = UIScreen.main.bounds
    heightConstraintWhenListModalIsShown = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: screenBounds.size.height - 80)

    widthConstraintWhenListModalIsHidden = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: settingsIcon, attribute: .width, multiplier: 1.0, constant: 0.0)

    heightConstraintWhenListModalIsHidden = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: settingsIcon, attribute: .height, multiplier: 1.0, constant: 0.0)

    // By default, we'll have the list modal hidden
    addConstraints([
      widthConstraintWhenListModalIsHidden,
      heightConstraintWhenListModalIsHidden
    ].compactMap { $0 })
    isSettingsListModalHidden = true
  }

  func showSettingsListModal() {
    if let settingsListModal = settingsListModal {
      addSubview(settingsListModal)
    }

    if let settingsListModal = settingsListModal {
      addConstraints([
        NSLayoutConstraint(item: settingsListModal, attribute: .top, relatedBy: .equal, toItem: settingsIcon, attribute: .top, multiplier: 1.0, constant: 0.0),
        // Pin left edge of settings list modal to superview
        NSLayoutConstraint(item: settingsListModal, attribute: .left, relatedBy: .equal, toItem: settingsIcon, attribute: .right, multiplier: 1.0, constant: 20.0),
        // Set width of settings list modal to be 380
        NSLayoutConstraint(item: settingsListModal, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 380.0),
        // Set height of settings list modal less than or equal to superview
        NSLayoutConstraint(item: settingsListModal, attribute: .height, relatedBy: .lessThanOrEqual, toItem: settingsListModal.superview, attribute: .height, multiplier: 1.0, constant: 0.0)
      ])
    }
    if let settingsListModal = settingsListModal {
      bringSubviewToFront(settingsListModal)
    }
  }

  func hideSettingsListModal() {
    settingsListModal?.removeFromSuperview()
  }

  func settingsIconPressed(_ sender: UIButton) {
    if isSettingsListModalHidden {
      isSettingsListModalHidden = false
      removeConstraints([
        widthConstraintWhenListModalIsHidden,
        heightConstraintWhenListModalIsHidden
      ].compactMap { $0 })
      addConstraints([
        widthConstraintWhenListModalIsShown,
        heightConstraintWhenListModalIsShown
      ].compactMap { $0 })
      showSettingsListModal()
      return
    }

    isSettingsListModalHidden = true
    removeConstraints([
      widthConstraintWhenListModalIsShown,
      heightConstraintWhenListModalIsShown
    ].compactMap { $0 })
    addConstraints([
      widthConstraintWhenListModalIsHidden,
      heightConstraintWhenListModalIsHidden
    ].compactMap { $0 })
    hideSettingsListModal()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}

// MARK: DropDownView

typealias Action = (Int) -> Void

class DropDownView: UITableView, UITableViewDelegate, UITableViewDataSource {
  private var _options: [String] = []
  private var _cellReuseIdentifier: String = "cell"
  private var _heightConstraint: NSLayoutConstraint!
  private var _isShown: Bool = false
  private let fontHeight: CGFloat = 17.0
  private var _activeIndex: Int = 0
  private var _action: Action?

  let accentColor = UIColor(named: "AccentColor") ?? #colorLiteral(red: 0, green: 0.765, blue: 1, alpha: 1)
  let controlBackgroundColor = UIColor(named: "ControlBackgroundColor") ?? #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
  let headerTextColor = UIColor(named: "HeaderTextColor") ?? #colorLiteral(red: 0.227, green: 0.227, blue: 0.235, alpha: 1)
  let darkTextColor = UIColor(named: "DarkTextColor") ?? #colorLiteral(red: 0.314, green: 0.314, blue: 0.325, alpha: 1)
  let lightTextColor = UIColor(named: "LightTextColor") ?? #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)

  var selectedIndex: Int {
    get { return _activeIndex }
    set {
      _activeIndex = newValue
      reloadData()
    }
  }

  var onChangedTarget: Action? {
    get { return _action }
    set {
      _action = newValue
    }
  }

  init(options: [String], activeIndex index: Int) {
    _options = options
    _cellReuseIdentifier = "cell"
    _isShown = false
    _activeIndex = index

    super.init(frame: CGRect.zero, style: .plain)

    register(UITableViewCell.self, forCellReuseIdentifier: _cellReuseIdentifier)

    _heightConstraint = heightAnchor.constraint(equalToConstant: 0)
    _heightConstraint.isActive = true

    dataSource = self
    delegate = self
    isScrollEnabled = false

    layoutIfNeeded()
    reloadData()
    _heightConstraint.constant = contentSize.height
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: _cellReuseIdentifier, for: indexPath)

    guard let label = cell.textLabel else { return cell }
    let iRow: Int = indexPath[1]
    if iRow == 0 { // header
      label.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      label.textColor = headerTextColor
      cell.backgroundColor = controlBackgroundColor
      label.text = _options[_activeIndex]
    } else if iRow - 1 == _activeIndex { // selected cell
      label.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      label.textColor = lightTextColor
      cell.backgroundColor = accentColor
      label.text = _options[iRow - 1]
    } else {
      label.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      label.textColor = darkTextColor
      cell.backgroundColor = controlBackgroundColor
      label.text = _options[iRow - 1]
    }
    return cell
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return _isShown ? 1 + _options.count : 1
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if _isShown {
      _isShown = false
      let iRow: Int = indexPath[1]
      if iRow > 0 && _activeIndex != (iRow - 1) {
        _activeIndex = iRow - 1
        if let action = _action {
          action(_activeIndex)
        }
      }
    } else {
      _isShown = true
    }

    reloadData()
    _heightConstraint.constant = contentSize.height
    layoutIfNeeded()
  }
}

@objcMembers
class SettingsListModal: UIScrollView {
  weak var popDelegate: SettingsPopupViewDelegate?
  private var marginSize: CGFloat = 14.0

  private let fontHeight: CGFloat = 17.0
  private let layoutMarginSize: CGFloat = 16.0
  private let fontHeightSmall: CGFloat = 14.0
  private let cornerRadius: CGFloat = 8.0
  private var _activeIndex: Int = 0
  private var _action: Action?

  let accentColor = UIColor(named: "AccentColor") ?? #colorLiteral(red: 0, green: 0.765, blue: 1, alpha: 1)
  let sectionTitleViewBackgroundColor = UIColor(named: "SectionTitleViewBackgroundColor") ?? #colorLiteral(red: 0.9179999828, green: 0.9179999828, blue: 0.9179999828, alpha: 1)
  let sectionDividerColor = UIColor(named: "SectionDividerColor") ?? #colorLiteral(red: 0.585, green: 0.585, blue: 0.585, alpha: 1)
  let controlBackgroundColor = UIColor(named: "ControlBackgroundColor") ?? #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
  let headerTextColor = UIColor(named: "HeaderTextColor") ?? #colorLiteral(red: 0.227, green: 0.227, blue: 0.235, alpha: 1)
  let darkTextColor = UIColor(named: "DarkTextColor") ?? #colorLiteral(red: 0.314, green: 0.314, blue: 0.325, alpha: 1)
  let lightTextColor = UIColor(named: "LightTextColor") ?? #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)

  private var contentView: UIView?
  // Objects that correspond to dynamic option settings
  private var depthResolutionSegmentedControl: UISegmentedControl?
  private var highResolutionColorSwitch: UISwitch?
  private var irAutoExposureSwitch: UISwitch?
  private var irManualExposureSlider: UISlider?
  private var irGainSegmentedControl: UISegmentedControl?

  private var streamPresetDropControl: DropDownView?
  private var slamOptionSegmentedControl: UISegmentedControl?
  private var trackerTypeSegmentedControl: UISegmentedControl?

  private var highResolutionMeshSwitch: UISwitch?
  private var improvedMapperSwitch: UISwitch?

  private var irExposureMaximumValueLabel: UILabel?
  private var irExposureMinimumValueLabel: UILabel?

  init(settingsPopupViewDelegate delegate: SettingsPopupViewDelegate?) {
    super.init(frame: CGRect.zero)

    popDelegate = delegate

    setupUIComponentsAndLayout()

    // Default option states
    depthResolutionSegmentedControl?.selectedSegmentIndex = 1

    highResolutionColorSwitch?.isOn = true

    irAutoExposureSwitch?.isOn = true

    irManualExposureSlider?.value = 14

    irManualExposureSlider?.isEnabled = !(irAutoExposureSwitch?.isOn ?? false)

    irGainSegmentedControl?.selectedSegmentIndex = 2

    streamPresetDropControl?.selectedIndex = 0

    slamOptionSegmentedControl?.selectedSegmentIndex = 0

    trackerTypeSegmentedControl?.selectedSegmentIndex = 0

    highResolutionMeshSwitch?.isOn = true

    improvedMapperSwitch?.isOn = true

    addTouchResponders()

    // NOTE: sreamingSettingsDidChange should call streamingPropertiesDidChange
    streamingOptionsDidChange(self)
    streamingOptionsDidChange(self)
    trackerSettingsDidChange(self)
    mapperSettingsDidChange(self)
  }

  func createHorizontalRule(_ height: CGFloat) -> UIView {
    // NOTE: You still need to add a width == superview.width constraint
    // You may also want to change the background color
    let horizontalRule = UIView()
    horizontalRule.translatesAutoresizingMaskIntoConstraints = false
    horizontalRule.backgroundColor = UIColor.darkGray

    horizontalRule.addConstraint(NSLayoutConstraint(item: horizontalRule, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: height))
    return horizontalRule
  }

  func depthIndexChanged(index: Int) {
    streamingOptionsDidChange(self)
  }

  func setupUIComponentsAndLayout() {
    // Attributes that apply to the whole content view
    backgroundColor = UIColor.white
    translatesAutoresizingMaskIntoConstraints = false
    clipsToBounds = true
    layer.cornerRadius = cornerRadius

    contentView = UIView()
    contentView?.translatesAutoresizingMaskIntoConstraints = false
    contentView?.clipsToBounds = true
    contentView?.layoutMargins = UIEdgeInsets(top: layoutMarginSize, left: layoutMarginSize, bottom: layoutMarginSize, right: layoutMarginSize)
    if let contentView = contentView {
      addSubview(contentView)
    }

    if let contentView = contentView {
      addConstraints([
        NSLayoutConstraint(item: contentView, attribute: .top, relatedBy: .equal, toItem: contentView.superview, attribute: .top, multiplier: 1.0, constant: 0.0),
        // Pin left of _contentView to its superview
        NSLayoutConstraint(item: contentView, attribute: .left, relatedBy: .equal, toItem: contentView.superview, attribute: .left, multiplier: 1.0, constant: 0.0),
        // Pin bottom of _contentView to its superview
        NSLayoutConstraint(item: contentView, attribute: .bottom, relatedBy: .equal, toItem: contentView.superview, attribute: .bottom, multiplier: 1.0, constant: 0.0),
        // Pin right of _contentView to its superview
        NSLayoutConstraint(item: contentView, attribute: .right, relatedBy: .equal, toItem: contentView.superview, attribute: .right, multiplier: 1.0, constant: 0.0),
        // Make width of _contentView equal to its superview
        NSLayoutConstraint(item: contentView, attribute: .width, relatedBy: .equal, toItem: contentView.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
      ])
    }

    let streamingSettingsLabel = UILabel()
    streamingSettingsLabel.translatesAutoresizingMaskIntoConstraints = false
    streamingSettingsLabel.font = UIFont.systemFont(ofSize: fontHeightSmall, weight: .medium)
    streamingSettingsLabel.textColor = darkTextColor
    streamingSettingsLabel.text = "STREAMING SETTINGS"
    contentView?.addSubview(streamingSettingsLabel)

    streamingSettingsLabel.superview?.addConstraints([
      NSLayoutConstraint(item: streamingSettingsLabel, attribute: .top, relatedBy: .equal, toItem: streamingSettingsLabel.superview, attribute: .topMargin, multiplier: 1.0, constant: 0.0),
      // Pin left of streaming settings label to superview with offset
      NSLayoutConstraint(item: streamingSettingsLabel, attribute: .leading, relatedBy: .equal, toItem: streamingSettingsLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
    ])

    let hr1 = createHorizontalRule(1.0)
    hr1.backgroundColor = sectionDividerColor
    contentView?.addSubview(hr1)

    hr1.superview?.addConstraints([
      NSLayoutConstraint(item: hr1, attribute: .top, relatedBy: .equal, toItem: streamingSettingsLabel, attribute: .bottom, multiplier: 1.0, constant: 9.0),
      // Pin leading edge of hr1 to superview
      NSLayoutConstraint(item: hr1, attribute: .centerX, relatedBy: .equal, toItem: hr1.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
      // Set width of hr1 to equal that of the superview
      NSLayoutConstraint(item: hr1, attribute: .width, relatedBy: .equal, toItem: hr1.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
    ])

    let streamingSettingsView = UIView()
    streamingSettingsView.translatesAutoresizingMaskIntoConstraints = false
    streamingSettingsView.backgroundColor = sectionTitleViewBackgroundColor
    streamingSettingsView.layoutMargins = UIEdgeInsets(top: layoutMarginSize, left: layoutMarginSize, bottom: layoutMarginSize, right: layoutMarginSize)
    contentView?.addSubview(streamingSettingsView)

    streamingSettingsView.superview?.addConstraints([
      NSLayoutConstraint(item: streamingSettingsView, attribute: .top, relatedBy: .equal, toItem: hr1, attribute: .bottom, multiplier: 1.0, constant: 0.0),
      // Pin leading edge of streaming settings view to superview
      NSLayoutConstraint(item: streamingSettingsView, attribute: .leading, relatedBy: .equal, toItem: streamingSettingsView.superview, attribute: .leading, multiplier: 1.0, constant: 0.0),
      // Pin trailing edge of streaming settings view to superview
      NSLayoutConstraint(item: streamingSettingsView, attribute: .width, relatedBy: .equal, toItem: streamingSettingsView.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
    ])

    // Streaming settings
    do {
      let depthResolutionLabel = UILabel()
      depthResolutionLabel.translatesAutoresizingMaskIntoConstraints = false
      depthResolutionLabel.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      depthResolutionLabel.textColor = headerTextColor
      depthResolutionLabel.text = "Depth Resolution"
      streamingSettingsView.addSubview(depthResolutionLabel)

      depthResolutionLabel.superview?.addConstraints([
        NSLayoutConstraint(item: depthResolutionLabel, attribute: .top, relatedBy: .equal, toItem: depthResolutionLabel.superview, attribute: .topMargin, multiplier: 1.0, constant: 0.0),
        // Pin leading edge of high-res color label to superview with offset
        NSLayoutConstraint(item: depthResolutionLabel, attribute: .leading, relatedBy: .equal, toItem: depthResolutionLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
      ])

      depthResolutionSegmentedControl = UISegmentedControl(items: ["QVGA", "VGA", "Full"])
      depthResolutionSegmentedControl?.translatesAutoresizingMaskIntoConstraints = false
      depthResolutionSegmentedControl?.clipsToBounds = true
      depthResolutionSegmentedControl?.isUserInteractionEnabled = true
      depthResolutionSegmentedControl?.backgroundColor = controlBackgroundColor
      depthResolutionSegmentedControl?.selectedSegmentTintColor = accentColor

      depthResolutionSegmentedControl?.setTitleTextAttributes([
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontHeight, weight: .medium),
        NSAttributedString.Key.foregroundColor: darkTextColor
      ], for: .normal)
      depthResolutionSegmentedControl?.setTitleTextAttributes([
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontHeight, weight: .medium),
        NSAttributedString.Key.foregroundColor: UIColor.white
      ], for: .selected)

      if let depthResolutionSegmentedControl = depthResolutionSegmentedControl {
        streamingSettingsView.addSubview(depthResolutionSegmentedControl)
        depthResolutionSegmentedControl.superview?.addConstraints([
          NSLayoutConstraint(item: depthResolutionSegmentedControl, attribute: .top, relatedBy: .equal, toItem: depthResolutionLabel, attribute: .bottom, multiplier: 1.0, constant: marginSize),
          // Pin leading edge of IR gain control to leading margin of superview
          NSLayoutConstraint(item: depthResolutionSegmentedControl, attribute: .leading, relatedBy: .equal, toItem: depthResolutionSegmentedControl.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0),
          // Pin trailing edge of IR gain control to trailing margin of superview
          NSLayoutConstraint(item: depthResolutionSegmentedControl, attribute: .trailing, relatedBy: .equal, toItem: depthResolutionSegmentedControl.superview, attribute: .trailingMargin, multiplier: 1.0, constant: 0.0)
        ])
      }

      let streamingHR1 = createHorizontalRule(1.0)
      streamingHR1.backgroundColor = sectionDividerColor
      streamingSettingsView.addSubview(streamingHR1)

      streamingHR1.superview?.addConstraints([
        NSLayoutConstraint(item: streamingHR1, attribute: .top, relatedBy: .equal, toItem: depthResolutionSegmentedControl, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of hr1 to superview
        NSLayoutConstraint(item: streamingHR1, attribute: .centerX, relatedBy: .equal, toItem: streamingHR1.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
        // Set width of hr1 to equal that of 90% of the superview
        NSLayoutConstraint(item: streamingHR1, attribute: .width, relatedBy: .equal, toItem: streamingHR1.superview, attribute: .width, multiplier: 0.9, constant: 0.0)
      ])

      let highResolutionColorLabel = UILabel()
      highResolutionColorLabel.translatesAutoresizingMaskIntoConstraints = false
      highResolutionColorLabel.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      highResolutionColorLabel.textColor = headerTextColor
      highResolutionColorLabel.text = "High Resolution Color"
      streamingSettingsView.addSubview(highResolutionColorLabel)

      highResolutionColorLabel.superview?.addConstraints([
        NSLayoutConstraint(item: highResolutionColorLabel, attribute: .top, relatedBy: .equal, toItem: streamingHR1, attribute: .topMargin, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of high-res color label to superview with offset
        NSLayoutConstraint(item: highResolutionColorLabel, attribute: .leading, relatedBy: .equal, toItem: highResolutionColorLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
      ])

      highResolutionColorSwitch = UISwitch()
      highResolutionColorSwitch?.translatesAutoresizingMaskIntoConstraints = false
      highResolutionColorSwitch?.isUserInteractionEnabled = true
      highResolutionColorSwitch?.onTintColor = accentColor
      if let highResolutionColorSwitch = highResolutionColorSwitch {
        streamingSettingsView.addSubview(highResolutionColorSwitch)

        highResolutionColorSwitch.superview?.addConstraints([
          NSLayoutConstraint(item: highResolutionColorSwitch, attribute: .centerY, relatedBy: .equal, toItem: highResolutionColorLabel, attribute: .centerY, multiplier: 1.0, constant: 0.0),
          // Pin trailing edge of switch to trailing edge of superview
          NSLayoutConstraint(item: highResolutionColorSwitch, attribute: .trailing, relatedBy: .equal, toItem: highResolutionColorSwitch.superview, attribute: .trailingMargin, multiplier: 1.0, constant: 0.0)
        ])
      }

      let streamingHR1d = createHorizontalRule(1.0)
      streamingHR1d.backgroundColor = sectionDividerColor
      streamingSettingsView.addSubview(streamingHR1d)

      streamingHR1d.superview?.addConstraints([
        NSLayoutConstraint(item: streamingHR1d, attribute: .top, relatedBy: .equal, toItem: highResolutionColorSwitch, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of hr1 to superview
        NSLayoutConstraint(item: streamingHR1d, attribute: .centerX, relatedBy: .equal, toItem: streamingHR1d.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
        // Set width of hr1 to equal that of 90% of the superview
        NSLayoutConstraint(item: streamingHR1d, attribute: .width, relatedBy: .equal, toItem: streamingHR1d.superview, attribute: .width, multiplier: 0.9, constant: 0.0)
      ])

      let irAutoExposureLabel = UILabel()
      irAutoExposureLabel.translatesAutoresizingMaskIntoConstraints = false
      irAutoExposureLabel.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      irAutoExposureLabel.textColor = headerTextColor
      irAutoExposureLabel.text = "IR Auto Exposure (Mark II only)"
      streamingSettingsView.addSubview(irAutoExposureLabel)

      irAutoExposureLabel.superview?.addConstraints([
        NSLayoutConstraint(item: irAutoExposureLabel, attribute: .top, relatedBy: .equal, toItem: streamingHR1d, attribute: .bottom, multiplier: 1.0, constant: 16.0),
        // Pin leading edge of IR auto exposure label to its superview's leading margin
        NSLayoutConstraint(item: irAutoExposureLabel, attribute: .leading, relatedBy: .equal, toItem: irAutoExposureLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
      ])

      irAutoExposureSwitch = UISwitch()
      irAutoExposureSwitch?.translatesAutoresizingMaskIntoConstraints = false
      irAutoExposureSwitch?.isUserInteractionEnabled = true
      irAutoExposureSwitch?.onTintColor = accentColor
      if let irAutoExposureSwitch = irAutoExposureSwitch {
        streamingSettingsView.addSubview(irAutoExposureSwitch)
        irAutoExposureSwitch.superview?.addConstraints([
          NSLayoutConstraint(item: irAutoExposureSwitch, attribute: .centerY, relatedBy: .equal, toItem: irAutoExposureLabel, attribute: .centerY, multiplier: 1.0, constant: 0.0),
          // Pin trailing edge of switch to trailing edge of superview
          NSLayoutConstraint(item: irAutoExposureSwitch, attribute: .trailing, relatedBy: .equal, toItem: irAutoExposureSwitch.superview, attribute: .trailingMargin, multiplier: 1.0, constant: 0.0)
        ])
      }

      let streamingHR2 = createHorizontalRule(1.0)
      streamingHR2.backgroundColor = sectionDividerColor
      streamingSettingsView.addSubview(streamingHR2)

      streamingHR2.superview?.addConstraints([
        NSLayoutConstraint(item: streamingHR2, attribute: .top, relatedBy: .equal, toItem: irAutoExposureSwitch, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of streamingHR2 to superview
        NSLayoutConstraint(item: streamingHR2, attribute: .centerX, relatedBy: .equal, toItem: streamingHR2.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
        // Set width of streamingHR2 to equal that of 90% of the superview
        NSLayoutConstraint(item: streamingHR2, attribute: .width, relatedBy: .equal, toItem: streamingHR2.superview, attribute: .width, multiplier: 0.9, constant: 0.0)
      ])

      let irManualExposureLabel = UILabel()
      irManualExposureLabel.translatesAutoresizingMaskIntoConstraints = false
      irManualExposureLabel.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      irManualExposureLabel.textColor = headerTextColor
      irManualExposureLabel.text = "IR Manual Exposure (Mark II only)"
      streamingSettingsView.addSubview(irManualExposureLabel)

      irManualExposureLabel.superview?.addConstraints([
        NSLayoutConstraint(item: irManualExposureLabel, attribute: .top, relatedBy: .equal, toItem: streamingHR2, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of IR manual exposure label to its superview's leading margin
        NSLayoutConstraint(item: irManualExposureLabel, attribute: .leading, relatedBy: .equal, toItem: irManualExposureLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
      ])

      irManualExposureSlider = UISlider()
      irManualExposureSlider?.translatesAutoresizingMaskIntoConstraints = false
      irManualExposureSlider?.tintColor = accentColor
      irManualExposureSlider?.minimumValue = 1.0
      irManualExposureSlider?.maximumValue = 16.0
      irManualExposureSlider?.isUserInteractionEnabled = true
      if let irManualExposureSlider = irManualExposureSlider {
        streamingSettingsView.addSubview(irManualExposureSlider)
      }

      irExposureMinimumValueLabel = UILabel()
      irExposureMinimumValueLabel?.translatesAutoresizingMaskIntoConstraints = false
      irExposureMinimumValueLabel?.font = UIFont.systemFont(ofSize: fontHeightSmall, weight: .regular)
      irExposureMinimumValueLabel?.textColor = sectionDividerColor
      irExposureMinimumValueLabel?.text = "1 ms"
      if let irExposureMinimumValueLabel = irExposureMinimumValueLabel {
        streamingSettingsView.addSubview(irExposureMinimumValueLabel)
      }

      irExposureMaximumValueLabel = UILabel()
      irExposureMaximumValueLabel?.translatesAutoresizingMaskIntoConstraints = false
      irExposureMaximumValueLabel?.font = UIFont.systemFont(ofSize: fontHeightSmall, weight: .regular)
      irExposureMaximumValueLabel?.textColor = sectionDividerColor
      irExposureMaximumValueLabel?.text = "16 ms"
      if let irExposureMaximumValueLabel = irExposureMaximumValueLabel {
        streamingSettingsView.addSubview(irExposureMaximumValueLabel)
      }

      if let irManualExposureSlider = irManualExposureSlider,
         let irExposureMinimumValueLabel = irExposureMinimumValueLabel,
         let irExposureMaximumValueLabel = irExposureMaximumValueLabel {
        irManualExposureSlider.superview?.addConstraints([
          NSLayoutConstraint(item: irManualExposureSlider, attribute: .centerY, relatedBy: .equal, toItem: irManualExposureLabel, attribute: .bottom, multiplier: 1.0, constant: 2*marginSize),
          // Pin centre Y of IR exposure min label to centre Y of IR exposure slider
          NSLayoutConstraint(item: irExposureMinimumValueLabel, attribute: .centerY, relatedBy: .equal, toItem: irManualExposureSlider, attribute: .centerY, multiplier: 1.0, constant: 0.0),
          // Pin left edge of IR exposure min label to left margin of superview
          NSLayoutConstraint(item: irExposureMinimumValueLabel, attribute: .left, relatedBy: .equal, toItem: irExposureMinimumValueLabel.superview, attribute: .leftMargin, multiplier: 1.0, constant: 0.0),
          // Pin right edge of IR exposure min label to left edge of IR exposure slider with offset
          NSLayoutConstraint(item: irManualExposureSlider, attribute: .left, relatedBy: .equal, toItem: irExposureMinimumValueLabel, attribute: .right, multiplier: 1.0, constant: 2*marginSize),
          // Pin centre Y of IR exposure max label to centre Y of IR exposure slider
          NSLayoutConstraint(item: irExposureMaximumValueLabel, attribute: .centerY, relatedBy: .equal, toItem: irManualExposureSlider, attribute: .centerY, multiplier: 1.0, constant: 0.0),
          // Pin right edge of IR exposure max label to right margin of superview
          NSLayoutConstraint(item: irExposureMaximumValueLabel, attribute: .right, relatedBy: .equal, toItem: irExposureMaximumValueLabel.superview, attribute: .rightMargin, multiplier: 1.0, constant: 0.0),
          // Pin left edge of IR max exposure to right edge of IR exposure slider with offset
          NSLayoutConstraint(item: irExposureMaximumValueLabel, attribute: .left, relatedBy: .equal, toItem: irManualExposureSlider, attribute: .right, multiplier: 1.0, constant: 2*marginSize)
        ])
      }

      let streamingHR3 = createHorizontalRule(1.0)
      streamingHR3.backgroundColor = sectionDividerColor
      streamingSettingsView.addSubview(streamingHR3)

      streamingHR3.superview?.addConstraints([
        NSLayoutConstraint(item: streamingHR3, attribute: .top, relatedBy: .equal, toItem: irManualExposureSlider, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of HR2 to superview
        NSLayoutConstraint(item: streamingHR3, attribute: .centerX, relatedBy: .equal, toItem: streamingHR3.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
        // Set width of HR2 to equal that of 90% of the superview
        NSLayoutConstraint(item: streamingHR3, attribute: .width, relatedBy: .equal, toItem: streamingHR3.superview, attribute: .width, multiplier: 0.9, constant: 0.0)
      ])

      let irGainLabel = UILabel()
      irGainLabel.translatesAutoresizingMaskIntoConstraints = false
      irGainLabel.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      irGainLabel.textColor = headerTextColor
      irGainLabel.text = "IR Analog Gain (Mark II only)"
      streamingSettingsView.addSubview(irGainLabel)

      irGainLabel.superview?.addConstraints([
        NSLayoutConstraint(item: irGainLabel, attribute: .top, relatedBy: .equal, toItem: streamingHR3, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of IR gain label to its superview's leading margin
        NSLayoutConstraint(item: irGainLabel, attribute: .leading, relatedBy: .equal, toItem: irGainLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
      ])

      irGainSegmentedControl = UISegmentedControl(items: ["1x", "2x", "4x", "8x"])
      irGainSegmentedControl?.translatesAutoresizingMaskIntoConstraints = false
      irGainSegmentedControl?.clipsToBounds = true
      irGainSegmentedControl?.isUserInteractionEnabled = true
      irGainSegmentedControl?.backgroundColor = controlBackgroundColor
      irGainSegmentedControl?.selectedSegmentTintColor = accentColor
      irGainSegmentedControl?.setTitleTextAttributes([
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontHeight, weight: .medium),
        NSAttributedString.Key.foregroundColor: darkTextColor
      ], for: .normal)
      irGainSegmentedControl?.setTitleTextAttributes([
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontHeight, weight: .medium),
        NSAttributedString.Key.foregroundColor: UIColor.white
      ], for: .selected)

      if let irGainSegmentedControl = irGainSegmentedControl {
        streamingSettingsView.addSubview(irGainSegmentedControl)
        irGainSegmentedControl.superview?.addConstraints([
          NSLayoutConstraint(item: irGainSegmentedControl, attribute: .top, relatedBy: .equal, toItem: irGainLabel, attribute: .bottom, multiplier: 1.0, constant: marginSize),
          // Pin leading edge of IR gain control to leading margin of superview
          NSLayoutConstraint(item: irGainSegmentedControl, attribute: .leading, relatedBy: .equal, toItem: irGainSegmentedControl.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0),
          // Pin trailing edge of IR gain control to trailing margin of superview
          NSLayoutConstraint(item: irGainSegmentedControl, attribute: .trailing, relatedBy: .equal, toItem: irGainSegmentedControl.superview, attribute: .trailingMargin, multiplier: 1.0, constant: 0.0)
        ])
      }

      let streamingHR4 = createHorizontalRule(1.0)
      streamingHR4.backgroundColor = sectionDividerColor
      streamingSettingsView.addSubview(streamingHR4)

      streamingHR4.superview?.addConstraints([
        NSLayoutConstraint(item: streamingHR4, attribute: .top, relatedBy: .equal, toItem: irGainSegmentedControl, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of HR3 to superview
        NSLayoutConstraint(item: streamingHR4, attribute: .centerX, relatedBy: .equal, toItem: streamingHR4.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
        // Set width of HR3 to equal that of 90% of the superview
        NSLayoutConstraint(item: streamingHR4, attribute: .width, relatedBy: .equal, toItem: streamingHR4.superview, attribute: .width, multiplier: 0.9, constant: 0.0)
      ])

      let streamPresetLabel = UILabel()
      streamPresetLabel.translatesAutoresizingMaskIntoConstraints = false
      streamPresetLabel.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      streamPresetLabel.textColor = headerTextColor
      streamPresetLabel.text = "Depth Stream Preset (Mark II only)"
      streamingSettingsView.addSubview(streamPresetLabel)

      streamPresetLabel.superview?.addConstraints([
        NSLayoutConstraint(item: streamPresetLabel, attribute: .top, relatedBy: .equal, toItem: streamingHR4, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of depth stream preset label to its superview's leading margin
        NSLayoutConstraint(item: streamPresetLabel, attribute: .leading, relatedBy: .equal, toItem: streamPresetLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
      ])
      streamPresetDropControl = DropDownView(options: ["Default", "Body Scanning", "Outdoor", "Room Scanning", "Close Range", "Hybrid Mode", "Dark Object Scanning", "Medium Range"], activeIndex: 0)

      streamPresetDropControl?.layer.cornerRadius = cornerRadius
      streamPresetDropControl?.translatesAutoresizingMaskIntoConstraints = false
      streamPresetDropControl?.isUserInteractionEnabled = true

      if let streamPresetDropControl = streamPresetDropControl {
        streamingSettingsView.addSubview(streamPresetDropControl)
        streamPresetDropControl.superview?.addConstraints([
          NSLayoutConstraint(item: streamPresetDropControl, attribute: .top, relatedBy: .equal, toItem: streamPresetLabel, attribute: .bottom, multiplier: 1.0, constant: marginSize),
          // Pin leading edge of IR gain control to leading margin of superview
          NSLayoutConstraint(item: streamPresetDropControl, attribute: .leading, relatedBy: .equal, toItem: streamPresetDropControl.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0),
          // Pin trailing edge of IR gain control to trailing margin of superview
          NSLayoutConstraint(item: streamPresetDropControl, attribute: .trailing, relatedBy: .equal, toItem: streamPresetDropControl.superview, attribute: .trailingMargin, multiplier: 1.0, constant: 0.0),
          // Pin bottom edge of stream preset control to bottom margin of superview
          NSLayoutConstraint(item: streamPresetDropControl, attribute: .bottom, relatedBy: .equal, toItem: streamPresetDropControl.superview, attribute: .bottomMargin, multiplier: 1.0, constant: 0.0)
        ])
      }
    }

    let hr2 = createHorizontalRule(1.0)
    hr2.backgroundColor = sectionDividerColor
    contentView?.addSubview(hr2)

    hr2.superview?.addConstraints([
      NSLayoutConstraint(item: hr2, attribute: .top, relatedBy: .equal, toItem: streamingSettingsView, attribute: .bottom, multiplier: 1.0, constant: 0.0),
      // Pin leading edge of hr1 to superview
      NSLayoutConstraint(item: hr2, attribute: .centerX, relatedBy: .equal, toItem: hr2.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
      // Set width of hr1 to equal that of the superview
      NSLayoutConstraint(item: hr2, attribute: .width, relatedBy: .equal, toItem: hr2.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
    ])

    let trackerSettingsLabel = UILabel()
    trackerSettingsLabel.translatesAutoresizingMaskIntoConstraints = false
    trackerSettingsLabel.font = UIFont.systemFont(ofSize: fontHeightSmall, weight: .medium)
    trackerSettingsLabel.textColor = darkTextColor
    trackerSettingsLabel.text = "TRACKER SETTINGS"
    contentView?.addSubview(trackerSettingsLabel)

    trackerSettingsLabel.superview?.addConstraints([
      NSLayoutConstraint(item: trackerSettingsLabel, attribute: .top, relatedBy: .equal, toItem: hr2, attribute: .bottom, multiplier: 1.0, constant: marginSize),
      // Pin left of tracker settings label to superview with offset
      NSLayoutConstraint(item: trackerSettingsLabel, attribute: .leading, relatedBy: .equal, toItem: trackerSettingsLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
    ])

    let hr3 = createHorizontalRule(1.0)
    hr3.backgroundColor = sectionDividerColor
    contentView?.addSubview(hr3)

    hr3.superview?.addConstraints([
      NSLayoutConstraint(item: hr3, attribute: .top, relatedBy: .equal, toItem: trackerSettingsLabel, attribute: .bottom, multiplier: 1.0, constant: 9.0),
      // Pin leading edge of hr1 to superview
      NSLayoutConstraint(item: hr3, attribute: .centerX, relatedBy: .equal, toItem: hr3.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
      // Set width of hr1 to equal that of the superview
      NSLayoutConstraint(item: hr3, attribute: .width, relatedBy: .equal, toItem: hr3.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
    ])

    let trackerSettingsView = UIView()
    trackerSettingsView.translatesAutoresizingMaskIntoConstraints = false
    trackerSettingsView.backgroundColor = sectionTitleViewBackgroundColor
    trackerSettingsView.layoutMargins = UIEdgeInsets(top: layoutMarginSize, left: layoutMarginSize, bottom: layoutMarginSize, right: layoutMarginSize)
    contentView?.addSubview(trackerSettingsView)

    trackerSettingsView.superview?.addConstraints([
      NSLayoutConstraint(item: trackerSettingsView, attribute: .top, relatedBy: .equal, toItem: hr3, attribute: .bottom, multiplier: 1.0, constant: 0.0),
      // Pin leading edge of tracker settings view to superview
      NSLayoutConstraint(item: trackerSettingsView, attribute: .leading, relatedBy: .equal, toItem: trackerSettingsView.superview, attribute: .leading, multiplier: 1.0, constant: 0.0),
      // Pin trailing edge of tracker settings view to superview
      NSLayoutConstraint(item: trackerSettingsView, attribute: .width, relatedBy: .equal, toItem: trackerSettingsView.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
    ])

    // Tracker Settings
    do {
      let trackerTypeLabel = UILabel()
      trackerTypeLabel.translatesAutoresizingMaskIntoConstraints = false
      trackerTypeLabel.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      trackerTypeLabel.textColor = headerTextColor
      trackerTypeLabel.text = "Tracker Type"
      trackerSettingsView.addSubview(trackerTypeLabel)

      trackerTypeLabel.superview?.addConstraints([
        NSLayoutConstraint(item: trackerTypeLabel, attribute: .top, relatedBy: .equal, toItem: trackerTypeLabel.superview, attribute: .topMargin, multiplier: 1.0, constant: 0.0),
        // Pin leading edge of high-res color label to superview with offset
        NSLayoutConstraint(item: trackerTypeLabel, attribute: .leading, relatedBy: .equal, toItem: trackerTypeLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
      ])

      trackerTypeSegmentedControl = UISegmentedControl(items: ["Color + Depth", "Depth Only"])
      trackerTypeSegmentedControl?.translatesAutoresizingMaskIntoConstraints = false
      trackerTypeSegmentedControl?.clipsToBounds = true
      trackerTypeSegmentedControl?.isUserInteractionEnabled = true
      trackerTypeSegmentedControl?.backgroundColor = controlBackgroundColor
      trackerTypeSegmentedControl?.selectedSegmentTintColor = accentColor
      trackerTypeSegmentedControl?.setTitleTextAttributes([
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontHeight, weight: .medium),
        NSAttributedString.Key.foregroundColor: darkTextColor
      ], for: .normal)
      trackerTypeSegmentedControl?.setTitleTextAttributes([
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontHeight, weight: .medium),
        NSAttributedString.Key.foregroundColor: UIColor.white
      ], for: .selected)

      if let trackerTypeSegmentedControl = trackerTypeSegmentedControl {
        trackerSettingsView.addSubview(trackerTypeSegmentedControl)
        trackerTypeSegmentedControl.superview?.addConstraints([
          NSLayoutConstraint(item: trackerTypeSegmentedControl, attribute: .top, relatedBy: .equal, toItem: trackerTypeLabel, attribute: .bottom, multiplier: 1.0, constant: marginSize),
          // Pin leading edge of IR gain control to leading margin of superview
          NSLayoutConstraint(item: trackerTypeSegmentedControl, attribute: .leading, relatedBy: .equal, toItem: trackerTypeSegmentedControl.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0),
          // Pin trailing edge of IR gain control to trailing margin of superview
          NSLayoutConstraint(item: trackerTypeSegmentedControl, attribute: .trailing, relatedBy: .equal, toItem: trackerTypeSegmentedControl.superview, attribute: .trailingMargin, multiplier: 1.0, constant: 0.0),
          // Pin bottom edge of stream preset control to bottom margin of superview
          NSLayoutConstraint(item: trackerTypeSegmentedControl, attribute: .bottom, relatedBy: .equal, toItem: trackerTypeSegmentedControl.superview, attribute: .bottomMargin, multiplier: 1.0, constant: 0.0)
        ])
      }
    }

    let hr4 = createHorizontalRule(1.0)
    hr4.backgroundColor = sectionDividerColor
    contentView?.addSubview(hr4)

    hr4.superview?.addConstraints([
      NSLayoutConstraint(item: hr4, attribute: .top, relatedBy: .equal, toItem: trackerSettingsView, attribute: .bottom, multiplier: 1.0, constant: 0.0),
      // Pin leading edge of hr1 to superview
      NSLayoutConstraint(item: hr4, attribute: .centerX, relatedBy: .equal, toItem: hr4.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
      // Set width of hr1 to equal that of the superview
      NSLayoutConstraint(item: hr4, attribute: .width, relatedBy: .equal, toItem: hr4.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
    ])

    let mapperSettingsLabel = UILabel()
    mapperSettingsLabel.translatesAutoresizingMaskIntoConstraints = false
    mapperSettingsLabel.font = UIFont.systemFont(ofSize: fontHeightSmall, weight: .medium)
    mapperSettingsLabel.textColor = darkTextColor
    mapperSettingsLabel.text = "MAPPER SETTINGS"
    contentView?.addSubview(mapperSettingsLabel)

    mapperSettingsLabel.superview?.addConstraints([
      NSLayoutConstraint(item: mapperSettingsLabel, attribute: .top, relatedBy: .equal, toItem: hr4, attribute: .bottom, multiplier: 1.0, constant: marginSize),
      // Pin left of mapper settings label to superview with offset
      NSLayoutConstraint(item: mapperSettingsLabel, attribute: .leading, relatedBy: .equal, toItem: mapperSettingsLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
    ])

    let hr5 = createHorizontalRule(1.0)
    hr5.backgroundColor = sectionDividerColor
    contentView?.addSubview(hr5)

    hr5.superview?.addConstraints([
      NSLayoutConstraint(item: hr5, attribute: .top, relatedBy: .equal, toItem: mapperSettingsLabel, attribute: .bottom, multiplier: 1.0, constant: 9.0),
      // Pin leading edge of hr1 to superview
      NSLayoutConstraint(item: hr5, attribute: .centerX, relatedBy: .equal, toItem: hr5.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
      // Set width of hr1 to equal that of the superview
      NSLayoutConstraint(item: hr5, attribute: .width, relatedBy: .equal, toItem: hr5.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
    ])

    let mapperSettingsView = UIView()
    mapperSettingsView.translatesAutoresizingMaskIntoConstraints = false
    mapperSettingsView.backgroundColor = sectionTitleViewBackgroundColor
    mapperSettingsView.layoutMargins = UIEdgeInsets(top: layoutMarginSize, left: layoutMarginSize, bottom: layoutMarginSize, right: layoutMarginSize)
    contentView?.addSubview(mapperSettingsView)

    trackerSettingsView.superview?.addConstraints([
      NSLayoutConstraint(item: mapperSettingsView, attribute: .top, relatedBy: .equal, toItem: hr5, attribute: .bottom, multiplier: 1.0, constant: 0.0),
      // Pin leading edge of tracker settings view to superview
      NSLayoutConstraint(item: mapperSettingsView, attribute: .leading, relatedBy: .equal, toItem: mapperSettingsView.superview, attribute: .leading, multiplier: 1.0, constant: 0.0),
      // Pin trailing edge of tracker settings view to superview
      NSLayoutConstraint(item: mapperSettingsView, attribute: .width, relatedBy: .equal, toItem: mapperSettingsView.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
    ])

    // Mapper Settings
    do {
      let highResolutionMeshLabel = UILabel()
      highResolutionMeshLabel.translatesAutoresizingMaskIntoConstraints = false
      highResolutionMeshLabel.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      highResolutionMeshLabel.textColor = headerTextColor
      highResolutionMeshLabel.text = "High Resolution Mesh"
      mapperSettingsView.addSubview(highResolutionMeshLabel)

      highResolutionMeshLabel.superview?.addConstraints([
        NSLayoutConstraint(item: highResolutionMeshLabel, attribute: .top, relatedBy: .equal, toItem: highResolutionMeshLabel.superview, attribute: .topMargin, multiplier: 1.0, constant: 0.0),
        // Pin leading edge of high-res mesh label to superview with offset
        NSLayoutConstraint(item: highResolutionMeshLabel, attribute: .leading, relatedBy: .equal, toItem: highResolutionMeshLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0)
      ])

      highResolutionMeshSwitch = UISwitch()
      highResolutionMeshSwitch?.translatesAutoresizingMaskIntoConstraints = false
      highResolutionMeshSwitch?.isUserInteractionEnabled = true
      highResolutionMeshSwitch?.onTintColor = accentColor
      if let highResolutionMeshSwitch = highResolutionMeshSwitch {
        mapperSettingsView.addSubview(highResolutionMeshSwitch)
      }

      if let highResolutionMeshSwitch = highResolutionMeshSwitch {
        highResolutionMeshSwitch.superview?.addConstraints([
          NSLayoutConstraint(item: highResolutionMeshSwitch, attribute: .centerY, relatedBy: .equal, toItem: highResolutionMeshLabel, attribute: .centerY, multiplier: 1.0, constant: 0.0),
          // Pin trailing edge of switch to trailing edge of superview
          NSLayoutConstraint(item: highResolutionMeshSwitch, attribute: .trailing, relatedBy: .equal, toItem: highResolutionMeshSwitch.superview, attribute: .trailingMargin, multiplier: 1.0, constant: 0.0)
        ])
      }

      let mapperHR1 = createHorizontalRule(1.0)
      mapperHR1.backgroundColor = sectionDividerColor
      mapperSettingsView.addSubview(mapperHR1)

      mapperHR1.superview?.addConstraints([
        NSLayoutConstraint(item: mapperHR1, attribute: .top, relatedBy: .equal, toItem: highResolutionMeshLabel, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of mapperHR1 to superview
        NSLayoutConstraint(item: mapperHR1, attribute: .centerX, relatedBy: .equal, toItem: mapperHR1.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
        // Set width of mapperHR1 to equal that of 90% of the superview
        NSLayoutConstraint(item: mapperHR1, attribute: .width, relatedBy: .equal, toItem: mapperHR1.superview, attribute: .width, multiplier: 0.9, constant: 0.0)
      ])

      let improvedMapperLabel = UILabel()
      improvedMapperLabel.translatesAutoresizingMaskIntoConstraints = false
      improvedMapperLabel.font = UIFont.systemFont(ofSize: fontHeight, weight: .medium)
      improvedMapperLabel.textColor = headerTextColor
      improvedMapperLabel.text = "Improved Mapper"
      mapperSettingsView.addSubview(improvedMapperLabel)

      improvedMapperLabel.superview?.addConstraints([
        NSLayoutConstraint(item: improvedMapperLabel, attribute: .top, relatedBy: .equal, toItem: mapperHR1, attribute: .bottom, multiplier: 1.0, constant: marginSize),
        // Pin leading edge of improved mapper label to superview with offset
        NSLayoutConstraint(item: improvedMapperLabel, attribute: .leading, relatedBy: .equal, toItem: improvedMapperLabel.superview, attribute: .leadingMargin, multiplier: 1.0, constant: 0.0),
        // Pin bottom edge of improved mapper label to bottom superview margin
        NSLayoutConstraint(item: improvedMapperLabel, attribute: .bottom, relatedBy: .equal, toItem: improvedMapperLabel.superview, attribute: .bottomMargin, multiplier: 1.0, constant: 0.0)
      ])

      improvedMapperSwitch = UISwitch()
      improvedMapperSwitch?.translatesAutoresizingMaskIntoConstraints = false
      improvedMapperSwitch?.isUserInteractionEnabled = true
      improvedMapperSwitch?.onTintColor = accentColor
      if let improvedMapperSwitch = improvedMapperSwitch {
        mapperSettingsView.addSubview(improvedMapperSwitch)
      }

      if let improvedMapperSwitch = improvedMapperSwitch {
        improvedMapperSwitch.superview?.addConstraints([
          NSLayoutConstraint(item: improvedMapperSwitch, attribute: .centerY, relatedBy: .equal, toItem: improvedMapperLabel, attribute: .centerY, multiplier: 1.0, constant: 0.0),
          // Pin trailing edge of switch to trailing edge of superview
          NSLayoutConstraint(item: improvedMapperSwitch, attribute: .trailing, relatedBy: .equal, toItem: improvedMapperSwitch.superview, attribute: .trailingMargin, multiplier: 1.0, constant: 0.0)
        ])
      }
    }

    let hr6 = createHorizontalRule(1.0)
    hr6.backgroundColor = sectionDividerColor
    contentView?.addSubview(hr6)

    hr6.superview?.addConstraints([
      NSLayoutConstraint(item: hr6, attribute: .top, relatedBy: .equal, toItem: mapperSettingsView, attribute: .bottom, multiplier: 1.0, constant: 0.0),
      // Pin leading edge of hr6 to superview
      NSLayoutConstraint(item: hr6, attribute: .centerX, relatedBy: .equal, toItem: hr6.superview, attribute: .centerX, multiplier: 1.0, constant: 0.0),
      // Set width of hr6 to equal that of the superview
      NSLayoutConstraint(item: hr6, attribute: .width, relatedBy: .equal, toItem: hr6.superview, attribute: .width, multiplier: 1.0, constant: 0.0)
    ])

    contentView?.addConstraint(NSLayoutConstraint(item: hr6, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottomMargin, multiplier: 1.0, constant: 0.0))
  }

  func addTouchResponders() {
    depthResolutionSegmentedControl?.addTarget(self, action: #selector(streamingOptionsDidChange(_:)), for: .valueChanged)

    highResolutionColorSwitch?.addTarget(self, action: #selector(streamingOptionsDidChange(_:)), for: .valueChanged)

    irAutoExposureSwitch?.addTarget(self, action: #selector(streamingPropertiesDidChange(_:)), for: .valueChanged)

    irManualExposureSlider?.addTarget(self, action: #selector(streamingPropertiesDidChange(_:)), for: .valueChanged)

    irGainSegmentedControl?.addTarget(self, action: #selector(streamingPropertiesDidChange(_:)), for: .valueChanged)

    streamPresetDropControl?.onChangedTarget = { _ in self.streamingOptionsDidChange(self) }

    trackerTypeSegmentedControl?.addTarget(self, action: #selector(trackerSettingsDidChange(_:)), for: .valueChanged)

    highResolutionMeshSwitch?.addTarget(self, action: #selector(mapperSettingsDidChange(_:)), for: .valueChanged)

    improvedMapperSwitch?.addTarget(self, action: #selector(mapperSettingsDidChange(_:)), for: .valueChanged)
  }

  func streamingOptionsDidChange(_ sender: Any?) {
    if popDelegate == nil {
      return
    }

    let presetMode = STCaptureSessionPreset(rawValue: streamPresetDropControl?.selectedIndex ?? 0)!
    let depthResolution = STCaptureSessionDepthFrameResolution(rawValue: (depthResolutionSegmentedControl?.selectedSegmentIndex ?? 0) + 1)!

    popDelegate?.streamingSettingsDidChange(highResolutionColorSwitch?.isOn ?? false, depthResolution: depthResolution, depthStreamPresetMode: presetMode)

    // NOTE: Everytime we restart streaming we should re-apply the properties.
    // The exposure / gain settings that are default to a preset will get reset
    // if the STCaptureSession stream config is reset as well, so we want to re-apply
    // these every time we restart streaming for consistency's sake.
    streamingPropertiesDidChange(sender)
  }

  func streamingPropertiesDidChange(_ sender: Any?) {
    if popDelegate == nil {
      return
    }

    // Disable manual exposure if the IR AutoExposureSwitch is on
    irManualExposureSlider?.isEnabled = !(irAutoExposureSwitch?.isOn ?? false)
    irManualExposureSlider?.tintColor = irManualExposureSlider?.isEnabled ?? false ? accentColor : sectionDividerColor
    irExposureMaximumValueLabel?.textColor = irManualExposureSlider?.isEnabled ?? false ? accentColor : sectionDividerColor
    irExposureMinimumValueLabel?.textColor = irManualExposureSlider?.isEnabled ?? false ? accentColor : sectionDividerColor

    var gainMode = STCaptureSessionSensorAnalogGainMode.mode8_0
    switch irGainSegmentedControl?.selectedSegmentIndex {
    case 0:
        gainMode = STCaptureSessionSensorAnalogGainMode.mode1_0
    case 1:
        gainMode = STCaptureSessionSensorAnalogGainMode.mode2_0
    case 2:
        gainMode = STCaptureSessionSensorAnalogGainMode.mode4_0
    case 3:
        gainMode = STCaptureSessionSensorAnalogGainMode.mode8_0
    default:
        fatalError("Unknown index found on gain setting.")
    }

    popDelegate?.streamingPropertiesDidChange(irAutoExposureSwitch?.isOn ?? false, irManualExposureValue: (irManualExposureSlider?.value ?? 0.0) / 1000 /* send value in seconds */, irAnalogGainValue: gainMode)
  }

  func trackerSettingsDidChange(_ sender: Any?) {
    if popDelegate == nil {
      return
    }
    popDelegate?.trackerSettingsDidChange(trackerTypeSegmentedControl?.selectedSegmentIndex == 0)
  }

  func mapperSettingsDidChange(_ sender: Any?) {
    if popDelegate == nil {
      return
    }
    popDelegate?.mapperSettingsDidChange(highResolutionMeshSwitch?.isOn ?? false, improvedMapperEnabled: improvedMapperSwitch?.isOn ?? false)
  }

  func disableNonDynamicSettingsDuringScanning() {
    highResolutionColorSwitch?.isEnabled = false
    streamPresetDropControl?.isUserInteractionEnabled = false
    trackerTypeSegmentedControl?.isEnabled = false
    highResolutionMeshSwitch?.isEnabled = false
    improvedMapperSwitch?.isEnabled = false
  }

  func enableAllSettingsDuringCubePlacement() {
    highResolutionColorSwitch?.isEnabled = true
    irAutoExposureSwitch?.isEnabled = true
    irManualExposureSlider?.isEnabled = true
    irGainSegmentedControl?.isEnabled = true
    streamPresetDropControl?.isUserInteractionEnabled = true
    trackerTypeSegmentedControl?.isEnabled = true
    highResolutionMeshSwitch?.isEnabled = true
    improvedMapperSwitch?.isEnabled = true
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
