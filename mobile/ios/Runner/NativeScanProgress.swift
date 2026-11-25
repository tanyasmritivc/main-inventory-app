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
  let shade = CALayer()
  let sweep = CAGradientLayer()
  var running = true
  var reduced = false
  private var sweepHeight: CGFloat = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    contentMode = .scaleAspectFill
    clipsToBounds = true
    layer.cornerRadius = 28
    layer.cornerCurve = .continuous
    shade.backgroundColor = UIColor.black.cgColor
    shade.opacity = 0.28
    layer.addSublayer(shade)
    sweep.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.12).cgColor,
                    UIColor.white.withAlphaComponent(0.90).cgColor]
    sweep.locations = [0, 0.98, 1]
    layer.addSublayer(sweep)
    accessibilityLabel = "Photo being reviewed"
    isAccessibilityElement = true
    for name in [UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification,
                 UIAccessibility.reduceMotionStatusDidChangeNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: name, object: nil)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  deinit { NotificationCenter.default.removeObserver(self) }
  override func didMoveToWindow() { super.didMoveToWindow(); refresh() }
  override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    shade.frame = bounds
    sweep.frame = CGRect(x: 0, y: -80, width: bounds.width, height: 80)
    CATransaction.commit()
    if sweepHeight != bounds.height {
      sweepHeight = bounds.height
      sweep.removeAnimation(forKey: "sweep")
    }
    refresh()
  }
  @objc func refresh(_ notification: Notification? = nil) {
    let visible = running && window != nil && image != nil && bounds.height > 0 &&
      !reduced && !UIAccessibility.isReduceMotionEnabled &&
      UIApplication.shared.applicationState == .active && notification?.name != UIApplication.willResignActiveNotification
    sweep.isHidden = !visible
    guard visible else { sweep.removeAnimation(forKey: "sweep"); return }
    guard sweep.animation(forKey: "sweep") == nil else { return }
    let animation = CABasicAnimation(keyPath: "transform.translation.y")
    animation.fromValue = 0
    animation.toValue = bounds.height + 80
    animation.duration = 2.2
    animation.repeatCount = .infinity
    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    sweep.add(animation, forKey: "sweep")
  }
}

private final class ScanSurface: UIView {
  var onLayout: (() -> Void)?
  override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
}

