import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import '../models/scene_runtime_node.dart';
import 'scene_runtime_component_tree.dart';
import 'scene_runtime_transform_composer.dart';
import 'scene_slot_layout_models.dart';

class SceneSlotLayoutSolver {
  const SceneSlotLayoutSolver();

  static const String proofTag = 'TF_SCENE_SLOT_LAYOUT_PROOF';

  SceneSlotLayoutSolveResult solve({
    required SceneRuntimeComponentTree tree,
    required SceneRuntimeCompositionResult composition,
  }) {
    final slotBoundsByNodeId = <String, SceneSlotLayoutRect>{};
    final contentBoundsByComponentNodeId = <String, SceneSlotLayoutRect>{};
    final issues = <SceneSlotLayoutIssue>[];

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
      return (left: 24.0, top: 18.0, right: 24.0, bottom: 18.0);
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
    final columns = math.max(1, math.sqrt(ordered.length).ceil());
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
