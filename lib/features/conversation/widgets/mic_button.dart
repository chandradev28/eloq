import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class MicButton extends StatelessWidget {
  const MicButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
  });

  final bool isRecording;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: isRecording ? 92 : 80,
      height: isRecording ? 92 : 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.accentPurple, AppColors.accentTeal],
        ),
        boxShadow: [
          BoxShadow(
            color: (isRecording ? AppColors.accentTeal : AppColors.accentPurple)
                .withOpacity(isRecording ? 0.45 : 0.2),
            blurRadius: isRecording ? 34 : 18,
            spreadRadius: isRecording ? 6 : 1,
          ),
        ],
      ),
      child: IconButton(
        tooltip: isRecording ? 'Stop recording' : 'Start recording',
        iconSize: 34,
        color: AppColors.textPrimary,
        icon: Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded),
        onPressed: onPressed,
      ),
    );
  }
}