private final class NativeScanProgressView: NSObject, FlutterPlatformView {
  private let root = ScanSurface()
  private let scroll = UIScrollView()
  private let stack = UIStackView()
  private let photo = ScanPhotoView(frame: .zero)
  private let status = UILabel()
  private let indicator = UIActivityIndicatorView(style: .medium)
  private let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
  private let toggle = UIButton(type: .system)
  private let bar = UIProgressView(progressViewStyle: .default)
  private let list = UIStackView()
  private let note = UILabel()
  private let primary = UIButton(type: .system)
  private let again = UIButton(type: .system)
  private let channel: FlutterMethodChannel
  private let stages = ["Reading your photo", "Finding items", "Naming and counting", "Getting them ready"]
  private var stage = 0
  private var done = false
  private var failed = false
  private var expanded = false
  private var scale: CGFloat = 1
  private var items: [[String: Any]] = []
  private var shown = 0
  private var reveal: Timer?
  private var reduced: Bool { photo.reduced || UIAccessibility.isReduceMotionEnabled }
  private func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
    .systemFont(ofSize: size * scale, weight: weight)
  }

  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, args: Any?) {
    channel = FlutterMethodChannel(name: "com.findez.app/scan-progress/\(id)", binaryMessenger: messenger)
    super.init()
    root.frame = frame
    root.backgroundColor = .clear
    root.addSubview(scroll)
    scroll.frame = root.bounds
    scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    scroll.addSubview(stack)
    let guide = scroll.contentLayoutGuide
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
      stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
      stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
      stack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
    ])
    let height = photo.heightAnchor.constraint(equalToConstant: 400)
    height.isActive = true
    root.onLayout = { [weak self] in
      guard let self = self else { return }
      height.constant = min(470, max(160, self.root.bounds.height * 0.63))
    }
    stack.addArrangedSubview(photo)
    status.numberOfLines = 0
    status.accessibilityIdentifier = "findez.scan.status"
    check.contentMode = .scaleAspectFit
    check.widthAnchor.constraint(equalToConstant: 22).isActive = true
    indicator.setContentHuggingPriority(.required, for: .horizontal)
    toggle.setContentHuggingPriority(.required, for: .horizontal)
    toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
    toggle.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    toggle.accessibilityIdentifier = "findez.scan.steps"
    toggle.addTarget(self, action: #selector(toggleSteps), for: .touchUpInside)
    let row = UIStackView(arrangedSubviews: [indicator, check, status, toggle])
    row.spacing = 8
    row.alignment = .center
    stack.addArrangedSubview(row)
    bar.accessibilityIdentifier = "findez.scan.progress"
    bar.heightAnchor.constraint(equalToConstant: 3).isActive = true
    stack.addArrangedSubview(bar)
    list.axis = .vertical
    stack.addArrangedSubview(list)
    note.numberOfLines = 0
    note.textAlignment = .center
    stack.addArrangedSubview(note)
    primary.layer.cornerRadius = 26
    primary.titleLabel?.adjustsFontSizeToFitWidth = true
    primary.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
    primary.addTarget(self, action: #selector(primaryAction), for: .touchUpInside)
    again.setTitle("Scan another photo", for: .normal)
    again.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    again.addTarget(self, action: #selector(scanAgain), for: .touchUpInside)
    stack.addArrangedSubview(primary)
    stack.addArrangedSubview(again)
    configure(args)
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self = self else { reply(nil); return }
      switch call.method {
      case "configure": self.configure(call.arguments)
      case "photo":
        if let bytes = call.arguments as? FlutterStandardTypedData {
          self.photo.image = UIImage(data: bytes.data)
          self.photo.refresh()
        }
      #if targetEnvironment(simulator)
      case "auditLayout":
        self.root.layoutIfNeeded()
        reply(["viewportHeight": self.scroll.bounds.height, "contentHeight": self.scroll.contentSize.height,
               "offset": self.scroll.contentOffset.y, "footerBottom": self.note.frame.maxY,
               "sweepActive": self.photo.sweep.animation(forKey: "sweep") == nil ? 0 : 1])
        return
      #endif
      default: reply(FlutterMethodNotImplemented); return
      }
      reply(nil)
    }
  }

  private func configure(_ args: Any?) {
    guard let model = args as? [String: Any] else { return }
    let wasDone = done
    done = model["complete"] as? Bool == true
    failed = model["failed"] as? Bool == true
    items = model["items"] as? [[String: Any]] ?? []
    scale = CGFloat(model["textScale"] as? Double ?? 1)
    root.overrideUserInterfaceStyle = model["dark"] as? Bool == true ? .dark : .light
    photo.reduced = model["reduceMotion"] as? Bool == true
    photo.running = !done && !failed
    photo.refresh()
    CATransaction.begin()
    CATransaction.setAnimationDuration(reduced ? 0 : 0.5)
    photo.shade.opacity = done ? 0.12 : 0.28
    CATransaction.commit()
    let message = (model["message"] as? String ?? "").lowercased()
    var fraction = model["progress"] as? Double ?? 0
    if message.contains("editable items") { fraction = max(fraction, 0.5) }
    if !items.isEmpty { fraction = max(fraction, 0.875) }
    if !done && !failed && fraction == 0 && model["steps"] as? [String] == ["Reading your photo..."] { stage = 0 }
    stage = max(stage, fraction >= 0.875 ? 3 : fraction >= 0.5 ? 2 : fraction >= 0.25 ? 1 : 0)
    status.font = font(19, .semibold)
    status.textColor = .label
    let count = items.count
    let unit = count == 1 ? "item" : "items"
    status.text = failed ? "Could not finish scanning" : done ? "\(count) \(unit) found" : stages[stage]
    indicator.hidesWhenStopped = false
    if photo.running && !reduced { indicator.startAnimating() } else { indicator.stopAnimating() }
    indicator.isHidden = !photo.running
    check.tintColor = .label
    check.isHidden = !done
    if done && !wasDone && !reduced {
      check.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
      UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0,
                     options: [.allowUserInteraction], animations: { self.check.transform = .identity })
    }
    toggle.isHidden = done || failed
    toggle.titleLabel?.font = font(15)
    toggle.tintColor = .secondaryLabel
    toggle.semanticContentAttribute = .forceRightToLeft
    toggle.setTitle("Steps ", for: .normal)
    bar.progressTintColor = .label
    bar.trackTintColor = .tertiarySystemFill
    bar.setProgress(done ? 1 : Float(max(0.04, fraction)), animated: !reduced)
    bar.accessibilityLabel = done ? "Scan complete" : stages[stage]
    primary.backgroundColor = .label
    primary.setTitleColor(.systemBackground, for: .normal)
    primary.titleLabel?.font = font(17, .semibold)
    primary.setTitle(failed ? "Retry" : "Review \(count) \(unit)", for: .normal)
    primary.isHidden = !(done || failed)
    again.isHidden = !done
    again.titleLabel?.font = font(15)
    again.tintColor = .secondaryLabel
    note.font = font(done ? 15 : 13)
    note.textColor = .secondaryLabel
    note.text = failed ? "Your photo is ready to retry." : "You can switch apps. FindEZ keeps scanning."
    if done {
      let names = items.prefix(3).compactMap { $0["name"] as? String }.joined(separator: ", ")
      note.text = names + (count > 3 ? " and \(count - 3) more." : "")
      note.textAlignment = .natural
    } else { note.textAlignment = .center }
    if done || failed {
      reveal?.invalidate()
      reveal = nil
    } else if shown < items.count && reveal == nil {
      shown += 1
      if shown < items.count {
        reveal = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
          guard let self = self else { timer.invalidate(); return }
          self.shown = min(self.shown + 1, self.items.count)
          if self.shown == self.items.count { timer.invalidate(); self.reveal = nil }
          self.renderList(animate: true)
        }
      }
    }
    renderList(animate: false)
  }

  private func renderList(animate: Bool) {
    list.arrangedSubviews.forEach { $0.removeFromSuperview() }
    toggle.setImage(UIImage(systemName: expanded ? "chevron.up" : "chevron.down",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11)), for: .normal)
    toggle.accessibilityValue = expanded ? "Expanded" : "Collapsed"
    list.isHidden = failed || (done && reveal == nil) || (!expanded && shown == 0)
    if list.isHidden { return }
    if expanded && !done {
      for (index, name) in stages.enumerated() {
        let title = UILabel()
        title.text = name
        title.font = font(15)
        title.textColor = index > stage ? .secondaryLabel : .label
        let marker: UIView
        if index == stage {
          let spinner = UIActivityIndicatorView(style: .medium)
          spinner.hidesWhenStopped = false
          if !reduced { spinner.startAnimating() }
          marker = spinner
        } else {
          let icon = UIImageView(image: UIImage(systemName: index < stage ? "checkmark" : "circle.fill",
              withConfiguration: UIImage.SymbolConfiguration(pointSize: index < stage ? 14 : 5)))
          icon.contentMode = .center
          icon.tintColor = title.textColor
          marker = icon
        }
        marker.widthAnchor.constraint(equalToConstant: 20).isActive = true
        let row = UIStackView(arrangedSubviews: [marker, title])
        row.alignment = .center
        row.spacing = 8
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        row.isAccessibilityElement = true
        row.accessibilityLabel = name + (index < stage ? ", complete" : index == stage ? ", current" : ", pending")
        list.addArrangedSubview(row)
      }
    } else {
      for (index, item) in items.prefix(shown).suffix(3).reversed().enumerated() {
        let name = UILabel()
        name.text = item["name"] as? String
        name.font = font(16)
        let count = UILabel()
        if let n = item["quantity"] as? NSNumber { count.text = "Qty \(n)" }
        count.font = font(14)
        count.textColor = .secondaryLabel
        count.setContentCompressionResistancePriority(.required, for: .horizontal)
        let dot = UIImageView(image: UIImage(systemName: "circle.fill",
                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 8)))
        dot.tintColor = .label
        dot.contentMode = .center
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        let row = UIStackView(arrangedSubviews: [dot, name, count])
        row.alignment = .center
        row.spacing = 8
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        list.addArrangedSubview(row)
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        list.addArrangedSubview(divider)
        if index == 0 && animate {
          row.alpha = 0
          if !reduced { row.transform = CGAffineTransform(translationX: 0, y: 6) }
          UIView.animate(withDuration: 0.15) { row.alpha = 1; row.transform = .identity }
        }
      }
    }
  }
  @objc private func toggleSteps() { expanded.toggle(); renderList(animate: false) }
  @objc private func primaryAction() { channel.invokeMethod(failed ? "retry" : "review", arguments: nil) }
  @objc private func scanAgain() { channel.invokeMethod("scanAgain", arguments: nil) }
  func view() -> UIView { root }
  deinit { reveal?.invalidate(); channel.setMethodCallHandler(nil) }
}
