import Flutter
import UIKit

/// Display-only UIKit surface. Flutter owns all requests, drafts and mutations.
final class NativeScanProgressFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeScanProgressView(frame: frame, id: viewId, messenger: messenger, args: args)
  }
}

private final class ScanPhotoView: UIImageView {
  var regions: [[String: Any]] = [] { didSet { setNeedsLayout() } }
  private var overlays: [UIView] = []
  private let photoMask = CAShapeLayer()
  private let sweep = CAGradientLayer()
  private var photoRect = CGRect.zero
  private var reduced = false
  var sweepIsActive: Bool { sweep.animation(forKey: "photo-sweep") != nil }

  override init(frame: CGRect) {
    super.init(frame: frame)
    sweep.colors = [UIColor.white.withAlphaComponent(0).cgColor,
                    UIColor.white.withAlphaComponent(0.12).cgColor,
                    UIColor.white.withAlphaComponent(0.95).cgColor,
                    UIColor.white.withAlphaComponent(0).cgColor]
    sweep.locations = [0, 0.82, 0.90, 1]
    sweep.startPoint = CGPoint(x: 0.5, y: 0); sweep.endPoint = CGPoint(x: 0.5, y: 1)
    layer.addSublayer(sweep)
    for name in [UIApplication.didBecomeActiveNotification,
                 UIApplication.willResignActiveNotification,
                 UIAccessibility.reduceMotionStatusDidChangeNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(updateSweep), name: name, object: nil)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  func configure(reduced: Bool) { self.reduced = reduced; updateSweep() }
  override func didMoveToWindow() { super.didMoveToWindow(); updateSweep() }
  @objc private func updateSweep(_ notification: Notification? = nil) {
    let active = notification?.name != UIApplication.willResignActiveNotification &&
      UIApplication.shared.applicationState == .active
    let animate = window != nil && !photoRect.isEmpty && image != nil && active &&
      !reduced && !UIAccessibility.isReduceMotionEnabled
    sweep.isHidden = !animate
    guard animate else { sweep.removeAnimation(forKey: "photo-sweep"); return }
    guard !sweepIsActive else { return }
    let motion = CABasicAnimation(keyPath: "transform.translation.y")
    motion.fromValue = -28; motion.toValue = photoRect.height
    motion.duration = 3.2; motion.autoreverses = true; motion.repeatCount = .infinity
    motion.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    sweep.add(motion, forKey: "photo-sweep")
  }
  deinit { NotificationCenter.default.removeObserver(self) }
  override func layoutSubviews() {
    super.layoutSubviews()
    overlays.forEach { $0.removeFromSuperview() }; overlays.removeAll()
    guard let image = image, image.size.width > 0, image.size.height > 0 else {
      photoRect = .zero; updateSweep(); return
    }
    let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let photo = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
    if photoRect != photo {
      photoRect = photo
      CATransaction.begin(); CATransaction.setDisableActions(true)
      sweep.frame = CGRect(x: photo.minX, y: photo.minY, width: photo.width, height: 28)
      CATransaction.commit()
      sweep.removeAnimation(forKey: "photo-sweep")
    }
    updateSweep()
    // Round the visible photo, not its surrounding aspect-fit letterbox.
    CATransaction.begin(); CATransaction.setDisableActions(true)
    photoMask.frame = bounds
    photoMask.path = UIBezierPath(roundedRect: photo,
      cornerRadius: min(18, min(photo.width, photo.height) / 2)).cgPath
    layer.mask = photoMask
    CATransaction.commit()
    for region in regions {
      guard let box = region["box"] as? [Double], box.count == 4,
            box.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }),
            box[2] > box[0], box[3] > box[1], let id = region["id"] as? Int else { continue }
      let checking = region["phase"] as? String == "checking"
      let outline = UIView(frame: CGRect(x: photo.minX + box[0] * photo.width,
        y: photo.minY + box[1] * photo.height, width: (box[2] - box[0]) * photo.width,
        height: (box[3] - box[1]) * photo.height))
      outline.isUserInteractionEnabled = false
      outline.layer.cornerRadius = 6
      outline.layer.borderWidth = checking ? 2 : 1
      outline.layer.borderColor = UIColor.white.withAlphaComponent(checking ? 1 : 0.6).cgColor
      outline.backgroundColor = checking ? UIColor.white.withAlphaComponent(0.1) : .clear
      outline.isAccessibilityElement = true
      outline.accessibilityLabel = "Object \(id + 1), \(region["status"] as? String ?? "Waiting")"
      let badge = UILabel(frame: CGRect(x: 0, y: 0, width: 24, height: 20))
      badge.text = "\(id + 1)"; badge.textAlignment = .center
      badge.font = .systemFont(ofSize: 11); badge.textColor = .black
      badge.backgroundColor = .white; badge.layer.cornerRadius = 4; badge.clipsToBounds = true
      badge.isAccessibilityElement = false
      outline.addSubview(badge); addSubview(outline); overlays.append(outline)
    }
  }
}

