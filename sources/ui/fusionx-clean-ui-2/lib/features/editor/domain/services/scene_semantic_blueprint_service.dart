import 'dart:collection';

import '../models/refusion_scene_program_models.dart';
import '../models/scene_semantic_blueprint_models.dart';
import 'scene_semantic_token_registry.dart';

const String kSceneBlueprintCompilerProofTag =
    'TF_SCENE_BLUEPRINT_COMPILER_PROOF';

class SceneSemanticBlueprintValidationResult {
  SceneSemanticBlueprintValidationResult({
    required this.issues,
    this.blueprint,
  });

  final SemanticSceneBlueprint? blueprint;
  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid =>
      blueprint != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneSemanticBlueprintLoweringResult {
  SceneSemanticBlueprintLoweringResult({
    required this.issues,
    this.program,
  });

  final ReFusionSceneProgram? program;
  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid =>
      program != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneSemanticBlueprintService {
  SceneSemanticBlueprintService({
    SceneSemanticTokenRegistry? tokenRegistry,
  }) : _tokenRegistry = tokenRegistry ?? SceneSemanticTokenRegistry();

  final SceneSemanticTokenRegistry _tokenRegistry;

  static const String schemaVersion = 'refusion.semantic-blueprint/v1';

  static const Set<String> _allowedRootKeys = <String>{
    'schemaVersion',
    'name',
    'durationMs',
    'frameRate',
    'components',
    'beats',
    'metadata',
  };

  SceneSemanticBlueprintValidationResult validate(
    Map<String, Object?> payload,
  ) {
    final issues = <ReFusionSceneProgramIssue>[];
    _warnUnsupportedRootFields(payload, issues);

    final rawSchema = payload['schemaVersion'];
    final schema =
        rawSchema is String && rawSchema.isNotEmpty ? rawSchema : schemaVersion;
    if (schema != schemaVersion) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Unsupported semantic blueprint schema `$schema`. Expected `$schemaVersion`.',
          path: 'schemaVersion',
        ),
      );
    }

    final durationMs = _readInt(payload['durationMs'], fallback: 3000);
    final frameRate = _readDouble(payload['frameRate'], fallback: 30);
    final name = _readString(payload['name']) ?? 'Untitled Semantic Blueprint';

