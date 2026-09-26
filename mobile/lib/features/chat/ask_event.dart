enum AskEventType { status, delta, conversation, navigation, error, done }

class AskEvent {
  const AskEvent._({
    required this.type,
    this.message,
    this.conversationId,
    this.navigation,
  });

  const AskEvent.status(String message)
    : this._(type: AskEventType.status, message: message);

  const AskEvent.delta(String content)
    : this._(type: AskEventType.delta, message: content);

  const AskEvent.conversation(String conversationId)
    : this._(type: AskEventType.conversation, conversationId: conversationId);

  const AskEvent.navigation(Map<String, dynamic> navigation)
    : this._(type: AskEventType.navigation, navigation: navigation);

  const AskEvent.error(String message)
    : this._(type: AskEventType.error, message: message);

  const AskEvent.done() : this._(type: AskEventType.done);

  final AskEventType type;
  final String? message;
  final String? conversationId;
  final Map<String, dynamic>? navigation;
}
