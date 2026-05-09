import 'dart:collection';

import '../models/refusion_scene_program_models.dart';
import '../models/scene_semantic_blueprint_models.dart';
import 'motion_interpolation_truth_compiler.dart';
import 'scene_semantic_beat_grammar_validator.dart';
import 'scene_semantic_component_registry.dart';
import 'scene_semantic_constraint_layout_solver.dart';
import 'scene_semantic_token_registry.dart';

const String kSceneBlueprintCompilerProofTag =
    'TF_SCENE_BLUEPRINT_COMPILER_PROOF';
const String kSceneSpeedyGraphDependencyProofTag =
    'TF_SCENE_SPEEDYGRAPH_DEPENDENCY_PROOF';
const String kSceneTextGeometryProofTag = 'TF_SCENE_TEXT_GEOMETRY_PROOF';
const String kSceneBlueprintV5ContractProofTag =
    'TF_SCENE_BLUEPRINT_V5_CONTRACT_PROOF';

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
    MotionInterpolationTruthCompiler? truthCompiler,
    SceneSemanticComponentRegistry? componentRegistry,
    SceneSemanticConstraintLayoutSolver? layoutSolver,
    SceneSemanticBeatGrammarValidator? beatGrammarValidator,
  })  : _tokenRegistry = tokenRegistry ?? SceneSemanticTokenRegistry(),
        _truthCompiler =
            truthCompiler ?? const MotionInterpolationTruthCompiler(),
        _componentRegistry =
            componentRegistry ?? SceneSemanticComponentRegistry(),
        _layoutSolver =
            layoutSolver ?? const SceneSemanticConstraintLayoutSolver(),
        _beatGrammarValidator =
            beatGrammarValidator ?? const SceneSemanticBeatGrammarValidator();

  final SceneSemanticTokenRegistry _tokenRegistry;
  final MotionInterpolationTruthCompiler _truthCompiler;
  final SceneSemanticComponentRegistry _componentRegistry;
  final SceneSemanticConstraintLayoutSolver _layoutSolver;
  final SceneSemanticBeatGrammarValidator _beatGrammarValidator;
  static const Set<String> _allowedOverflowPolicies = <String>{
    'error',
    'ellipsis',
    'clip',
  };
  static const Set<String> _allowedFitPolicies = <String>{
    'none',
    'shrinktofit',
    'wraptolines',
    'ellipsisaftermaxlines',
    'cliptoframe',
    'shorten',
    'scalexfornumericonly',
  };

  static const String schemaVersion = 'refusion.semantic-blueprint/v5';

  static const Set<String> _allowedRootKeys = <String>{
    'schemaVersion',
    'name',
    'durationMs',
    'frameRate',
    'compositionIntent',
    'tasteProfile',
    'components',
    'beats',
    'metadata',
  };
  static const String _schemaVersionV5 = schemaVersion;
  static const String _schemaVersionV1Legacy = 'refusion.semantic-blueprint/v1';

  SceneSemanticBlueprintValidationResult validate(
    Map<String, Object?> payload,
  ) {
    final issues = <ReFusionSceneProgramIssue>[];
    _warnUnsupportedRootFields(payload, issues);

    final rawSchema = payload['schemaVersion'];
    final schema = rawSchema is String && rawSchema.isNotEmpty
        ? rawSchema
        : _schemaVersionV5;
    final schemaAllowed =
        schema == _schemaVersionV5 || schema == _schemaVersionV1Legacy;
    if (!schemaAllowed) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Unsupported semantic blueprint schema `$schema`. Expected `$_schemaVersionV5`.',
          path: 'schemaVersion',
        ),
      );
    } else if (schema == _schemaVersionV1Legacy) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Semantic blueprint schema v1 is legacy. Prefer `refusion.semantic-blueprint/v5`.',
          path: 'schemaVersion',
        ),
      );
    }

    final durationMs = _readInt(payload['durationMs'], fallback: 3000);
    final frameRate = _readDouble(payload['frameRate'], fallback: 30);
    final name = _readString(payload['name']) ?? 'Untitled Semantic Blueprint';
    final compositionIntent = _readString(payload['compositionIntent']);
    final tasteProfile = _readString(payload['tasteProfile']);

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
    _validateComponentContracts(components, issues);
    _validateTextGeometryContracts(components, issues);
    final metadata = _readMap(payload['metadata']) ?? const <String, Object?>{};
    _validateConstraintLayoutContracts(
      components: components,
      metadata: metadata,
      issues: issues,
    );

    final beats = _readBeats(payload['beats'], issues);
    _validateV5AgentContracts(
      schema: schema,
      blueprintCompositionIntent: compositionIntent,
      blueprintTasteProfile: tasteProfile,
      components: components,
      issues: issues,
    );
    issues.addAll(
      _beatGrammarValidator.validate(
        beats: beats,
        sceneDurationMs: durationMs,
        components: components,
      ),
    );
    final blueprint = SemanticSceneBlueprint(
      schemaVersion: schema,
      name: name,
      durationMs: durationMs,
      frameRate: frameRate,
      compositionIntent: compositionIntent,
      tasteProfile: tasteProfile,
      components: components,
      beats: beats,
      metadata: metadata,
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
      final definition = _componentRegistry.findByType(component.type);
      final canonicalType = definition?.id ?? component.type;
      final normalizedType = canonicalType.trim().toLowerCase();
      if (normalizedType != 'promptinputbar') {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Unsupported semantic component `${canonicalType}` in v2-03a lowerer.',
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
      schemaVersion: blueprint.schemaVersion,
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
    final resolvedMotionIntents =
        _tokenRegistry.resolveBlueprintValue(component.motionIntents);
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
    for (final error in resolvedMotionIntents.errors) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: error.message,
          path: 'components.${component.id}.motionIntents${error.path}',
        ),
      );
    }
    if (resolvedProperties.errors.isNotEmpty ||
        resolvedSlots.errors.isNotEmpty ||
        resolvedMotionIntents.errors.isNotEmpty) {
      return null;
    }

    final properties = resolvedProperties.value is Map<String, Object?>
        ? resolvedProperties.value as Map<String, Object?>
        : const <String, Object?>{};
    final slots = resolvedSlots.value is Map<String, Object?>
        ? resolvedSlots.value as Map<String, Object?>
        : const <String, Object?>{};
    final motionIntents = resolvedMotionIntents.value is Map<String, Object?>
        ? resolvedMotionIntents.value as Map<String, Object?>
        : const <String, Object?>{};

    _validateSpeedGraphDependency(
      componentId: component.id,
      motionIntents: motionIntents,
      issues: issues,
    );
    if (issues.any((issue) =>
        issue.severity == ReFusionSceneProgramIssueSeverity.error &&
        (issue.path?.startsWith('components.${component.id}.motionIntents') ??
            false))) {
      return null;
    }

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
          variant: _readString(entry['variant']),
          iconToken: _readString(entry['iconToken']),
          brandToken: _readString(entry['brandToken']),
          motionRecipe: _readString(entry['motionRecipe']),
          fitPolicy: _readString(entry['fitPolicy']),
          compositionIntent: _readString(entry['compositionIntent']),
          microScene: _readString(entry['microScene']),
          tasteProfile: _readString(entry['tasteProfile']),
          properties:
              _readMap(entry['properties']) ?? const <String, Object?>{},
          slots: _readMap(entry['slots']) ?? const <String, Object?>{},
          motionIntents:
              _readMap(entry['motionIntents']) ?? const <String, Object?>{},
          componentChoreography: _readMap(entry['componentChoreography']) ??
              const <String, Object?>{},
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
      final overlapPolicy = _readString(entry['overlapPolicy']);
      final componentRefs = _readStringList(entry['componentRefs']);
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
          overlapPolicy: overlapPolicy,
          componentRefs: componentRefs,
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

  List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    final items = <String>[];
    for (final entry in value) {
      if (entry is String && entry.trim().isNotEmpty) {
        items.add(entry.trim());
      }
    }
    return List.unmodifiable(items);
  }

  String _buildProof({
    required String schemaVersion,
    required int componentCount,
    required int loweredCount,
    required int errorCount,
  }) {
    return '$kSceneBlueprintCompilerProofTag '
        'schemaVersion=$schemaVersion '
        'componentCount=$componentCount loweredCount=$loweredCount errorCount=$errorCount';
  }

  void _validateV5AgentContracts({
    required String schema,
    required String? blueprintCompositionIntent,
    required String? blueprintTasteProfile,
    required List<SemanticSceneBlueprintComponent> components,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final enforce = schema == _schemaVersionV5;
    if (enforce &&
        !_isTokenReference(
          blueprintCompositionIntent,
          prefix: r'$composition.',
        )) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Semantic Blueprint v5 requires tokenized `compositionIntent` with `\$composition.*`.',
          path: 'compositionIntent',
        ),
      );
    }
    if (enforce &&
        !_isTokenReference(
          blueprintTasteProfile,
          prefix: r'$taste.',
        )) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Semantic Blueprint v5 requires tokenized `tasteProfile` with `\$taste.*`.',
          path: 'tasteProfile',
        ),
      );
    }

    for (var index = 0; index < components.length; index += 1) {
      final component = components[index];
      final path = 'components[$index]';
      _requireTokenField(
        enforce: enforce,
        value: component.iconToken,
        prefix: r'$icon.',
        path: '$path.iconToken',
        fieldName: 'iconToken',
        issues: issues,
      );
      _requireTokenField(
        enforce: enforce,
        value: component.brandToken,
        prefix: r'$brand.',
        path: '$path.brandToken',
        fieldName: 'brandToken',
        issues: issues,
      );
      _requireTokenField(
        enforce: enforce,
        value: component.motionRecipe,
        prefix: r'$motion.',
        path: '$path.motionRecipe',
        fieldName: 'motionRecipe',
        issues: issues,
      );
      _requireTokenField(
        enforce: enforce,
        value: component.fitPolicy,
        prefix: r'$textFit.',
        path: '$path.fitPolicy',
        fieldName: 'fitPolicy',
        issues: issues,
      );
      _requireTokenField(
        enforce: enforce,
        value: component.compositionIntent,
        prefix: r'$composition.',
        path: '$path.compositionIntent',
        fieldName: 'compositionIntent',
        issues: issues,
      );
      _requireTokenField(
        enforce: enforce,
        value: component.microScene,
        prefix: r'$microScene.',
        path: '$path.microScene',
        fieldName: 'microScene',
        issues: issues,
      );
      _requireTokenField(
        enforce: enforce,
        value: component.tasteProfile,
        prefix: r'$taste.',
        path: '$path.tasteProfile',
        fieldName: 'tasteProfile',
        issues: issues,
      );

      if (component.componentChoreography.isNotEmpty) {
        final enter =
            _readString(component.componentChoreography['enterRecipe']);
        final exit = _readString(component.componentChoreography['exitRecipe']);
        if (enter != null && !_isTokenReference(enter, prefix: r'$motion.')) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Component choreography `enterRecipe` must reference `\$motion.*` token.',
              path: '$path.componentChoreography.enterRecipe',
            ),
          );
        }
        if (exit != null && !_isTokenReference(exit, prefix: r'$motion.')) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Component choreography `exitRecipe` must reference `\$motion.*` token.',
              path: '$path.componentChoreography.exitRecipe',
            ),
          );
        }
      }

      if (enforce) {
        final rawIcon = _readString(component.properties['icon']);
        if (rawIcon != null &&
            rawIcon.isNotEmpty &&
            (component.iconToken == null || component.iconToken!.isEmpty)) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Semantic Blueprint v5 requires `iconToken` instead of loose `properties.icon` values.',
              path: '$path.properties.icon',
            ),
          );
        }
        final rawBrand = _readString(component.properties['brand']);
        if (rawBrand != null &&
            rawBrand.isNotEmpty &&
            (component.brandToken == null || component.brandToken!.isEmpty)) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Semantic Blueprint v5 requires `brandToken` instead of loose `properties.brand` values.',
              path: '$path.properties.brand',
            ),
          );
        }
      }
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneBlueprintV5ContractProofTag '
            'schema=$schema '
            'componentCount=${components.length} '
            'enforced=${enforce.toString()}',
        path: 'semanticBlueprint',
      ),
    );
  }

  void _requireTokenField({
    required bool enforce,
    required String? value,
    required String prefix,
    required String path,
    required String fieldName,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    if (enforce && (value == null || value.trim().isEmpty)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Semantic Blueprint v5 requires `$fieldName` as tokenized reference.',
          path: path,
        ),
      );
      return;
    }
    if (value == null || value.trim().isEmpty) {
      return;
    }
    if (!_isTokenReference(value, prefix: prefix)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Field `$fieldName` must use `$prefix*` token format, got `$value`.',
          path: path,
        ),
      );
    }
  }

  bool _isTokenReference(String? value, {required String prefix}) {
    if (value == null) {
      return false;
    }
    final trimmed = value.trim();
    return trimmed.startsWith(prefix);
  }

  void _validateComponentContracts(
    List<SemanticSceneBlueprintComponent> components,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    for (var index = 0; index < components.length; index += 1) {
      final component = components[index];
      issues.addAll(
        _componentRegistry.validateComponent(
          component: component,
          index: index,
        ),
      );
    }
  }

  void _validateConstraintLayoutContracts({
    required List<SemanticSceneBlueprintComponent> components,
    required Map<String, Object?> metadata,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final profile = _readCanvasProfile(metadata['canvasProfile']);
    final result = _layoutSolver.solve(
      components: components,
      tokenRegistry: _tokenRegistry,
      profile: profile,
    );
    issues.addAll(result.issues);
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneLayoutSolverProofTag '
            'canvasProfile=${profile.name} '
            'deterministicLayoutHash=${result.deterministicLayoutHash}',
        path: 'metadata.canvasProfile',
      ),
    );
  }

  SceneSemanticCanvasProfile _readCanvasProfile(Object? raw) {
    final value = _readString(raw) ?? 'story_9_16';
    final normalized = _normalizeToken(value);
    switch (normalized) {
      case 'landscape169':
      case 'landscape':
      case 'youtube':
      case 'cinema':
        return SceneSemanticCanvasProfile.landscape169;
      case 'square11':
      case 'square':
        return SceneSemanticCanvasProfile.square11;
      case 'portrait45':
      case 'portrait':
      case 'social':
        return SceneSemanticCanvasProfile.portrait45;
      case 'story916':
      default:
        return SceneSemanticCanvasProfile.story916;
    }
  }

  void _validateTextGeometryContracts(
    List<SemanticSceneBlueprintComponent> components,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    for (var index = 0; index < components.length; index += 1) {
      final component = components[index];
      final definition = _componentRegistry.findByType(component.type);
      if (definition == null) {
        continue;
      }
      final resolvedProperties =
          _tokenRegistry.resolveBlueprintValue(component.properties);
      final resolvedSlots =
          _tokenRegistry.resolveBlueprintValue(component.slots);
      final properties = resolvedProperties.value is Map<String, Object?>
          ? resolvedProperties.value as Map<String, Object?>
          : const <String, Object?>{};
      final slots = resolvedSlots.value is Map<String, Object?>
          ? resolvedSlots.value as Map<String, Object?>
          : const <String, Object?>{};
      for (final slotName in _textSlotsForComponent(definition.id)) {
        if (!slots.containsKey(slotName)) {
          continue;
        }
        _validateTextSlotContract(
          component: component,
          componentIndex: index,
          definitionId: definition.id,
          slotName: slotName,
          slotValue: slots[slotName],
          properties: properties,
          issues: issues,
        );
      }
    }
  }

  Set<String> _textSlotsForComponent(String definitionId) {
    switch (definitionId) {
      case 'PromptInputBar':
        return const <String>{'primaryText'};
      case 'FeedbackCard':
        return const <String>{'title', 'body'};
      case 'FeatureCard':
        return const <String>{'title', 'body'};
      case 'ResultCard':
        return const <String>{'title', 'summary'};
      case 'DashboardPanel':
        return const <String>{'header', 'body'};
      case 'CTAButton':
        return const <String>{'label'};
      case 'MotionTextBlock':
        return const <String>{'text', 'subtitle'};
      case 'FloatingWindowCard':
        return const <String>{'title', 'body'};
      case 'OrbitalFeatureRing':
        return const <String>{'centerLabel', 'orbitNodeA', 'orbitNodeB'};
      default:
        return const <String>{};
    }
  }

  void _validateTextSlotContract({
    required SemanticSceneBlueprintComponent component,
    required int componentIndex,
    required String definitionId,
    required String slotName,
    required Object? slotValue,
    required Map<String, Object?> properties,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final pathPrefix = 'components[$componentIndex].slots.$slotName';
    final textValue = _extractSlotText(
      definitionId: definitionId,
      slotName: slotName,
      slotValue: slotValue,
      properties: properties,
    );
    final textFrame = _extractTextFrame(
      definitionId: definitionId,
      slotName: slotName,
      slotValue: slotValue,
      properties: properties,
    );
    if (textFrame == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Text slot `$slotName` in `${component.type}` requires a `textFrame` contract with finite bounds.',
          path: '$pathPrefix.textFrame',
        ),
      );
      return;
    }
    final frameWidth = _doubleFromMap(textFrame, const <String>['width']);
    final frameHeight = _doubleFromMap(textFrame, const <String>['height']);
    final maxLines =
        _doubleFromMap(textFrame, const <String>['maxLines']) ?? 1.0;
    final overflow = (_stringFromMap(
              textFrame,
              const <String>['overflow', 'overflowPolicy'],
            ) ??
            'ellipsis')
        .trim();
    final fitPolicy = (_stringFromMap(
              textFrame,
              const <String>['fitPolicy'],
            ) ??
            'none')
        .trim();
    final normalizedOverflow = _normalizeToken(overflow);
    final normalizedFitPolicy = _normalizeToken(fitPolicy);

    if (frameWidth == null || frameWidth <= 0) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Text slot `$slotName` in `${component.type}` must define `textFrame.width > 0`.',
          path: '$pathPrefix.textFrame.width',
        ),
      );
    }
    if (frameHeight == null || frameHeight <= 0) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Text slot `$slotName` in `${component.type}` must define `textFrame.height > 0`.',
          path: '$pathPrefix.textFrame.height',
        ),
      );
    }
    if (maxLines < 1) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Text slot `$slotName` in `${component.type}` must define `textFrame.maxLines >= 1`.',
          path: '$pathPrefix.textFrame.maxLines',
        ),
      );
    }
    if (!_allowedOverflowPolicies.contains(normalizedOverflow)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Unsupported overflow policy `$overflow` in `${component.type}` text slot `$slotName`.',
          path: '$pathPrefix.textFrame.overflow',
        ),
      );
    }
    if (!_allowedFitPolicies.contains(normalizedFitPolicy)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Unsupported fit policy `$fitPolicy` in `${component.type}` text slot `$slotName`.',
          path: '$pathPrefix.textFrame.fitPolicy',
        ),
      );
    }

    final fontSize = _readDouble(
      textFrame['fontSize'],
      fallback: _readDouble(properties['fontSize'], fallback: 32.0),
    );
    final lineHeight = _readDouble(
      textFrame['lineHeight'],
      fallback: 1.0,
    );
    final estimatedWidth = _estimateTextWidth(
      text: textValue,
      fontSize: fontSize,
      letterSpacing: _readDouble(textFrame['letterSpacing'], fallback: 0.0),
    );
    final estimatedHeight = fontSize * lineHeight * maxLines;
    final overflowDetected = frameWidth != null &&
            frameHeight != null &&
            (estimatedWidth > frameWidth + 1.0 ||
                estimatedHeight > frameHeight + 1.0)
        ? true
        : false;

    if (overflowDetected && normalizedFitPolicy == 'none') {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Text slot `$slotName` in `${component.type}` overflows frame and `fitPolicy` is `none`.',
          path: '$pathPrefix.textFrame.fitPolicy',
        ),
      );
    }

    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneTextGeometryProofTag '
            'componentId=${component.id} '
            'componentType=${component.type} '
            'slotId=$slotName '
            'frameWidth=${frameWidth?.toStringAsFixed(2) ?? 'null'} '
            'frameHeight=${frameHeight?.toStringAsFixed(2) ?? 'null'} '
            'maxLines=${maxLines.toStringAsFixed(2)} '
            'overflowPolicy=$normalizedOverflow '
            'fitPolicy=$normalizedFitPolicy '
            'estimatedWidth=${estimatedWidth.toStringAsFixed(2)} '
            'estimatedHeight=${estimatedHeight.toStringAsFixed(2)} '
            'overflowDetected=$overflowDetected',
        path: pathPrefix,
      ),
    );
  }

  String _extractSlotText({
    required String definitionId,
    required String slotName,
    required Object? slotValue,
    required Map<String, Object?> properties,
  }) {
    if (slotValue is String && slotValue.trim().isNotEmpty) {
      return slotValue.trim();
    }
    if (slotValue is Map<String, Object?>) {
      final fromText = _readString(slotValue['text']);
      if (fromText != null) {
        return fromText;
      }
      final fromValue = _readString(slotValue['value']);
      if (fromValue != null) {
        return fromValue;
      }
      final fromContent = _readString(slotValue['content']);
      if (fromContent != null) {
        return fromContent;
      }
    }
    if (definitionId == 'PromptInputBar' && slotName == 'primaryText') {
      return _readString(properties['promptText']) ??
          'generate new offer for my business';
    }
    return '';
  }

  Map<String, Object?>? _extractTextFrame({
    required String definitionId,
    required String slotName,
    required Object? slotValue,
    required Map<String, Object?> properties,
  }) {
    if (slotValue is Map<String, Object?>) {
      final fromSlot = _readMap(slotValue['textFrame']);
      if (fromSlot != null) {
        return fromSlot;
      }
    }
    final fromNamedProperty = _readMap(properties['${slotName}TextFrame']);
    if (fromNamedProperty != null) {
      return fromNamedProperty;
    }
    final fromGeneric = _readMap(properties['textFrame']);
    if (fromGeneric != null) {
      return fromGeneric;
    }
    if (definitionId == 'PromptInputBar' && slotName == 'primaryText') {
      final width = _readDouble(properties['textFrameWidth'],
          fallback: _readDouble(properties['width'], fallback: 860.0) - 180.0);
      final height = _readDouble(
        properties['textFrameHeight'],
        fallback: 60.0,
      );
      return <String, Object?>{
        'width': width,
        'height': height,
        'maxLines': 1.0,
        'overflow': 'ellipsis',
        'fitPolicy': 'shrinkToFit',
      };
    }
    return null;
  }

  String? _stringFromMap(Map<String, Object?>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
    final normalized = keys.map(_normalizeToken).toSet();
    for (final entry in map.entries) {
      if (!normalized.contains(_normalizeToken(entry.key))) {
        continue;
      }
      if (entry.value is String) {
        final value = (entry.value as String).trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  double? _doubleFromMap(Map<String, Object?>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
    final normalized = keys.map(_normalizeToken).toSet();
    for (final entry in map.entries) {
      if (!normalized.contains(_normalizeToken(entry.key))) {
        continue;
      }
      if (entry.value is num) {
        return (entry.value as num).toDouble();
      }
    }
    return null;
  }

  double _estimateTextWidth({
    required String text,
    required double fontSize,
    required double letterSpacing,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0.0;
    }
    final glyphCount = trimmed.runes.length;
    final glyphWidth = fontSize * 0.56;
    final spacing = (glyphCount > 1 ? (glyphCount - 1) : 0) * letterSpacing;
    return (glyphWidth * glyphCount) + spacing;
  }

  String _normalizeToken(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  void _validateSpeedGraphDependency({
    required String componentId,
    required Map<String, Object?> motionIntents,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    if (motionIntents.isEmpty) {
      return;
    }
    _walkMotionIntents(
      node: motionIntents,
      path: 'components.$componentId.motionIntents',
      componentId: componentId,
      issues: issues,
    );
  }

  void _walkMotionIntents({
    required Object? node,
    required String path,
    required String componentId,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    if (node is Map<String, Object?>) {
      if (_looksLikeBezierLiteral(node)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'SpeedyGraph dependency gate rejected direct bezier literals in semantic motion intents. Use easing or preset tokens so interpolation compiles through MotionInterpolationTruthCompiler.',
            path: path,
          ),
        );
        return;
      }
      for (final entry in node.entries) {
        final childPath = '$path.${entry.key}';
        if (_isSpeedGraphKey(entry.key) && entry.value is String) {
          _compileSpeedGraphCandidate(
            componentId: componentId,
            candidate: entry.value as String,
            path: childPath,
            issues: issues,
          );
        } else {
          _walkMotionIntents(
            node: entry.value,
            path: childPath,
            componentId: componentId,
            issues: issues,
          );
        }
      }
      return;
    }
    if (node is List) {
      for (var index = 0; index < node.length; index += 1) {
        _walkMotionIntents(
          node: node[index],
          path: '$path[$index]',
          componentId: componentId,
          issues: issues,
        );
      }
    }
  }

  void _compileSpeedGraphCandidate({
    required String componentId,
    required String candidate,
    required String path,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final raw = candidate.trim();
    if (raw.isEmpty) {
      return;
    }
    final canonical = MotionInterpolationTruthCompiler.canonicalPresetId(raw);
    final compileResult = _truthCompiler.compileFromPresetId(canonical);
    final unknownPreset = canonical == 'linear' && !_isLinearAlias(raw);
    if (unknownPreset) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Unknown SpeedyGraph preset `$raw` in semantic motion intent. Use a known preset token so motion compiles through MotionInterpolationTruthCompiler.',
          path: path,
        ),
      );
      return;
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneSpeedyGraphDependencyProofTag '
            'componentId=$componentId '
            'path=$path '
            'rawPreset=$raw '
            'canonicalPreset=${compileResult.presetId ?? canonical} '
            'executionTruth=${compileResult.executionTruth} '
            'curveHash=${compileResult.curveHash} '
            'velocityHash=${compileResult.velocityHash} '
            'routedThroughTruthCompiler=true',
        path: path,
      ),
    );
  }

  bool _looksLikeBezierLiteral(Map<String, Object?> map) {
    final keys = map.keys.map((it) => it.toLowerCase()).toSet();
    return keys.contains('x1') &&
        keys.contains('y1') &&
        keys.contains('x2') &&
        keys.contains('y2');
  }

  bool _isSpeedGraphKey(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized == 'easing' ||
        normalized == 'preset' ||
        normalized == 'speedgraph' ||
        normalized == 'speed_graph' ||
        normalized == 'curve';
  }

  bool _isLinearAlias(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '',
        );
    return normalized == 'linear' ||
        normalized == 'line' ||
        normalized == 'none' ||
        normalized == 'nolinearease';
  }
}