private final class ScanPlaceholderView: UIView {
  private let shine = CAGradientLayer()
  private var reduceMotion = false
  private let phase: Double

  init(phase: Double) {
    self.phase = phase
    super.init(frame: .zero)
    layer.cornerRadius = 14; layer.cornerCurve = .continuous
    clipsToBounds = true; backgroundColor = .tertiarySystemFill
    isUserInteractionEnabled = false; isAccessibilityElement = false
    shine.startPoint = CGPoint(x: 0, y: 1)
    shine.endPoint = CGPoint(x: 1, y: 0)
    shine.locations = [0.32, 0.43, 0.50, 0.57, 0.68]
    layer.addSublayer(shine)
    for name in [UIApplication.didBecomeActiveNotification,
                 UIApplication.willResignActiveNotification,
                 UIAccessibility.reduceMotionStatusDidChangeNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(updateMotion), name: name, object: nil)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  func configure(dark: Bool, reduced: Bool) {
    reduceMotion = reduced
    CATransaction.begin(); CATransaction.setDisableActions(true)
    backgroundColor = dark
      ? UIColor(red: 52/255, green: 43/255, blue: 49/255, alpha: 1)
      : UIColor(red: 227/255, green: 217/255, blue: 222/255, alpha: 1)
    let rose = UIColor(red: 184/255, green: 116/255, blue: 141/255, alpha: 1)
    let softRose = UIColor(red: 221/255, green: 172/255, blue: 187/255, alpha: 1)
    shine.colors = [rose.withAlphaComponent(0).cgColor,
      rose.withAlphaComponent(dark ? 0.34 : 0.20).cgColor,
      softRose.withAlphaComponent(dark ? 0.60 : 0.52).cgColor,
      rose.withAlphaComponent(dark ? 0.34 : 0.20).cgColor,
      rose.withAlphaComponent(0).cgColor]
    CATransaction.commit()
    updateMotion()
  }
  override func layoutSubviews() {
    super.layoutSubviews()
    // Extend vertically too, so the moving layer's edges stay transparent
    // throughout the diagonal sweep instead of producing a rectangular seam.
    let frame = bounds.insetBy(dx: -bounds.width, dy: -bounds.height)
    if shine.frame != frame {
      CATransaction.begin(); CATransaction.setDisableActions(true)
      shine.frame = frame
      CATransaction.commit()
      shine.removeAnimation(forKey: "scan-shine")
    }
    updateMotion()
  }
  override func didMoveToWindow() { super.didMoveToWindow(); updateMotion() }
  @objc private func updateMotion(_ notification: Notification? = nil) {
    let active = notification?.name != UIApplication.willResignActiveNotification &&
      UIApplication.shared.applicationState == .active
    let animate = window != nil && !bounds.isEmpty && active &&
      !reduceMotion && !UIAccessibility.isReduceMotionEnabled
    shine.isHidden = !animate
    guard animate else { shine.removeAnimation(forKey: "scan-shine"); return }
    guard shine.animation(forKey: "scan-shine") == nil else { return }
    let sweep = CABasicAnimation(keyPath: "transform.translation.x")
    sweep.fromValue = -bounds.width * 2; sweep.toValue = bounds.width * 2
    sweep.duration = 2.4; sweep.repeatCount = .infinity
    sweep.beginTime = shine.convertTime(CACurrentMediaTime(), from: nil) + phase
    sweep.fillMode = .backwards
    shine.add(sweep, forKey: "scan-shine")
  }
  deinit { NotificationCenter.default.removeObserver(self) }
}

private final class ScanSurface: UIView {
  var onLayout: (() -> Void)?
  var onWindowChanged: (() -> Void)?
  override func didMoveToWindow() { super.didMoveToWindow(); onWindowChanged?() }
  override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
}

private final class NativeScanProgressView: NSObject, FlutterPlatformView {
  private let root = ScanSurface()
  private let channel: FlutterMethodChannel
  private let title = UILabel()
  private let close = UIButton(type: .close)
  private let scroll = UIScrollView()
  private let stack = UIStackView()
  private let photo = ScanPhotoView(frame: .zero)
  private let status = UILabel()
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let stepsButton = UIButton(type: .system)
  private let stepsStack = UIStackView()
  private let progress = UIProgressView(progressViewStyle: .default)
  private let timing = UILabel()
  private let footer = UILabel()
  private let placeholders = UIStackView()
  private var photoHeight: NSLayoutConstraint!
  private var model: [String: Any] = [:]
  private var steps: [String] = []
  private var expanded = false
  private var stopped = false
  private var scale: CGFloat = 1
  private var tips: [String] = []
  private var tipIndex = 0
  private var tipTimer: Timer?
  private var timingHeight: NSLayoutConstraint!

  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, args: Any?) {
    channel = FlutterMethodChannel(name: "com.findez.app/scan-progress/\(id)", binaryMessenger: messenger)
    super.init()
    root.frame = frame
    root.layer.cornerRadius = 26; root.clipsToBounds = true
    title.text = "Review extraction"; title.numberOfLines = 0
    title.accessibilityTraits = .header
    close.accessibilityLabel = "Stop scanning"; close.accessibilityIdentifier = "findez.scan.stop"
    close.addTarget(self, action: #selector(stop), for: .touchUpInside)
    let header = UIStackView(arrangedSubviews: [title, close])
    header.axis = .horizontal; header.alignment = .center; header.spacing = 12
    header.translatesAutoresizingMaskIntoConstraints = false
    close.widthAnchor.constraint(equalToConstant: 44).isActive = true
    close.heightAnchor.constraint(equalToConstant: 44).isActive = true
    root.addSubview(header)
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.alwaysBounceVertical = true
    root.addSubview(scroll)
    stack.axis = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
    scroll.addSubview(stack)
    photo.contentMode = .scaleAspectFit; photo.clipsToBounds = true; photo.layer.cornerRadius = 18
    photo.backgroundColor = .secondarySystemGroupedBackground
    photo.accessibilityLabel = "Photo being reviewed"; photo.isAccessibilityElement = false
    photoHeight = photo.heightAnchor.constraint(equalToConstant: 240); photoHeight.isActive = true
    stack.addArrangedSubview(photo)
    status.numberOfLines = 0; status.accessibilityIdentifier = "findez.scan.status"
    spinner.setContentHuggingPriority(.required, for: .horizontal)
    stepsButton.setTitle("Steps", for: .normal); stepsButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
    stepsButton.semanticContentAttribute = .forceRightToLeft
    stepsButton.setContentHuggingPriority(.required, for: .horizontal)
    stepsButton.accessibilityIdentifier = "findez.scan.steps"
    stepsButton.addTarget(self, action: #selector(toggleSteps), for: .touchUpInside)
    let statusRow = UIStackView(arrangedSubviews: [spinner, status])
    statusRow.axis = .horizontal; statusRow.alignment = .top; statusRow.spacing = 8
    stack.addArrangedSubview(statusRow)
    let stepsRow = UIStackView(arrangedSubviews: [UIView(), stepsButton])
    stepsRow.axis = .horizontal
    stack.addArrangedSubview(stepsRow)
    stepsStack.axis = .vertical; stepsStack.spacing = 8; stepsStack.isHidden = true
    stack.addArrangedSubview(stepsStack)
    progress.progressTintColor = NativeAppearanceColors.primary
    progress.accessibilityIdentifier = "findez.scan.progress"
    stack.addArrangedSubview(progress)
    timing.numberOfLines = 0; footer.numberOfLines = 0
    timing.accessibilityIdentifier = "findez.scan.tip"
    timingHeight = timing.heightAnchor.constraint(equalToConstant: 40)
    timingHeight.isActive = true
    stack.addArrangedSubview(timing)
    placeholders.axis = .horizontal; placeholders.spacing = 10; placeholders.distribution = .fillEqually
    placeholders.heightAnchor.constraint(equalToConstant: 54).isActive = true
    placeholders.isAccessibilityElement = false; placeholders.accessibilityElementsHidden = true
    for index in 0..<3 {
      placeholders.addArrangedSubview(ScanPlaceholderView(phase: Double(index) * 0.12))
    }
    stack.addArrangedSubview(placeholders); stack.addArrangedSubview(footer)
    NSLayoutConstraint.activate([
      header.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
      header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
      header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
      scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
      scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
      stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
      stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
      stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
    ])
    root.onLayout = { [weak self] in
      guard let self = self else { return }
      self.photoHeight.constant = min(300, max(96, self.root.bounds.height * 0.46))
      self.sizeTip()
    }
    root.onWindowChanged = { [weak self] in self?.updateTips() }
    for name in [UIApplication.didBecomeActiveNotification,
                 UIApplication.willResignActiveNotification,
                 UIAccessibility.voiceOverStatusDidChangeNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(updateTips), name: name, object: nil)
    }
    configure(args)
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self = self else { reply(nil); return }
      switch call.method {
      #if targetEnvironment(simulator)
      case "auditLayout":
        self.root.layoutIfNeeded()
        reply(["viewportHeight": self.scroll.bounds.height,
               "contentHeight": self.scroll.contentSize.height,
               "offset": self.scroll.contentOffset.y,
               "footerBottom": self.footer.frame.maxY + 24,
               "sweepActive": self.photo.sweepIsActive ? 1 : 0,
               "tipIndex": self.tipIndex,
               "tipTimerActive": self.tipTimer == nil ? 0 : 1])
      #endif
      case "configure": self.configure(call.arguments); reply(nil)
      case "photo":
        if let data = call.arguments as? FlutterStandardTypedData {
          self.photo.image = UIImage(data: data.data); self.photo.setNeedsLayout()
        }
        reply(nil)
      default: reply(FlutterMethodNotImplemented)
      }
    }
  }

