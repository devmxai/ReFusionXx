import 'dart:collection';
import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import '../models/scene_semantic_blueprint_models.dart';
import 'scene_semantic_component_registry.dart';
import 'scene_semantic_token_registry.dart';

const String kSceneLayoutSolverProofTag = 'TF_SCENE_LAYOUT_SOLVER_PROOF';
const String kSceneTreeLayoutSolverProofTag =
    'TF_SCENE_TREE_LAYOUT_SOLVER_PROOF';

enum SceneSemanticCanvasProfile {
  story916,
  landscape169,
  square11,
  portrait45,
}

class SceneSemanticLayoutBounds {
  const SceneSemanticLayoutBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  bool overlaps(SceneSemanticLayoutBounds other) {
    return !(right <= other.left ||
        other.right <= left ||
        bottom <= other.top ||
        other.bottom <= top);
  }

  @override
  String toString() {
    return '${left.toStringAsFixed(2)},${top.toStringAsFixed(2)},'
        '${right.toStringAsFixed(2)},${bottom.toStringAsFixed(2)}';
  }
}

class SceneSemanticConstraintLayoutResult {
  SceneSemanticConstraintLayoutResult({
    required List<ReFusionSceneProgramIssue> issues,
    required Map<String, SceneSemanticLayoutBounds> boundsByComponent,
    required Map<String, SceneSemanticLayoutBounds> boundsBySlot,
    required this.deterministicLayoutHash,
  })  : issues = List.unmodifiable(issues),
        boundsByComponent =
            UnmodifiableMapView<String, SceneSemanticLayoutBounds>(
          boundsByComponent,
        ),
        boundsBySlot = UnmodifiableMapView<String, SceneSemanticLayoutBounds>(
          boundsBySlot,
        );

  final List<ReFusionSceneProgramIssue> issues;
  final Map<String, SceneSemanticLayoutBounds> boundsByComponent;
  final Map<String, SceneSemanticLayoutBounds> boundsBySlot;
  final String deterministicLayoutHash;
}

class SceneSemanticConstraintLayoutSolver {
  const SceneSemanticConstraintLayoutSolver();

