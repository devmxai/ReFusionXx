import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../services/composition_workspace_inspector_adapter.dart';

const Color _inspectorWarning = Color(0xFFE4B955);
const Color _inspectorDanger = Color(0xFFFF6B7A);

class CompositionWorkspaceInspectorBottomSheet extends StatelessWidget {
  const CompositionWorkspaceInspectorBottomSheet({
    super.key,
    required this.result,
  });

  final CompositionWorkspaceInspectorResult result;

  @override
  Widget build(BuildContext context) {
    final model = result.model;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.38,
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
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Row(
                    children: [
                      Icon(
                        _iconFor(model?.targetKind),
                        color: FxPalette.textPrimary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inspector',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: FxPalette.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            if (model != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  model.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FxPalette.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: FxPalette.textMuted,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    children: [
                      if (result.hasIssues)
                        _InspectorIssuesBanner(issues: result.issues),
                      if (model != null) ...[
                        _InspectorTargetHeader(model: model),
                        const SizedBox(height: 12),
                        for (final section in model.sections)
                          _InspectorSectionView(section: section),
                      ],
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

  IconData _iconFor(CompositionWorkspaceInspectorTargetKind? kind) {
    return switch (kind) {
      CompositionWorkspaceInspectorTargetKind.rootComposition =>
        Icons.dashboard_customize_rounded,
      CompositionWorkspaceInspectorTargetKind.sceneClipInstance =>
        Icons.view_in_ar_rounded,
      CompositionWorkspaceInspectorTargetKind.sourceComposition =>
        Icons.account_tree_rounded,
      CompositionWorkspaceInspectorTargetKind.layer => Icons.layers_rounded,
      CompositionWorkspaceInspectorTargetKind.element => Icons.category_rounded,
      CompositionWorkspaceInspectorTargetKind.keyframe => Icons.diamond_rounded,
      null => Icons.tune_rounded,
    };
  }
}

class _InspectorTargetHeader extends StatelessWidget {
  const _InspectorTargetHeader({
    required this.model,
  });

  final CompositionWorkspaceInspectorModel model;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FxPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FxPalette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    model.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FxPalette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            if (model.hasEditableProperties)
              const Icon(
                Icons.edit_note_rounded,
                color: FxPalette.accent,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _InspectorSectionView extends StatelessWidget {
  const _InspectorSectionView({
    required this.section,
  });

  final CompositionWorkspaceInspectorSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FxPalette.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _iconFor(section.kind),
                    color: FxPalette.textMuted,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FxPalette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final property in section.properties)
                _InspectorPropertyRow(property: property),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(CompositionWorkspaceInspectorSectionKind kind) {
    return switch (kind) {
      CompositionWorkspaceInspectorSectionKind.format =>
        Icons.crop_landscape_rounded,
      CompositionWorkspaceInspectorSectionKind.timing => Icons.schedule_rounded,
      CompositionWorkspaceInspectorSectionKind.source => Icons.hub_rounded,
      CompositionWorkspaceInspectorSectionKind.transform =>
        Icons.open_with_rounded,
      CompositionWorkspaceInspectorSectionKind.style => Icons.palette_rounded,
      CompositionWorkspaceInspectorSectionKind.effects =>
        Icons.auto_fix_high_rounded,
      CompositionWorkspaceInspectorSectionKind.drawOrder =>
        Icons.layers_rounded,
      CompositionWorkspaceInspectorSectionKind.metadata => Icons.sell_rounded,
      CompositionWorkspaceInspectorSectionKind.graph => Icons.timeline_rounded,
    };
  }
}

class _InspectorPropertyRow extends StatelessWidget {
  const _InspectorPropertyRow({
    required this.property,
  });

  final CompositionWorkspaceInspectorProperty property;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              property.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FxPalette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    _formatPropertyValue(property),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: FxPalette.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (property.isEditable)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.edit_rounded,
                      color: FxPalette.accent,
                      size: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPropertyValue(CompositionWorkspaceInspectorProperty property) {
    final value = property.value;
    if (value == null) {
      return 'None';
    }
    final formatted = switch (property.kind) {
      CompositionWorkspaceInspectorPropertyKind.colorArgb =>
        _formatColor(value),
      CompositionWorkspaceInspectorPropertyKind.number => _formatNumber(value),
      CompositionWorkspaceInspectorPropertyKind.timeMs => '$value',
      _ => value.toString(),
    };
    final unit = property.unit;
    if (unit == null || unit.isEmpty) {
      return formatted;
    }
    return '$formatted $unit';
  }

  String _formatColor(Object value) {
    if (value is int) {
      return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    }
    return value.toString();
  }

  String _formatNumber(Object value) {
    if (value is num) {
      final doubleValue = value.toDouble();
      if (doubleValue == doubleValue.roundToDouble()) {
        return doubleValue.toInt().toString();
      }
      return doubleValue.toStringAsFixed(3);
    }
    return value.toString();
  }
}

class _InspectorIssuesBanner extends StatelessWidget {
  const _InspectorIssuesBanner({
    required this.issues,
  });

  final List<CompositionWorkspaceInspectorIssue> issues;

  @override
  Widget build(BuildContext context) {
    final firstIssue = issues.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: (issues.length > 1 ? _inspectorDanger : _inspectorWarning)
              .withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (issues.length > 1 ? _inspectorDanger : _inspectorWarning)
                .withOpacity(0.38),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                issues.length > 1
                    ? Icons.error_outline_rounded
                    : Icons.warning_amber_rounded,
                color: issues.length > 1 ? _inspectorDanger : _inspectorWarning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  firstIssue.message,
                  maxLines: 4,
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