  private func configure(_ args: Any?) {
    guard let next = args as? [String: Any] else { return }
    model = next
    let dark = next["dark"] as? Bool == true
    root.overrideUserInterfaceStyle = dark ? .dark : .light
    root.backgroundColor = dark ? .secondarySystemGroupedBackground
      : UIColor(red: 238/255, green: 240/255, blue: 243/255, alpha: 1)
    photo.backgroundColor = root.backgroundColor
    for case let tile as ScanPlaceholderView in placeholders.arrangedSubviews {
      tile.configure(dark: next["dark"] as? Bool == true,
                     reduced: next["reduceMotion"] as? Bool == true)
    }
    photo.configure(reduced: next["reduceMotion"] as? Bool == true)
    scale = max(0.5, min(4, next["textScale"] as? Double ?? 1))
    title.font = .systemFont(ofSize: 17 * scale, weight: .semibold)
    status.font = .systemFont(ofSize: 15 * scale)
    timing.font = .systemFont(ofSize: 13 * scale)
    footer.font = .systemFont(ofSize: 13 * scale)
    stepsButton.titleLabel?.font = .systemFont(ofSize: 14 * scale)
    title.textColor = NativeAppearanceColors.primary; status.textColor = NativeAppearanceColors.primary
    timing.textColor = NativeAppearanceColors.secondary; footer.textColor = NativeAppearanceColors.secondary
    stepsButton.tintColor = NativeAppearanceColors.secondary
    status.text = next["message"] as? String
    let receivedTips = (next["tips"] as? [String] ?? []).filter { !$0.isEmpty }
    let nextTips = receivedTips.isEmpty ? [next["timing"] as? String ?? ""] : receivedTips
    if nextTips != tips {
      tips = nextTips; tipIndex = 0; timing.text = tips.first
    }
    footer.text = next["footer"] as? String
    sizeTip(); updateTips()
    let value = Float(next["progress"] as? Double ?? 0)
    progress.setProgress(value, animated: next["reduceMotion"] as? Bool != true)
    let stage = value >= 0.75 ? 4 : value >= 0.5 ? 3 : value >= 0.25 ? 2 : 1
    progress.accessibilityLabel = "Scan stages. Stage \(stage) of 4"
    if next["reduceMotion"] as? Bool == true { spinner.stopAnimating(); spinner.hidesWhenStopped = false }
    else { spinner.startAnimating() }
    photo.regions = next["regions"] as? [[String: Any]] ?? []
    photo.isAccessibilityElement = photo.regions.isEmpty
    let received = next["steps"] as? [String] ?? []
    if received != steps || expanded { steps = received; renderSteps() }
  }

