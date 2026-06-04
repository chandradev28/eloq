import 'package:flutter/material.dart';

enum VoicePracticeMode {
  nativeAudio,
  standard,
}

class VoiceModeSwitch extends StatelessWidget {
  const VoiceModeSwitch({
    super.key,
    required this.selectedMode,
    required this.onNativeTap,
    required this.onStandardTap,
  });

  final VoicePracticeMode selectedMode;
  final VoidCallback onNativeTap;
  final VoidCallback onStandardTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 258,
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          _VoiceModeSegment(
            icon: Icons.graphic_eq_rounded,
            label: 'Native audio',
            selected: selectedMode == VoicePracticeMode.nativeAudio,
            onTap: onNativeTap,
          ),
          const SizedBox(width: 4),
          _VoiceModeSegment(
            icon: Icons.mic_rounded,
            label: 'Standard',
            selected: selectedMode == VoicePracticeMode.standard,
            onTap: onStandardTap,
          ),
        ],
      ),
    );
  }
}

class _VoiceModeSegment extends StatelessWidget {
  const _VoiceModeSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.black : Colors.white.withOpacity(0.82);
    return Expanded(
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: selected ? null : onTap,
          child: SizedBox.expand(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
