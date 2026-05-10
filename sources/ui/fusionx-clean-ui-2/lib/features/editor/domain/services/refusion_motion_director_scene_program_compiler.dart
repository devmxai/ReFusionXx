import '../models/refusion_motion_director_models.dart';
import '../models/refusion_scene_program_models.dart';
import 'refusion_motion_director_linter.dart';
import 'refusion_scene_program_import_service.dart';

class ReFusionMotionDirectorSceneProgramCompileResult {
  ReFusionMotionDirectorSceneProgramCompileResult({
    required List<ReFusionMotionDirectorIssue> issues,
    this.program,
  }) : issues = List.unmodifiable(issues);

  final ReFusionSceneProgram? program;
  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid =>
      program != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class ReFusionMotionDirectorSceneProgramCompiler {
  const ReFusionMotionDirectorSceneProgramCompiler({
    ReFusionMotionDirectorLinter linter = const ReFusionMotionDirectorLinter(),
  }) : _linter = linter;

  final ReFusionMotionDirectorLinter _linter;

  ReFusionMotionDirectorSceneProgramCompileResult compile(
    ReFusionMotionDirectorPlan plan,
  ) {
    final lintResult = _linter.lint(plan);
    if (!lintResult.isValid) {
      return ReFusionMotionDirectorSceneProgramCompileResult(
        issues: lintResult.issues,
      );
    }

    final primitiveBuckets = <String, List<ReFusionMotionDirectorPrimitive>>{};
    for (final primitive in plan.primitives) {
      primitiveBuckets
          .putIfAbsent(
            primitive.targetComponentId,
            () => <ReFusionMotionDirectorPrimitive>[],
          )
          .add(primitive);
    }

    final layers = <ReFusionSceneProgramLayer>[];
    final issues = <ReFusionMotionDirectorIssue>[
      ...lintResult.issues,
    ];
    for (var index = 0; index < plan.components.length; index += 1) {
      final component = plan.components[index];
      final layer = _compileComponent(
        plan: plan,
        component: component,
        zIndex: index,
        primitives: primitiveBuckets[component.id] ??
            const <ReFusionMotionDirectorPrimitive>[],
        issues: issues,
      );
      if (layer != null) {
        layers.add(layer);
      }
    }

    if (layers.isEmpty) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Director plan produced no Scene Program layers.',
          path: 'components',
        ),
      );
      return ReFusionMotionDirectorSceneProgramCompileResult(issues: issues);
    }

    return ReFusionMotionDirectorSceneProgramCompileResult(
      issues: issues,
      program: ReFusionSceneProgram(
        schemaVersion: ReFusionSceneProgramImportService.schemaVersion,
        name: plan.name,
        durationMs: plan.durationMs,
        frameRate: plan.frameRate,
        layers: layers,
      ),
    );
  }

  ReFusionSceneProgramLayer? _compileComponent({
    required ReFusionMotionDirectorPlan plan,
    required ReFusionMotionDirectorComponent component,
    required int zIndex,
    required List<ReFusionMotionDirectorPrimitive> primitives,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    final role = _normalizeToken(component.role);
    final layerId = _sanitizeId(
      component.layerId ?? '${component.id}_layer',
    );
    final elementId = _sanitizeId(
      component.elementId ?? component.id,
    );
    final componentSpec = _componentSpecFor(
      component: component,
      role: role,
      elementId: elementId,
      plan: plan,
      zIndex: zIndex,
    );
    if (componentSpec == null) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Director component `${component.id}` has unsupported role `${component.role}` and was skipped.',
          path: 'components[$zIndex].role',
        ),
      );
      return null;
    }

    return ReFusionSceneProgramLayer(
      id: layerId,
      kind: componentSpec.layerKind,
      name: component.label,
      startMs: 0,
      durationMs: plan.durationMs,
      elements: <ReFusionSceneProgramElement>[
        ReFusionSceneProgramElement(
          id: elementId,
          kind: componentSpec.elementKind,
          name: component.label,
          text: componentSpec.text,
          properties: componentSpec.properties,
          channels: _channelsForPrimitives(
            primitives: primitives,
            role: role,
            ownerId: elementId,
          ),
        ),
      ],
    );
  }

  List<ReFusionSceneProgramChannel> _channelsForPrimitives({
    required List<ReFusionMotionDirectorPrimitive> primitives,
    required String role,
    required String ownerId,
  }) {
    final primitiveBuckets =
        <String, List<_CompiledDirectorPrimitiveChannel>>{};
    for (final primitive in primitives) {
      final property = _propertyForPrimitive(primitive, role);
      if (property == null) {
        continue;
      }
      final normalizedProperty = _normalizeToken(property);
      primitiveBuckets
          .putIfAbsent(
            normalizedProperty,
            () => <_CompiledDirectorPrimitiveChannel>[],
          )
          .add(
            _CompiledDirectorPrimitiveChannel(
              property: property,
              primitive: primitive,
            ),
          );
    }

    final channels = <ReFusionSceneProgramChannel>[];
    for (final entry in primitiveBuckets.entries) {
      final primitiveChannels = List<_CompiledDirectorPrimitiveChannel>.from(
        entry.value,
      )..sort(
          (left, right) {
            final startComparison =
                left.primitive.startMs.compareTo(right.primitive.startMs);
            if (startComparison != 0) {
              return startComparison;
            }
            return left.primitive.endMs.compareTo(right.primitive.endMs);
          },
        );
      if (primitiveChannels.isEmpty) {
        continue;
      }
      final property = primitiveChannels.first.property;
      final keyframes = <ReFusionSceneProgramKeyframe>[];
      for (final primitiveChannel in primitiveChannels) {
        final primitive = primitiveChannel.primitive;
        _appendMergedKeyframe(
          keyframes,
          ReFusionSceneProgramKeyframe(
            timeMs: primitive.startMs,
            value: _coercePrimitiveChannelValue(
              primitive,
              property,
              isStart: true,
            ),
            easing: primitive.easing,
          ),
        );
        _appendMergedKeyframe(
          keyframes,
          ReFusionSceneProgramKeyframe(
            timeMs: primitive.endMs,
            value: _coercePrimitiveChannelValue(
              primitive,
              property,
              isStart: false,
            ),
            easing: primitive.easing,
          ),
        );
      }
      channels.add(
        ReFusionSceneProgramChannel(
          target: ownerId,
          property: property,
          keyframes: keyframes,
        ),
      );
    }
    return channels;
  }

  void _appendMergedKeyframe(
    List<ReFusionSceneProgramKeyframe> keyframes,
    ReFusionSceneProgramKeyframe next,
  ) {
    if (keyframes.isEmpty) {
      keyframes.add(next);
      return;
    }
    final previous = keyframes.last;
    if (previous.timeMs != next.timeMs) {
      keyframes.add(next);
      return;
    }

    // Same-time handoffs should remain one editable timeline point. If the
    // values differ, keep the later primitive's value because it defines the
    // state after the handoff.
    keyframes[keyframes.length - 1] = ReFusionSceneProgramKeyframe(
      timeMs: next.timeMs,
      value: next.value,
      easing: next.easing,
    );
  }

  String? _propertyForPrimitive(
    ReFusionMotionDirectorPrimitive primitive,
    String role,
  ) {
    final explicit = primitive.property?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final kind = _normalizeToken(primitive.kind);
    if (kind == 'typewriter' || kind == 'typing' || kind == 'letterreveal') {
      return 'typewriterProgress';
    }
    if (kind == 'enter' || kind == 'fade' || kind == 'opacity') {
      return 'opacity';
    }
    if (kind == 'move' || kind == 'slide') {
      return 'position';
    }
    if (kind == 'scale' || kind == 'press' || kind == 'cover') {
      return 'scale';
    }
    if (kind == 'widthgrow' || kind == 'linegrow') {
      return 'width';
    }
    if (role.contains('typewriter')) {
      return 'typewriterProgress';
    }
    return null;
  }

  Object _coercePrimitiveChannelValue(
    ReFusionMotionDirectorPrimitive primitive,
    String property, {
    required bool isStart,
  }) {
    final value = isStart ? primitive.fromValue : primitive.toValue;
    if (value != null) {
      return value;
    }
    final normalizedProperty = _normalizeToken(property);
    final kind = _normalizeToken(primitive.kind);
    if (normalizedProperty == 'typewriterprogress' ||
        normalizedProperty == 'typingprogress' ||
        normalizedProperty == 'reveal' ||
        kind == 'typewriter' ||
        kind == 'typing' ||
        kind == 'letterreveal') {
      return isStart ? 0.0 : 1.0;
    }
    if (normalizedProperty == 'position') {
      return const <String, double>{'x': 0, 'y': 0};
    }
    if (normalizedProperty == 'color' || normalizedProperty == 'fillcolor') {
      return '#FFFFFF';
    }
    return 0.0;
  }

  _DirectorComponentSpec? _componentSpecFor({
    required ReFusionMotionDirectorComponent component,
    required String role,
    required String elementId,
    required ReFusionMotionDirectorPlan plan,
    required int zIndex,
  }) {
    final baseProperties = Map<String, Object?>.from(component.properties);
    if (role.contains('background') || role.contains('canvas')) {
      return _DirectorComponentSpec(
        layerKind: 'shape',
        elementKind: 'shape',
        properties: <String, Object?>{
          'shapeKind': 'rectangle',
          'width': plan.canvasWidth,
          'height': plan.canvasHeight,
          'color': baseProperties['color'] ?? '#090A0F',
          'opacity': baseProperties['opacity'] ?? 1.0,
          ...baseProperties,
        },
      );
    }
    if (role.contains('prompt') ||
        role.contains('shell') ||
        role.contains('inputbar')) {
      return _DirectorComponentSpec(
        layerKind: 'shape',
        elementKind: 'shape',
        properties: <String, Object?>{
          'shapeKind': 'roundedRectangle',
          'width': 900,
          'height': 132,
          'cornerRadius': 54,
          'color': '#191B24',
          'borderWidth': 1.5,
          'strokeWidth': 1.5,
          'strokeColor': '#D5D8E2',
          'opacity': 1.0,
          ...baseProperties,
        },
      );
    }
    if (role.contains('text') ||
        role.contains('typewriter') ||
        role.contains('copy')) {
      return _DirectorComponentSpec(
        layerKind: 'text',
        elementKind: 'text',
        text: '${baseProperties.remove('text') ?? component.label}',
        properties: <String, Object?>{
          'fontSize': 58,
          'color': '#FFFFFF',
          'opacity': 1.0,
          'reveal': 0.0,
          ...baseProperties,
        },
      );
    }
    if (role.contains('send') && role.contains('icon')) {
      return _DirectorComponentSpec(
        layerKind: 'shape',
        elementKind: 'icon',
        properties: <String, Object?>{
          'icon': 'send',
          'width': 42,
          'height': 42,
          'color': '#090A0F',
          'opacity': 1.0,
          ...baseProperties,
        },
      );
    }
    if (role.contains('icon')) {
      return _DirectorComponentSpec(
        layerKind: 'shape',
        elementKind: 'icon',
        properties: <String, Object?>{
          'icon': baseProperties['icon'] ?? 'sparkles',
          'width': 48,
          'height': 48,
          'color': '#FFFFFF',
          'opacity': 1.0,
          ...baseProperties,
        },
      );
    }
    if (role.contains('button') ||
        role.contains('circle') ||
        role.contains('cover')) {
      return _DirectorComponentSpec(
        layerKind: 'shape',
        elementKind: 'shape',
        properties: <String, Object?>{
          'shapeKind': 'circle',
          'width': role.contains('cover') ? 160 : 76,
          'height': role.contains('cover') ? 160 : 76,
          'color': role.contains('cover') ? '#FFFFFF' : '#FFFFFF',
          'opacity': 1.0,
          ...baseProperties,
        },
      );
    }
    if (role.contains('line')) {
      return _DirectorComponentSpec(
        layerKind: 'shape',
        elementKind: 'shape',
        properties: <String, Object?>{
          'shapeKind': 'roundedRectangle',
          'width': 8,
          'height': 16,
          'cornerRadius': 999,
          'color': '#FFFFFF',
          'opacity': 1.0,
          ...baseProperties,
        },
      );
    }
    if (role.contains('shape')) {
      final isCard = role.contains('card');
      return _DirectorComponentSpec(
        layerKind: 'shape',
        elementKind: 'shape',
        properties: <String, Object?>{
          'shapeKind': baseProperties['shapeKind'] ?? 'roundedRectangle',
          'width': 220,
          'height': 220,
          'cornerRadius': 32,
          'color': '#FFFFFF',
          if (isCard) 'borderWidth': 1.25,
          if (isCard) 'strokeWidth': 1.25,
          if (isCard) 'strokeColor': '#DFE5F2',
          'opacity': 1.0,
          ...baseProperties,
        },
      );
    }
    return null;
  }

  String _sanitizeId(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? 'director-item' : normalized;
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}

class _DirectorComponentSpec {
  const _DirectorComponentSpec({
    required this.layerKind,
    required this.elementKind,
    required this.properties,
    this.text,
  });

  final String layerKind;
  final String elementKind;
  final String? text;
  final Map<String, Object?> properties;
}

class _CompiledDirectorPrimitiveChannel {
  const _CompiledDirectorPrimitiveChannel({
    required this.property,
    required this.primitive,
  });

  final String property;
  final ReFusionMotionDirectorPrimitive primitive;
}
