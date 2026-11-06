class ChatChoice {
  const ChatChoice(this.label, this.detail, this.reply, this.kind);
  final String label, detail, reply, kind;
}

class ChatQuestion {
  const ChatQuestion(this.id, this.prompt, this.choices);
  final String id, prompt;
  final List<ChatChoice> choices;
  static ChatQuestion? parse(dynamic raw) {
    if (raw is! Map) return null;
    bool text(dynamic v, int limit) =>
        v is String && v.trim().isNotEmpty && v.length <= limit;
    if (!text(raw['id'], 80) ||
        !text(raw['prompt'], 160) ||
        raw['choices'] is! List) {
      return null;
    }
    final rows = raw['choices'] as List;
    if (rows.length < 2 || rows.length > 4) return null;
    final choices = <ChatChoice>[];
    for (final row in rows) {
      if (row is! Map ||
          !text(row['label'], 100) ||
          !text(row['reply'], 700) ||
          row['detail'] is! String ||
          (row['detail'] as String).length > 250 ||
          !const [
            'answer',
            'existing_space',
            'new_space',
          ].contains(row['kind'])) {
        return null;
      }
      choices.add(
        ChatChoice(row['label'], row['detail'], row['reply'], row['kind']),
      );
    }
    return ChatQuestion(raw['id'], raw['prompt'], List.unmodifiable(choices));
  }
}
