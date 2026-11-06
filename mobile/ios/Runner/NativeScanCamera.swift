import Flutter
import UIKit
import AVFoundation
import PhotosUI

/// System camera and Photos picker for the bottom-bar capture action.
final class NativeScanCamera: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
  private let channel: FlutterMethodChannel
  private var result: FlutterResult?
  private var token: String?
  private var controller: UIViewController?
  private var dark = true
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.findez.app/scan-camera", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self = self else { reply(nil); return }
      let data = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "present":
        guard self.result == nil else { reply(FlutterError(code: "busy", message: "Camera is already open.", details: nil)); return }
        self.result = reply; self.token = data["token"] as? String; self.dark = data["dark"] as? Bool == true
        self.start()
      case "dismiss":
        if data["token"] as? String == self.token { self.finish(nil) }
        reply(nil)
      default: reply(FlutterMethodNotImplemented)
      }
    }
  }
  private func start() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else { showLibrary(); return }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: showCamera()
    case .notDetermined:
      let active = token
      AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
        DispatchQueue.main.async {
          guard let self = self, self.result != nil, self.token == active else { return }
          if allowed { self.showCamera() } else { self.showDenied() }
        }
      }
    default: showDenied()
    }
  }
  private func present(_ view: UIViewController) {
    guard result != nil, let parent = findezTopPresenter(), !parent.isBeingDismissed else { finish(nil); return }
    controller = view
    view.overrideUserInterfaceStyle = dark ? .dark : .light
    if !(view is UIAlertController) { view.modalPresentationStyle = .fullScreen }
    parent.present(view, animated: !UIAccessibility.isReduceMotionEnabled)
  }
  private func showCamera() {
    guard result != nil else { return }
    let camera = UIImagePickerController()
    camera.sourceType = .camera; camera.cameraCaptureMode = .photo; camera.delegate = self
    camera.allowsEditing = false
    camera.accessibilityViewIsModal = true
    let overlay = ScanCameraOverlay(frame: camera.view.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.photos.addAction(UIAction { [weak self, weak camera, weak overlay] _ in
      guard let self = self else { return }
      overlay?.photos.isEnabled = false
      camera?.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) {
        self.controller = nil; self.showLibrary()
      }
    }, for: .touchUpInside)
    camera.cameraOverlayView = overlay
    present(camera)
  }
  private func showLibrary() {
    guard result != nil else { return }
    var config = PHPickerConfiguration(); config.filter = .images; config.selectionLimit = 1
    let picker = PHPickerViewController(configuration: config); picker.delegate = self
    present(picker)
  }
  private func showDenied() {
    let alert = UIAlertController(title: "Allow camera access", message: "Enable Camera for FindEZ in Settings, or choose a photo from your library.", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Photos", style: .default) { [weak self] _ in
      guard let self = self else { return }
      self.controller?.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) {
        self.controller = nil; self.showLibrary()
      }
    })
    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { [weak self] _ in
      self?.finish(nil)
      if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.finish(nil) })
    present(alert)
  }
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { finish(nil) }
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    guard let image = info[.originalImage] as? UIImage else { finish(FlutterError(code: "photo", message: "Could not read this photo.", details: nil)); return }
    encode(image)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    guard let provider = results.first?.itemProvider else {
      if UIImagePickerController.isSourceTypeAvailable(.camera) && AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
        picker.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { [weak self] in self?.controller = nil; self?.showCamera() }
      } else { finish(nil) }
      return
    }
    let active = token
    guard provider.canLoadObject(ofClass: UIImage.self) else { finish(FlutterError(code: "photo", message: "Choose a supported photo.", details: nil)); return }
    provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
      DispatchQueue.main.async {
        guard let self = self, self.result != nil, self.token == active else { return }
        guard let image = object as? UIImage, error == nil else { self.finish(FlutterError(code: "photo", message: "Could not read this photo. Try downloading it from iCloud first.", details: nil)); return }
        self.encode(image)
      }
    }
  }
  private func encode(_ image: UIImage) {
    let active = token
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let ratio = min(1, 2048 / max(image.size.width, image.size.height))
      let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
      let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
      let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
      let bytes = normalized.jpegData(compressionQuality: 0.92)
      DispatchQueue.main.async {
        guard let self = self, self.result != nil, self.token == active else { return }
        guard let bytes = bytes, bytes.count <= 10 * 1024 * 1024 else { self.finish(FlutterError(code: "photo", message: "Choose a photo smaller than 10 MB.", details: nil)); return }
        self.finish(FlutterStandardTypedData(bytes: bytes))
      }
    }
  }
  private func finish(_ value: Any?) {
    let reply = result; result = nil; token = nil
    let view = controller; controller = nil
    if let view = view, view.presentingViewController != nil {
      view.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { reply?(value) }
    } else { reply?(value) }
  }
}

private final class ScanCameraOverlay: UIView {
  let photos = UIButton(type: .system)
  private let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
  override init(frame: CGRect) {
    super.init(frame: frame)
    let label = UILabel(); label.text = "Take a photo to add items"
    label.textColor = .white; label.font = .preferredFont(forTextStyle: .subheadline)
    label.adjustsFontForContentSizeCategory = true; label.numberOfLines = 0
    var style = UIButton.Configuration.plain()
    style.title = "Photos"; style.image = UIImage(systemName: "photo.on.rectangle"); style.imagePadding = 6
    style.baseForegroundColor = .white
    photos.configuration = style; photos.accessibilityLabel = "Choose from Photos"
    photos.accessibilityIdentifier = "scan.camera.photos"
    photos.setContentCompressionResistancePriority(.required, for: .horizontal)
    let row = UIStackView(arrangedSubviews: [label, photos]); row.spacing = 12; row.alignment = .center
    panel.layer.cornerRadius = 18; panel.clipsToBounds = true
    addSubview(panel); panel.contentView.addSubview(row)
    panel.translatesAutoresizingMaskIntoConstraints = false; row.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      panel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
      panel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
      panel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 70),
      row.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 16),
      row.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -10),
      row.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 8),
      row.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -8),
      photos.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let target = super.hitTest(point, with: event)
    return target === self ? nil : target
  }
}
