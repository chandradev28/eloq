import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/message.dart';
import 'grammar_feedback.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isUser ? AppColors.accentPurple : AppColors.bgCard;
    final foreground = isUser ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 22),
                ),
                boxShadow: isUser
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.purpleDeep.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser ? 'You' : 'Eloq',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isUser
                              ? Colors.white.withOpacity(0.72)
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(message.text, style: TextStyle(color: foreground)),
                ],
              ),
            ),
            if (message.corrections.isNotEmpty)
              GrammarFeedback(corrections: message.corrections),
          ],
        ),
      ),
    );
  }
}
