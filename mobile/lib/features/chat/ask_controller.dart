import 'dart:async';

import 'ask_client.dart';
import 'ask_event.dart';

enum AskRunOutcome { completed, cancelled, failed }

typedef AskEventHandler = void Function(AskEvent event);
typedef AskStateHandler = void Function();

class AskMessage {
  AskMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.navHint,
  });

  final String role;
  final String content;
  final int timestamp;
  final bool isStreaming;
  final Map<String, dynamic>? navHint;

  AskMessage copyWith({
    String? content,
    int? timestamp,
    bool? isStreaming,
    Map<String, dynamic>? navHint,
  }) {
    return AskMessage(
      role: role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      navHint: navHint ?? this.navHint,
    );
  }
}

class AskConversationState {
  AskConversationState({List<AskMessage>? messages, this.conversationId})
    : messages = messages ?? <AskMessage>[],
      hasStarted = messages?.isNotEmpty ?? false;

  final List<AskMessage> messages;
  bool hasStarted;
  String? conversationId;
}

class AskController {
  AskController({
    required AskGateway gateway,
    AskStateHandler? onStateChanged,
    AskConversationState? conversationState,
  }) : _gateway = gateway,
       _onStateChanged = onStateChanged,
       _conversationState = conversationState ?? AskConversationState();

  final AskGateway _gateway;
  final AskStateHandler? _onStateChanged;
  final AskConversationState _conversationState;

  AskRequest? _activeRequest;
  StreamSubscription<AskEvent>? _activeSubscription;
  Completer<AskRunOutcome>? _activeCompletion;
  var _generation = 0;

  bool isBusy = false;
  String? status;
  String? errorMessage;
  Map<String, dynamic>? pendingNavigation;
  List<AskMessage> get messages => _conversationState.messages;
  bool get hasStarted => _conversationState.hasStarted;
  set hasStarted(bool value) => _conversationState.hasStarted = value;
  String? get conversationId => _conversationState.conversationId;
  set conversationId(String? value) =>
      _conversationState.conversationId = value;

  Future<AskRunOutcome> sendText({
    required String message,
    required AskEventHandler onEvent,
  }) {
    return _run(
      () =>
          _gateway.streamText(message: message, conversationId: conversationId),
      onEvent,
    );
  }

  Future<AskRunOutcome> sendFile({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    required AskEventHandler onEvent,
  }) {
    return _run(
      () => _gateway.streamFile(
        filename: filename,
        bytes: bytes,
        mimeType: mimeType,
        conversationId: conversationId,
      ),
      onEvent,
    );
  }

  Future<AskRunOutcome> _run(
    Future<AskRequest> Function() createRequest,
    AskEventHandler onEvent,
  ) async {
    if (isBusy) return AskRunOutcome.failed;
    final generation = ++_generation;
    isBusy = true;
    status = null;
    errorMessage = null;
    pendingNavigation = null;
    _notify();

    AskRequest request;
    try {
      request = await createRequest();
    } on Object catch (error) {
      if (generation != _generation) return AskRunOutcome.cancelled;
      final event = AskEvent.error(_publicError(error));
      errorMessage = event.message;
      isBusy = false;
      onEvent(event);
      _notify();
      return AskRunOutcome.failed;
    }
    if (generation != _generation) {
      await request.cancel();
      return AskRunOutcome.cancelled;
    }

    _activeRequest = request;
    final completion = Completer<AskRunOutcome>();
    _activeCompletion = completion;
    var terminalSeen = false;
    var errorSeen = false;
    late final StreamSubscription<AskEvent> subscription;
    subscription = request.events.listen(
      (event) {
        if (generation != _generation) return;
        switch (event.type) {
          case AskEventType.status:
            status = event.message;
          case AskEventType.conversation:
            conversationId = event.conversationId;
          case AskEventType.navigation:
            pendingNavigation = event.navigation;
          case AskEventType.error:
            errorMessage = event.message;
            errorSeen = true;
          case AskEventType.done:
            terminalSeen = true;
          case AskEventType.delta:
            status = null;
        }
        onEvent(event);
        _notify();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _generation || completion.isCompleted) return;
        final event = AskEvent.error(_publicError(error));
        errorMessage = event.message;
        onEvent(event);
        completion.complete(AskRunOutcome.failed);
      },
      onDone: () {
        if (generation != _generation || completion.isCompleted) return;
        completion.complete(
          terminalSeen && !errorSeen
              ? AskRunOutcome.completed
              : AskRunOutcome.failed,
        );
      },
      cancelOnError: false,
    );
    _activeSubscription = subscription;

    final outcome = await completion.future;
    if (generation == _generation) {
      await subscription.cancel();
      await request.cancel();
      _activeSubscription = null;
      _activeRequest = null;
      _activeCompletion = null;
      isBusy = false;
      status = null;
      _notify();
    }
    return outcome;
  }

  Future<void> cancelActive() async {
    if (!isBusy) return;
    _generation += 1;
    await _activeSubscription?.cancel();
    await _activeRequest?.cancel();
    if (_activeCompletion case final completion?) {
      if (!completion.isCompleted) completion.complete(AskRunOutcome.cancelled);
    }
    _activeSubscription = null;
    _activeRequest = null;
    _activeCompletion = null;
    isBusy = false;
    status = null;
    errorMessage = null;
    _notify();
  }

  void useConversation(String? id) {
    conversationId = id;
    pendingNavigation = null;
    errorMessage = null;
    _notify();
  }

  Map<String, dynamic>? takeNavigation() {
    final value = pendingNavigation;
    pendingNavigation = null;
    return value;
  }

  void replaceMessages(Iterable<AskMessage> replacement) {
    messages
      ..clear()
      ..addAll(replacement);
    hasStarted = messages.isNotEmpty;
    _notify();
  }

  void setLegacyBusy(bool value) {
    isBusy = value;
  }

  void setLegacyStatus(String? value) {
    status = value;
  }

  void reset() {
    unawaited(cancelActive());
    messages.clear();
    hasStarted = false;
    conversationId = null;
    pendingNavigation = null;
    errorMessage = null;
    status = null;
    _notify();
  }

  Future<void> dispose() => cancelActive();

  String _publicError(Object error) {
    if (error is AskTransportException) return error.message;
    return 'Ask FindEZ could not complete that request. Please try again.';
  }

  void _notify() => _onStateChanged?.call();
}
