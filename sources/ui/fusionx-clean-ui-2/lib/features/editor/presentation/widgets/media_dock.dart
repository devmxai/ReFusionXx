import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/editor_media_tab.dart';

class MediaDock extends StatelessWidget {
  const MediaDock({
    super.key,
    required this.activeTab,
    required this.onAddTap,
    required this.onToolTap,
    this.onSceneTap,
    this.enabledTabs,
    this.addEnabled = true,
    this.embedded = false,
  });

  final EditorMediaTab activeTab;
  final VoidCallback onAddTap;
  final ValueChanged<EditorMediaTab> onToolTap;
  final VoidCallback? onSceneTap;
  final Set<EditorMediaTab>? enabledTabs;
  final bool addEnabled;
  final bool embedded;

  static const List<EditorMediaTab> _toolTabs = <EditorMediaTab>[
    EditorMediaTab.audio,
    EditorMediaTab.text,
    EditorMediaTab.speed,
    EditorMediaTab.lipSync,
  ];

  bool get _isAddActive =>
      addEnabled &&
      (activeTab == EditorMediaTab.video || activeTab == EditorMediaTab.image);

  bool _isToolEnabled(EditorMediaTab tab) => enabledTabs?.contains(tab) ?? true;

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
          Expanded(
            child: _DockButton(
              icon: Icons.add_rounded,
              label: 'Add',
              isActive: _isAddActive,
              onTap: _isAddActive ? onAddTap : null,
            ),
          ),
          Expanded(
            child: _DockButton(
              icon: Icons.auto_awesome_motion_rounded,
              label: 'Scene',
              isActive: false,
              onTap: onSceneTap,
            ),
          ),
          for (final tab in _toolTabs)
            Expanded(
              child: _DockButton(
                icon: tab.icon,
                label: tab.label,
                isActive: tab == activeTab,
                onTap: _isToolEnabled(tab) ? () => onToolTap(tab) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
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
