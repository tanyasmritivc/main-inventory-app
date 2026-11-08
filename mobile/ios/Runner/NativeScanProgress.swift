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
  override func layoutSubviews() {
    super.layoutSubviews()
    overlays.forEach { $0.removeFromSuperview() }; overlays.removeAll()
    guard let image = image, image.size.width > 0, image.size.height > 0 else { return }
    let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let photo = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
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

private final class ScanSurface: UIView {
  var onLayout: (() -> Void)?
  override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
}

private final class NativeScanProgressView: NSObject, FlutterPlatformView {
  private let root = ScanSurface()
  private let channel: FlutterMethodChannel
  private let title = UILabel()
  private let close = UIButton(type: .close)
  private let scroll = UIScrollView()
  private let stack = UIStackView()
  private let photo = ScanPhotoView()
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
    stack.addArrangedSubview(timing)
    placeholders.axis = .horizontal; placeholders.spacing = 10; placeholders.distribution = .fillEqually
    placeholders.heightAnchor.constraint(equalToConstant: 54).isActive = true
    placeholders.isAccessibilityElement = false; placeholders.accessibilityElementsHidden = true
    for _ in 0..<3 {
      let tile = UIView(); tile.layer.cornerRadius = 14; tile.backgroundColor = .tertiarySystemFill
      placeholders.addArrangedSubview(tile)
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
               "footerBottom": self.footer.frame.maxY + 24])
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
    root.overrideUserInterfaceStyle = next["dark"] as? Bool == true ? .dark : .light
    root.backgroundColor = .secondarySystemGroupedBackground
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
    timing.text = next["timing"] as? String; footer.text = next["footer"] as? String
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
    channel.invokeMethod("stop", arguments: nil)
  }
  func view() -> UIView { root }
  deinit { channel.setMethodCallHandler(nil) }
}
