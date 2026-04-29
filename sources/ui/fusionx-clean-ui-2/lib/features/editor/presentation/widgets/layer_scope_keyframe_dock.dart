import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class LayerScopeKeyframeDock extends StatelessWidget {
  const LayerScopeKeyframeDock({
    super.key,
    required this.addEnabled,
    required this.keyframeEnabled,
    required this.valueEnabled,
    required this.graphEnabled,
    required this.isValueActive,
    required this.isGraphActive,
    required this.onAddTap,
    required this.onAddKeyframeTap,
    required this.onValueTap,
    required this.onGraphTap,
    this.embedded = false,
    this.showAddButton = true,
    this.showAnimateButton = false,
    this.showFxButton = false,
    this.animateEnabled = false,
    this.fxEnabled = false,
    this.onAnimateTap,
    this.onFxTap,
    this.animateLabel = 'Animate',
    this.fxLabel = 'FX',
    this.animateIcon = Icons.auto_awesome_motion_rounded,
    this.fxIcon = Icons.auto_fix_high_rounded,
    this.addLabel = 'Add',
    this.addIcon = Icons.add_rounded,
  });

  final bool addEnabled;
  final bool keyframeEnabled;
  final bool valueEnabled;
  final bool graphEnabled;
  final bool isValueActive;
  final bool isGraphActive;
  final VoidCallback? onAddTap;
  final VoidCallback? onAddKeyframeTap;
  final VoidCallback? onValueTap;
  final VoidCallback? onGraphTap;
  final bool embedded;
  final bool showAddButton;
  final bool showAnimateButton;
  final bool showFxButton;
  final bool animateEnabled;
  final bool fxEnabled;
  final VoidCallback? onAnimateTap;
  final VoidCallback? onFxTap;
  final String animateLabel;
  final String fxLabel;
  final IconData animateIcon;
  final IconData fxIcon;
  final String addLabel;
  final IconData addIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: embedded ? Colors.transparent : FxPalette.surface,
        borderRadius: BorderRadius.circular(embedded ? 0 : 18),
        border:
            embedded ? null : Border.all(color: FxPalette.divider, width: 1),
      ),
      child: Row(
        children: [
          if (showAnimateButton)
            Expanded(
              child: _LayerScopeDockButton(
                icon: animateIcon,
                label: animateLabel,
                isActive: false,
                onTap: animateEnabled ? onAnimateTap : null,
              ),
            ),
          if (showFxButton)
            Expanded(
              child: _LayerScopeDockButton(
                icon: fxIcon,
                label: fxLabel,
                isActive: false,
                onTap: fxEnabled ? onFxTap : null,
              ),
            ),
          if (showAddButton)
            Expanded(
              child: _LayerScopeDockButton(
                icon: addIcon,
                label: addLabel,
                isActive: false,
                onTap: addEnabled ? onAddTap : null,
              ),
            ),
          Expanded(
            child: _LayerScopeDockButton(
              icon: Icons.add_circle_outline_rounded,
              label: 'Key',
              isActive: false,
              onTap: keyframeEnabled ? onAddKeyframeTap : null,
            ),
          ),
          Expanded(
            child: _LayerScopeDockButton(
              icon: Icons.tune_rounded,
              label: 'Value',
              isActive: isValueActive,
              onTap: valueEnabled ? onValueTap : null,
            ),
          ),
          Expanded(
            child: _LayerScopeDockButton(
              icon: Icons.auto_graph_rounded,
              label: 'Graph',
              isActive: isGraphActive,
              onTap: graphEnabled ? onGraphTap : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerScopeDockButton extends StatelessWidget {
  const _LayerScopeDockButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive && onTap != null
              ? Colors.white.withOpacity(0.045)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: onTap == null
                  ? FxPalette.textMuted.withOpacity(0.5)
                  : isActive
                      ? FxPalette.textPrimary
                      : FxPalette.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: onTap == null
                    ? FxPalette.textMuted.withOpacity(0.5)
                    : isActive
                        ? FxPalette.textPrimary
                        : FxPalette.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
