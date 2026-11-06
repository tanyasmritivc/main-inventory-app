import Flutter
import UIKit

func findezTopPresenter() -> UIViewController? {
  let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
  var top = scenes.first(where: { $0.activationState == .foregroundActive })?
    .windows.first(where: { $0.isKeyWindow })?.rootViewController
  while let presented = top?.presentedViewController { top = presented }
  return top
}

/// Isolated native inbox. The Chats/Settings renderer remains unchanged.
final class NativeNotifications: NSObject, UIAdaptivePresentationControllerDelegate {
  private let channel: FlutterMethodChannel
  private var result: FlutterResult?
  private var token: String?
  private var navigation: UINavigationController?
  private var inbox: NotificationListController?
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.findez.app/notifications", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self = self else { reply(nil); return }
      let data = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "present":
        guard self.result == nil, let parent = findezTopPresenter(), !parent.isBeingDismissed else {
          reply(FlutterError(code: "busy", message: "Another control is open.", details: nil)); return
        }
        self.result = reply; self.token = data["token"] as? String
        let inbox = NotificationListController(model: data)
        inbox.onClose = { [weak self] in self?.finish(nil) }
        inbox.onOpen = { [weak self] id in self?.finish(id) }
        inbox.onAction = { [weak self] id in
          guard let self = self, let token = self.token else { return }
          self.channel.invokeMethod("action", arguments: ["token": token, "id": id])
        }
        let nav = UINavigationController(rootViewController: inbox)
        nav.overrideUserInterfaceStyle = data["dark"] as? Bool == true ? .dark : .light
        nav.modalPresentationStyle = .pageSheet
        nav.sheetPresentationController?.detents = [.large()]
        nav.sheetPresentationController?.prefersGrabberVisible = true
        nav.presentationController?.delegate = self
        self.navigation = nav; self.inbox = inbox
        parent.present(nav, animated: !UIAccessibility.isReduceMotionEnabled)
      case "update":
        if data["token"] as? String == self.token { self.inbox?.update(data) }
        reply(nil)
      case "dismiss":
        if data["token"] as? String == self.token { self.finish(nil) }
        reply(nil)
      default: reply(FlutterMethodNotImplemented)
      }
    }
  }
  private func finish(_ id: String?) {
    guard let nav = navigation else { complete(id); return }
    nav.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { [weak self] in self?.complete(id) }
  }
  private func complete(_ id: String?) {
    let reply = result
    result = nil; token = nil; navigation = nil; inbox = nil
    reply?(id)
  }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { complete(nil) }
}

private final class NotificationListController: UITableViewController {
  private var model: [String: Any]
  var onClose: (() -> Void)?
  var onOpen: ((String) -> Void)?
  var onAction: ((String) -> Void)?
  init(model: [String: Any]) { self.model = model; super.init(style: .insetGrouped) }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  private var sections: [[String: Any]] { model["sections"] as? [[String: Any]] ?? [] }
  private var busy: Bool { model["busy"] as? Bool == true }
  private func row(_ path: IndexPath) -> [String: Any] {
    (sections[path.section]["rows"] as? [[String: Any]] ?? [])[path.row]
  }
  private func font(_ size: CGFloat, _ style: UIFont.TextStyle) -> UIFont {
    let factor = min(1.3, max(0.8, (model["textSizeFactor"] as? NSNumber)?.doubleValue ?? 1))
    let base = UIFont.systemFont(ofSize: size * CGFloat(factor), weight: .regular)
    let descriptor = base.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.regular]])
    return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: size * CGFloat(factor)), compatibleWith: traitCollection)
  }
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Notifications"
    tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 78
    refreshControl = UIRefreshControl()
    refreshControl?.addAction(UIAction { [weak self] _ in self?.onAction?("refresh") }, for: .valueChanged)
    navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.onClose?() })
    update(model)
  }
  func update(_ data: [String: Any]) {
    model = data
    guard isViewLoaded else { return }
    navigationController?.navigationBar.titleTextAttributes = [.font: font(17, .headline)]
    let options = (data["options"] as? [[String: Any]] ?? []).map { option -> UIAction in
      let action = UIAction(title: option["title"] as? String ?? "", image: UIImage(systemName: option["symbol"] as? String ?? "bell")) { [weak self] _ in
        if let id = option["id"] as? String { self?.onAction?(id) }
      }
      if option["disabled"] as? Bool == true { action.attributes = .disabled }
      return action
    }
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: options))
    navigationItem.leftBarButtonItem?.accessibilityLabel = "Notification options"
    if !busy { refreshControl?.endRefreshing() }
    if data["loading"] as? Bool == true && sections.isEmpty {
      let spinner = UIActivityIndicatorView(style: .medium); spinner.startAnimating(); tableView.backgroundView = spinner
    } else if sections.isEmpty {
      let label = UILabel(); label.text = data["empty"] as? String ?? "No updates yet"
      label.textAlignment = .center; label.numberOfLines = 0; label.textColor = .secondaryLabel
      label.font = font(15, .body); label.adjustsFontForContentSizeCategory = true
      tableView.backgroundView = label
    } else { tableView.backgroundView = nil }
    tableView.reloadData()
  }
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory { update(model) }
  }
  override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { (sections[section]["rows"] as? [[String: Any]] ?? []).count }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section]["title"] as? String }
  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { sections[section]["footer"] as? String }
  override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    (view as? UITableViewHeaderFooterView)?.textLabel?.font = font(13, .footnote)
  }
  override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
    (view as? UITableViewHeaderFooterView)?.textLabel?.font = font(12, .footnote)
  }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let data = row(indexPath), cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration()
    content.text = data["title"] as? String; content.secondaryText = data["subtitle"] as? String
    content.textProperties.font = font(15, .body); content.secondaryTextProperties.font = font(13, .subheadline)
    content.textProperties.numberOfLines = 0; content.secondaryTextProperties.numberOfLines = 0
    content.image = UIImage(systemName: data["symbol"] as? String ?? "bell")
    content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
    content.imageProperties.tintColor = .secondaryLabel
    cell.contentConfiguration = content
    cell.accessibilityIdentifier = data["id"] as? String
    cell.accessibilityLabel = [data["unread"] as? Bool == true ? "Unread" : nil, content.text, content.secondaryText].compactMap { $0 }.joined(separator: ", ")
    if data["unread"] as? Bool == true {
      let dot = UIImageView(image: UIImage(systemName: "circle.fill")); dot.tintColor = .label
      dot.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 7); dot.sizeToFit(); cell.accessoryView = dot
    } else if data["open"] as? Bool == true { cell.accessoryType = .disclosureIndicator }
    if data["open"] as? Bool != true && data["action"] as? Bool != true { cell.selectionStyle = .none }
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let data = row(indexPath)
    guard let id = data["id"] as? String else { return }
    if data["open"] as? Bool == true { onOpen?(id) }
    else if data["action"] as? Bool == true && !busy { onAction?(id) }
  }
  override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    let data = row(indexPath)
    guard !busy, data["dismissible"] as? Bool == true, let id = data["id"] as? String else { return nil }
    let action = UIContextualAction(style: .normal, title: "Dismiss") { [weak self] _, _, complete in
      complete(false)
      self?.onAction?("dismiss:" + id)
    }
    action.image = UIImage(systemName: "xmark")
    action.backgroundColor = .secondaryLabel
    let configuration = UISwipeActionsConfiguration(actions: [action])
    configuration.performsFirstActionWithFullSwipe = false
    return configuration
  }
}
