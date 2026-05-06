import 'package:flutter/foundation.dart';

import 'master_time_models.dart';
import 'master_value_truth_models.dart';
import 'professional_motion_models.dart';

enum MasterVisualSourceKind {
  video,
  image,
  unknown,
}

enum MasterVisualTransitionRole {
  none,
  outgoing,
  incoming,
  overlay,
  matte,
}

enum MasterVisualLayerFamilyHint {
  none,
  videoLayer,
  imageLayer,
  textLayer,
  shapeLayer,
  groupPrecomp,
  sceneClipInstance,
  adjustmentControl,
}

@immutable
class MasterVisualSourceBinding {
  const MasterVisualSourceBinding({
    required this.targetId,
    required this.kind,
    required this.sourceUri,
    this.scrubStoreKey,
    this.sourceWidth,
    this.sourceHeight,
  });

  final String targetId;
  final MasterVisualSourceKind kind;
  final String sourceUri;
  final String? scrubStoreKey;
  final int? sourceWidth;
  final int? sourceHeight;
}

@immutable
class MasterVisualTransform {
  const MasterVisualTransform({
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotationRadians = 0.0,
  });

  final double positionX;
  final double positionY;
  final double scaleX;
  final double scaleY;
  final double rotationRadians;

  MasterVisualTransform copyWith({
    double? positionX,
    double? positionY,
    double? scaleX,
    double? scaleY,
    double? rotationRadians,
  }) {
    return MasterVisualTransform(
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotationRadians: rotationRadians ?? this.rotationRadians,
    );
  }
}

@immutable
class MasterVisualEffectBinding {
  const MasterVisualEffectBinding({
    required this.id,
    required this.rendererValue,
    required this.rendererUnit,
  });

  final String id;
  final double rendererValue;
  final MasterValueUnit rendererUnit;
}

@immutable
class MasterMotionBlurPolicy {
  const MasterMotionBlurPolicy({
    this.enabled = false,
    this.amount = 0.0,
    this.shutterAngleDegrees = 180.0,
    this.shutterPhaseDegrees = -90.0,
    this.samples = 8,
    this.adaptiveSampleLimit = 16,
    this.maxTrailPx = 240.0,
    this.affectPosition = true,
    this.affectScale = true,
    this.affectRotation = true,
  });

  final bool enabled;
  final double amount;
  final double shutterAngleDegrees;
  final double shutterPhaseDegrees;
  final int samples;
  final int adaptiveSampleLimit;
  final double maxTrailPx;
  final bool affectPosition;
  final bool affectScale;
  final bool affectRotation;

  bool get isEnabled =>
      enabled &&
      amount > 0 &&
      shutterAngleDegrees > 0 &&
      samples > 0 &&
      (affectPosition || affectScale || affectRotation);

  MasterMotionBlurPolicy copyWith({
    bool? enabled,
    double? amount,
    double? shutterAngleDegrees,
    double? shutterPhaseDegrees,
    int? samples,
    int? adaptiveSampleLimit,
    double? maxTrailPx,
    bool? affectPosition,
    bool? affectScale,
    bool? affectRotation,
  }) {
    return MasterMotionBlurPolicy(
      enabled: enabled ?? this.enabled,
      amount: amount ?? this.amount,
      shutterAngleDegrees: shutterAngleDegrees ?? this.shutterAngleDegrees,
      shutterPhaseDegrees: shutterPhaseDegrees ?? this.shutterPhaseDegrees,
      samples: samples ?? this.samples,
      adaptiveSampleLimit: adaptiveSampleLimit ?? this.adaptiveSampleLimit,
      maxTrailPx: maxTrailPx ?? this.maxTrailPx,
      affectPosition: affectPosition ?? this.affectPosition,
      affectScale: affectScale ?? this.affectScale,
      affectRotation: affectRotation ?? this.affectRotation,
    );
  }
}

enum MasterEdgeFillMode {
  off,
  reflect,
  replicate,
  wrap,
  blurredReflect,
  blurredBackground,
  autoOverscan,
  color,
}

