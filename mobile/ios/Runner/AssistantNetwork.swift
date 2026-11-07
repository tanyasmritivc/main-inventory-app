import Flutter
import UIKit

/// iOS, rather than a foreground Dart socket, owns each user-started exchange.
/// Payload files are private, excluded from backup, and removed on completion.
final class AssistantNetwork: NSObject, URLSessionDataDelegate {
  static let identifier = "com.findez.app.assistant.requests"
  private let channel: FlutterMethodChannel
  private var session: URLSession!
  private var liveSession: URLSession!
  private var readers: [Int: Int] = [:]
  private var ready = false
  private var waiting: [() -> Void] = []
  private var requests: [Int: Request] = [:]
  var backgroundCompletion: (() -> Void)?
  private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("assistant-network", isDirectory: true)
  private struct Request {
    let id: String
    let file: URL
    let task: URLSessionUploadTask
    var reader: URLSessionDataTask?
    var headersSent = false
    var nativeOffset = 0
    var readerOffset = 0
    var delivered = 0
    var readerAttempts = 0
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.findez.app/assistant-network", binaryMessenger: messenger)
    super.init()
    let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
    configuration.isDiscretionary = false
    configuration.sessionSendsLaunchEvents = true
    configuration.waitsForConnectivity = true
    configuration.timeoutIntervalForRequest = 120
    configuration.timeoutIntervalForResource = 600
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    let live = URLSessionConfiguration.ephemeral
    live.timeoutIntervalForRequest = 120
    live.timeoutIntervalForResource = 600
    live.httpCookieStorage = nil
    live.urlCredentialStorage = nil
    live.urlCache = nil
    liveSession = URLSession(configuration: live, delegate: self, delegateQueue: .main)
    // A new engine has no owner for an old request. Never deliver it to another
    // login or replay a request after the user clears the app.
    session.getAllTasks { [weak self] tasks in
      DispatchQueue.main.async {
        guard let self = self else { return }
        tasks.forEach { $0.cancel() }
        try? FileManager.default.removeItem(at: self.directory)
        self.ready = true
        let pending = self.waiting
        self.waiting.removeAll()
        pending.forEach { $0() }
      }
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "cancel", let args = call.arguments as? [String: Any], let id = args["id"] as? String {
        for (key, request) in self.requests where request.id == id {
          request.task.cancel()
          request.reader?.cancel()
          if let reader = request.reader { self.readers.removeValue(forKey: reader.taskIdentifier) }
          try? FileManager.default.removeItem(at: request.file)
          self.requests.removeValue(forKey: key)
        }
        // Retire a start queued during initial stale-task cleanup as well.
        if !self.ready { self.cancelled.insert(id) }
        result(nil)
      } else if call.method == "start", let args = call.arguments as? [String: Any] {
        let start = { [weak self] in self?.start(args, result: result); return }
        if self.ready { start() } else { self.waiting.append(start) }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
  private var cancelled = Set<String>()
  private func start(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["id"] as? String,
          let raw = args["url"] as? String, let url = URL(string: raw),
          url.scheme == "https", url.user == nil, url.password == nil,
          let method = args["method"] as? String, method == "POST",
          let headers = args["headers"] as? [String: String],
          let body = args["body"] as? FlutterStandardTypedData,
          body.data.count <= 16 * 1024 * 1024 else {
      result(FlutterError(code: "invalid_request", message: "The request could not start.", details: nil)); return
    }
    if cancelled.remove(id) != nil { result(nil); return }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      var file = directory.appendingPathComponent(UUID().uuidString)
      try body.data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      var values = URLResourceValues(); values.isExcludedFromBackup = true
      try file.setResourceValues(values)
      var request = URLRequest(url: url)
      request.httpMethod = method
      request.allHTTPHeaderFields = headers
      request.setValue(UUID().uuidString, forHTTPHeaderField: "X-FindEZ-Stream-ID")
      let task = session.uploadTask(with: request, fromFile: file)
      requests[task.taskIdentifier] = Request(id: id, file: file, task: task)
      task.resume()
      // The POST remains the sole owner of computation and writes. This GET
      // only mirrors its bytes while foregrounded; failure never replays POST.
      var read = request
      read.httpMethod = "GET"
      read.setValue(nil, forHTTPHeaderField: "Content-Length")
      read.setValue(nil, forHTTPHeaderField: "Content-Type")
      read.setValue("1", forHTTPHeaderField: "X-FindEZ-Stream-Read")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        self?.startReader(task.taskIdentifier, request: read)
      }
      result(nil)
    } catch {
      result(FlutterError(code: "request_start", message: "The request could not start.", details: nil))
    }
  }
  private func startReader(_ key: Int, request: URLRequest) {
    guard let state = requests[key], state.readerAttempts < 10 else { return }
    let reader = liveSession.dataTask(with: request)
    readers[reader.taskIdentifier] = key
    requests[key]?.reader = reader
    requests[key]?.readerAttempts += 1
    reader.resume()
  }
  private func sendHeaders(_ key: Int, response: URLResponse?) {
    guard var state = requests[key], !state.headersSent,
          let response = response as? HTTPURLResponse else { return }
    state.headersSent = true; requests[key] = state
    var headers: [String: String] = [:]
    for (key, value) in response.allHeaderFields { headers[String(describing: key).lowercased()] = String(describing: value) }
    channel.invokeMethod("event", arguments: ["id": state.id, "type": "headers", "status": response.statusCode, "headers": headers])
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    if session === liveSession {
      guard let key = readers[dataTask.taskIdentifier] else { completionHandler(.cancel); return }
      guard (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-FindEZ-Stream-Ready") == "1" else {
        // The system-owned upload can start after this foreground GET.
        if (response as? HTTPURLResponse)?.statusCode == 404, let request = dataTask.originalRequest {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.startReader(key, request: request) }
        }
        completionHandler(.cancel); return
      }
      sendHeaders(key, response: response)
    } else { sendHeaders(dataTask.taskIdentifier, response: response) }
    completionHandler(.allow)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    let live = session === liveSession
    guard let key = live ? readers[dataTask.taskIdentifier] : dataTask.taskIdentifier,
          var state = requests[key] else { return }
    sendHeaders(key, response: dataTask.response)
    state = requests[key]!
    let offset = live ? state.readerOffset : state.nativeOffset
    let skip = min(data.count, max(0, state.delivered - offset))
    if live { state.readerOffset += data.count } else { state.nativeOffset += data.count }
    state.delivered = max(state.delivered, offset + data.count)
    requests[key] = state
    if skip < data.count {
      channel.invokeMethod("event", arguments: ["id": state.id, "type": "data", "bytes": FlutterStandardTypedData(bytes: data.dropFirst(skip))])
    }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if session === liveSession {
      readers.removeValue(forKey: task.taskIdentifier)
      return
    }
    sendHeaders(task.taskIdentifier, response: task.response)
    guard let state = requests.removeValue(forKey: task.taskIdentifier) else { return }
    if let reader = state.reader { readers.removeValue(forKey: reader.taskIdentifier); reader.cancel() }
    try? FileManager.default.removeItem(at: state.file)
    channel.invokeMethod("event", arguments: ["id": state.id, "type": error == nil ? "done" : "error"])
  }
  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    let completion = backgroundCompletion; backgroundCompletion = nil
    completion?()
  }
}
