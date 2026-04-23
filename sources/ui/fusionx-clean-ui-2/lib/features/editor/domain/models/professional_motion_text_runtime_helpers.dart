import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_compilation_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_models.dart';

@immutable
class MotionTextPresetCompileResult {
  MotionTextPresetCompileResult({
    required List<MotionPropertyChannelModel> generatedChannels,
    required Map<String, List<MotionPropertyAssignment>>
        generatedStaticProperties,
    required List<MotionResolvedTextAnimationModel> resolvedTextAnimations,
    required List<MotionCompileIssue> issues,
  })  : generatedChannels = List.unmodifiable(generatedChannels),
        generatedStaticProperties = Map.unmodifiable(
          generatedStaticProperties.map(
            (key, value) => MapEntry(
                key, List<MotionPropertyAssignment>.unmodifiable(value)),
          ),
        ),
        resolvedTextAnimations = List.unmodifiable(resolvedTextAnimations),
        issues = List.unmodifiable(issues);

  final List<MotionPropertyChannelModel> generatedChannels;
  final Map<String, List<MotionPropertyAssignment>> generatedStaticProperties;
  final List<MotionResolvedTextAnimationModel> resolvedTextAnimations;
  final List<MotionCompileIssue> issues;
}

class BasicMotionTextPresetCompiler {
  BasicMotionTextPresetCompiler({
    List<MotionTextPresetDefinition>? presetCatalog,
  }) : _presetCatalog = {
          for (final preset in presetCatalog ?? MotionBuiltInTextPresets.all)
            preset.id: preset,
        };

  final Map<String, MotionTextPresetDefinition> _presetCatalog;

  MotionTextPresetCompileResult compileBindings({
    required MotionCompileRequest request,
    required Map<String, MotionElementModel> elementsById,
  }) {
    final generatedChannels = <MotionPropertyChannelModel>[];
    final generatedStaticProperties =
        <String, List<MotionPropertyAssignment>>{};
    final resolvedTextAnimations = <MotionResolvedTextAnimationModel>[];
    final issues = <MotionCompileIssue>[];

    for (final binding in request.textAnimationBindings) {
      if (binding.elementTarget.kind != MotionTargetKind.element) {
        issues.add(
          MotionCompileIssue(
            code: MotionCompileIssueCode.unsupportedTarget,
            severity: MotionCompileIssueSeverity.warning,
            message:
                'Text binding `${binding.id}` must target an element address.',
            elementId: binding.elementTarget.targetId,
          ),
        );
        continue;
      }

      final targetElement = elementsById[binding.elementTarget.targetId];
      if (targetElement == null) {
        issues.add(
          MotionCompileIssue(
            code: MotionCompileIssueCode.missingElement,
            severity: MotionCompileIssueSeverity.warning,
            message:
                'Text binding `${binding.id}` points to missing element `${binding.elementTarget.targetId}`.',
            elementId: binding.elementTarget.targetId,
          ),
        );
        continue;
      }

      if (targetElement.kind != MotionElementKind.text) {
        issues.add(
          MotionCompileIssue(
            code: MotionCompileIssueCode.unsupportedTarget,
            severity: MotionCompileIssueSeverity.warning,
            message:
                'Text binding `${binding.id}` points to non-text element `${binding.elementTarget.targetId}`.',
            elementId: binding.elementTarget.targetId,
          ),
        );
        continue;
      }

      final preset =
          binding.presetId == null ? null : _presetCatalog[binding.presetId!];
      if (binding.presetId != null && preset == null) {
        issues.add(
          MotionCompileIssue(
            code: MotionCompileIssueCode.unresolvedPresetReference,
            severity: MotionCompileIssueSeverity.warning,
            message:
                'Text preset `${binding.presetId}` was not found for binding `${binding.id}`.',
            elementId: binding.elementTarget.targetId,
          ),
        );
      }

      final parameterValues = _mergedParameters(preset, binding);
      final blocks = <MotionTextAnimationBlock>[
        if (preset != null) ...preset.animationBlocks,
        ...binding.animationBlocks,
      ];

      final staticAssignments = <MotionPropertyAssignment>[
        if (preset != null)
          ...preset.staticProperties.map(
            (assignment) => MotionPropertyAssignment(
              target: binding.elementTarget,
              definition: assignment.definition,
              value: assignment.value,
            ),
          ),
      ];
      if (staticAssignments.isNotEmpty) {
        generatedStaticProperties
            .putIfAbsent(
              binding.elementTarget.targetId,
              () => <MotionPropertyAssignment>[],
            )
            .addAll(staticAssignments);
      }

      final channelAccumulator = <String, _MutableTextChannel>{};
      final generatedChannelIds = <String>[];

      for (final block in blocks) {
        final absoluteRange = TimelineTimeRange(
          start: binding.activeRange.start + block.relativeRange.start,
          endExclusive:
              binding.activeRange.start + block.relativeRange.endExclusive,
        );
        _applyBlock(
          binding: binding,
          block: block,
          absoluteRange: absoluteRange,
          parameterValues: parameterValues,
          accumulator: channelAccumulator,
        );
      }

      for (final entry in channelAccumulator.entries) {
        final mutable = entry.value;
        generatedChannelIds.add(mutable.channelId);
        generatedChannels.add(
          MotionPropertyChannelModel(
            id: mutable.channelId,
            target: binding.elementTarget,
            definition: mutable.definition,
            activeRange: binding.activeRange,
            baseValue: mutable.baseValue,
            keyframes: mutable.sortedKeyframes,
          ),
        );
      }

      resolvedTextAnimations.add(
        MotionResolvedTextAnimationModel(
          id: binding.id,
          targetElementId: binding.elementTarget.targetId,
          targetAddress: binding.elementTarget.canonicalAddress,
          projectRange: binding.activeRange,
          presetId: preset?.id ?? binding.presetId,
          animationKinds:
              blocks.map((block) => block.kind).toList(growable: false),
          generatedChannelIds: generatedChannelIds,
          animationBlocks: blocks
              .map(
                (block) => MotionResolvedTextAnimationBlockModel(
                  id: block.id,
                  kind: block.kind,
                  projectRange: TimelineTimeRange(
                    start:
                        binding.activeRange.start + block.relativeRange.start,
                    endExclusive: binding.activeRange.start +
                        block.relativeRange.endExclusive,
                  ),
                  interpolation: block.interpolation,
                  revealSpec: block.revealSpec,
                  parameters: block.parameters,
                ),
              )
              .toList(growable: false),
          parameterValues: parameterValues,
        ),
      );
    }

    return MotionTextPresetCompileResult(
      generatedChannels: generatedChannels,
      generatedStaticProperties: generatedStaticProperties,
      resolvedTextAnimations: resolvedTextAnimations,
      issues: issues,
    );
  }

