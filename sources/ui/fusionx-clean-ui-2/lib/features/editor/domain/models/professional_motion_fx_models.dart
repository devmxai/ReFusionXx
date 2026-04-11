import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_models.dart';

enum MotionEffectKind {
  blur,
  brightness,
  contrast,
  shadow,
  glow,
  shake,
  custom,
}

enum MotionTransitionKind {
  fade,
  blurDissolve,
  cameraPush,
  cameraPull,
  shake,
  zoom,
  custom,
}

enum MotionCameraBindingScope {
  project,
  scene,
  layer,
}

@immutable
class MotionEffectBindingModel {
  MotionEffectBindingModel({
    required this.id,
    required this.kind,
    required this.target,
    required this.activeRange,
    this.name,
    this.isEnabled = true,
    Map<String, MotionPropertyValue> parameters =
        const <String, MotionPropertyValue>{},
  }) : parameters = Map.unmodifiable(parameters);

  final String id;
  final MotionEffectKind kind;
  final MotionPropertyTarget target;
  final TimelineTimeRange activeRange;
  final String? name;
  final bool isEnabled;
  final Map<String, MotionPropertyValue> parameters;
}

@immutable
class MotionTransitionBindingModel {
  MotionTransitionBindingModel({
    required this.id,
    required this.kind,
    required this.leftTargetId,
    required this.rightTargetId,
    required this.activeRange,
    this.name,
    this.isEnabled = true,
    Map<String, MotionPropertyValue> parameters =
        const <String, MotionPropertyValue>{},
  }) : parameters = Map.unmodifiable(parameters);

  final String id;
  final MotionTransitionKind kind;
  final String leftTargetId;
  final String rightTargetId;
  final TimelineTimeRange activeRange;
  final String? name;
  final bool isEnabled;
  final Map<String, MotionPropertyValue> parameters;
}

@immutable
class MotionCameraBindingModel {
  MotionCameraBindingModel({
    required this.id,
    required this.scope,
    required this.target,
    required this.activeRange,
    this.name,
    this.isEnabled = true,
    List<MotionPropertyAssignment> staticProperties =
        const <MotionPropertyAssignment>[],
    List<MotionPropertyChannelModel> propertyChannels =
        const <MotionPropertyChannelModel>[],
  }) : staticProperties = List.unmodifiable(staticProperties),
       propertyChannels = List.unmodifiable(propertyChannels);

  final String id;
  final MotionCameraBindingScope scope;
  final MotionPropertyTarget target;
  final TimelineTimeRange activeRange;
  final String? name;
  final bool isEnabled;
  final List<MotionPropertyAssignment> staticProperties;
  final List<MotionPropertyChannelModel> propertyChannels;
}
