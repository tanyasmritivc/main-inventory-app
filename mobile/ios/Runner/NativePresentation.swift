import Flutter
import UIKit
import CoreText

/// System presentations only. Dart remains responsible for data and permissions.
final class NativePresentation: NSObject, UIAdaptivePresentationControllerDelegate {
  private let channel: FlutterMethodChannel
  private var result: FlutterResult?
  private var token: String?
  private var controller: UIViewController?
  private var model: [String: Any] = [:]
  private var busy = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.findez.app/presentation", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self = self else { reply(nil); return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "present": self.present(args, reply: reply)
      case "dismiss":
        if args["token"] as? String == self.token { self.finish(nil) }
        reply(nil)
      default: reply(FlutterMethodNotImplemented)
      }
    }
  }

  private func presenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var top = scenes.first(where: { $0.activationState == .foregroundActive })?
      .windows.first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  private func present(_ data: [String: Any], reply: @escaping FlutterResult) {
    guard result == nil, let parent = presenter(), !parent.isBeingDismissed else {
      reply(FlutterError(code: "presentation_busy", message: "Another control is open.", details: nil)); return
    }
    token = data["token"] as? String
    result = reply
    model = data
    if data["kind"] as? String == "alert" {
      let alert = makeAlert(data) { [weak self] value in self?.finish(value) }
      controller = alert
    } else {
      let list = NativeListController(page: data, owner: self)
      let navigation = UINavigationController(rootViewController: list)
      navigation.modalPresentationStyle = .pageSheet
      if let sheet = navigation.sheetPresentationController {
        sheet.detents = [.medium(), .large()]
        sheet.selectedDetentIdentifier = data["large"] as? Bool == true ? .large : .medium
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = true
      }
      controller = navigation
    }
    guard let controller = controller else { finish(nil); return }
    controller.overrideUserInterfaceStyle = data["dark"] as? Bool == true ? .dark : .light
    controller.view.tintColor = .label
    // UIAlertController owns its presentation delegate and asserts if replaced.
    // Only our sheet navigation controller needs interactive-dismiss callbacks.
    if controller is UINavigationController { controller.presentationController?.delegate = self }
    parent.present(controller, animated: (!UIAccessibility.isReduceMotionEnabled || UIAccessibility.prefersCrossFadeTransitions)) { [weak self] in
      guard let self = self, self.model["load"] as? Bool == true else { return }
      self.perform(["id": "load", "close": false])
    }
  }

  private func makeAlert(_ data: [String: Any], completion: @escaping ([String: Any]?) -> Void) -> UIAlertController {
    let alert = UIAlertController(title: data["title"] as? String,
      message: data["message"] as? String, preferredStyle: .alert)
    alert.overrideUserInterfaceStyle = controller?.overrideUserInterfaceStyle ?? (model["dark"] as? Bool == true ? .dark : .light)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(nil) })
    let save = UIAlertAction(title: data["confirmLabel"] as? String ?? "Confirm",
      style: data["destructive"] as? Bool == true ? .destructive : .default) { [weak alert] _ in
        var value: [String: Any] = ["action": "confirm"]
        if let text = alert?.textFields?.first?.text { value["text"] = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        completion(value)
      }
    if data["input"] as? Bool == true {
      alert.addTextField { field in
        field.placeholder = data["placeholder"] as? String
        field.text = data["initial"] as? String
        field.autocapitalizationType = .sentences
        field.addAction(UIAction { [weak field, weak save] _ in
          save?.isEnabled = !(field?.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }, for: .editingChanged)
      }
      save.isEnabled = !(alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
    alert.addAction(save)
    if data["destructive"] as? Bool != true { alert.preferredAction = save }
    return alert
  }

  func perform(_ row: [String: Any], value: Bool? = nil) {
    guard !busy, let id = row["id"] as? String else { return }
    if let confirmation = row["confirmation"] as? [String: Any] {
      var approved = row
      approved.removeValue(forKey: "confirmation")
      let alert = makeAlert(confirmation) { [weak self] response in
        if response != nil { self?.perform(approved, value: value) }
      }
      controller?.present(alert, animated: (!UIAccessibility.isReduceMotionEnabled || UIAccessibility.prefersCrossFadeTransitions))
      return
    }
    if row["close"] as? Bool != false {
      finish(["action": id]); return
    }
    guard let activeToken = token else { return }
    busy = true
    controller?.isModalInPresentation = true
    controller?.view.isUserInteractionEnabled = false
    var args: [String: Any] = ["token": activeToken, "id": id]
    if let value = value { args["value"] = value }
    channel.invokeMethod("action", arguments: args) { [weak self] response in
      guard let self = self, self.token == activeToken else { return }
      self.busy = false
      self.controller?.isModalInPresentation = false
      self.controller?.view.isUserInteractionEnabled = true
      guard let updated = response as? [String: Any] else {
        self.showError("Could not complete that action. Please try again."); return
      }
      self.model = updated
      if let dark = updated["dark"] as? Bool { self.controller?.overrideUserInterfaceStyle = dark ? .dark : .light }
      if let navigation = self.controller as? UINavigationController {
        for case let list as NativeListController in navigation.viewControllers {
          if let page = self.page(list.pageID, in: updated) { list.update(page) }
        }
      }
      if let error = updated["error"] as? String { self.showError(error) }
    }
  }

  private func page(_ id: String, in data: [String: Any]) -> [String: Any]? {
    if (data["pageID"] as? String ?? "root") == id { return data }
    for section in data["sections"] as? [[String: Any]] ?? [] {
      for row in section["rows"] as? [[String: Any]] ?? [] {
        if let child = row["children"] as? [String: Any], let found = page(id, in: child) { return found }
      }
    }
    return nil
  }

  private func showError(_ message: String) {
    let alert = UIAlertController(title: "Please try again", message: message, preferredStyle: .alert)
    alert.overrideUserInterfaceStyle = controller?.overrideUserInterfaceStyle ?? .unspecified
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    controller?.present(alert, animated: (!UIAccessibility.isReduceMotionEnabled || UIAccessibility.prefersCrossFadeTransitions))
  }

  func close() { if !busy { finish(nil) } }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { complete(nil) }
  private func finish(_ value: [String: Any]?) {
    guard let current = controller else { complete(value); return }
    // Complete after dismissal; Flutter can safely open the selected destination.
    current.dismiss(animated: (!UIAccessibility.isReduceMotionEnabled || UIAccessibility.prefersCrossFadeTransitions)) { [weak self] in self?.complete(value) }
  }
  private func complete(_ value: [String: Any]?) {
    let reply = result
    result = nil; token = nil; controller = nil; model = [:]; busy = false
    reply?(value)
  }
}

private final class NativeListController: UITableViewController, UISearchResultsUpdating {
  private var page: [String: Any]
  private weak var owner: NativePresentation?
  private var search: UISearchController?
  var pageID: String { page["pageID"] as? String ?? "root" }
  init(page: [String: Any], owner: NativePresentation) {
    self.page = page; self.owner = owner
    super.init(style: .insetGrouped)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 58
    tableView.keyboardDismissMode = .onDrag
    if page["search"] as? Bool == true {
      let search = UISearchController(searchResultsController: nil)
      search.obscuresBackgroundDuringPresentation = false
      search.searchResultsUpdater = self
      search.searchBar.placeholder = page["searchPlaceholder"] as? String ?? "Search"
      self.search = search
      navigationItem.searchController = search
      navigationItem.hidesSearchBarWhenScrolling = false
      definesPresentationContext = true
    }
    update(page)
  }
  func update(_ data: [String: Any]) {
    page = data; title = data["title"] as? String
    navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close,
      primaryAction: UIAction { [weak self] _ in self?.owner?.close() })
    if let primary = data["primary"] as? [String: Any] {
      navigationItem.leftBarButtonItem = UIBarButtonItem(title: primary["title"] as? String,
        image: UIImage(systemName: primary["symbol"] as? String ?? "plus"),
        primaryAction: UIAction { [weak self] _ in self?.owner?.perform(primary) })
      navigationItem.leftBarButtonItem?.accessibilityLabel = primary["title"] as? String
    }
    let label = UILabel()
    label.text = (search?.searchBar.text ?? "").isEmpty ? (data["empty"] as? String ?? "No items") : "No matching results"
    label.textColor = .secondaryLabel; label.textAlignment = .center
    label.font = appFont(15, style: .body)
    label.adjustsFontForContentSizeCategory = true
    label.numberOfLines = 0
    if data["loading"] as? Bool == true {
      let spinner = UIActivityIndicatorView(style: .medium); spinner.startAnimating()
      tableView.backgroundView = spinner
    } else { tableView.backgroundView = visibleSections.allSatisfy { ($0["rows"] as? [[String: Any]] ?? []).isEmpty } ? label : nil }
    if page["textSizeFactor"] != nil {
      navigationController?.navigationBar.titleTextAttributes = [
        .font: appFont(17, style: .headline, weight: .regular)
      ]
      search?.searchBar.searchTextField.font = appFont(15, style: .body)
      search?.searchBar.searchTextField.adjustsFontForContentSizeCategory = true
    }
    tableView.reloadData()
  }
  // Match Flutter's 15pt body / 13pt detail at the same app-size factor.
  // UIFontMetrics applies the system Dynamic Type curve exactly once.
  private func appFont(_ size: CGFloat, style: UIFont.TextStyle,
                       weight: UIFont.Weight = .regular) -> UIFont {
    let factor = min(1.3, max(0.8, (page["textSizeFactor"] as? NSNumber)?.doubleValue ?? 1))
    let pointSize = size * CGFloat(factor)
    let base = UIFont.systemFont(ofSize: pointSize, weight: .regular)
    let descriptor = base.fontDescriptor.addingAttributes([
      .traits: [UIFontDescriptor.TraitKey.weight: weight]
    ])
    return UIFontMetrics(forTextStyle: style).scaledFont(
      for: UIFont(descriptor: descriptor, size: pointSize),
      compatibleWith: traitCollection)
  }
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
      update(page)
    }
  }
  override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    guard page["textSizeFactor"] != nil, let header = view as? UITableViewHeaderFooterView else { return }
    header.textLabel?.font = appFont(13, style: .footnote, weight: .regular)
    header.textLabel?.adjustsFontForContentSizeCategory = true
  }
  override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
    guard page["textSizeFactor"] != nil, let footer = view as? UITableViewHeaderFooterView else { return }
    footer.textLabel?.font = appFont(12, style: .footnote)
    footer.textLabel?.adjustsFontForContentSizeCategory = true
  }
  private var visibleSections: [[String: Any]] {
    let query = search?.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return (page["sections"] as? [[String: Any]] ?? []).map { section in
      var filtered = section
      if !query.isEmpty {
        filtered["rows"] = (section["rows"] as? [[String: Any]] ?? []).filter {
          (($0["title"] as? String ?? "") + " " + ($0["subtitle"] as? String ?? "")).localizedCaseInsensitiveContains(query)
        }
      }
      return filtered
    }
  }
  private func row(_ path: IndexPath) -> [String: Any] { (visibleSections[path.section]["rows"] as? [[String: Any]] ?? [])[path.row] }
  override func numberOfSections(in tableView: UITableView) -> Int { visibleSections.count }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { (visibleSections[section]["rows"] as? [[String: Any]] ?? []).count }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { visibleSections[section]["title"] as? String }
  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { visibleSections[section]["footer"] as? String }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let data = row(indexPath)
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration()
    content.text = data["title"] as? String; content.secondaryText = data["subtitle"] as? String
    if page["textSizeFactor"] != nil {
      content.textProperties.font = appFont(15, style: .body)
      content.secondaryTextProperties.font = appFont(13, style: .subheadline)
      content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
    }
    content.textProperties.numberOfLines = 0
    content.secondaryTextProperties.numberOfLines = 0
    content.textProperties.color = data["destructive"] as? Bool == true ? .systemRed : .label
    if let symbol = data["symbol"] as? String { content.image = UIImage(systemName: symbol); content.imageProperties.tintColor = .secondaryLabel }
    cell.contentConfiguration = content
    cell.accessibilityIdentifier = data["id"] as? String
    cell.isAccessibilityElement = data["value"] == nil
    cell.accessibilityLabel = [data["title"] as? String, data["subtitle"] as? String].compactMap { $0 }.joined(separator: ", ")
    cell.accessibilityTraits = .button
    if data["checked"] as? Bool == true { cell.accessibilityTraits.insert(.selected) }

    if let value = data["value"] as? Bool {
      let toggle = UISwitch(); toggle.isOn = value
      toggle.accessibilityLabel = data["title"] as? String
      toggle.addAction(UIAction { [weak self, weak toggle] _ in self?.owner?.perform(data, value: toggle?.isOn) }, for: .valueChanged)
      cell.accessoryView = toggle; cell.selectionStyle = .none
      cell.accessibilityElements = [toggle]
    } else if data["children"] != nil || data["disclosure"] as? Bool == true { cell.accessoryType = .disclosureIndicator }
    else if data["checked"] as? Bool == true { cell.accessoryType = .checkmark }
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let data = row(indexPath)
    if data["value"] is Bool { return }
    if let child = data["children"] as? [String: Any], let owner = owner {
      navigationController?.pushViewController(NativeListController(page: child, owner: owner), animated: (!UIAccessibility.isReduceMotionEnabled || UIAccessibility.prefersCrossFadeTransitions))
    } else { owner?.perform(data) }
  }
  override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let delete = row(indexPath)["delete"] as? [String: Any] else { return nil }
    let action = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, complete in
      complete(false); self?.owner?.perform(delete)
    }
    action.image = UIImage(systemName: "trash")
    let config = UISwipeActionsConfiguration(actions: [action]); config.performsFirstActionWithFullSwipe = false
    return config
  }
  func updateSearchResults(for searchController: UISearchController) { update(page) }
}