  Map<String, MotionPropertyValue> _mergedParameters(
    MotionTextPresetDefinition? preset,
    MotionTextAnimationBindingModel binding,
  ) {
    final values = <String, MotionPropertyValue>{};
    if (preset != null) {
      for (final parameter in preset.parameters) {
        values[parameter.id] = parameter.defaultValue;
      }
    }
    values.addAll(binding.parameterValues);
    return values;
  }

  void _applyBlock({
    required MotionTextAnimationBindingModel binding,
    required MotionTextAnimationBlock block,
    required TimelineTimeRange absoluteRange,
    required Map<String, MotionPropertyValue> parameterValues,
    required Map<String, _MutableTextChannel> accumulator,
  }) {
    switch (block.kind) {
      case MotionTextAnimationKind.fadeIn:
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.opacity,
          from: 0,
          to: 1,
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.fadeOut:
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.opacity,
          from: 1,
          to: 0,
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.bounceIn:
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.opacity,
          from: _readScalar(block, parameterValues, 'fromOpacity', 0),
          to: _readScalar(block, parameterValues, 'toOpacity', 1),
          range: absoluteRange,
          interpolation: const MotionInterpolationSpec.easeOut(),
        );
        _addUniformScaleAnimation(
          accumulator: accumulator,
          binding: binding,
          from: _readScalar(block, parameterValues, 'fromScale', 0.68),
          to: _readScalar(block, parameterValues, 'toScale', 1.0),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.positionY,
          from: _readScalar(block, parameterValues, 'fromOffsetY', 56),
          to: _readScalar(block, parameterValues, 'toOffsetY', 0),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.scaleIn:
        _addUniformScaleAnimation(
          accumulator: accumulator,
          binding: binding,
          from: _readScalar(block, parameterValues, 'fromScale', 0.82),
          to: _readScalar(block, parameterValues, 'toScale', 1.0),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.elasticPop:
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.opacity,
          from: _readScalar(block, parameterValues, 'fromOpacity', 0),
          to: _readScalar(block, parameterValues, 'toOpacity', 1),
          range: absoluteRange,
          interpolation: const MotionInterpolationSpec.easeOut(),
        );
        _addUniformScaleAnimation(
          accumulator: accumulator,
          binding: binding,
          from: _readScalar(block, parameterValues, 'fromScale', 0.72),
          to: _readScalar(block, parameterValues, 'toScale', 1.0),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.scaleOut:
        _addUniformScaleAnimation(
          accumulator: accumulator,
          binding: binding,
          from: _readScalar(block, parameterValues, 'fromScale', 1.0),
          to: _readScalar(block, parameterValues, 'toScale', 1.12),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.blurIn:
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.blurAmount,
          from: _parameterScalar(
            parameterValues,
            'blurStrength',
            _readScalar(block, parameterValues, 'fromBlur', 16),
          ),
          to: _readScalar(block, parameterValues, 'toBlur', 0),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.blurOut:
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.blurAmount,
          from: _readScalar(block, parameterValues, 'fromBlur', 0),
          to: _parameterScalar(
            parameterValues,
            'blurStrength',
            _readScalar(block, parameterValues, 'toBlur', 16),
          ),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.wordReveal:
      case MotionTextAnimationKind.letterReveal:
      case MotionTextAnimationKind.typewriter:
        if (_readBoolean(block, 'manualRevealProgress', false)) {
          break;
        }
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.revealProgress,
          from: 0,
          to: 1,
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.rotationSettle:
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.rotationDegrees,
          from: _readScalar(block, parameterValues, 'fromRotation', -5),
          to: _readScalar(block, parameterValues, 'toRotation', 0),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.letterSpacing,
          from: _parameterScalar(
            parameterValues,
            'spacingAmount',
            _readScalar(
              block,
              parameterValues,
              'fromLetterSpacing',
              10,
            ),
          ),
          to: _readScalar(block, parameterValues, 'toLetterSpacing', 0),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.cinematicEntrance:
        _addUniformScaleAnimation(
          accumulator: accumulator,
          binding: binding,
          from: _readScalar(block, parameterValues, 'fromScale', 1.14),
          to: _readScalar(block, parameterValues, 'toScale', 1.0),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.opacity,
          from: _readScalar(block, parameterValues, 'fromOpacity', 0),
          to: _readScalar(block, parameterValues, 'toOpacity', 1),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
      case MotionTextAnimationKind.cinematicExit:
        _addScalarAnimation(
          accumulator: accumulator,
          binding: binding,
          definition: MotionPropertyCatalog.opacity,
          from: _readScalar(block, parameterValues, 'fromOpacity', 1),
          to: _readScalar(block, parameterValues, 'toOpacity', 0),
          range: absoluteRange,
          interpolation: block.interpolation,
        );
        break;
    }
  }

  void _addUniformScaleAnimation({
    required Map<String, _MutableTextChannel> accumulator,
    required MotionTextAnimationBindingModel binding,
    required double from,
    required double to,
    required TimelineTimeRange range,
    required MotionInterpolationSpec interpolation,
  }) {
    _addScalarAnimation(
      accumulator: accumulator,
      binding: binding,
      definition: MotionPropertyCatalog.scaleX,
      from: from,
      to: to,
      range: range,
      interpolation: interpolation,
    );
    _addScalarAnimation(
      accumulator: accumulator,
      binding: binding,
      definition: MotionPropertyCatalog.scaleY,
      from: from,
      to: to,
      range: range,
      interpolation: interpolation,
    );
  }

  void _addScalarAnimation({
    required Map<String, _MutableTextChannel> accumulator,
    required MotionTextAnimationBindingModel binding,
    required MotionPropertyDefinition definition,
    required double from,
    required double to,
    required TimelineTimeRange range,
    required MotionInterpolationSpec interpolation,
  }) {
    final channelKey = definition.id;
    final channel = accumulator.putIfAbsent(
      channelKey,
      () => _MutableTextChannel(
        channelId: '${binding.id}.${definition.id}',
        definition: definition,
        baseValue: definition.defaultValue,
      ),
    );
    channel.keyframes.add(
      MotionKeyframeModel(
        id: '${channel.channelId}.start.${channel.keyframes.length}',
        channelId: channel.channelId,
        time: range.start,
        value: MotionPropertyValue.scalar(from),
        interpolationToNext: interpolation,
      ),
    );
    channel.keyframes.add(
      MotionKeyframeModel(
        id: '${channel.channelId}.end.${channel.keyframes.length}',
        channelId: channel.channelId,
        time: range.endExclusive,
        value: MotionPropertyValue.scalar(to),
        interpolationToNext: const MotionInterpolationSpec.hold(),
      ),
    );
  }

  double _readScalar(
    MotionTextAnimationBlock block,
    Map<String, MotionPropertyValue> parameterValues,
    String key,
    double fallback,
  ) {
    final inline = block.parameters[key];
    if (inline != null && inline.kind == MotionPropertyValueKind.scalar) {
      return inline.rawValue as double;
    }
    return _parameterScalar(parameterValues, key, fallback);
  }

  double _parameterScalar(
    Map<String, MotionPropertyValue> parameterValues,
    String key,
    double fallback,
  ) {
    final value = parameterValues[key];
    if (value == null || value.kind != MotionPropertyValueKind.scalar) {
      return fallback;
    }
    return value.rawValue as double;
  }

  bool _readBoolean(
    MotionTextAnimationBlock block,
    String key,
    bool fallback,
  ) {
    final value = block.parameters[key];
    if (value == null || value.kind != MotionPropertyValueKind.boolean) {
      return fallback;
    }
    return value.rawValue as bool;
  }
}

class _MutableTextChannel {
  _MutableTextChannel({
    required this.channelId,
    required this.definition,
    required this.baseValue,
  });

  final String channelId;
  final MotionPropertyDefinition definition;
  final MotionPropertyValue baseValue;
  final List<MotionKeyframeModel> keyframes = <MotionKeyframeModel>[];

  List<MotionKeyframeModel> get sortedKeyframes {
    final copy = List<MotionKeyframeModel>.from(keyframes);
    copy.sort((left, right) => left.time.compareTo(right.time));
    return copy;
  }
}
