import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import '../models/scene_runtime_node.dart';
import 'scene_runtime_component_tree.dart';
import 'scene_runtime_transform_composer.dart';
import 'scene_slot_layout_models.dart';

class SceneSlotLayoutSolver {
  const SceneSlotLayoutSolver();

  static const String proofTag = 'TF_SCENE_SLOT_LAYOUT_PROOF';
  static const String proportionalProofTag =
      'TF_SCENE_PROPORTIONAL_RULES_PROOF';

  SceneSlotLayoutSolveResult solve({
    required SceneRuntimeComponentTree tree,
    required SceneRuntimeCompositionResult composition,
  }) {
    final slotBoundsByNodeId = <String, SceneSlotLayoutRect>{};
    final contentBoundsByComponentNodeId = <String, SceneSlotLayoutRect>{};
    final issues = <SceneSlotLayoutIssue>[];
    final aspectPolicy = _aspectPolicyFor(composition);

    final components = tree.nodeById.values
        .where((node) => node.nodeType == SceneRuntimeNodeType.component)
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    for (final component in components) {
      final componentRecord = composition.recordsByNodeId[component.id];
      if (componentRecord == null) {
        continue;
      }
      final slotNodes = tree
          .children(component.id)
          .where((node) => node.nodeType == SceneRuntimeNodeType.slot)
          .toList(growable: false);
      if (slotNodes.isEmpty) {
        continue;
      }

      final componentRect = SceneSlotLayoutRect(
        left: componentRecord.worldBounds.left,
        top: componentRecord.worldBounds.top,
        right: componentRecord.worldBounds.right,
        bottom: componentRecord.worldBounds.bottom,
      );
      final contentRect =
          _contentRectFor(component: component, bounds: componentRect);
      if (contentRect.width <= 0 || contentRect.height <= 0) {
        issues.add(
          SceneSlotLayoutIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: 'invalid_content_bounds',
            message:
                'Component `${component.id}` produced invalid content bounds.',
            path: 'runtimeTree.nodes.${component.id}',
          ),
        );
        continue;
      }

      contentBoundsByComponentNodeId[component.id] = contentRect;
      final slotRects = _solveSlotRects(
        component: component,
        slotNodes: slotNodes,
        contentRect: contentRect,
        aspectPolicy: aspectPolicy,
      );
      for (final entry in slotRects.entries) {
        slotBoundsByNodeId[entry.key] = entry.value;
        final leafChildren = tree.children(entry.key);
        for (final leaf in leafChildren) {
          slotBoundsByNodeId[leaf.id] = entry.value;
        }
      }
      issues.add(
        SceneSlotLayoutIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          code: 'slot_layout_proof',
          message: '$proofTag componentId=${component.id} '
              'slotCount=${slotRects.length} '
              'contentBounds=${contentRect.toString()}',
          path: 'runtimeTree.nodes.${component.id}',
        ),
      );
      issues.addAll(
        _proportionalIssuesFor(
          component: component,
          componentRect: componentRect,
          contentRect: contentRect,
          slotRects: slotRects,
          aspectPolicy: aspectPolicy,
        ),
      );
    }

    final layoutHash = _layoutHash(
      slotBoundsByNodeId: slotBoundsByNodeId,
      contentBoundsByComponentNodeId: contentBoundsByComponentNodeId,
    );
    return SceneSlotLayoutSolveResult(
      slotBoundsByNodeId:
          Map<String, SceneSlotLayoutRect>.unmodifiable(slotBoundsByNodeId),
      contentBoundsByComponentNodeId:
          Map<String, SceneSlotLayoutRect>.unmodifiable(
              contentBoundsByComponentNodeId),
      issues: List<SceneSlotLayoutIssue>.unmodifiable(issues),
      deterministicLayoutHash: layoutHash,
    );
  }

  SceneSlotLayoutRect _contentRectFor({
    required SceneRuntimeNode component,
    required SceneSlotLayoutRect bounds,
  }) {
    final insets = _readInsets(component.metadata);
    return bounds.inset(
      left: insets.left,
      top: insets.top,
      right: insets.right,
      bottom: insets.bottom,
    );
  }

  ({double left, double top, double right, double bottom}) _readInsets(
    Map<String, Object?> metadata,
  ) {
    final map = _map(metadata['contentInsets']);
    if (map != null) {
      return (
        left: _double(map['left']) ?? 0.0,
        top: _double(map['top']) ?? 0.0,
        right: _double(map['right']) ?? 0.0,
        bottom: _double(map['bottom']) ?? 0.0,
      );
    }
    final componentType =
        _normalize((metadata['componentType'] as String?) ?? '');
    if (componentType == 'promptinputbar') {
      return (left: 44.0, top: 16.0, right: 124.0, bottom: 16.0);
    }
    if (componentType == 'featurecard') {
      return (left: 27.0, top: 27.0, right: 27.0, bottom: 27.0);
    }
    if (componentType == 'ctabutton') {
      return (left: 20.0, top: 12.0, right: 20.0, bottom: 12.0);
    }
    return (left: 0.0, top: 0.0, right: 0.0, bottom: 0.0);
  }

  Map<String, SceneSlotLayoutRect> _solveSlotRects({
    required SceneRuntimeNode component,
    required List<SceneRuntimeNode> slotNodes,
    required SceneSlotLayoutRect contentRect,
    required _AspectPolicy aspectPolicy,
  }) {
    final byNodeId = <String, SceneSlotLayoutRect>{};
    final normalizedBySlot = <String, SceneRuntimeNode>{};
    for (final slotNode in slotNodes) {
      final slot = _normalize(slotNode.slotId ?? '');
      if (slot.isNotEmpty) {
        normalizedBySlot[slot] = slotNode;
      }
    }
    final componentType =
        _normalize((component.metadata['componentType'] as String?) ?? '');

    if (componentType == 'promptinputbar' &&
        normalizedBySlot.containsKey('primarytext') &&
        normalizedBySlot.containsKey('trailingaccessory')) {
      final trailingNode = normalizedBySlot['trailingaccessory']!;
      final textNode = normalizedBySlot['primarytext']!;
      final leadingNode = normalizedBySlot['leadingaccessory'];
      final trailingWidth = math.min(124.0, contentRect.width * 0.32);
      final leadingWidth =
          leadingNode == null ? 0.0 : math.min(92.0, contentRect.width * 0.22);
      if (leadingNode != null) {
        byNodeId[leadingNode.id] = SceneSlotLayoutRect(
          left: contentRect.left,
          top: contentRect.top,
          right: contentRect.left + leadingWidth,
          bottom: contentRect.bottom,
        );
      }
      byNodeId[trailingNode.id] = SceneSlotLayoutRect(
        left: contentRect.right - trailingWidth,
        top: contentRect.top,
        right: contentRect.right,
        bottom: contentRect.bottom,
      );
      byNodeId[textNode.id] = SceneSlotLayoutRect(
        left: contentRect.left + leadingWidth,
        top: contentRect.top,
        right: contentRect.right - trailingWidth,
        bottom: contentRect.bottom,
      );
      return byNodeId;
    }

    if (componentType == 'featurecard' &&
        normalizedBySlot.containsKey('title') &&
        normalizedBySlot.containsKey('body')) {
      final titleNode = normalizedBySlot['title']!;
      final bodyNode = normalizedBySlot['body']!;
      final iconNode =
          normalizedBySlot['leadingicon'] ?? normalizedBySlot['icon'];
      final iconReserve =
          iconNode == null ? 0.0 : math.min(92.0, contentRect.width * 0.22);
      if (iconNode != null) {
        byNodeId[iconNode.id] = SceneSlotLayoutRect(
          left: contentRect.left,
          top: contentRect.top,
          right: contentRect.left + iconReserve,
          bottom: contentRect.bottom,
        );
      }
      final textLeft =
          contentRect.left + (iconNode == null ? 0.0 : iconReserve + 16.0);
      final headerHeight = contentRect.height * 0.34;
      byNodeId[titleNode.id] = SceneSlotLayoutRect(
        left: textLeft,
        top: contentRect.top,
        right: contentRect.right,
        bottom: contentRect.top + headerHeight,
      );
      byNodeId[bodyNode.id] = SceneSlotLayoutRect(
        left: textLeft,
        top: contentRect.top + headerHeight,
        right: contentRect.right,
        bottom: contentRect.bottom,
      );
      for (final slotNode in slotNodes) {
        if (byNodeId.containsKey(slotNode.id)) {
          continue;
        }
        byNodeId[slotNode.id] = _defaultBadgeBounds(contentRect);
      }
      return byNodeId;
    }

    final ordered = slotNodes.toList(growable: false)
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    final columns = _fallbackColumnsFor(
      count: ordered.length,
      aspectPolicy: aspectPolicy,
    );
    final rows = (ordered.length / columns).ceil();
    final cellWidth = contentRect.width / columns;
    final cellHeight = contentRect.height / rows;
    for (var i = 0; i < ordered.length; i += 1) {
      final col = i % columns;
      final row = i ~/ columns;
      final left = contentRect.left + (col * cellWidth);
      final top = contentRect.top + (row * cellHeight);
      byNodeId[ordered[i].id] = SceneSlotLayoutRect(
        left: left,
        top: top,
        right: left + cellWidth,
        bottom: top + cellHeight,
      );
    }
    return byNodeId;
  }

  SceneSlotLayoutRect _defaultBadgeBounds(SceneSlotLayoutRect contentRect) {
    final width = math.min(180.0, contentRect.width * 0.42);
    final height = math.min(52.0, contentRect.height * 0.28);
    return SceneSlotLayoutRect(
      left: contentRect.right - width,
      top: contentRect.top,
      right: contentRect.right,
      bottom: contentRect.top + height,
    );
  }

  List<SceneSlotLayoutIssue> _proportionalIssuesFor({
    required SceneRuntimeNode component,
    required SceneSlotLayoutRect componentRect,
    required SceneSlotLayoutRect contentRect,
    required Map<String, SceneSlotLayoutRect> slotRects,
    required _AspectPolicy aspectPolicy,
  }) {
    final issues = <SceneSlotLayoutIssue>[];
    final componentType =
        _normalize((component.metadata['componentType'] as String?) ?? '');
    final widthRatio = componentRect.width == 0.0
        ? 0.0
        : contentRect.width / componentRect.width;
    final horizontalPadding =
        math.max(0.0, (componentRect.width - contentRect.width) / 2.0);
    final verticalPadding =
        math.max(0.0, (componentRect.height - contentRect.height) / 2.0);

    if (componentType == 'featurecard') {
      const titleFontSize = 35.0;
      const bodyFontSize = 18.0;
      final minWidth = titleFontSize * 6.0;
      final minPadding = bodyFontSize * 1.5;
      if (componentRect.width < minWidth) {
        issues.add(
          SceneSlotLayoutIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: 'feature_card_min_width_violation',
            message:
                'FeatureCard `${component.id}` width=${componentRect.width.toStringAsFixed(1)} < minWidth=${minWidth.toStringAsFixed(1)}.',
            path: 'runtimeTree.nodes.${component.id}',
          ),
        );
      }
      if (horizontalPadding < minPadding || verticalPadding < minPadding) {
        issues.add(
          SceneSlotLayoutIssue(
            severity: ReFusionSceneProgramIssueSeverity.warning,
            code: 'feature_card_min_padding_warning',
            message:
                'FeatureCard `${component.id}` padding below preferred min=${minPadding.toStringAsFixed(1)} (horizontal=${horizontalPadding.toStringAsFixed(1)}, vertical=${verticalPadding.toStringAsFixed(1)}).',
            path: 'runtimeTree.nodes.${component.id}',
          ),
        );
      }
      if (widthRatio < 0.60 || widthRatio > 0.75) {
        issues.add(
          SceneSlotLayoutIssue(
            severity: ReFusionSceneProgramIssueSeverity.warning,
            code: 'feature_card_content_ratio_warning',
            message:
                'FeatureCard `${component.id}` contentRatio=${widthRatio.toStringAsFixed(3)} outside preferred [0.60, 0.75].',
            path: 'runtimeTree.nodes.${component.id}',
          ),
        );
      }
      final iconRect = _slotByName(slotRects, 'leadingicon') ??
          _slotByName(slotRects, 'icon');
      final titleRect = _slotByName(slotRects, 'title');
      if (iconRect != null && titleRect != null && titleRect.height > 0.0) {
        final iconToHeading = iconRect.height / titleRect.height;
        if (iconToHeading < 1.1 || iconToHeading > 1.8) {
          issues.add(
            SceneSlotLayoutIssue(
              severity: ReFusionSceneProgramIssueSeverity.warning,
              code: 'feature_card_icon_heading_ratio_warning',
              message:
                  'FeatureCard `${component.id}` icon/title ratio=${iconToHeading.toStringAsFixed(3)} outside preferred [1.10, 1.80].',
              path: 'runtimeTree.nodes.${component.id}',
            ),
          );
        }
      }
    }

    if (componentType == 'promptinputbar' &&
        (widthRatio < 0.60 || widthRatio > 0.82)) {
      issues.add(
        SceneSlotLayoutIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          code: 'prompt_content_ratio_warning',
          message:
              'PromptInputBar `${component.id}` contentRatio=${widthRatio.toStringAsFixed(3)} outside preferred [0.60, 0.82].',
          path: 'runtimeTree.nodes.${component.id}',
        ),
      );
    }
    if (componentType == 'promptinputbar') {
      if (componentRect.width < 560.0 ||
          componentRect.width > 980.0 ||
          componentRect.height < 84.0 ||
          componentRect.height > 140.0) {
        issues.add(
          SceneSlotLayoutIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: 'prompt_intrinsic_bounds_violation',
            message:
                'PromptInputBar `${component.id}` resolved bounds ${componentRect.width.toStringAsFixed(1)}x${componentRect.height.toStringAsFixed(1)} outside intrinsic range 560-980x84-140.',
            path: 'runtimeTree.nodes.${component.id}',
          ),
        );
      }
    }

    issues.add(
      SceneSlotLayoutIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        code: 'proportional_rules_proof',
        message: '$proportionalProofTag '
            'componentId=${component.id} '
            'componentType=$componentType '
            'aspectPolicy=${aspectPolicy.name} '
            'contentRatio=${widthRatio.toStringAsFixed(3)} '
            'horizontalPadding=${horizontalPadding.toStringAsFixed(1)} '
            'verticalPadding=${verticalPadding.toStringAsFixed(1)}',
        path: 'runtimeTree.nodes.${component.id}',
      ),
    );

    return issues;
  }

  SceneSlotLayoutRect? _slotByName(
    Map<String, SceneSlotLayoutRect> slotRects,
    String slotName,
  ) {
    for (final entry in slotRects.entries) {
      if (_normalize(entry.key).contains(slotName)) {
        return entry.value;
      }
    }
    return null;
  }

  _AspectPolicy _aspectPolicyFor(SceneRuntimeCompositionResult composition) {
    final root = composition.recordsByNodeId['__scene_root__'];
    if (root == null || root.worldBounds.height == 0.0) {
      return _AspectPolicy.portrait;
    }
    final ratio = root.worldBounds.width / root.worldBounds.height;
    if ((ratio - 1.0).abs() <= 0.08) {
      return _AspectPolicy.square;
    }
    if ((ratio - 0.8).abs() <= 0.06) {
      return _AspectPolicy.portraitFeed;
    }
    if (ratio >= 1.45) {
      return _AspectPolicy.landscape;
    }
    return _AspectPolicy.portrait;
  }

  int _fallbackColumnsFor({
    required int count,
    required _AspectPolicy aspectPolicy,
  }) {
    if (count <= 1) {
      return 1;
    }
    switch (aspectPolicy) {
      case _AspectPolicy.landscape:
        return count;
      case _AspectPolicy.square:
        return math.min(2, count);
      case _AspectPolicy.portraitFeed:
      case _AspectPolicy.portrait:
        return 1;
    }
  }

  String _layoutHash({
    required Map<String, SceneSlotLayoutRect> slotBoundsByNodeId,
    required Map<String, SceneSlotLayoutRect> contentBoundsByComponentNodeId,
  }) {
    final slotLines = slotBoundsByNodeId.keys.toList(growable: false)..sort();
    final contentLines =
        contentBoundsByComponentNodeId.keys.toList(growable: false)..sort();
    final data = <String>[
      ...slotLines.map((id) => '$id:${slotBoundsByNodeId[id].toString()}'),
      ...contentLines
          .map((id) => '$id:${contentBoundsByComponentNodeId[id].toString()}'),
    ].join('|');
    return data;
  }

  Map<String, Object?>? _map(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      final output = <String, Object?>{};
      value.forEach((key, val) {
        output[key.toString()] = val;
      });
      return output;
    }
    return null;
  }

  double? _double(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  String _normalize(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').toLowerCase();
  }
}

enum _AspectPolicy {
  portrait,
  landscape,
  square,
  portraitFeed,
}