@immutable
class MasterEdgeFillPolicy {
  const MasterEdgeFillPolicy({
    this.enabled = false,
    this.mode = MasterEdgeFillMode.reflect,
    this.amount = 0.0,
    this.overscanScale = 1.0,
    this.softnessPx = 0.0,
    this.blurSigmaPx = 0.0,
    this.maxExpansionPx = 320.0,
    this.affectRotation = true,
    this.affectScale = true,
    this.affectPosition = true,
    this.affectMotionBlur = true,
  });

  final bool enabled;
  final MasterEdgeFillMode mode;
  final double amount;
  final double overscanScale;
  final double softnessPx;
  final double blurSigmaPx;
  final double maxExpansionPx;
  final bool affectRotation;
  final bool affectScale;
  final bool affectPosition;
  final bool affectMotionBlur;

  MasterEdgeFillPolicy copyWith({
    bool? enabled,
    MasterEdgeFillMode? mode,
    double? amount,
    double? overscanScale,
    double? softnessPx,
    double? blurSigmaPx,
    double? maxExpansionPx,
    bool? affectRotation,
    bool? affectScale,
    bool? affectPosition,
    bool? affectMotionBlur,
  }) {
    return MasterEdgeFillPolicy(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      amount: amount ?? this.amount,
      overscanScale: overscanScale ?? this.overscanScale,
      softnessPx: softnessPx ?? this.softnessPx,
      blurSigmaPx: blurSigmaPx ?? this.blurSigmaPx,
      maxExpansionPx: maxExpansionPx ?? this.maxExpansionPx,
      affectRotation: affectRotation ?? this.affectRotation,
      affectScale: affectScale ?? this.affectScale,
      affectPosition: affectPosition ?? this.affectPosition,
      affectMotionBlur: affectMotionBlur ?? this.affectMotionBlur,
    );
  }
}

@immutable
class MasterVisualCrop {
  const MasterVisualCrop({
    this.rect,
  });

  final MotionRect? rect;

  bool get hasCrop => rect != null;

  MasterVisualCrop copyWith({
    MotionRect? rect,
    bool clearRect = false,
  }) {
    return MasterVisualCrop(
      rect: clearRect ? null : rect ?? this.rect,
    );
  }
}

@immutable
class MasterVisualMask {
  const MasterVisualMask({
    this.revealProgress,
  });

  final double? revealProgress;

  bool get hasMask => revealProgress != null;

  MasterVisualMask copyWith({
    double? revealProgress,
    bool clearRevealProgress = false,
  }) {
    return MasterVisualMask(
      revealProgress:
          clearRevealProgress ? null : revealProgress ?? this.revealProgress,
    );
  }
}

@immutable
class MasterVisualColorStyle {
  const MasterVisualColorStyle({
    this.visualColorArgb,
    this.shadowColorArgb,
  });

  final int? visualColorArgb;
  final int? shadowColorArgb;

  bool get hasColorStyle => visualColorArgb != null || shadowColorArgb != null;

  MasterVisualColorStyle copyWith({
    int? visualColorArgb,
    int? shadowColorArgb,
    bool clearVisualColor = false,
    bool clearShadowColor = false,
  }) {
    return MasterVisualColorStyle(
      visualColorArgb:
          clearVisualColor ? null : visualColorArgb ?? this.visualColorArgb,
      shadowColorArgb:
          clearShadowColor ? null : shadowColorArgb ?? this.shadowColorArgb,
    );
  }
}

@immutable
class MasterVisualTextStyle {
  const MasterVisualTextStyle({
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.fontStyle,
    this.lineHeight,
    this.alignment,
    this.letterSpacing,
    this.revealProgress,
  });

  final double? fontSize;
  final double? fontWeight;
  final String? fontFamily;
  final String? fontStyle;
  final double? lineHeight;
  final String? alignment;
  final double? letterSpacing;
  final double? revealProgress;

  bool get hasTextStyle =>
      fontSize != null ||
      fontWeight != null ||
      fontFamily != null ||
      fontStyle != null ||
      lineHeight != null ||
      alignment != null ||
      letterSpacing != null ||
      revealProgress != null;

  MasterVisualTextStyle copyWith({
    double? fontSize,
    double? fontWeight,
    String? fontFamily,
    String? fontStyle,
    double? lineHeight,
    String? alignment,
    double? letterSpacing,
    double? revealProgress,
  }) {
    return MasterVisualTextStyle(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      fontStyle: fontStyle ?? this.fontStyle,
      lineHeight: lineHeight ?? this.lineHeight,
      alignment: alignment ?? this.alignment,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      revealProgress: revealProgress ?? this.revealProgress,
    );
  }
}

