import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'fx_icon_button.dart';

class TransitionFocusToolsBar extends StatelessWidget {
  const TransitionFocusToolsBar({
    super.key,
    required this.isPlaying,
    required this.onBack,
    required this.onFrameToolsTap,
    required this.onMoveToKeyframe,
    required this.onPlayToggle,
  });

  final bool isPlaying;
  final VoidCallback onBack;
  final VoidCallback? onFrameToolsTap;
  final VoidCallback? onMoveToKeyframe;
  final VoidCallback? onPlayToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          FxIconButton(
            icon: Icons.arrow_back_rounded,
            size: 30,
            iconScale: 0.46,
            foregroundColor: FxPalette.textPrimary,
            onPressed: onBack,
          ),
          const SizedBox(width: 5),
          FxIconButton(
            icon: Icons.auto_graph_rounded,
            size: 30,
            iconScale: 0.45,
            foregroundColor: FxPalette.textPrimary,
            onPressed: onFrameToolsTap,
          ),
          const SizedBox(width: 5),
          FxIconButton(
            icon: Icons.open_with_rounded,
            size: 30,
            iconScale: 0.4,
            foregroundColor: onMoveToKeyframe == null
                ? FxPalette.textMuted.withOpacity(0.42)
                : FxPalette.textPrimary,
            onPressed: onMoveToKeyframe,
          ),
          const Spacer(),
          Container(
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 1,
            color: FxPalette.dividerSoft.withOpacity(0.9),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: FxIconButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 32,
              iconScale: 0.48,
              foregroundColor: FxPalette.textPrimary,
              onPressed: onPlayToggle,
            ),
          ),
        ],
      ),
    );
  }
}
