import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/timeline_time.dart';
import '../services/composition_workspace_outliner_adapter.dart';

const Color _outlinerWarning = Color(0xFFE4B955);

class CompositionWorkspaceOutlinerBottomSheet extends StatelessWidget {
  const CompositionWorkspaceOutlinerBottomSheet({
    super.key,
    required this.result,
  });

  final CompositionWorkspaceOutlinerResult result;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.44,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: FxPalette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: FxPalette.divider, width: 1),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 58,
                  height: 5,
                  decoration: BoxDecoration(
                    color: FxPalette.dividerSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_tree_rounded,
                        color: FxPalette.textPrimary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Outliner',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: FxPalette.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      Text(
                        '${result.flattened.length} items',
                        style: const TextStyle(
                          color: FxPalette.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (result.hasIssues)
                  _OutlinerIssuesBanner(issues: result.issues),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 22),
                    children: [
                      _OutlinerNodeTile(
                        node: result.root,
                        depth: 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OutlinerIssuesBanner extends StatelessWidget {
  const _OutlinerIssuesBanner({
    required this.issues,
  });

  final List<CompositionWorkspaceOutlinerIssue> issues;

  @override
  Widget build(BuildContext context) {
    final firstIssue = issues.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _outlinerWarning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outlinerWarning.withOpacity(0.36)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: _outlinerWarning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  firstIssue.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FxPalette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinerNodeTile extends StatelessWidget {
  const _OutlinerNodeTile({
    required this.node,
    required this.depth,
  });

  final CompositionWorkspaceOutlinerNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final canSelect = _canSelect(node);
    final childTiles = <Widget>[
      for (final child in node.children)
        _OutlinerNodeTile(
          node: child,
          depth: depth + 1,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 14.0, bottom: 4),
          child: Material(
            color: node.isSelected
                ? FxPalette.accent.withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: canSelect ? () => Navigator.of(context).pop(node) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(node.kind),
                      color: node.isSelected
                          ? FxPalette.accent
                          : _iconColorFor(node),
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: node.isEnabled
                                  ? FxPalette.textPrimary
                                  : FxPalette.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          if (_subtitleFor(node) != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _subtitleFor(node)!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FxPalette.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (node.isLocked)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: FxPalette.textMuted,
                          size: 15,
                        ),
                      ),
                    if (node.hasChildren)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: FxPalette.textMuted,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ...childTiles,
      ],
    );
  }

  bool _canSelect(CompositionWorkspaceOutlinerNode node) {
    switch (node.kind) {
      case CompositionWorkspaceOutlinerNodeKind.sceneClipInstance:
      case CompositionWorkspaceOutlinerNodeKind.sourceComposition:
      case CompositionWorkspaceOutlinerNodeKind.layer:
      case CompositionWorkspaceOutlinerNodeKind.element:
      case CompositionWorkspaceOutlinerNodeKind.channel:
      case CompositionWorkspaceOutlinerNodeKind.rootBackgroundLayer:
        return true;
      case CompositionWorkspaceOutlinerNodeKind.project:
      case CompositionWorkspaceOutlinerNodeKind.assetsGroup:
      case CompositionWorkspaceOutlinerNodeKind.rootComposition:
      case CompositionWorkspaceOutlinerNodeKind.backgroundLayersGroup:
      case CompositionWorkspaceOutlinerNodeKind.sceneClipsGroup:
      case CompositionWorkspaceOutlinerNodeKind.sourceCompositionsGroup:
        return false;
    }
  }

  Color _iconColorFor(CompositionWorkspaceOutlinerNode node) {
    if (!node.isEnabled) {
      return FxPalette.textMuted.withOpacity(0.56);
    }
    switch (node.kind) {
      case CompositionWorkspaceOutlinerNodeKind.sceneClipInstance:
      case CompositionWorkspaceOutlinerNodeKind.sourceComposition:
      case CompositionWorkspaceOutlinerNodeKind.rootComposition:
        return FxPalette.accent;
      case CompositionWorkspaceOutlinerNodeKind.rootBackgroundLayer:
        return _outlinerWarning;
      case CompositionWorkspaceOutlinerNodeKind.layer:
      case CompositionWorkspaceOutlinerNodeKind.element:
      case CompositionWorkspaceOutlinerNodeKind.channel:
        return FxPalette.textPrimary;
      case CompositionWorkspaceOutlinerNodeKind.project:
      case CompositionWorkspaceOutlinerNodeKind.assetsGroup:
      case CompositionWorkspaceOutlinerNodeKind.backgroundLayersGroup:
      case CompositionWorkspaceOutlinerNodeKind.sceneClipsGroup:
      case CompositionWorkspaceOutlinerNodeKind.sourceCompositionsGroup:
        return FxPalette.textMuted;
    }
  }

  IconData _iconFor(CompositionWorkspaceOutlinerNodeKind kind) {
    return switch (kind) {
      CompositionWorkspaceOutlinerNodeKind.project =>
        Icons.folder_special_rounded,
      CompositionWorkspaceOutlinerNodeKind.assetsGroup =>
        Icons.inventory_2_outlined,
      CompositionWorkspaceOutlinerNodeKind.rootComposition =>
        Icons.dashboard_customize_rounded,
      CompositionWorkspaceOutlinerNodeKind.backgroundLayersGroup =>
        Icons.layers_outlined,
      CompositionWorkspaceOutlinerNodeKind.rootBackgroundLayer =>
        Icons.wallpaper_rounded,
      CompositionWorkspaceOutlinerNodeKind.sceneClipsGroup =>
        Icons.auto_awesome_motion_rounded,
      CompositionWorkspaceOutlinerNodeKind.sceneClipInstance =>
        Icons.dashboard_rounded,
      CompositionWorkspaceOutlinerNodeKind.sourceCompositionsGroup =>
        Icons.account_tree_rounded,
      CompositionWorkspaceOutlinerNodeKind.sourceComposition =>
        Icons.snippet_folder_rounded,
      CompositionWorkspaceOutlinerNodeKind.layer => Icons.layers_rounded,
      CompositionWorkspaceOutlinerNodeKind.element => Icons.category_rounded,
      CompositionWorkspaceOutlinerNodeKind.channel => Icons.timeline_rounded,
    };
  }

  String? _subtitleFor(CompositionWorkspaceOutlinerNode node) {
    final range = node.rootRange;
    final zIndex = node.zIndex;
    final parts = <String>[];
    if (range != null) {
      parts.add(
        '${_seconds(range.start)}s - ${_seconds(range.endExclusive)}s',
      );
    }
    if (zIndex != null) {
      parts.add('z $zIndex');
    }
    if (node.channelId != null) {
      parts.add('editable channel');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('  ');
  }

  String _seconds(TimelineTime time) {
    final seconds = time.inSecondsDouble;
    return seconds
        .toStringAsFixed(seconds.truncateToDouble() == seconds ? 0 : 2);
  }
}
