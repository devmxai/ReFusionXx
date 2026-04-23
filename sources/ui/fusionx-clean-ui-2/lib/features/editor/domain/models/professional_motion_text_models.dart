import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_models.dart';

enum MotionTextAnimationKind {
  fadeIn,
  fadeOut,
  wordReveal,
  letterReveal,
  typewriter,
  bounceIn,
  riseIn,
  slideIn,
  wordRiseIn,
  letterPopIn,
  blurRiseIn,
  rotateIn,
  elasticPop,
  scaleIn,
  scaleOut,
  blurIn,
  blurOut,
  rotationSettle,
  cinematicEntrance,
  cinematicExit,
}

enum MotionTextRevealUnit {
  wholeText,
  word,
  letter,
}

enum MotionTextRevealDirection {
  forward,
  reverse,
}

enum MotionTextPresetKind {
  hiWord,
  reviewGen,
  cinematic,
  custom,
}

@immutable
class MotionTextPresetParameterDefinition {
  const MotionTextPresetParameterDefinition({
    required this.id,
    required this.label,
    required this.defaultValue,
    this.minValue,
    this.maxValue,
    this.description,
  });

  final String id;
  final String label;
  final MotionPropertyValue defaultValue;
  final double? minValue;
  final double? maxValue;
  final String? description;
}

@immutable
class MotionTextRevealSpec {
  const MotionTextRevealSpec({
    required this.unit,
    this.stagger = TimelineTime.zero,
  });

  final MotionTextRevealUnit unit;
  final TimelineTime stagger;
}

@immutable
class MotionTextAnimationBlock {
  MotionTextAnimationBlock({
    required this.id,
    required this.kind,
    required this.relativeRange,
    this.interpolation = const MotionInterpolationSpec.easeInOut(),
    this.revealSpec,
    Map<String, MotionPropertyValue> parameters =
        const <String, MotionPropertyValue>{},
  }) : parameters = Map.unmodifiable(parameters);

  final String id;
  final MotionTextAnimationKind kind;
  final TimelineTimeRange relativeRange;
  final MotionInterpolationSpec interpolation;
  final MotionTextRevealSpec? revealSpec;
  final Map<String, MotionPropertyValue> parameters;
}

@immutable
class MotionTextPresetDefinition {
  MotionTextPresetDefinition({
    required this.id,
    required this.kind,
    required this.label,
    required this.defaultText,
    required List<MotionTextAnimationBlock> animationBlocks,
    List<MotionPropertyAssignment> staticProperties =
        const <MotionPropertyAssignment>[],
    List<MotionTextPresetParameterDefinition> parameters =
        const <MotionTextPresetParameterDefinition>[],
    this.description,
  })  : animationBlocks = List.unmodifiable(animationBlocks),
        staticProperties = List.unmodifiable(staticProperties),
        parameters = List.unmodifiable(parameters);

  final String id;
  final MotionTextPresetKind kind;
  final String label;
  final String defaultText;
  final String? description;
  final List<MotionTextAnimationBlock> animationBlocks;
  final List<MotionPropertyAssignment> staticProperties;
  final List<MotionTextPresetParameterDefinition> parameters;
}

@immutable
class MotionTextAnimationBindingModel {
  MotionTextAnimationBindingModel({
    required this.id,
    required this.elementTarget,
    required this.activeRange,
    this.presetId,
    List<MotionTextAnimationBlock> animationBlocks =
        const <MotionTextAnimationBlock>[],
    Map<String, MotionPropertyValue> parameterValues =
        const <String, MotionPropertyValue>{},
  })  : animationBlocks = List.unmodifiable(animationBlocks),
        parameterValues = Map.unmodifiable(parameterValues);

  final String id;
  final MotionPropertyTarget elementTarget;
  final TimelineTimeRange activeRange;
  final String? presetId;
  final List<MotionTextAnimationBlock> animationBlocks;
  final Map<String, MotionPropertyValue> parameterValues;
}

class MotionBuiltInTextPresets {
  MotionBuiltInTextPresets._();

