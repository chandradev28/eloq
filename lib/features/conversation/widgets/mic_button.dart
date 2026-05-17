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
      width: isRecording ? 82 : 72,
      height: isRecording ? 82 : 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.42),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(isRecording ? 0.52 : 0.26),
            blurRadius: isRecording ? 26 : 18,
            spreadRadius: isRecording ? 5 : 1,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          tooltip: isRecording ? 'Stop recording' : 'Start recording',
          iconSize: 30,
          color: isRecording ? AppColors.accentRed : AppColors.accentPurple,
          icon: Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
