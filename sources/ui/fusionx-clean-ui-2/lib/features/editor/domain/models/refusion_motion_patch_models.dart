import 'professional_motion_models.dart';

enum ReFusionMotionPatchIssueSeverity {
  error,
  warning,
  info,
}

class ReFusionMotionPatchIssue {
  const ReFusionMotionPatchIssue({
    required this.severity,
    required this.message,
    this.path,
  });

  final ReFusionMotionPatchIssueSeverity severity;
  final String message;
  final String? path;
}

class ReFusionMotionPatch {
  ReFusionMotionPatch({
    required this.schemaVersion,
    required this.name,
    required this.scopeDurationMs,
    List<ReFusionMotionPatchOperation> operations =
        const <ReFusionMotionPatchOperation>[],
  }) : operations = List.unmodifiable(operations);

  final String schemaVersion;
  final String name;
  final int scopeDurationMs;
  final List<ReFusionMotionPatchOperation> operations;
}

class ReFusionMotionPatchOperation {
  ReFusionMotionPatchOperation({
    required this.id,
    required this.action,
    required this.target,
    required this.property,
    List<ReFusionMotionPatchKeyframe> keyframes =
        const <ReFusionMotionPatchKeyframe>[],
  }) : keyframes = List.unmodifiable(keyframes);

  final String id;
  final String action;
  final String target;
  final String property;
  final List<ReFusionMotionPatchKeyframe> keyframes;
}

class ReFusionMotionPatchKeyframe {
  const ReFusionMotionPatchKeyframe({
    required this.timeMs,
    required this.value,
    this.easing = 'linear',
  });

  final int timeMs;
  final Object value;
  final String easing;
}

class ReFusionMotionPatchResolvedChannel {
  const ReFusionMotionPatchResolvedChannel({
    required this.operation,
    required this.definition,
    required this.target,
    this.component,
  });

  final ReFusionMotionPatchOperation operation;
  final MotionPropertyDefinition definition;
  final MotionPropertyTarget target;
  final String? component;
}