  static final MotionTextPresetDefinition hiWord = MotionTextPresetDefinition(
    id: 'text.hi_word',
    kind: MotionTextPresetKind.hiWord,
    label: 'Hi Word',
    defaultText: 'Hi Word',
    description: 'Clean short intro with soft fade and scale settle.',
    animationBlocks: <MotionTextAnimationBlock>[
      MotionTextAnimationBlock(
        id: 'hi_word.fade_in',
        kind: MotionTextAnimationKind.fadeIn,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(420),
        ),
        interpolation: const MotionInterpolationSpec.easeOut(),
      ),
      MotionTextAnimationBlock(
        id: 'hi_word.scale_in',
        kind: MotionTextAnimationKind.scaleIn,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(520),
        ),
        interpolation: const MotionInterpolationSpec.easeOut(),
        parameters: const <String, MotionPropertyValue>{
          'fromScale': MotionPropertyValue.scalar(0.84),
          'toScale': MotionPropertyValue.scalar(1.0),
        },
      ),
    ],
  );

  static final MotionTextPresetDefinition reviewGen =
      MotionTextPresetDefinition(
    id: 'text.review_gen',
    kind: MotionTextPresetKind.reviewGen,
    label: 'ReviewGen',
    defaultText: 'ReviewGen',
    description: 'Readable review-style preset with typewriter rhythm.',
    animationBlocks: <MotionTextAnimationBlock>[
      MotionTextAnimationBlock(
        id: 'review_gen.typewriter',
        kind: MotionTextAnimationKind.typewriter,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(1400),
        ),
        revealSpec: MotionTextRevealSpec(
          unit: MotionTextRevealUnit.letter,
          stagger: TimelineTime.fromMilliseconds(42),
        ),
        interpolation: const MotionInterpolationSpec.linear(),
      ),
      MotionTextAnimationBlock(
        id: 'review_gen.fade_in',
        kind: MotionTextAnimationKind.fadeIn,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(240),
        ),
        interpolation: const MotionInterpolationSpec.easeOut(),
      ),
    ],
  );

  static final MotionTextPresetDefinition cinematic =
      MotionTextPresetDefinition(
    id: 'text.cinematic',
    kind: MotionTextPresetKind.cinematic,
    label: 'Cinematic',
    defaultText: 'CINEMATIC',
    description:
        'Far-to-near cinematic entrance with blur, spacing, and settle.',
    parameters: const <MotionTextPresetParameterDefinition>[
      MotionTextPresetParameterDefinition(
        id: 'blurStrength',
        label: 'Blur Strength',
        defaultValue: MotionPropertyValue.scalar(18),
        minValue: 0,
        maxValue: 64,
      ),
      MotionTextPresetParameterDefinition(
        id: 'spacingAmount',
        label: 'Letter Spacing',
        defaultValue: MotionPropertyValue.scalar(18),
        minValue: 0,
        maxValue: 80,
      ),
    ],
    animationBlocks: <MotionTextAnimationBlock>[
      MotionTextAnimationBlock(
        id: 'cinematic.blur_in',
        kind: MotionTextAnimationKind.blurIn,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(700),
        ),
        interpolation: const MotionInterpolationSpec.easeOut(),
        parameters: const <String, MotionPropertyValue>{
          'fromBlur': MotionPropertyValue.scalar(18),
          'toBlur': MotionPropertyValue.scalar(0),
        },
      ),
      MotionTextAnimationBlock(
        id: 'cinematic.scale_in',
        kind: MotionTextAnimationKind.cinematicEntrance,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(900),
        ),
        interpolation: const MotionInterpolationSpec.easeOut(),
        parameters: const <String, MotionPropertyValue>{
          'fromScale': MotionPropertyValue.scalar(1.16),
          'toScale': MotionPropertyValue.scalar(1.0),
          'fromOpacity': MotionPropertyValue.scalar(0),
          'toOpacity': MotionPropertyValue.scalar(1),
        },
      ),
      MotionTextAnimationBlock(
        id: 'cinematic.letter_settle',
        kind: MotionTextAnimationKind.rotationSettle,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.fromMilliseconds(120),
          endExclusive: TimelineTime.fromMilliseconds(1000),
        ),
        interpolation: const MotionInterpolationSpec.easeInOut(),
        parameters: const <String, MotionPropertyValue>{
          'fromLetterSpacing': MotionPropertyValue.scalar(18),
          'toLetterSpacing': MotionPropertyValue.scalar(0),
          'fromRotation': MotionPropertyValue.scalar(-6),
          'toRotation': MotionPropertyValue.scalar(0),
        },
      ),
    ],
  );

  static final MotionTextPresetDefinition professional =
      MotionTextPresetDefinition(
    id: 'text.professional',
    kind: MotionTextPresetKind.cinematic,
    label: 'Professional',
    defaultText: 'professional',
    description:
        'Blur-led professional entrance with wide spacing settle, a brief clean hold, and a soft blur fade-out.',
    parameters: const <MotionTextPresetParameterDefinition>[
      MotionTextPresetParameterDefinition(
        id: 'blurStrength',
        label: 'Blur Strength',
        defaultValue: MotionPropertyValue.scalar(26),
        minValue: 0,
        maxValue: 72,
      ),
      MotionTextPresetParameterDefinition(
        id: 'spacingAmount',
        label: 'Letter Spacing',
        defaultValue: MotionPropertyValue.scalar(24),
        minValue: 0,
        maxValue: 96,
      ),
    ],
    animationBlocks: <MotionTextAnimationBlock>[
      MotionTextAnimationBlock(
        id: 'professional.blur_in',
        kind: MotionTextAnimationKind.blurIn,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(760),
        ),
        interpolation: const MotionInterpolationSpec.easeOut(),
        parameters: const <String, MotionPropertyValue>{
          'fromBlur': MotionPropertyValue.scalar(26),
          'toBlur': MotionPropertyValue.scalar(0),
        },
      ),
      MotionTextAnimationBlock(
        id: 'professional.entrance',
        kind: MotionTextAnimationKind.cinematicEntrance,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(860),
        ),
        interpolation: const MotionInterpolationSpec.easeOut(),
        parameters: const <String, MotionPropertyValue>{
          'fromScale': MotionPropertyValue.scalar(1.08),
          'toScale': MotionPropertyValue.scalar(1.0),
          'fromOpacity': MotionPropertyValue.scalar(0),
          'toOpacity': MotionPropertyValue.scalar(1),
        },
      ),
      MotionTextAnimationBlock(
        id: 'professional.spacing_settle',
        kind: MotionTextAnimationKind.rotationSettle,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(980),
        ),
        interpolation: const MotionInterpolationSpec.easeInOut(),
        parameters: const <String, MotionPropertyValue>{
          'fromLetterSpacing': MotionPropertyValue.scalar(24),
          'toLetterSpacing': MotionPropertyValue.scalar(0),
          'fromRotation': MotionPropertyValue.scalar(0),
          'toRotation': MotionPropertyValue.scalar(0),
        },
      ),
      MotionTextAnimationBlock(
        id: 'professional.blur_out',
        kind: MotionTextAnimationKind.blurOut,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.fromMilliseconds(2160),
          endExclusive: TimelineTime.fromMilliseconds(3000),
        ),
        interpolation: const MotionInterpolationSpec.easeIn(),
        parameters: const <String, MotionPropertyValue>{
          'fromBlur': MotionPropertyValue.scalar(0),
          'toBlur': MotionPropertyValue.scalar(22),
        },
      ),
      MotionTextAnimationBlock(
        id: 'professional.exit',
        kind: MotionTextAnimationKind.cinematicExit,
        relativeRange: TimelineTimeRange(
          start: TimelineTime.fromMilliseconds(2220),
          endExclusive: TimelineTime.fromMilliseconds(3000),
        ),
        interpolation: const MotionInterpolationSpec.easeIn(),
        parameters: const <String, MotionPropertyValue>{
          'fromOpacity': MotionPropertyValue.scalar(1),
          'toOpacity': MotionPropertyValue.scalar(0),
        },
      ),
    ],
  );

  static final List<MotionTextPresetDefinition> all =
      <MotionTextPresetDefinition>[
    professional,
    cinematic,
    hiWord,
    reviewGen,
  ];
}
