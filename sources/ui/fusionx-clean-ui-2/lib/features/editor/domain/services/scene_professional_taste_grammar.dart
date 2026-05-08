import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';

const String kSceneTasteGrammarProofTag = 'TF_SCENE_TASTE_GRAMMAR_PROOF';

class SceneProfessionalTasteSuggestion {
  const SceneProfessionalTasteSuggestion({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final ReFusionSceneProgramIssueSeverity severity;
}

class SceneProfessionalTasteReport {
  const SceneProfessionalTasteReport({
    required this.focalScore,
    required this.densityScore,
    required this.typeScaleScore,
    required this.motionPacingScore,
    required this.suggestions,
    required this.issues,
  });

  final int focalScore;
  final int densityScore;
  final int typeScaleScore;
  final int motionPacingScore;
  final List<SceneProfessionalTasteSuggestion> suggestions;
  final List<ReFusionSceneProgramIssue> issues;
}

class SceneProfessionalTasteGrammar {
  const SceneProfessionalTasteGrammar();

  SceneProfessionalTasteReport evaluate(
    ReFusionSceneProgram program, {
    String profile = 'default',
  }) {
    final elements = program.layers
        .expand((layer) => layer.elements)
        .toList(growable: false);
    final textElements = elements
        .where((element) => _normalize(element.kind) == 'text')
        .toList(growable: false);
    final allChannels = <ReFusionSceneProgramChannel>[
      ...program.layers.expand((layer) => layer.channels),
      ...program.layers.expand((layer) => layer.elements.expand(
            (element) => element.channels,
          )),
    ];

    final focalScore = _focalScore(elements.length);
    final densityScore = _densityScore(elements.length);
    final typeScaleScore = _typeScaleScore(textElements);
    final motionPacingScore = _motionPacingScore(allChannels);

    final suggestions = <SceneProfessionalTasteSuggestion>[
      ..._focalSuggestions(focalScore),
      ..._densitySuggestions(densityScore),
      ..._typeScaleSuggestions(typeScaleScore, textElements),
      ..._motionSuggestions(motionPacingScore),
    ];

    final issues = <ReFusionSceneProgramIssue>[
      for (final suggestion in suggestions)
        ReFusionSceneProgramIssue(
          severity: suggestion.severity,
          message: '${suggestion.code}: ${suggestion.message}',
          path: r'$',
        ),
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneTasteGrammarProofTag '
            'sceneId=${program.name} '
            'profile=$profile '
            'focalScore=$focalScore '
            'densityScore=$densityScore '
            'typeScaleScore=$typeScaleScore '
            'motionPacingScore=$motionPacingScore '
            'suggestions=${suggestions.map((s) => s.code).join('|')}',
        path: r'$',
      ),
    ];

    return SceneProfessionalTasteReport(
      focalScore: focalScore,
      densityScore: densityScore,
      typeScaleScore: typeScaleScore,
      motionPacingScore: motionPacingScore,
      suggestions: List<SceneProfessionalTasteSuggestion>.unmodifiable(
        suggestions,
      ),
      issues: List<ReFusionSceneProgramIssue>.unmodifiable(issues),
    );
  }

  int _focalScore(int elementCount) {
    if (elementCount <= 1) {
      return 82;
    }
    final penalty = math.max(0, elementCount - 4) * 8;
    return (92 - penalty).clamp(0, 100).toInt();
  }

  int _densityScore(int elementCount) {
    const idealMin = 4;
    const idealMax = 12;
    if (elementCount >= idealMin && elementCount <= idealMax) {
      return 92;
    }
    final distance = elementCount < idealMin
        ? idealMin - elementCount
        : elementCount - idealMax;
    return (92 - (distance * 9)).clamp(0, 100).toInt();
  }

  int _typeScaleScore(List<ReFusionSceneProgramElement> textElements) {
    final fontSizes = <double>[
      for (final element in textElements) _fontSizeFor(element) ?? -1.0,
    ].where((size) => size > 0).toList(growable: false);
    if (fontSizes.isEmpty) {
      return 72;
    }
    final minFont = fontSizes.reduce(math.min);
    final maxFont = fontSizes.reduce(math.max);
    var score = 90;
    final ratio = minFont == 0 ? 0 : maxFont / minFont;
    if (ratio < 1.15 || ratio > 3.2) {
      score -= 26;
    }
    if (maxFont > 74 || minFont < 10) {
      score -= 20;
    }
    return score.clamp(0, 100).toInt();
  }

  int _motionPacingScore(List<ReFusionSceneProgramChannel> channels) {
    final deltas = <int>[];
    for (final channel in channels) {
      final sorted = channel.keyframes.toList(growable: false)
        ..sort((left, right) => left.timeMs.compareTo(right.timeMs));
      for (var index = 1; index < sorted.length; index += 1) {
        deltas.add(sorted[index].timeMs - sorted[index - 1].timeMs);
      }
    }
    if (deltas.isEmpty) {
      return 68;
    }
    final minDelta = deltas.reduce(math.min);
    final maxDelta = deltas.reduce(math.max);
    var score = 90;
    if (minDelta < 80) {
      score -= 24;
    }
    if (maxDelta > 2200) {
      score -= 18;
    }
    return score.clamp(0, 100).toInt();
  }

  List<SceneProfessionalTasteSuggestion> _focalSuggestions(int score) {
    if (score >= 70) {
      return const <SceneProfessionalTasteSuggestion>[];
    }
    return const <SceneProfessionalTasteSuggestion>[
      SceneProfessionalTasteSuggestion(
        code: 'FOCAL_HIERARCHY_WEAK',
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message:
            'Strengthen focal hierarchy by reducing simultaneous primary objects and emphasizing one anchor component.',
      ),
    ];
  }

  List<SceneProfessionalTasteSuggestion> _densitySuggestions(int score) {
    if (score >= 70) {
      return const <SceneProfessionalTasteSuggestion>[];
    }
    return const <SceneProfessionalTasteSuggestion>[
      SceneProfessionalTasteSuggestion(
        code: 'CARD_DENSITY_IMBALANCED',
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message:
            'Rebalance card density and spacing to avoid crowded or overly empty composition zones.',
      ),
    ];
  }

  List<SceneProfessionalTasteSuggestion> _typeScaleSuggestions(
    int score,
    List<ReFusionSceneProgramElement> textElements,
  ) {
    final suggestions = <SceneProfessionalTasteSuggestion>[];
    if (score < 70) {
      suggestions.add(
        const SceneProfessionalTasteSuggestion(
          code: 'TYPE_SCALE_IMBALANCED',
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Typography scale is imbalanced; align heading/body ratios with professional type tokens.',
        ),
      );
    }
    final fitRisk = textElements.any(_hasBoundedTextFitRisk);
    if (fitRisk) {
      suggestions.add(
        const SceneProfessionalTasteSuggestion(
          code: 'TEXT_FIT_RISK',
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Text fit risk detected. Prefer bounded textFrame with shrinkToFit or ellipsis policy.',
        ),
      );
    }
    return suggestions;
  }

  List<SceneProfessionalTasteSuggestion> _motionSuggestions(int score) {
    if (score >= 70) {
      return const <SceneProfessionalTasteSuggestion>[];
    }
    return const <SceneProfessionalTasteSuggestion>[
      SceneProfessionalTasteSuggestion(
        code: 'MOTION_PACING_IMBALANCED',
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message:
            'Motion pacing is inconsistent. Increase readable holds and avoid ultra-short transition bursts.',
      ),
    ];
  }

  bool _hasBoundedTextFitRisk(ReFusionSceneProgramElement element) {
    final text = element.text ?? '';
    if (text.trim().isEmpty) {
      return false;
    }
    final frame = element.properties['textFrame'];
    if (frame is! Map<String, Object?>) {
      return false;
    }
    final width = _readDouble(frame['width']);
    if (width == null || width <= 0) {
      return false;
    }
    final overflow = _normalize((frame['overflow'] ?? '').toString());
    final fitPolicy = _normalize((frame['fitPolicy'] ?? '').toString());
    if (overflow == 'ellipsis' || fitPolicy == 'shrinktofit') {
      return false;
    }
    final fontSize = _fontSizeFor(element) ?? 24;
    final estimatedWidth = text.length * fontSize * 0.55;
    return estimatedWidth > width;
  }

  double? _fontSizeFor(ReFusionSceneProgramElement element) {
    return _readDouble(element.properties['fontSize']);
  }

  double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
