import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'fx_icon_button.dart';

class EditorToolsBar extends StatelessWidget {
  const EditorToolsBar({
    super.key,
    this.embedded = false,
    this.isPlaying = false,
    this.onSplit,
    this.onTrimToggle,
    this.isTrimModeActive = false,
    this.onDuplicate,
    this.onDelete,
    this.onPlayToggle,
  });

  final bool embedded;
  final bool isPlaying;
  final VoidCallback? onSplit;
  final VoidCallback? onTrimToggle;
  final bool isTrimModeActive;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final VoidCallback? onPlayToggle;

  @override
  Widget build(BuildContext context) {
    final toolButtons = <Widget>[
      FxIconButton(
        icon: Icons.cut_rounded,
        size: 30,
        iconScale: 0.4,
        onPressed: onSplit,
      ),
      const SizedBox(width: 5),
      FxIconButton(
        icon: Icons.fit_screen_rounded,
        size: 30,
        iconScale: 0.4,
        foregroundColor:
            isTrimModeActive ? FxPalette.background : FxPalette.textMuted,
        backgroundColor:
            isTrimModeActive ? FxPalette.accent : FxPalette.surface,
        onPressed: onTrimToggle,
      ),
      const SizedBox(width: 5),
      FxIconButton(
        icon: Icons.copy_rounded,
        size: 30,
        iconScale: 0.4,
        onPressed: onDuplicate,
      ),
      const SizedBox(width: 5),
      FxIconButton(
        icon: Icons.delete_outline_rounded,
        size: 30,
        iconScale: 0.4,
        onPressed: onDelete,
      ),
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: embedded ? Colors.transparent : FxPalette.surface,
        borderRadius: BorderRadius.circular(embedded ? 0 : 16),
        border:
            embedded ? null : Border.all(color: FxPalette.divider, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                child: Row(children: toolButtons),
              ),
            ),
          ),
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
