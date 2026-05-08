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
  const SceneVisualFrameQaValidator({
    this.enforceOverflowAsError = false,
  });
  static const int _fullProbeBudget = 9;
  static const int _fallbackProbeBudget = 5;
  static const int _probeTimeBudgetMs = 800;
  static const double _defaultCanvasWidth = 1080;
  static const double _defaultCanvasHeight = 1920;
  static const double _safeAreaInset = 24;
  final bool enforceOverflowAsError;

  SceneVisualFrameQaValidationResult validate(ReFusionSceneProgram program) {
    final stopwatch = Stopwatch()..start();
    final issues = <ReFusionSceneProgramIssue>[];
    final allRects = <_ElementRect>[];
    for (var layerIndex = 0; layerIndex < program.layers.length; layerIndex++) {
      final layer = program.layers[layerIndex];
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex++) {
        final rect = _rectForElement(layer.elements[elementIndex]);
        if (rect != null) {
          allRects.add(
            _ElementRect(
              layerIndex: layerIndex,
              elementIndex: elementIndex,
              elementId: layer.elements[elementIndex].id,
              rect: rect,
            ),
          );
        }
      }
      _lintLayer(
        program: program,
        layer: layer,
        layerIndex: layerIndex,
        allRects: allRects,
        elapsedMsProvider: () => stopwatch.elapsedMilliseconds,
        issues: issues,
      );
    }
    stopwatch.stop();
    return SceneVisualFrameQaValidationResult(issues: issues);
  }

  void _lintLayer({
    required ReFusionSceneProgram program,
    required ReFusionSceneProgramLayer layer,
    required int layerIndex,
    required List<_ElementRect> allRects,
    required int Function() elapsedMsProvider,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final allProbeTimes = _collectProbeTimes(
      layer: layer,
      sceneDuration: program.durationMs,
    );
    final heavyScene = _isHeavyScene(layer);
    final probeBudget = heavyScene ? _fallbackProbeBudget : _fullProbeBudget;
    final probeTimes = _trimProbeTimes(allProbeTimes, maxCount: probeBudget);
    if (probeTimes.isEmpty) {
      return;
    }

    final layerRects = allRects.where((it) => it.layerIndex == layerIndex).toList(
          growable: false,
        );
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
        final textFrame = _mapFromProperties(
          element.properties,
          const <String>['textFrame', 'layoutTextFrame'],
        );
        if (textFrame == null) {
          continue;
        }
        _lintBoundedTextElement(
          layerIndex: layerIndex,
          elementIndex: elementIndex,
          element: element,
          textFrame: textFrame,
          layerRects: layerRects,
          probeTimes: probeTimes,
          elapsedMsProvider: elapsedMsProvider,
          sceneDuration: program.durationMs,
          issues: issues,
          revealMode: false,
        );
        continue;
      }
      final textFrame = _mapFromProperties(
        element.properties,
        const <String>['textFrame', 'layoutTextFrame'],
      );
      if (textFrame == null) {
        continue;
      }
      _lintBoundedTextElement(
        layerIndex: layerIndex,
        elementIndex: elementIndex,
        element: element,
        textFrame: textFrame,
        layerRects: layerRects,
        probeTimes: probeTimes,
        elapsedMsProvider: elapsedMsProvider,
        sceneDuration: program.durationMs,
        issues: issues,
        revealMode: true,
      );
    }
  }

  void _lintBoundedTextElement({
    required int layerIndex,
    required int elementIndex,
    required ReFusionSceneProgramElement element,
    required Map<String, Object?> textFrame,
    required List<_ElementRect> layerRects,
    required List<int> probeTimes,
    required int sceneDuration,
    required int Function() elapsedMsProvider,
    required List<ReFusionSceneProgramIssue> issues,
    required bool revealMode,
  }) {
    final frameWidth =
        _doubleFromMap(textFrame, const <String>['width', 'maxWidth']);
    final frameHeight =
        _doubleFromMap(textFrame, const <String>['height', 'maxHeight']);
    final maxLines =
        _doubleFromMap(textFrame, const <String>['maxLines']) ?? 1.0;
    final overflowPolicy = (_stringFromMap(
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
    final normalizedFitPolicy = _normalizeToken(fitPolicy);
    final estimatedWidth = _estimateTextWidth(element);
    final estimatedHeight = _estimateTextHeight(element) * maxLines;
    final widthOverflow =
        frameWidth != null && estimatedWidth > frameWidth + 1.0;
    final heightOverflow =
        frameHeight != null && estimatedHeight > frameHeight + 1.0;
    final overflowDetected = widthOverflow || heightOverflow;
    final supportedFitPolicy = normalizedFitPolicy == 'shrinktofit' ||
        normalizedFitPolicy == 'wraptolines' ||
        normalizedFitPolicy == 'ellipsisaftermaxlines' ||
        normalizedFitPolicy == 'cliptoframe' ||
        normalizedFitPolicy == 'shorten' ||
        normalizedFitPolicy == 'scalexfornumericonly';
    final rect = _rectForElement(element);
    final clipped = rect != null && _isOutsideCanvas(rect);
    final safeAreaViolation = rect != null && _violatesSafeArea(rect);
    final overlap = rect != null &&
        _hasOverlap(
          layerRects: layerRects,
          targetElementId: element.id,
          targetRect: rect,
        );
    final contrastPass = _contrastPass(element);
    final unfinishedMotion = _unfinishedMotionAtBoundary(
      probeTimes: probeTimes,
      sceneDuration: sceneDuration,
      revealMode: revealMode,
    );
    final probeCount = probeTimes.length;
    final budgetExceeded = elapsedMsProvider() > _probeTimeBudgetMs;

    if (overflowDetected) {
      final permissiveLegacyPolicy =
          !enforceOverflowAsError && normalizedFitPolicy == 'none';
      final severity = (supportedFitPolicy || permissiveLegacyPolicy)
          ? ReFusionSceneProgramIssueSeverity.warning
          : ReFusionSceneProgramIssueSeverity.error;
      issues.add(
        ReFusionSceneProgramIssue(
          severity: severity,
          message: 'Text element `${element.id}` '
              '${revealMode ? 'reveal' : 'static'} bounded frame overflow detected. '
              'overflowPolicy=$overflowPolicy fitPolicy=$fitPolicy '
              'estimatedWidth=${estimatedWidth.toStringAsFixed(2)} '
              'estimatedHeight=${estimatedHeight.toStringAsFixed(2)} '
              'frameWidth=${frameWidth?.toStringAsFixed(2) ?? 'null'} '
              'frameHeight=${frameHeight?.toStringAsFixed(2) ?? 'null'}',
          path:
              'layers[$layerIndex].elements[$elementIndex].properties.textFrame',
        ),
      );
    }

    for (var index = 0; index < probeTimes.length; index += 1) {
      final frameMs = probeTimes[index];
      final passed = !overflowDetected && !clipped && !safeAreaViolation && !overlap;
      final failureReason = passed
          ? 'none'
          : _firstFailureReason(
              overflowDetected: overflowDetected,
              clipped: clipped,
              overlap: overlap,
              safeAreaViolation: safeAreaViolation,
            );
      final proof = StringBuffer()
        ..write('TF_SCENE_VISUAL_FRAME_QA_PROOF ')
        ..write('frameMs=$frameMs ')
        ..write('probeIndex=${index + 1} ')
        ..write('probeCount=$probeCount ')
        ..write('componentId=${element.id} ')
        ..write('textOverflow=${overflowDetected.toString()} ')
        ..write('clipped=${clipped.toString()} ')
        ..write('overlap=${overlap.toString()} ')
        ..write('safeAreaViolation=${safeAreaViolation.toString()} ')
        ..write('contrastPass=${contrastPass.toString()} ')
        ..write('unfinishedMotion=${unfinishedMotion.toString()} ')
        ..write('probeDurationMs=${elapsedMsProvider()} ')
        ..write('performanceBudgetExceeded=${budgetExceeded.toString()} ')
        ..write('passed=${passed.toString()} ')
        ..write('failureReason=$failureReason');
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          message: proof.toString(),
          path: 'layers[$layerIndex].elements[$elementIndex].probe[$index]',
        ),
      );
    }
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

  List<int> _trimProbeTimes(List<int> values, {required int maxCount}) {
    if (values.length <= maxCount) {
      return values;
    }
    final selected = <int>{values.first, values.last};
    if (values.length > 2) {
      selected.add(values[(values.length / 2).floor()]);
    }
    var index = 1;
    while (selected.length < maxCount && index < values.length - 1) {
      selected.add(values[index]);
      if (selected.length >= maxCount) {
        break;
      }
      selected.add(values[values.length - 1 - index]);
      index += 1;
    }
    final sorted = selected.toList(growable: false)..sort();
    return sorted.take(maxCount).toList(growable: false);
  }

  bool _isHeavyScene(ReFusionSceneProgramLayer layer) {
    final channelCount = layer.channels.length +
        layer.elements.fold<int>(
          0,
          (sum, element) => sum + element.channels.length,
        );
    return layer.elements.length > 12 || channelCount > 24;
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

  String? _stringFromMap(Map<String, Object?>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
    final normalized = keys.map(_normalizeToken).toSet();
    for (final entry in map.entries) {
      if (!normalized.contains(_normalizeToken(entry.key))) {
        continue;
      }
      final value = entry.value;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
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

  double _estimateTextHeight(ReFusionSceneProgramElement element) {
    final fontSize = _readScalar(
          element.properties,
          const <String>['fontSize', 'fontsize'],
        ) ??
        16;
    final lineHeight = _readScalar(
          element.properties,
          const <String>['lineHeight', 'lineheight'],
        ) ??
        1.0;
    return fontSize * lineHeight;
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

  _Rect? _rectForElement(ReFusionSceneProgramElement element) {
    final x = _readScalar(
      element.properties,
      const <String>['x', 'left', 'positionX'],
    );
    final y = _readScalar(
      element.properties,
      const <String>['y', 'top', 'positionY'],
    );
    var width = _readScalar(
      element.properties,
      const <String>['width', 'w'],
    );
    var height = _readScalar(
      element.properties,
      const <String>['height', 'h'],
    );
    final textFrame = _mapFromProperties(
      element.properties,
      const <String>['textFrame', 'layoutTextFrame'],
    );
    width ??= _doubleFromMap(textFrame, const <String>['width', 'maxWidth']);
    height ??= _doubleFromMap(textFrame, const <String>['height', 'maxHeight']);
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    return _Rect(x: x, y: y, width: width, height: height);
  }

  bool _hasOverlap({
    required List<_ElementRect> layerRects,
    required String targetElementId,
    required _Rect targetRect,
  }) {
    for (final item in layerRects) {
      if (_normalizeToken(item.elementId) == _normalizeToken(targetElementId)) {
        continue;
      }
      if (_intersects(targetRect, item.rect)) {
        return true;
      }
    }
    return false;
  }

  bool _intersects(_Rect a, _Rect b) {
    final ax2 = a.x + a.width;
    final ay2 = a.y + a.height;
    final bx2 = b.x + b.width;
    final by2 = b.y + b.height;
    return a.x < bx2 && ax2 > b.x && a.y < by2 && ay2 > b.y;
  }

  bool _isOutsideCanvas(_Rect rect) {
    return rect.x < 0 ||
        rect.y < 0 ||
        rect.x + rect.width > _defaultCanvasWidth ||
        rect.y + rect.height > _defaultCanvasHeight;
  }

  bool _violatesSafeArea(_Rect rect) {
    return rect.x < _safeAreaInset ||
        rect.y < _safeAreaInset ||
        rect.x + rect.width > _defaultCanvasWidth - _safeAreaInset ||
        rect.y + rect.height > _defaultCanvasHeight - _safeAreaInset;
  }

  bool _contrastPass(ReFusionSceneProgramElement element) {
    final opacity = _readScalar(
      element.properties,
      const <String>['opacity', 'alpha'],
    );
    if (opacity != null && opacity < 0.35) {
      return false;
    }
    return true;
  }

  bool _unfinishedMotionAtBoundary({
    required List<int> probeTimes,
    required int sceneDuration,
    required bool revealMode,
  }) {
    if (probeTimes.isEmpty) {
      return false;
    }
    final hasFinalBoundaryProbe = probeTimes.last >= sceneDuration - 1;
    if (!hasFinalBoundaryProbe) {
      return true;
    }
    return false && revealMode;
  }

  String _firstFailureReason({
    required bool overflowDetected,
    required bool clipped,
    required bool overlap,
    required bool safeAreaViolation,
  }) {
    if (overflowDetected) {
      return 'text_overflow';
    }
    if (clipped) {
      return 'clipped';
    }
    if (overlap) {
      return 'overlap';
    }
    if (safeAreaViolation) {
      return 'safe_area_violation';
    }
    return 'unknown';
  }

  String _normalizeToken(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _Rect {
  const _Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

class _ElementRect {
  const _ElementRect({
    required this.layerIndex,
    required this.elementIndex,
    required this.elementId,
    required this.rect,
  });

  final int layerIndex;
  final int elementIndex;
  final String elementId;
  final _Rect rect;
}
