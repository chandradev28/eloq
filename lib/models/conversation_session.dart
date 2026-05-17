import '../features/conversation/models/message.dart';
import 'grammar_correction.dart';

class ConversationSession {
  const ConversationSession({
    required this.id,
    required this.topicId,
    required this.topicName,
    required this.startedAt,
    required this.updatedAt,
    this.messages = const [],
    this.provider = 'demo',
  });

  final String id;
  final String topicId;
  final String topicName;
  final DateTime startedAt;
  final DateTime updatedAt;
  final List<Message> messages;
  final String provider;

  int get userTurns => messages.where((item) => item.isUser).length;
  int get correctionCount => corrections.length;

  List<GrammarCorrection> get corrections {
    return messages.expand((message) => message.corrections).toList();
  }

  String get preview {
    final userMessage = messages.where((item) => item.isUser).lastOrNull;
    return userMessage?.text ?? 'Started practice';
  }

  ConversationSession copyWith({
    DateTime? updatedAt,
    List<Message>? messages,
    String? provider,
  }) {
    return ConversationSession(
      id: id,
      topicId: topicId,
      topicName: topicName,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      provider: provider ?? this.provider,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'topicId': topicId,
        'topicName': topicName,
        'startedAt': startedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((item) => item.toJson()).toList(),
        'provider': provider,
      };

  factory ConversationSession.fromJson(Map<dynamic, dynamic> json) {
    return ConversationSession(
      id: json['id']?.toString() ?? '',
      topicId: json['topicId']?.toString() ?? '',
      topicName: json['topicName']?.toString() ?? 'Practice',
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      messages: (json['messages'] as List?)
              ?.whereType<Map>()
              .map(Message.fromJson)
              .toList() ??
          const [],
      provider: json['provider']?.toString() ?? 'demo',
    );
  }
}