  SceneSemanticConstraintLayoutResult solve({
    required List<SemanticSceneBlueprintComponent> components,
    required SceneSemanticTokenRegistry tokenRegistry,
    SceneSemanticComponentRegistry? componentRegistry,
    SceneSemanticCanvasProfile profile = SceneSemanticCanvasProfile.story916,
  }) {
    final registry = componentRegistry ?? SceneSemanticComponentRegistry();
    final issues = <ReFusionSceneProgramIssue>[];
    final boundsByComponent = <String, SceneSemanticLayoutBounds>{};
    final boundsBySlot = <String, SceneSemanticLayoutBounds>{};
    final canvas = _canvasForProfile(profile);
    final safe = _safeForProfile(profile);
    var horizontalCursor = safe.left;
    var verticalCursor = safe.top;

    for (var index = 0; index < components.length; index += 1) {
      final component = components[index];
      final resolved =
          tokenRegistry.resolveBlueprintValue(component.properties).value;
      final properties = resolved is Map<String, Object?>
          ? resolved
          : const <String, Object?>{};
      final layout =
          _readMap(properties['layout']) ?? const <String, Object?>{};
      final layoutType = (_readString(layout['type']) ??
              _readString(properties['layoutType']) ??
              'anchored')
          .trim();
      final width = _readDouble(properties['width'], fallback: 420.0);
      final height = _readDouble(properties['height'], fallback: 220.0);
      final gap = _readDouble(layout['gap'], fallback: 24.0);
      final anchor = _readMap(properties['anchor']) ??
          const <String, Object?>{'x': 0.0, 'y': 0.0};
      final centerX = _readDouble(anchor['x'], fallback: 0.0);
      final centerY = _readDouble(anchor['y'], fallback: 0.0);
      final normalizedLayout = _normalize(layoutType);

      SceneSemanticLayoutBounds bounds;
      if (normalizedLayout == 'horizontalstack') {
        final left = horizontalCursor;
        final top = centerY - (height / 2);
        bounds = SceneSemanticLayoutBounds(
          left: left,
          top: top,
          right: left + width,
          bottom: top + height,
        );
        horizontalCursor = bounds.right + gap;
      } else if (normalizedLayout == 'verticalstack') {
        final left = centerX - (width / 2);
        final top = verticalCursor;
        bounds = SceneSemanticLayoutBounds(
          left: left,
          top: top,
          right: left + width,
          bottom: top + height,
        );
        verticalCursor = bounds.bottom + gap;
      } else if (normalizedLayout == 'grid') {
        final columns = _readInt(layout['columns'], fallback: 2).clamp(1, 6);
        final row = index ~/ columns;
        final col = index % columns;
        final left = safe.left + (col * (width + gap));
        final top = safe.top + (row * (height + gap));
        bounds = SceneSemanticLayoutBounds(
          left: left,
          top: top,
          right: left + width,
          bottom: top + height,
        );
      } else {
        bounds = SceneSemanticLayoutBounds(
          left: centerX - (width / 2),
          top: centerY - (height / 2),
          right: centerX + (width / 2),
          bottom: centerY + (height / 2),
        );
      }
      boundsByComponent[component.id] = bounds;
      final insets = _readInsets(properties['contentInsets']);
      final contentBounds = SceneSemanticLayoutBounds(
        left: bounds.left + insets.left,
        top: bounds.top + insets.top,
        right: bounds.right - insets.right,
        bottom: bounds.bottom - insets.bottom,
      );
      final validContentBounds = contentBounds.width > 0 &&
          contentBounds.height > 0 &&
          contentBounds.width.isFinite &&
          contentBounds.height.isFinite;
      if (!validContentBounds) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Component `${component.id}` produced invalid content bounds after contentInsets.',
            path: 'components[$index].properties.contentInsets',
          ),
        );
      } else {
        final slotLayout = _solveSlotBounds(
          component: component,
          contentBounds: contentBounds,
          componentRegistry: registry,
          issues: issues,
          componentPath: 'components[$index]',
        );
        boundsBySlot.addAll(slotLayout);
      }
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          message: '$kSceneTreeLayoutSolverProofTag '
              'componentId=${component.id} '
              'contentBounds=${contentBounds.toString()} '
              'slotCount=${component.slots.length} '
              'contentBoundsValid=${validContentBounds.toString()}',
          path: 'components[$index].slots',
        ),
      );

      final fullBleed = _readBool(properties['fullBleed']) ?? false;
      final insideSafe = fullBleed ||
          (bounds.left >= safe.left &&
              bounds.right <= safe.right &&
              bounds.top >= safe.top &&
              bounds.bottom <= safe.bottom);
      if (!insideSafe) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Component `${component.id}` exceeds safe area for `${profile.name}`.',
            path: 'components[$index].properties.anchor',
          ),
        );
      }

      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          message: '$kSceneLayoutSolverProofTag '
              'canvasProfile=${profile.name} '
              'componentId=${component.id} '
              'layoutType=$layoutType '
              'parentBounds=${canvas.toString()} '
              'contentBounds=${safe.toString()} '
              'childBounds=${bounds.toString()} '
              'safeArea=${insideSafe.toString()}',
          path: 'components[$index]',
        ),
      );
    }

    final ids = boundsByComponent.keys.toList(growable: false);
    for (var left = 0; left < ids.length; left += 1) {
      for (var right = left + 1; right < ids.length; right += 1) {
        final leftId = ids[left];
        final rightId = ids[right];
        final leftBounds = boundsByComponent[leftId]!;
        final rightBounds = boundsByComponent[rightId]!;
        if (!leftBounds.overlaps(rightBounds)) {
          continue;
        }
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Constraint layout overlap detected between `$leftId` and `$rightId`.',
            path: 'components',
          ),
        );
      }
    }

    final sortedIds = ids.toList(growable: false)..sort();
    final sortedSlots = boundsBySlot.keys.toList(growable: false)..sort();
    final hash = sortedIds
        .map((id) => '$id:${boundsByComponent[id].toString()}')
        .followedBy(
          sortedSlots.map((id) => '$id:${boundsBySlot[id].toString()}'),
        )
        .join('|');
    return SceneSemanticConstraintLayoutResult(
      issues: issues,
      boundsByComponent: boundsByComponent,
      boundsBySlot: boundsBySlot,
      deterministicLayoutHash: hash.toString(),
    );
  }

  Map<String, SceneSemanticLayoutBounds> _solveSlotBounds({
    required SemanticSceneBlueprintComponent component,
    required SceneSemanticLayoutBounds contentBounds,
    required SceneSemanticComponentRegistry componentRegistry,
    required List<ReFusionSceneProgramIssue> issues,
    required String componentPath,
  }) {
    final definition = componentRegistry.findByType(component.type);
    if (definition == null) {
      return const <String, SceneSemanticLayoutBounds>{};
    }
    final slotIds = component.slots.keys.toList(growable: false)..sort();
    if (slotIds.isEmpty) {
      return const <String, SceneSemanticLayoutBounds>{};
    }
    final bounds = <String, SceneSemanticLayoutBounds>{};
    final normalizedSlotIds = slotIds.map(_normalize).toSet();

    if (definition.id == 'PromptInputBar' &&
        normalizedSlotIds.contains('primarytext') &&
        normalizedSlotIds.contains('trailingaccessory')) {
      final trailingWidth = math.min(124.0, contentBounds.width * 0.32);
      final textRight = contentBounds.right - trailingWidth;
      final textBounds = SceneSemanticLayoutBounds(
        left: contentBounds.left,
        top: contentBounds.top,
        right: textRight,
        bottom: contentBounds.bottom,
      );
      final trailingBounds = SceneSemanticLayoutBounds(
        left: textRight,
        top: contentBounds.top,
        right: contentBounds.right,
        bottom: contentBounds.bottom,
      );
      bounds['${component.id}::primaryText'] = textBounds;
      bounds['${component.id}::trailingAccessory'] = trailingBounds;
      if (normalizedSlotIds.contains('leadingaccessory')) {
        final leadingWidth = math.min(92.0, contentBounds.width * 0.22);
        bounds['${component.id}::leadingAccessory'] = SceneSemanticLayoutBounds(
          left: contentBounds.left,
          top: contentBounds.top,
          right: contentBounds.left + leadingWidth,
          bottom: contentBounds.bottom,
        );
      }
      _emitSlotProofs(
        componentPath: componentPath,
        componentId: component.id,
        boundsBySlot: bounds,
        issues: issues,
      );
      return bounds;
    }

    if (normalizedSlotIds.contains('title') &&
        normalizedSlotIds.contains('body')) {
      final headerHeight = contentBounds.height * 0.34;
      final titleBounds = SceneSemanticLayoutBounds(
        left: contentBounds.left,
        top: contentBounds.top,
        right: contentBounds.right,
        bottom: contentBounds.top + headerHeight,
      );
      final bodyBounds = SceneSemanticLayoutBounds(
        left: contentBounds.left,
        top: contentBounds.top + headerHeight,
        right: contentBounds.right,
        bottom: contentBounds.bottom,
      );
      for (final slotId in slotIds) {
        final normalizedSlot = _normalize(slotId);
        if (normalizedSlot == 'title') {
          bounds['${component.id}::$slotId'] = titleBounds;
        } else if (normalizedSlot == 'body') {
          bounds['${component.id}::$slotId'] = bodyBounds;
        } else {
          bounds['${component.id}::$slotId'] = _defaultBadgeBounds(
            contentBounds: contentBounds,
          );
        }
      }
      _emitSlotProofs(
        componentPath: componentPath,
        componentId: component.id,
        boundsBySlot: bounds,
        issues: issues,
      );
      return bounds;
    }

    final columns = math.max(1, math.sqrt(slotIds.length).ceil());
    final rows = (slotIds.length / columns).ceil();
    final cellWidth = contentBounds.width / columns;
    final cellHeight = contentBounds.height / rows;
    for (var i = 0; i < slotIds.length; i += 1) {
      final col = i % columns;
      final row = i ~/ columns;
      final left = contentBounds.left + (col * cellWidth);
      final top = contentBounds.top + (row * cellHeight);
      bounds['${component.id}::${slotIds[i]}'] = SceneSemanticLayoutBounds(
        left: left,
        top: top,
        right: left + cellWidth,
        bottom: top + cellHeight,
      );
    }
    _emitSlotProofs(
      componentPath: componentPath,
      componentId: component.id,
      boundsBySlot: bounds,
      issues: issues,
    );
    return bounds;
  }

  SceneSemanticLayoutBounds _defaultBadgeBounds({
    required SceneSemanticLayoutBounds contentBounds,
  }) {
    final width = math.min(180.0, contentBounds.width * 0.42);
    final height = math.min(52.0, contentBounds.height * 0.28);
    return SceneSemanticLayoutBounds(
      left: contentBounds.right - width,
      top: contentBounds.top,
      right: contentBounds.right,
      bottom: contentBounds.top + height,
    );
  }

  void _emitSlotProofs({
    required String componentPath,
    required String componentId,
    required Map<String, SceneSemanticLayoutBounds> boundsBySlot,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    for (final entry in boundsBySlot.entries) {
      final slotBounds = entry.value;
      final valid = slotBounds.width > 0 &&
          slotBounds.height > 0 &&
          slotBounds.width.isFinite &&
          slotBounds.height.isFinite;
      if (!valid) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Slot `${entry.key}` produced invalid tree layout bounds.',
            path: '$componentPath.slots',
          ),
        );
      }
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          message: '$kSceneTreeLayoutSolverProofTag '
              'componentId=$componentId '
              'slotKey=${entry.key} '
              'slotBounds=${slotBounds.toString()} '
              'valid=${valid.toString()}',
          path: '$componentPath.slots',
        ),
      );
    }
  }

  SceneSemanticLayoutBounds _canvasForProfile(
      SceneSemanticCanvasProfile profile) {
    switch (profile) {
      case SceneSemanticCanvasProfile.story916:
        return const SceneSemanticLayoutBounds(
          left: -540,
          top: -960,
          right: 540,
          bottom: 960,
        );
      case SceneSemanticCanvasProfile.landscape169:
        return const SceneSemanticLayoutBounds(
          left: -960,
          top: -540,
          right: 960,
          bottom: 540,
        );
      case SceneSemanticCanvasProfile.square11:
        return const SceneSemanticLayoutBounds(
          left: -540,
          top: -540,
          right: 540,
          bottom: 540,
        );
      case SceneSemanticCanvasProfile.portrait45:
        return const SceneSemanticLayoutBounds(
          left: -540,
          top: -675,
          right: 540,
          bottom: 675,
        );
    }
  }

  SceneSemanticLayoutBounds _safeForProfile(
      SceneSemanticCanvasProfile profile) {
    final canvas = _canvasForProfile(profile);
    final marginX = canvas.width * 0.08;
    final marginY = canvas.height * 0.08;
    return SceneSemanticLayoutBounds(
      left: canvas.left + marginX,
      top: canvas.top + marginY,
      right: canvas.right - marginX,
      bottom: canvas.bottom - marginY,
    );
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  Map<String, Object?>? _readMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      final next = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is String) {
          next[entry.key as String] = entry.value;
        }
      }
      return next;
    }
    return null;
  }

  String? _readString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  double _readDouble(Object? value, {required double fallback}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  int _readInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  bool? _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return null;
  }

  ({double left, double top, double right, double bottom}) _readInsets(
    Object? rawInsets,
  ) {
    final map = _readMap(rawInsets);
    if (map == null) {
      return (left: 0.0, top: 0.0, right: 0.0, bottom: 0.0);
    }
    final all = _readDouble(map['all'], fallback: 0.0);
    final horizontal = _readDouble(map['horizontal'], fallback: all);
    final vertical = _readDouble(map['vertical'], fallback: all);
    return (
      left: _readDouble(map['left'], fallback: horizontal),
      top: _readDouble(map['top'], fallback: vertical),
      right: _readDouble(map['right'], fallback: horizontal),
      bottom: _readDouble(map['bottom'], fallback: vertical),
    );
  }
}
