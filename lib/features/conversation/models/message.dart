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
}
