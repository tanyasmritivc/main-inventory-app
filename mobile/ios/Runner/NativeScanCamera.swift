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
  private var barcodes = false
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
        self.barcodes = data["barcodes"] as? Bool == true
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
    if barcodes {
      let camera = PhotoBarcodeCameraController()
      camera.onPhoto = { [weak self] image in self?.encode(image) }
      camera.onBarcode = { [weak self] code in self?.finish(["barcode": code]) }
      camera.onCancel = { [weak self] in self?.finish(nil) }
      camera.onLibrary = { [weak self, weak camera] in
        camera?.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) {
          self?.controller = nil; self?.showLibrary()
        }
      }
      camera.onFailure = { [weak self] in self?.finish(FlutterError(code: "camera", message: "Could not start the camera. Try again or choose a photo.", details: nil)) }
      present(camera)
      return
    }
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
        self.finish(self.barcodes ? ["photo": FlutterStandardTypedData(bytes: bytes)] : FlutterStandardTypedData(bytes: bytes))
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


/// One camera session captures photos and recognizes item/product codes locally.
/// A detected code requires a tap, so labels in a bulk photo never steal capture.
private final class PhotoBarcodeCameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate {
  var onPhoto: ((UIImage) -> Void)?
  var onBarcode: ((String) -> Void)?
  var onLibrary: (() -> Void)?
  var onCancel: (() -> Void)?
  var onFailure: (() -> Void)?
  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "com.findez.camera.session")
  private let photoOutput = AVCapturePhotoOutput()
  private var preview: AVCaptureVideoPreviewLayer!
  private let shutter = UIButton(type: .system)
  private let codeButton = UIButton(type: .system)
  private var code: String?
  private var finished = false
  private var ready = false
  private var visible = false
  private var lastCodeAt = Date.distantPast
  private var expiry: Timer?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    preview = AVCaptureVideoPreviewLayer(session: session)
    preview.videoGravity = .resizeAspectFill
    view.layer.addSublayer(preview)
    let cancel = UIButton(type: .system)
    cancel.setTitle("Cancel", for: .normal)
    cancel.addAction(UIAction { [weak self] _ in self?.finish { self?.onCancel?() } }, for: .touchUpInside)
    let photos = UIButton(type: .system)
    photos.setTitle("Photos", for: .normal)
    photos.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
    photos.addAction(UIAction { [weak self] _ in self?.finish { self?.onLibrary?() } }, for: .touchUpInside)
    shutter.setImage(UIImage(systemName: "circle.inset.filled", withConfiguration: UIImage.SymbolConfiguration(pointSize: 64)), for: .normal)
    shutter.accessibilityLabel = "Take photo"
    shutter.accessibilityIdentifier = "scan.camera.shutter"
    shutter.isEnabled = false
    shutter.addAction(UIAction { [weak self] _ in self?.takePhoto() }, for: .touchUpInside)
    let hint = UILabel()
    hint.text = "Photograph items or point at a barcode"
    hint.font = .preferredFont(forTextStyle: .subheadline)
    hint.adjustsFontForContentSizeCategory = true
    hint.textColor = .white; hint.numberOfLines = 0; hint.textAlignment = .center
    let controls = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    controls.layer.cornerRadius = 24; controls.clipsToBounds = true
    let row = UIStackView(arrangedSubviews: [cancel, shutter, photos])
    row.axis = .horizontal; row.distribution = .equalSpacing; row.alignment = .center; row.spacing = 12
    let stack = UIStackView(arrangedSubviews: [hint, codeButton, row])
    stack.axis = .vertical; stack.spacing = 12
    codeButton.isHidden = true
    codeButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
    codeButton.titleLabel?.numberOfLines = 2
    codeButton.accessibilityIdentifier = "scan.camera.barcode"
    codeButton.addAction(UIAction { [weak self] _ in
      guard let self = self, let code = self.code, Date().timeIntervalSince(self.lastCodeAt) < 2 else { return }
      self.finish { self.onBarcode?(code) }
    }, for: .touchUpInside)
    for button in [cancel, shutter, photos, codeButton] {
      button.tintColor = .white
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }
    view.addSubview(controls); controls.contentView.addSubview(stack)
    controls.translatesAutoresizingMaskIntoConstraints = false; stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      controls.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
      controls.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
      stack.leadingAnchor.constraint(equalTo: controls.contentView.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: controls.contentView.trailingAnchor, constant: -16),
      stack.topAnchor.constraint(equalTo: controls.contentView.topAnchor, constant: 16),
      stack.bottomAnchor.constraint(equalTo: controls.contentView.bottomAnchor, constant: -16),
      shutter.widthAnchor.constraint(equalToConstant: 72), shutter.heightAnchor.constraint(equalToConstant: 72),
    ])
    NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: UIApplication.didBecomeActiveNotification, object: nil)
    queue.async { [weak self] in self?.configure() }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews(); preview.frame = view.bounds
    updateOrientation()
  }
  private func updateOrientation() {
    let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
    let video: AVCaptureVideoOrientation
    switch orientation {
    case .landscapeLeft: video = .landscapeLeft
    case .landscapeRight: video = .landscapeRight
    case .portraitUpsideDown: video = .portraitUpsideDown
    default: video = .portrait
    }
    for connection in [preview.connection, photoOutput.connection(with: .video)].compactMap({ $0 }) {
      if connection.isVideoOrientationSupported { connection.videoOrientation = video }
    }
  }
  override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); visible = true; foreground() }
  override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); visible = false; background() }
  deinit { expiry?.invalidate(); NotificationCenter.default.removeObserver(self) }
  @objc private func background() {
    code = nil; codeButton.isHidden = true
    queue.async { [session] in session.stopRunning() }
  }
  @objc private func foreground() {
    guard visible, !finished, ready else { return }
    queue.async { [session] in if !session.isRunning { session.startRunning() } }
  }
  private func configure() {
    session.beginConfiguration(); session.sessionPreset = .photo
    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input), session.canAddOutput(photoOutput) else {
      session.commitConfiguration(); DispatchQueue.main.async { [weak self] in self?.onFailure?() }; return
    }
    session.addInput(input); session.addOutput(photoOutput)
    let metadata = AVCaptureMetadataOutput()
    if session.canAddOutput(metadata) {
      session.addOutput(metadata)
      metadata.setMetadataObjectsDelegate(self, queue: .main)
      let formats: [AVMetadataObject.ObjectType] = [.qr, .ean8, .ean13, .upce, .code128, .code39, .code93, .interleaved2of5, .itf14, .pdf417, .dataMatrix, .aztec]
      metadata.metadataObjectTypes = formats.filter { metadata.availableMetadataObjectTypes.contains($0) }
    }
    session.commitConfiguration()
    DispatchQueue.main.async { [weak self] in
      guard let self = self, !self.finished else { return }
      self.ready = true; self.updateOrientation(); self.shutter.isEnabled = true; self.foreground()
    }
  }
  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    guard !finished, shutter.isEnabled, visible else { return }
    let candidates = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }
      .filter { !($0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
      .sorted { hypot($0.bounds.midX - 0.5, $0.bounds.midY - 0.5) < hypot($1.bounds.midX - 0.5, $1.bounds.midY - 0.5) }
    guard let value = candidates.first?.stringValue, value.count <= 2048 else { return }
    code = value; lastCodeAt = Date()
    codeButton.setTitle("Barcode found. Tap to look up", for: .normal)
    codeButton.isHidden = false
    expiry?.invalidate()
    expiry = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in self?.code = nil; self?.codeButton.isHidden = true }
  }
  private func takePhoto() {
    guard ready, !finished, shutter.isEnabled else { return }
    shutter.isEnabled = false; codeButton.isHidden = true
    updateOrientation()
    photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
  }
  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, !self.finished else { return }
      guard error == nil, let bytes = photo.fileDataRepresentation(), let image = UIImage(data: bytes) else {
        self.shutter.isEnabled = true
        let alert = UIAlertController(title: "Could not take photo", message: "Please try again or choose a photo from your library.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
        return
      }
      self.finish { self.onPhoto?(image) }
    }
  }
  private func finish(_ action: () -> Void) {
    guard !finished else { return }; finished = true; expiry?.invalidate(); background(); action()
  }
}
