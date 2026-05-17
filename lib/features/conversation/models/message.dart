import '../../../models/grammar_correction.dart';

enum MessageRole { user, assistant }

class Message {
  const Message({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.corrections = const [],
  });

  final String id;
  final MessageRole role;
  final String text;
  final DateTime createdAt;
  final List<GrammarCorrection> corrections;

  bool get isUser => role == MessageRole.user;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'corrections': corrections.map((item) => item.toJson()).toList(),
      };

  factory Message.fromJson(Map<dynamic, dynamic> json) {
    final roleName = json['role']?.toString() ?? MessageRole.assistant.name;
    return Message(
      id: json['id']?.toString() ?? '',
      role: MessageRole.values.firstWhere(
        (item) => item.name == roleName,
        orElse: () => MessageRole.assistant,
      ),
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      corrections: (json['corrections'] as List?)
              ?.whereType<Map>()
              .map((item) =>
                  GrammarCorrection.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          const [],
    );
  }
}
