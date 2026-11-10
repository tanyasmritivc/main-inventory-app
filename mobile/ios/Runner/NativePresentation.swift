import Flutter
import UIKit

// Opaque light roles match Flutter; UIKit retains its existing dark roles.
enum NativeAppearanceColors {
  static let canvas = UIColor { $0.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 246/255, green: 247/255, blue: 249/255, alpha: 1) }
  static let separator = UIColor { $0.userInterfaceStyle == .dark ? .separator : UIColor(red: 230/255, green: 232/255, blue: 236/255, alpha: 1) }
  static let secondary = UIColor { $0.userInterfaceStyle == .dark ? .secondaryLabel : UIColor(red: 112/255, green: 117/255, blue: 125/255, alpha: 1) }
  static let primary = UIColor { $0.userInterfaceStyle == .dark ? .label : UIColor(red: 32/255, green: 34/255, blue: 38/255, alpha: 1) }
}
import CoreText

/// System presentations only. Dart remains responsible for data and permissions.
final class NativePresentation: NSObject, UIAdaptivePresentationControllerDelegate, UIPopoverPresentationControllerDelegate {
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
    if data["kind"] as? String == "organization" {
      let list = NativeListController(page: data, owner: self)
      list.modalPresentationStyle = .popover
      let sections = data["sections"] as? [[String: Any]] ?? []
      let rows = sections.reduce(0) { $0 + (($1["rows"] as? [[String: Any]])?.count ?? 0) }
      list.preferredContentSize = CGSize(width: min(280, parent.view.bounds.width - 48),
        height: min(CGFloat(rows) * 48, min(360, parent.view.bounds.height * 0.5)))
      if let popover = list.popoverPresentationController {
        let anchor = data["anchor"] as? [String: Double] ?? [:]
        popover.sourceView = parent.view
        let rect = CGRect(x: anchor["x"] ?? 16, y: anchor["y"] ?? 60,
          width: anchor["width"] ?? 160, height: anchor["height"] ?? 44)
        popover.sourceRect = parent.view.convert(rect, from: parent.view.window)
        popover.permittedArrowDirections = [.up, .down]
        popover.popoverLayoutMargins = UIEdgeInsets(top: 16, left: 24, bottom: 24, right: 24)
        popover.delegate = self
      }
      controller = list
    } else if data["kind"] as? String == "photoSource" {
      let sheet = NativePhotoSourceController(message: data["message"] as? String) { [weak self] choice in
        self?.finish(choice.map { ["action": $0] })
      }
      sheet.modalPresentationStyle = .pageSheet
      if let presentation = sheet.sheetPresentationController {
        if #available(iOS 16.0, *) {
          presentation.detents = [.custom(identifier: .init("photoSource")) { [weak sheet] context in
            min(context.maximumDetentValue, sheet?.fittingHeight ?? 330)
          }]
        } else {
          presentation.detents = [.medium(), .large()]
        }
        presentation.prefersGrabberVisible = true
        presentation.prefersScrollingExpandsWhenScrolledToEdge = false
      }
      controller = sheet
    } else if data["kind"] as? String == "alert" {
      let alert = makeAlert(data) { [weak self] value in self?.finish(value) }
      controller = alert
    } else {
      let list = NativeListController(page: data, owner: self)
      list.overrideUserInterfaceStyle = data["dark"] as? Bool == true ? .dark : .light
      let navigation = UINavigationController(rootViewController: list)
      navigation.overrideUserInterfaceStyle = list.overrideUserInterfaceStyle
      navigation.modalPresentationStyle = .pageSheet
      if data["opaque"] as? Bool == true {
        navigation.view.backgroundColor = data["dark"] as? Bool == true ? UIColor(white: 0.08, alpha: 1) : UIColor(red: 246/255, green: 247/255, blue: 249/255, alpha: 1)
      }
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
    controller.view.tintColor = NativeAppearanceColors.primary
    // UIAlertController owns its presentation delegate and asserts if replaced.
    // Only our sheet navigation controller needs interactive-dismiss callbacks.
    if controller is UINavigationController || controller is NativePhotoSourceController { controller.presentationController?.delegate = self }
    parent.present(controller, animated: (!UIAccessibility.isReduceMotionEnabled || UIAccessibility.prefersCrossFadeTransitions)) { [weak self] in
      guard let self = self, self.model["load"] as? Bool == true else { return }
      self.perform(["id": "load", "close": false])
    }
  }

  func adaptivePresentationStyle(for controller: UIPresentationController,
    traitCollection: UITraitCollection) -> UIModalPresentationStyle { .none }

  func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
    complete(nil)
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
    super.init(style: page["kind"] as? String == "organization" ? .plain : .insetGrouped)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func viewDidLoad() {
    super.viewDidLoad()
    if page["opaque"] as? Bool == true {
      tableView.backgroundColor = page["dark"] as? Bool == true ? UIColor(white: 0.08, alpha: 1) : UIColor(red: 246/255, green: 247/255, blue: 249/255, alpha: 1)
    }
    if page["opaque"] as? Bool != true {
      tableView.backgroundColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 246/255, green: 247/255, blue: 249/255, alpha: 1)
      }
    }
    tableView.separatorColor = NativeAppearanceColors.separator
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 58
    tableView.keyboardDismissMode = .onDrag
    if page["kind"] as? String == "organization" {
      // A popover is a compact menu, not a grouped Settings page. Grouped
      // section padding is especially large on iOS 26.
      tableView.backgroundColor = .secondarySystemGroupedBackground
      tableView.contentInsetAdjustmentBehavior = .never
      tableView.contentInset = .zero
      tableView.sectionHeaderTopPadding = 0
      tableView.estimatedSectionHeaderHeight = 0
      tableView.estimatedSectionFooterHeight = 0
      tableView.tableHeaderView = UIView(frame: .zero)
      tableView.tableFooterView = UIView(frame: .zero)
      tableView.estimatedRowHeight = 48
      tableView.separatorInset = UIEdgeInsets(top: 0, left: 50, bottom: 0, right: 12)
    }
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
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard page["kind"] as? String == "organization" else { return }
    let available = (presentingViewController?.view.bounds.height ?? 800)
    let maximum = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
      ? available * 0.6 : min(360, available * 0.5)
    let height = min(tableView.contentSize.height, maximum)
    if abs(preferredContentSize.height - height) > 1 {
      preferredContentSize.height = height
    }
  }
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    page["kind"] as? String == "organization" ? .leastNormalMagnitude : UITableView.automaticDimension
  }
  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    page["kind"] as? String == "organization" ? .leastNormalMagnitude : UITableView.automaticDimension
  }
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    guard page["kind"] as? String == "organization" else { return UITableView.automaticDimension }
    let font = appFont(15, style: .body)
    let title = row(indexPath)["title"] as? String ?? ""
    // UIKit's automatic list minimum is roomier than a compact menu. Keep a
    // full 44pt hit target, growing only when text actually needs more space.
    let width = max(80, tableView.bounds.width - 96)
    let height = (title as NSString).boundingRect(
      with: CGSize(width: width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: font], context: nil).height
    let lines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
      ? height : min(height, font.lineHeight * 2)
    return max(44, ceil(lines) + 16)
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
    label.textColor = NativeAppearanceColors.secondary; label.textAlignment = .center
    label.font = appFont(15, style: .body)
    label.adjustsFontForContentSizeCategory = true
    label.numberOfLines = 0
    let statusView: UIView?
    if data["loading"] as? Bool == true {
      let spinner = UIActivityIndicatorView(style: .medium); spinner.startAnimating()
      statusView = spinner
    } else {
      statusView = visibleSections.allSatisfy { ($0["rows"] as? [[String: Any]] ?? []).isEmpty } ? label : nil
    }
    tableView.backgroundView = statusView
    if page["textSizeFactor"] != nil {
      navigationController?.navigationBar.titleTextAttributes = [
        .font: appFont(17, style: .headline, weight: .regular)
      ]
      search?.searchBar.searchTextField.font = appFont(15, style: .body)
      search?.searchBar.searchTextField.adjustsFontForContentSizeCategory = true
    }
    if traitCollection.userInterfaceStyle != .dark {
      var titleStyle = navigationController?.navigationBar.titleTextAttributes ?? [:]
      titleStyle[.foregroundColor] = NativeAppearanceColors.primary
      navigationController?.navigationBar.titleTextAttributes = titleStyle
      var largeStyle = navigationController?.navigationBar.largeTitleTextAttributes ?? [:]
      largeStyle[.foregroundColor] = NativeAppearanceColors.primary
      navigationController?.navigationBar.largeTitleTextAttributes = largeStyle
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
    if traitCollection.userInterfaceStyle != .dark { (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = NativeAppearanceColors.secondary }
    guard page["textSizeFactor"] != nil, let header = view as? UITableViewHeaderFooterView else { return }
    header.textLabel?.font = appFont(13, style: .footnote, weight: .regular)
    header.textLabel?.adjustsFontForContentSizeCategory = true
  }
  override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
    if traitCollection.userInterfaceStyle != .dark { (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = NativeAppearanceColors.secondary }
    guard page["textSizeFactor"] != nil, let footer = view as? UITableViewHeaderFooterView else { return }
    footer.textLabel?.font = appFont(12, style: .footnote)
    footer.textLabel?.adjustsFontForContentSizeCategory = true
  }
  private var visibleSections: [[String: Any]] {
    if page["kind"] as? String == "organization" {
      // Preserve all row IDs/actions while omitting empty section furniture.
      let sections = page["sections"] as? [[String: Any]] ?? []
      return [["rows": sections.flatMap { $0["rows"] as? [[String: Any]] ?? [] }]]
    }
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
    if page["opaque"] as? Bool == true {
      cell.backgroundColor = UIColor(white: page["dark"] as? Bool == true ? 0.16 : 1, alpha: 1)
    }
    var content = cell.defaultContentConfiguration()
    content.text = data["title"] as? String; content.secondaryText = data["subtitle"] as? String
    if page["textSizeFactor"] != nil {
      content.textProperties.font = appFont(15, style: .body)
      content.secondaryTextProperties.font = appFont(13, style: .subheadline)
      content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
    }
    content.textProperties.numberOfLines = 0
    content.secondaryTextProperties.numberOfLines = 0
    content.textProperties.color = data["destructive"] as? Bool == true ? .systemRed : NativeAppearanceColors.primary
    if traitCollection.userInterfaceStyle != .dark { content.secondaryTextProperties.color = NativeAppearanceColors.secondary }
    if let symbol = data["symbol"] as? String { content.image = UIImage(systemName: symbol); content.imageProperties.tintColor = NativeAppearanceColors.secondary }
    if data["announcementPlan"] as? Bool == true {
      content.textProperties.font = appFont(16, style: .body, weight: .medium)
      content.secondaryTextProperties.font = appFont(13, style: .subheadline)
      content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 14)
      content.image = announcementTile()
      content.imageProperties.maximumSize = CGSize(width: 42, height: 42)
      content.imageProperties.cornerRadius = 12
      // Let the inset-grouped table own its corner mask. A separately rounded
      // background view creates a second, visibly clipped curve in this row.
      var background = UIBackgroundConfiguration.listGroupedCell()
      background.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.086, green: 0.086, blue: 0.094, alpha: 1) : .white }
      background.strokeWidth = 0
      cell.backgroundConfiguration = background
      if let badge = data["badge"] as? String {
        let label = UILabel()
        label.text = "  \(badge)  "
        label.font = appFont(12.5, style: .caption1, weight: .medium)
        label.textColor = NativeAppearanceColors.secondary
        label.layer.cornerRadius = 13
        label.layer.borderWidth = 1
        label.layer.borderColor = (traitCollection.userInterfaceStyle == .dark ? UIColor.label.withAlphaComponent(0.12) : NativeAppearanceColors.separator).resolvedColor(with: traitCollection).cgColor
        label.sizeToFit()
        label.frame.size.height = max(26, label.frame.height + 8)
        cell.accessoryView = label
      }
    }
    if let initial = data["initial"] as? String {
      content.image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { _ in
        UIColor.tertiarySystemFill.setFill()
        UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 32, height: 32)).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: NativeAppearanceColors.primary]
        let text = initial.uppercased() as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (32-size.width)/2, y: (32-size.height)/2), withAttributes: attributes)
      }
    }
    if page["kind"] as? String == "organization" {
      content.textProperties.font = appFont(15, style: .body)
      content.textProperties.numberOfLines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 0 : 2
      content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
      content.imageToTextPadding = 10
      content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
      content.imageProperties.maximumSize = CGSize(width: 26, height: 26)
      content.imageProperties.reservedLayoutSize = CGSize(width: 26, height: 26)
      cell.backgroundColor = .secondarySystemGroupedBackground
      cell.separatorInset = UIEdgeInsets(top: 0, left: 50, bottom: 0, right: 12)
    }
    cell.contentConfiguration = content
    cell.accessibilityIdentifier = data["id"] as? String
    cell.isAccessibilityElement = data["value"] == nil
    cell.accessibilityLabel = [data["title"] as? String, data["subtitle"] as? String].compactMap { $0 }.joined(separator: ", ")
    cell.accessibilityTraits = data["readOnly"] as? Bool == true ? .staticText : .button
    if data["readOnly"] as? Bool == true { cell.selectionStyle = .none }
    if data["checked"] as? Bool == true { cell.accessibilityTraits.insert(.selected) }

    if let value = data["value"] as? Bool {
      let toggle = UISwitch(); toggle.isOn = value
      toggle.accessibilityLabel = data["title"] as? String
      toggle.addAction(UIAction { [weak self, weak toggle] _ in self?.owner?.perform(data, value: toggle?.isOn) }, for: .valueChanged)
      cell.accessoryView = toggle; cell.selectionStyle = .none
      cell.accessibilityElements = [toggle]
    } else if data["children"] != nil || data["disclosure"] as? Bool == true {
      cell.accessoryType = .disclosureIndicator
      if traitCollection.userInterfaceStyle != .dark && cell.accessoryView == nil {
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)))
        chevron.tintColor = NativeAppearanceColors.secondary
        chevron.isAccessibilityElement = false
        cell.accessoryView = chevron
      }
    }
    else if data["checked"] as? Bool == true { cell.accessoryType = .checkmark }
    return cell
  }
  private func announcementTile() -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 42, height: 42)).image { renderer in
      let ctx = renderer.cgContext
      let rect = CGRect(x: 0, y: 0, width: 42, height: 42)
      UIBezierPath(roundedRect: rect, cornerRadius: 12).addClip()
      let colors = [UIColor(red: 0.27, green: 0.20, blue: 0.29, alpha: 1).cgColor,
                    UIColor(red: 0.47, green: 0.25, blue: 0.26, alpha: 1).cgColor,
                    UIColor(red: 0.60, green: 0.38, blue: 0.31, alpha: 1).cgColor]
      if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.55, 1]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 42), end: CGPoint(x: 42, y: 0), options: [])
      }
      let key = FlutterDartProject.lookupKey(forAsset: "assets/brand/findez-mark-white.png")
      if let path = Bundle.main.path(forResource: key, ofType: nil), let mark = UIImage(contentsOfFile: path) {
        mark.draw(in: CGRect(x: 12, y: 12, width: 18, height: 18))
      }
    }
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let data = row(indexPath)
    if data["value"] is Bool || data["readOnly"] as? Bool == true { return }
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