final class NativeControlFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeControl(frame: frame, id: viewId, messenger: messenger, args: args)
  }
}

private final class NativeControl: NSObject, FlutterPlatformView {
  let button = UIButton(type: .system)
  let channel: FlutterMethodChannel
  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, args: Any?) {
    channel = FlutterMethodChannel(name: "com.findez.app/toolbar-control/\(id)", binaryMessenger: messenger)
    super.init()
    button.frame = frame
    button.addAction(UIAction { [weak self] _ in self?.channel.invokeMethod("selected", arguments: "__press__") }, for: .touchUpInside)
    if #available(iOS 16.0, *) { button.preferredMenuElementOrder = .fixed }
    configure(args)
    channel.setMethodCallHandler { [weak self] call, reply in
      if call.method == "configure" { self?.configure(call.arguments); reply(nil) }
      else { reply(FlutterMethodNotImplemented) }
    }
  }
  private func configure(_ args: Any?) {
    let data = args as? [String: Any] ?? [:]
    button.overrideUserInterfaceStyle = data["dark"] as? Bool == true ? .dark : .light
    var configuration: UIButton.Configuration = .plain()
    if #available(iOS 26.0, *), data["glass"] as? Bool == true { configuration = .glass() }
    configuration.cornerStyle = .capsule
    configuration.baseForegroundColor = .label
    let symbolSize = min(28, max(12, CGFloat((data["symbolSize"] as? NSNumber)?.doubleValue ?? 20)))
    configuration.image = UIImage(systemName: data["symbol"] as? String ?? "ellipsis",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular))
    if let size = data["symbolSize"] as? NSNumber {
      configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
        pointSize: min(28, max(12, CGFloat(size.doubleValue))), weight: .regular)
    }
    button.configuration = configuration
    button.accessibilityLabel = data["label"] as? String
    button.isEnabled = data["enabled"] as? Bool == true
    let items = data["items"] as? [[String: Any]] ?? []
    button.showsMenuAsPrimaryAction = !items.isEmpty
    button.menu = items.isEmpty ? nil : UIMenu(children: items.map { item in
      UIAction(title: item["title"] as? String ?? "", image: UIImage(systemName: item["symbol"] as? String ?? ""),
        attributes: item["destructive"] as? Bool == true ? .destructive : []) { [weak self] _ in
          self?.channel.invokeMethod("selected", arguments: item["id"])
        }
    })
  }
  func view() -> UIView { button }
  deinit { channel.setMethodCallHandler(nil) }
}
