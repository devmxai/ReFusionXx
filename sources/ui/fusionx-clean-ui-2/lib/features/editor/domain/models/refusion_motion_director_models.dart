import 'package:flutter/foundation.dart';

enum ReFusionMotionDirectorIssueSeverity {
  error,
  warning,
  info,
}

@immutable
class ReFusionMotionDirectorIssue {
  const ReFusionMotionDirectorIssue({
    required this.severity,
    required this.message,
    this.path,
  });

  final ReFusionMotionDirectorIssueSeverity severity;
  final String message;
  final String? path;
}

@immutable
class ReFusionMotionDirectorPlan {
  ReFusionMotionDirectorPlan({
    required this.schemaVersion,
    required this.name,
    required this.durationMs,
    required this.frameRate,
    this.canvasWidth = 1080,
    this.canvasHeight = 1920,
    List<ReFusionMotionDirectorBeat> beats =
        const <ReFusionMotionDirectorBeat>[],
    List<ReFusionMotionDirectorComponent> components =
        const <ReFusionMotionDirectorComponent>[],
    List<ReFusionMotionDirectorPrimitive> primitives =
        const <ReFusionMotionDirectorPrimitive>[],
  })  : beats = List.unmodifiable(beats),
        components = List.unmodifiable(components),
        primitives = List.unmodifiable(primitives);

  static const String currentSchemaVersion = 'refusion.motion-director/v1';

  final String schemaVersion;
  final String name;
  final int durationMs;
  final double frameRate;
  final int canvasWidth;
  final int canvasHeight;
  final List<ReFusionMotionDirectorBeat> beats;
  final List<ReFusionMotionDirectorComponent> components;
  final List<ReFusionMotionDirectorPrimitive> primitives;
}

@immutable
class ReFusionMotionDirectorBeat {
  ReFusionMotionDirectorBeat({
    required this.id,
    required this.label,
    required this.startMs,
    required this.endMs,
    required this.intent,
    List<String> componentRefs = const <String>[],
  }) : componentRefs = List.unmodifiable(componentRefs);

  final String id;
  final String label;
  final int startMs;
  final int endMs;
  final String intent;
  final List<String> componentRefs;

  int get durationMs => endMs - startMs;
}

@immutable
class ReFusionMotionDirectorComponent {
  const ReFusionMotionDirectorComponent({
    required this.id,
    required this.role,
    required this.label,
    this.layerId,
    this.elementId,
  });

  final String id;
  final String role;
  final String label;
  final String? layerId;
  final String? elementId;
}

@immutable
class ReFusionMotionDirectorPrimitive {
  const ReFusionMotionDirectorPrimitive({
    required this.id,
    required this.beatId,
    required this.targetComponentId,
    required this.kind,
    required this.startMs,
    required this.endMs,
    this.property,
    this.fromValue,
    this.toValue,
    this.easing = 'linear',
    this.note,
  });

  final String id;
  final String beatId;
  final String targetComponentId;
  final String kind;
  final int startMs;
  final int endMs;
  final String? property;
  final Object? fromValue;
  final Object? toValue;
  final String easing;
  final String? note;

  int get durationMs => endMs - startMs;
}