@immutable
class MasterVisualShapeStyle {
  const MasterVisualShapeStyle({
    this.width,
    this.height,
    this.cornerRadius,
    this.trimStart,
    this.trimEnd,
    this.trimOffset,
  });

  final double? width;
  final double? height;
  final double? cornerRadius;
  final double? trimStart;
  final double? trimEnd;
  final double? trimOffset;

  bool get hasShapeStyle =>
      width != null ||
      height != null ||
      cornerRadius != null ||
      trimStart != null ||
      trimEnd != null ||
      trimOffset != null;

  MasterVisualShapeStyle copyWith({
    double? width,
    double? height,
    double? cornerRadius,
    double? trimStart,
    double? trimEnd,
    double? trimOffset,
  }) {
    return MasterVisualShapeStyle(
      width: width ?? this.width,
      height: height ?? this.height,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      trimOffset: trimOffset ?? this.trimOffset,
    );
  }
}

@immutable
class MasterVisualSurface {
  MasterVisualSurface({
    required this.targetId,
    required this.sourceKind,
    this.coreLayerFamilyHint = MasterVisualLayerFamilyHint.none,
    this.source,
    this.drawOrder = 0,
    this.transitionRole = MasterVisualTransitionRole.none,
    this.transform = const MasterVisualTransform(),
    this.crop = const MasterVisualCrop(),
    this.mask = const MasterVisualMask(),
    this.colors = const MasterVisualColorStyle(),
    this.textStyle = const MasterVisualTextStyle(),
    this.shapeStyle = const MasterVisualShapeStyle(),
    this.opacity = 1.0,
    this.motionBlur = const MasterMotionBlurPolicy(),
    this.edgeFill = const MasterEdgeFillPolicy(),
    List<MasterVisualEffectBinding> effects =
        const <MasterVisualEffectBinding>[],
    List<String> blockers = const <String>[],
  })  : effects = List.unmodifiable(effects),
        blockers = List.unmodifiable(blockers);

  final String targetId;
  final MasterVisualSourceKind sourceKind;
  final MasterVisualLayerFamilyHint coreLayerFamilyHint;
  final MasterVisualSourceBinding? source;
  final int drawOrder;
  final MasterVisualTransitionRole transitionRole;
  final MasterVisualTransform transform;
  final MasterVisualCrop crop;
  final MasterVisualMask mask;
  final MasterVisualColorStyle colors;
  final MasterVisualTextStyle textStyle;
  final MasterVisualShapeStyle shapeStyle;
  final double opacity;
  final MasterMotionBlurPolicy motionBlur;
  final MasterEdgeFillPolicy edgeFill;
  final List<MasterVisualEffectBinding> effects;
  final List<String> blockers;
}

@immutable
class MasterVisualTransitionState {
  MasterVisualTransitionState({
    List<String> activeTransitionIds = const <String>[],
    required this.hasRenderableTransitionPixels,
    required this.reason,
  }) : activeTransitionIds = List.unmodifiable(activeTransitionIds);

  final List<String> activeTransitionIds;
  final bool hasRenderableTransitionPixels;
  final String reason;

  bool get hasTransitionWindow => activeTransitionIds.isNotEmpty;
}

@immutable
class MasterVisualProgram {
  MasterVisualProgram({
    required this.time,
    List<MasterVisualSurface> surfaces = const <MasterVisualSurface>[],
    List<String> blockers = const <String>[],
    List<String> diagnostics = const <String>[],
    required this.transitionState,
  })  : surfaces = List.unmodifiable(surfaces),
        blockers = List.unmodifiable(blockers),
        diagnostics = List.unmodifiable(diagnostics);

  final MasterTimeSnapshot time;
  final List<MasterVisualSurface> surfaces;
  final List<String> blockers;
  final List<String> diagnostics;
  final MasterVisualTransitionState transitionState;

  bool get canRenderTruthfully {
    if (blockers.isNotEmpty) {
      return false;
    }
    for (final surface in surfaces) {
      if (surface.blockers.isNotEmpty) {
        return false;
      }
    }
    return true;
  }
}