    final components = _readComponents(payload['components'], issues);
    if (components.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Semantic blueprint must include at least one component.',
          path: 'components',
        ),
      );
    }

    final beats = _readBeats(payload['beats'], issues);
    final blueprint = SemanticSceneBlueprint(
      schemaVersion: schema,
      name: name,
      durationMs: durationMs,
      frameRate: frameRate,
      components: components,
      beats: beats,
      metadata: _readMap(payload['metadata']) ?? const <String, Object?>{},
    );
    return SceneSemanticBlueprintValidationResult(
      blueprint: blueprint,
      issues: List.unmodifiable(issues),
    );
  }

  SceneSemanticBlueprintLoweringResult lowerToSceneProgram(
    SemanticSceneBlueprint blueprint,
  ) {
    final issues = <ReFusionSceneProgramIssue>[];
    final layers = <ReFusionSceneProgramLayer>[];
    var loweredComponents = 0;

    for (final component in blueprint.components) {
      final normalizedType = component.type.trim().toLowerCase();
      if (normalizedType != 'promptinputbar') {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Unsupported semantic component `${component.type}` in v2-02 lowerer.',
            path: 'components.${component.id}.type',
          ),
        );
        continue;
      }
      final lowered = _lowerPromptInputBar(
        component: component,
        durationMs: blueprint.durationMs,
        issues: issues,
      );
      if (lowered != null) {
        layers.add(lowered);
        loweredComponents += 1;
      }
    }

    final proof = _buildProof(
      componentCount: blueprint.components.length,
      loweredCount: loweredComponents,
      errorCount: issues
          .where((it) => it.severity == ReFusionSceneProgramIssueSeverity.error)
          .length,
    );
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: proof,
        path: 'semanticBlueprint',
      ),
    );

    if (layers.isEmpty) {
      return SceneSemanticBlueprintLoweringResult(
        issues: List.unmodifiable(issues),
      );
    }

    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: blueprint.name,
      durationMs: blueprint.durationMs,
      frameRate: blueprint.frameRate,
      layers: layers,
    );
    return SceneSemanticBlueprintLoweringResult(
      program: program,
      issues: List.unmodifiable(issues),
    );
  }

  ReFusionSceneProgramLayer? _lowerPromptInputBar({
    required SemanticSceneBlueprintComponent component,
    required int durationMs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final resolvedProperties =
        _tokenRegistry.resolveBlueprintValue(component.properties);
    final resolvedSlots = _tokenRegistry.resolveBlueprintValue(component.slots);
    for (final error in resolvedProperties.errors) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: error.message,
          path: 'components.${component.id}.properties${error.path}',
        ),
      );
    }
    for (final error in resolvedSlots.errors) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: error.message,
          path: 'components.${component.id}.slots${error.path}',
        ),
      );
    }
    if (resolvedProperties.errors.isNotEmpty ||
        resolvedSlots.errors.isNotEmpty) {
      return null;
    }

    final properties = resolvedProperties.value is Map<String, Object?>
        ? resolvedProperties.value as Map<String, Object?>
        : const <String, Object?>{};
    final slots = resolvedSlots.value is Map<String, Object?>
        ? resolvedSlots.value as Map<String, Object?>
        : const <String, Object?>{};

    final promptText = _readString(properties['promptText']) ??
        _readString(slots['primaryText']) ??
        'generate new offer for my business';
    final anchor = _readMap(properties['anchor']) ??
        const <String, Object?>{'x': 0.0, 'y': -40.0};
    final width = _readDouble(properties['width'], fallback: 860.0);
    final height = _readDouble(properties['height'], fallback: 112.0);
    final textFrameWidth =
        _readDouble(properties['textFrameWidth'], fallback: width - 180.0);
    final textFrameHeight =
        _readDouble(properties['textFrameHeight'], fallback: 60.0);

    final shellId = '${component.id}-shell';
    final textId = '${component.id}-text';
    final buttonId = '${component.id}-send-button';
    final iconId = '${component.id}-send-icon';

    return ReFusionSceneProgramLayer(
      id: '${component.id}-layer',
      name: component.type,
      kind: 'shape',
      startMs: 0,
      durationMs: durationMs,
      elements: <ReFusionSceneProgramElement>[
        ReFusionSceneProgramElement(
          id: shellId,
          kind: 'shape',
          properties: <String, Object?>{
            'layoutRole': 'container',
            'shapeKind': 'roundedRectangle',
            'position': <String, Object?>{
              'x': _readDouble(anchor['x'], fallback: 0.0),
              'y': _readDouble(anchor['y'], fallback: -40.0),
            },
            'width': width,
            'height': height,
            'cornerRadius': 56.0,
            'color': '#F8FAFC',
            'opacity': 1.0,
            'contentInsets': const <String, Object?>{
              'left': 44.0,
              'right': 124.0,
              'top': 16.0,
              'bottom': 16.0,
            },
          },
        ),
        ReFusionSceneProgramElement(
          id: textId,
          kind: 'text',
          text: promptText,
          properties: <String, Object?>{
            'parentId': shellId,
            'layoutRole': 'content',
            'layout': const <String, Object?>{
              'slot': 'primaryText',
              'anchor': 'centerLeft',
              'maxLines': 1,
              'overflow': 'clip',
            },
            'textFrame': <String, Object?>{
              'width': textFrameWidth,
              'height': textFrameHeight,
              'anchor': 'centerLeft',
              'maxLines': 1,
              'overflow': 'ellipsis',
              'fitPolicy': 'shrinkToFit',
              'minFontSize': 24.0,
              'maxFontSize': 32.0,
              'measure': 'fullText',
            },
            'position': <String, Object?>{
              'x': _readDouble(anchor['x'], fallback: 0.0) - 76.0,
              'y': _readDouble(anchor['y'], fallback: -40.0),
            },
            'fontSize': 32.0,
            'fontWeight': 650,
            'lineHeight': 1.0,
            'letterSpacing': 0.0,
            'textAlign': 'left',
            'color': '#101827',
            'opacity': 1.0,
            'typewriterProgress': 0.0,
          },
          channels: <ReFusionSceneProgramChannel>[
            ReFusionSceneProgramChannel(
              target: textId,
              property: 'typewriterProgress',
              keyframes: const <ReFusionSceneProgramKeyframe>[
                ReFusionSceneProgramKeyframe(
                  timeMs: 900,
                  value: 0.0,
                  easing: 'linear',
                ),
                ReFusionSceneProgramKeyframe(
                  timeMs: 2200,
                  value: 1.0,
                  easing: 'linear',
                ),
              ],
            ),
          ],
        ),
        ReFusionSceneProgramElement(
          id: buttonId,
          kind: 'shape',
          properties: <String, Object?>{
            'parentId': shellId,
            'layoutRole': 'trailingAccessory',
            'shapeKind': 'circle',
            'position': <String, Object?>{
              'x': _readDouble(anchor['x'], fallback: 0.0) + 332.0,
              'y': _readDouble(anchor['y'], fallback: -40.0),
            },
            'width': 76.0,
            'height': 76.0,
            'color': '#101827',
            'opacity': 1.0,
          },
        ),
        ReFusionSceneProgramElement(
          id: iconId,
          kind: 'icon',
          properties: <String, Object?>{
            'parentId': buttonId,
            'icon': 'send',
            'position': <String, Object?>{
              'x': _readDouble(anchor['x'], fallback: 0.0) + 332.0,
              'y': _readDouble(anchor['y'], fallback: -40.0),
            },
            'width': 28.0,
            'height': 28.0,
            'color': '#F8FAFC',
            'opacity': 1.0,
          },
        ),
      ],
    );
  }

  void _warnUnsupportedRootFields(
    Map<String, Object?> payload,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    for (final key in payload.keys) {
      if (_allowedRootKeys.contains(key)) {
        continue;
      }
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Unsupported semantic blueprint field `$key` is ignored in v2-02.',
          path: key,
        ),
      );
    }
  }

  List<SemanticSceneBlueprintComponent> _readComponents(
    Object? raw,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    if (raw is! List) {
      return const <SemanticSceneBlueprintComponent>[];
    }
    final components = <SemanticSceneBlueprintComponent>[];
    final ids = <String>{};
    for (var index = 0; index < raw.length; index += 1) {
      final entry = raw[index];
      if (entry is! Map<String, Object?>) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Component declaration must be an object.',
            path: 'components[$index]',
          ),
        );
        continue;
      }
      final id = _readString(entry['id']);
      final type = _readString(entry['type']);
      if (id == null || id.isEmpty || type == null || type.isEmpty) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Component requires `id` and `type`.',
            path: 'components[$index]',
          ),
        );
        continue;
      }
      if (!ids.add(id)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Duplicate component id `$id`.',
            path: 'components[$index].id',
          ),
        );
        continue;
      }
      components.add(
        SemanticSceneBlueprintComponent(
          id: id,
          type: type,
          properties:
              _readMap(entry['properties']) ?? const <String, Object?>{},
          slots: _readMap(entry['slots']) ?? const <String, Object?>{},
          motionIntents:
              _readMap(entry['motionIntents']) ?? const <String, Object?>{},
        ),
      );
    }
    return components;
  }

  List<SemanticSceneBlueprintBeat> _readBeats(
    Object? raw,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    if (raw is! List) {
      return const <SemanticSceneBlueprintBeat>[];
    }
    final beats = <SemanticSceneBlueprintBeat>[];
    for (var index = 0; index < raw.length; index += 1) {
      final entry = raw[index];
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final id = _readString(entry['id']);
      final intent = _readString(entry['intent']);
      final startMs = _readInt(entry['startMs'], fallback: 0);
      final endMs = _readInt(entry['endMs'], fallback: 0);
      if (id == null || intent == null) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.warning,
            message: 'Beat declaration should include `id` and `intent`.',
            path: 'beats[$index]',
          ),
        );
        continue;
      }
      beats.add(
        SemanticSceneBlueprintBeat(
          id: id,
          startMs: startMs,
          endMs: endMs,
          intent: intent,
        ),
      );
    }
    return beats;
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

  double _readDouble(Object? value, {required double fallback}) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  String? _readString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  Map<String, Object?>? _readMap(Object? value) {
    if (value is Map<String, Object?>) {
      return UnmodifiableMapView<String, Object?>(value);
    }
    if (value is Map) {
      final next = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is String) {
          next[entry.key as String] = entry.value;
        }
      }
      return UnmodifiableMapView<String, Object?>(next);
    }
    return null;
  }

  String _buildProof({
    required int componentCount,
    required int loweredCount,
    required int errorCount,
  }) {
    return '$kSceneBlueprintCompilerProofTag '
        'componentCount=$componentCount loweredCount=$loweredCount errorCount=$errorCount';
  }
}