  private func sizeTip() {
    let width = max(1, root.bounds.width - 32)
    let height = tips.map {
      ($0 as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: timing.font as Any], context: nil).height
    }.max() ?? 0
    timingHeight.constant = ceil(height) + 2
  }
  @objc private func updateTips(_ notification: Notification? = nil) {
    let active = notification?.name != UIApplication.willResignActiveNotification &&
      UIApplication.shared.applicationState == .active
    guard root.window != nil && active && !stopped && !UIAccessibility.isVoiceOverRunning && tips.count > 1 else {
      tipTimer?.invalidate(); tipTimer = nil; return
    }
    guard tipTimer == nil else { return }
    tipTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.tipIndex = (self.tipIndex + 1) % self.tips.count
      let change = { self.timing.text = self.tips[self.tipIndex] }
      if self.model["reduceMotion"] as? Bool == true || UIAccessibility.isReduceMotionEnabled {
        change()
      } else {
        UIView.transition(with: self.timing, duration: 0.25,
          options: [.transitionCrossDissolve, .allowUserInteraction], animations: change)
      }
    }
  }

  private func renderSteps() {
    stepsStack.arrangedSubviews.forEach { stepsStack.removeArrangedSubview($0); $0.removeFromSuperview() }
    for (index, text) in steps.enumerated() {
      let label = UILabel(); label.numberOfLines = 0
      label.text = (index == steps.count - 1 ? "… " : "✓ ") + text
      label.font = .systemFont(ofSize: 13 * scale); label.textColor = NativeAppearanceColors.secondary
      stepsStack.addArrangedSubview(label)
    }
    stepsStack.isHidden = !expanded
  }
  @objc private func toggleSteps() {
    expanded.toggle()
    stepsButton.setImage(UIImage(systemName: expanded ? "chevron.up" : "chevron.down"), for: .normal)
    stepsButton.accessibilityValue = expanded ? "Expanded" : "Collapsed"
    renderSteps()
  }
  @objc private func stop() {
    guard !stopped else { return }
    stopped = true; close.isEnabled = false
    tipTimer?.invalidate(); tipTimer = nil
    photo.configure(reduced: true)
    channel.invokeMethod("stop", arguments: nil)
  }
  func view() -> UIView { root }
  deinit { tipTimer?.invalidate(); NotificationCenter.default.removeObserver(self); channel.setMethodCallHandler(nil) }
}
