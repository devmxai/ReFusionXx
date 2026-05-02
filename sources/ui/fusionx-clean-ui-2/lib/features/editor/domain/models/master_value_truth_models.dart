import 'package:flutter/foundation.dart';

import 'professional_motion_models.dart';

enum MasterValueType {
  scalar,
  percent,
  signedPercent,
  dimension,
  point2D,
  scale2D,
  degrees,
  radians,
  color,
  boolean,
  enumValue,
  stringValue,
}

enum MasterValueUnit {
  percentUi,
  signedPercentUi,
  normalized01,
  multiplier,
  canvasPx,
  sourcePx,
  devicePx,
  degrees,
  radians,
  shaderSigmaPx,
  milliseconds,
  timelineTicks,
  colorArgb,
  enumToken,
  stringToken,
}

enum MasterPropertyCategory {
  transform,
  visual,
  effect,
}

enum MasterRenderCapability {
  preview,
  playback,
  liveScrub,
  export,
  diagnostics,
}

@immutable
class MasterValueLayer {
  const MasterValueLayer({
    this.scalar,
    this.point,
    this.colorArgb,
    this.booleanValue,
    this.token,
  });

  final double? scalar;
  final MotionPoint2D? point;
  final int? colorArgb;
  final bool? booleanValue;
  final String? token;
}

@immutable
class MasterPropertyValueMapping {
  const MasterPropertyValueMapping({
    required this.ui,
    required this.engine,
    required this.renderer,
    required this.uiUnit,
    required this.engineUnit,
    required this.rendererUnit,
  });

  final MasterValueLayer ui;
  final MasterValueLayer engine;
  final MasterValueLayer renderer;
  final MasterValueUnit uiUnit;
  final MasterValueUnit engineUnit;
  final MasterValueUnit rendererUnit;
}

typedef MasterPropertyMapper = MasterPropertyValueMapping Function(
  MotionPropertyValue value,
);

@immutable
class MasterPropertyDefinition {
  const MasterPropertyDefinition({
    required this.id,
    required this.category,
    required this.valueType,
    required this.uiUnit,
    required this.engineUnit,
    required this.rendererUnit,
    required this.defaultValue,
    required this.minValue,
    required this.maxValue,
    required this.mapper,
    required this.supportedTargets,
    required this.supportedRenderModes,
    this.unsupportedCases = const <String>[],
  });

  final String id;
  final MasterPropertyCategory category;
  final MasterValueType valueType;
  final MasterValueUnit uiUnit;
  final MasterValueUnit engineUnit;
  final MasterValueUnit rendererUnit;
  final MotionPropertyValue defaultValue;
  final double minValue;
  final double maxValue;
  final MasterPropertyMapper mapper;
  final List<MotionTargetKind> supportedTargets;
  final List<MasterRenderCapability> supportedRenderModes;
  final List<String> unsupportedCases;
}
