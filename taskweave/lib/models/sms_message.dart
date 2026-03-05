class SmsMessage {
  final String id;
  final String sender;
  final String body;
  final DateTime receivedAt;
  final bool processed;

  SmsMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.processed = false,
  });

  SmsMessage copyWith({
    String? id,
    String? sender,
    String? body,
    DateTime? receivedAt,
    bool? processed,
  }) {
    return SmsMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      receivedAt: receivedAt ?? this.receivedAt,
      processed: processed ?? this.processed,
    );
  }
}

class TodoSuggestion {
  final String suggestedTitle;
  final String? suggestedDescription;
  final DateTime? suggestedDeadline;
  final String sourceMessageId;
  final String sourceMessageSnippet;
  double confidence;

  TodoSuggestion({
    required this.suggestedTitle,
    this.suggestedDescription,
    this.suggestedDeadline,
    required this.sourceMessageId,
    required this.sourceMessageSnippet,
    this.confidence = 0.5,
  });
}
