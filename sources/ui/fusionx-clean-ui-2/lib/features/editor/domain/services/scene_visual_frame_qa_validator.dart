import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';

class SceneVisualFrameQaValidationResult {
  SceneVisualFrameQaValidationResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneVisualFrameQaValidator {
  const SceneVisualFrameQaValidator();

  SceneVisualFrameQaValidationResult validate(ReFusionSceneProgram program) {
    final issues = <ReFusionSceneProgramIssue>[];
    for (var layerIndex = 0; layerIndex < program.layers.length; layerIndex++) {
      final layer = program.layers[layerIndex];
      _lintLayer(
        program: program,
        layer: layer,
        layerIndex: layerIndex,
        issues: issues,
      );
    }
    return SceneVisualFrameQaValidationResult(issues: issues);
  }

  void _lintLayer({
    required ReFusionSceneProgram program,
    required ReFusionSceneProgramLayer layer,
    required int layerIndex,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final probeTimes =
        _collectProbeTimes(layer: layer, sceneDuration: program.durationMs);
    if (probeTimes.isEmpty) {
      return;
    }

    for (var elementIndex = 0;
        elementIndex < layer.elements.length;
        elementIndex++) {
      final element = layer.elements[elementIndex];
      if (_normalizeToken(element.kind) != 'text') {
        continue;
      }
      final hasReveal = _hasTypewriterChannel(
        layerChannels: layer.channels,
        element: element,
      );
      if (!hasReveal) {
        continue;
      }
      final textFrame = _mapFromProperties(
        element.properties,
        const <String>['textFrame', 'layoutTextFrame'],
      );
      final frameWidth =
          _doubleFromMap(textFrame, const <String>['width', 'maxWidth']);
      final estimatedWidth = _estimateTextWidth(element);
      if (frameWidth != null && estimatedWidth > frameWidth + 1.0) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.warning,
            message:
                'Text element `${element.id}` may overflow its fixed reveal frame at QA probes. Increase frame width or use shrinkToFit.',
            path:
                'layers[$layerIndex].elements[$elementIndex].properties.textFrame.width',
          ),
        );
      }
    }

    final proof = StringBuffer()
      ..write('TF_SCENE_VISUAL_FRAME_QA_PROOF ')
      ..write('layer=${layer.id} ')
      ..write('probeCount=${probeTimes.length} ')
      ..write('probesMs=${probeTimes.join(",")} ')
      ..write('fallbackReason=none');
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: proof.toString(),
        path: 'layers[$layerIndex]',
      ),
    );
  }

  List<int> _collectProbeTimes({
    required ReFusionSceneProgramLayer layer,
    required int sceneDuration,
  }) {
    final probes = <int>{
      layer.startMs.clamp(0, sceneDuration),
      (layer.startMs + (layer.durationMs / 2).round()).clamp(0, sceneDuration),
      (layer.startMs + layer.durationMs - 1).clamp(0, sceneDuration),
    };

    void absorbChannel(ReFusionSceneProgramChannel channel) {
      final sorted = channel.keyframes.toList(growable: false)
        ..sort((left, right) => left.timeMs.compareTo(right.timeMs));
      for (var index = 0; index < sorted.length; index++) {
        probes.add(sorted[index].timeMs.clamp(0, sceneDuration));
        if (index > 0) {
          final previous = sorted[index - 1].timeMs;
          final current = sorted[index].timeMs;
          probes
              .add(((previous + current) / 2).round().clamp(0, sceneDuration));
        }
      }
    }

    for (final channel in layer.channels) {
      absorbChannel(channel);
    }
    for (final element in layer.elements) {
      for (final channel in element.channels) {
        absorbChannel(channel);
      }
    }
    final sorted = probes.toList(growable: false)..sort();
    return sorted;
  }

  bool _hasTypewriterChannel({
    required List<ReFusionSceneProgramChannel> layerChannels,
    required ReFusionSceneProgramElement element,
  }) {
    bool matches(ReFusionSceneProgramChannel channel) {
      final property = _normalizeToken(channel.property);
      final target = _normalizeToken(channel.target);
      return property == 'typewriterprogress' &&
          target == _normalizeToken(element.id);
    }

    for (final channel in layerChannels) {
      if (matches(channel)) {
        return true;
      }
    }
    for (final channel in element.channels) {
      if (_normalizeToken(channel.property) == 'typewriterprogress') {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?>? _mapFromProperties(
    Map<String, Object?> properties,
    List<String> keys,
  ) {
    final normalized = keys.map(_normalizeToken).toSet();
    for (final entry in properties.entries) {
      if (!normalized.contains(_normalizeToken(entry.key))) {
        continue;
      }
      final value = entry.value;
      if (value is Map) {
        return value.cast<String, Object?>();
      }
      return null;
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
      final value = entry.value;
      if (value is num) {
        return value.toDouble();
      }
    }
    return null;
  }

  double _estimateTextWidth(ReFusionSceneProgramElement element) {
    final text = (element.text ?? '').trim();
    if (text.isEmpty) {
      return 0;
    }
    final fontSize = _readScalar(
          element.properties,
          const <String>['fontSize', 'fontsize'],
        ) ??
        16;
    final letterSpacing = _readScalar(
          element.properties,
          const <String>['letterSpacing', 'tracking'],
        ) ??
        0;
    final estimatedGlyphWidth = fontSize * 0.56;
    final glyphCount = text.runes.length;
    final spacing = math.max(0, glyphCount - 1) * letterSpacing;
    return (estimatedGlyphWidth * glyphCount) + spacing;
  }

  double? _readScalar(Map<String, Object?> map, List<String> keys) {
    final normalized = keys.map(_normalizeToken).toSet();
    for (final entry in map.entries) {
      if (!normalized.contains(_normalizeToken(entry.key))) {
        continue;
      }
      final value = entry.value;
      if (value is num) {
        return value.toDouble();
      }
    }
    return null;
  }

  String _normalizeToken(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
