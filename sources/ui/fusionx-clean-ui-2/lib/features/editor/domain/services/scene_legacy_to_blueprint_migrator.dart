import '../models/refusion_scene_program_models.dart';

enum SceneLegacyBlueprintMigrationTier {
  tierA,
  tierB,
  tierC,
  tierD,
}

class SceneLegacyToBlueprintMigrationResult {
  SceneLegacyToBlueprintMigrationResult({
    required this.tier,
    required this.reason,
    required List<ReFusionSceneProgramIssue> issues,
    this.blueprintPayload,
  }) : issues = List.unmodifiable(issues);

  final SceneLegacyBlueprintMigrationTier tier;
  final String reason;
  final Map<String, Object?>? blueprintPayload;
  final List<ReFusionSceneProgramIssue> issues;

  bool get isMigrated => blueprintPayload != null;
}

class SceneLegacyToBlueprintMigrator {
  const SceneLegacyToBlueprintMigrator();

  SceneLegacyToBlueprintMigrationResult migrate({
    required Map<String, Object?> legacyPayload,
  }) {
    final layers = legacyPayload['layers'];
    if (layers is! List) {
      return SceneLegacyToBlueprintMigrationResult(
        tier: SceneLegacyBlueprintMigrationTier.tierD,
        reason: 'missing_layers',
        issues: const <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Legacy migration rejected: raw payload does not look like a SceneProgram layer graph.',
            path: r'$',
          ),
        ],
      );
    }

    final promptPattern = _detectPromptInputPattern(layers);
    if (promptPattern == null) {
      return SceneLegacyToBlueprintMigrationResult(
        tier: SceneLegacyBlueprintMigrationTier.tierC,
        reason: 'no_known_component_pattern',
        issues: const <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.warning,
            message:
                'Legacy payload kept as raw SceneProgram (Tier C). No known component-safe pattern was detected for auto-conversion.',
            path: r'$.layers',
          ),
        ],
      );
    }

    final durationMs = _asInt(legacyPayload['durationMs'], fallback: 3000);
    final frameRate = _asDouble(legacyPayload['frameRate'], fallback: 30.0);
    final sceneName =
        (legacyPayload['name'] as String?)?.trim().isNotEmpty == true
            ? (legacyPayload['name'] as String).trim()
            : 'Migrated Legacy Scene';

    final blueprint = <String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': '$sceneName (Migrated)',
      'durationMs': durationMs,
      'frameRate': frameRate,
      'components': <Object?>[
        <String, Object?>{
          'id': 'migrated-prompt-input',
          'type': 'PromptInputBar',
          'properties': <String, Object?>{
            'promptText': promptPattern.promptText,
            'width': promptPattern.shellWidth,
            'height': promptPattern.shellHeight,
            'anchor': <String, Object?>{
              'x': promptPattern.shellX,
              'y': promptPattern.shellY,
            },
            'textFrameWidth': promptPattern.textFrameWidth,
            'textFrameHeight': promptPattern.textFrameHeight,
          },
          'slots': <String, Object?>{
            'primaryText': promptPattern.promptText,
          },
          'motionIntents': const <String, Object?>{
            'timing': r'$duration.standard',
            'easing': r'$easing.standard',
          },
        },
      ],
      'beats': <Object?>[
        <String, Object?>{
          'id': 'intro',
          'startMs': 0,
          'endMs': (durationMs * 0.45).round(),
          'intent': 'introduce prompt input',
          'componentRefs': const <Object?>['migrated-prompt-input'],
        },
        <String, Object?>{
          'id': 'hold',
          'startMs': (durationMs * 0.45).round(),
          'endMs': durationMs,
          'intent': 'readable hold for prompt input',
          'componentRefs': const <Object?>['migrated-prompt-input'],
        },
      ],
      'metadata': const <String, Object?>{
        'migrationSource': 'legacy_scene_program',
        'migrationTier': 'tierA',
      },
    };

    return SceneLegacyToBlueprintMigrationResult(
      tier: SceneLegacyBlueprintMigrationTier.tierA,
      reason: 'prompt_input_pattern_detected',
      blueprintPayload: blueprint,
      issues: const <ReFusionSceneProgramIssue>[
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          message:
              'Legacy scene auto-converted to semantic blueprint (Tier A: PromptInputBar pattern).',
          path: r'$.components',
        ),
      ],
    );
  }

  _PromptInputPattern? _detectPromptInputPattern(List<dynamic> layers) {
    Map<String, Object?>? shell;
    Map<String, Object?>? text;
    for (final rawLayer in layers) {
      if (rawLayer is! Map<String, Object?>) {
        continue;
      }
      final elements = rawLayer['elements'];
      if (elements is! List) {
        continue;
      }
      for (final rawElement in elements) {
        if (rawElement is! Map<String, Object?>) {
          continue;
        }
        final id = ((rawElement['id'] as String?) ?? '').toLowerCase();
        final kind = ((rawElement['kind'] as String?) ?? '').toLowerCase();
        if (kind == 'shape' &&
            (id.contains('prompt') || id.contains('shell'))) {
          shell = rawElement;
        }
        if (kind == 'text' && id.contains('prompt')) {
          text = rawElement;
        }
      }
    }
    if (shell == null || text == null) {
      return null;
    }

    final shellProps = shell['properties'] is Map<String, Object?>
        ? shell['properties'] as Map<String, Object?>
        : const <String, Object?>{};
    final textProps = text['properties'] is Map<String, Object?>
        ? text['properties'] as Map<String, Object?>
        : const <String, Object?>{};
    final shellPosition = _readPoint(shellProps['position']);

    final textFrame = textProps['textFrame'] is Map<String, Object?>
        ? textProps['textFrame'] as Map<String, Object?>
        : const <String, Object?>{};

    return _PromptInputPattern(
      promptText: ((text['text'] as String?) ?? 'generate new offer').trim(),
      shellX: _asDouble(shellProps['x'], fallback: shellPosition.$1 ?? 0.0),
      shellY: _asDouble(shellProps['y'], fallback: shellPosition.$2 ?? -40.0),
      shellWidth: _asDouble(shellProps['width'], fallback: 860.0),
      shellHeight: _asDouble(shellProps['height'], fallback: 112.0),
      textFrameWidth: _asDouble(textFrame['width'], fallback: 680.0),
      textFrameHeight: _asDouble(textFrame['height'], fallback: 60.0),
    );
  }

  (double?, double?) _readPoint(Object? value) {
    if (value is Map<String, Object?>) {
      return (
        _asDouble(value['x'], fallback: null),
        _asDouble(value['y'], fallback: null)
      );
    }
    return (null, null);
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  double _asDouble(Object? value, {required double? fallback}) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback ?? 0.0;
  }
}

class _PromptInputPattern {
  const _PromptInputPattern({
    required this.promptText,
    required this.shellX,
    required this.shellY,
    required this.shellWidth,
    required this.shellHeight,
    required this.textFrameWidth,
    required this.textFrameHeight,
  });

  final String promptText;
  final double shellX;
  final double shellY;
  final double shellWidth;
  final double shellHeight;
  final double textFrameWidth;
  final double textFrameHeight;
}