/// Compact UIKit sheet shared by Ask and Space photo capture.
private final class NativePhotoSourceController: UIViewController {
  private let message: String?
  private let completion: (String?) -> Void
  private let stack = UIStackView()
  var fittingHeight: CGFloat {
    loadViewIfNeeded()
    let width = max(240, view.bounds.width - 40)
    return stack.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height + 66
  }
  init(message: String?, completion: @escaping (String?) -> Void) {
    self.message = message; self.completion = completion
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = NativeAppearanceColors.canvas
    let scroll = UIScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll)
    stack.axis = .vertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = false
    scroll.addSubview(stack)
    for (id, title, symbol) in [("camera", "Take photo", "camera"), ("photos", "Choose photo", "photo.on.rectangle")] {
      let button = UIButton(type: .system)
      var configuration = UIButton.Configuration.plain()
      configuration.title = title; configuration.image = UIImage(systemName: symbol)
      configuration.imagePadding = 16
      configuration.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
      button.configuration = configuration
      button.contentHorizontalAlignment = .leading
      button.titleLabel?.font = .preferredFont(forTextStyle: .body)
      button.titleLabel?.adjustsFontForContentSizeCategory = true
      button.titleLabel?.numberOfLines = 0
      button.tintColor = NativeAppearanceColors.primary
      button.backgroundColor = .secondarySystemGroupedBackground
      button.layer.cornerRadius = 16; button.layer.cornerCurve = .continuous
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
      button.addAction(UIAction { [weak self] _ in self?.completion(id) }, for: .touchUpInside)
      stack.addArrangedSubview(button)
    }
    if let message = message {
      let label = UILabel(); label.text = message; label.numberOfLines = 0
      label.font = .preferredFont(forTextStyle: .footnote); label.adjustsFontForContentSizeCategory = true
      label.textColor = NativeAppearanceColors.secondary
      stack.addArrangedSubview(label)
    }
    let cancel = UIButton(type: .system)
    cancel.setTitle("Cancel", for: .normal); cancel.tintColor = NativeAppearanceColors.primary
    cancel.titleLabel?.font = .preferredFont(forTextStyle: .body)
    cancel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    cancel.addAction(UIAction { [weak self] _ in self?.completion(nil) }, for: .touchUpInside)
    stack.addArrangedSubview(cancel)
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 26),
      scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
      stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -8),
      stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
      stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
    ])
  }
}
