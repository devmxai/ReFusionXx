import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_models.dart';

const String kReFusionSceneProgramSchemaVersion = 'refusion.scene-program/v1';

enum ReFusionSceneProgramIssueSeverity {
  error,
  warning,
  info,
}

enum ReFusionSceneProgramIssueCode {
  emptySource,
  invalidFileType,
  invalidJson,
  rootNotObject,
  executableField,
  missingSchemaVersion,
  unsupportedSchemaVersion,
  invalidKind,
  missingRequiredField,
  invalidDuration,
  invalidList,
  invalidObject,
  unsupportedProperty,
  unsupportedValueKind,
  invalidValue,
  emptyKeyframes,
}

@immutable
class ReFusionSceneProgramIssue {
  const ReFusionSceneProgramIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.path,
  });

  final ReFusionSceneProgramIssueSeverity severity;
  final ReFusionSceneProgramIssueCode code;
  final String message;
  final String? path;
}

@immutable
class ReFusionSceneProgramKeyframeSpec {
  const ReFusionSceneProgramKeyframeSpec({
    required this.time,
    required this.value,
    required this.interpolation,
  });

  final TimelineTime time;
  final MotionPropertyValue value;
  final MotionInterpolationSpec interpolation;
}

@immutable
class ReFusionSceneProgramChannelSpec {
  ReFusionSceneProgramChannelSpec({
    required this.id,
    required this.targetId,
    required this.definition,
    required List<ReFusionSceneProgramKeyframeSpec> keyframes,
  }) : keyframes = List.unmodifiable(keyframes);

  final String id;
  final String targetId;
  final MotionPropertyDefinition definition;
  final List<ReFusionSceneProgramKeyframeSpec> keyframes;
}

@immutable
class ReFusionSceneProgramElementSpec {
  const ReFusionSceneProgramElementSpec({
    required this.id,
    required this.kind,
    this.layerId,
    this.text,
    this.range,
  });

  final String id;
  final MotionElementKind kind;
  final String? layerId;
  final String? text;
  final TimelineTimeRange? range;
}

@immutable
class ReFusionSceneProgramDocument {
  ReFusionSceneProgramDocument({
    required this.schemaVersion,
    required this.id,
    required this.duration,
    this.name,
    List<ReFusionSceneProgramElementSpec> elements =
        const <ReFusionSceneProgramElementSpec>[],
    List<ReFusionSceneProgramChannelSpec> channels =
        const <ReFusionSceneProgramChannelSpec>[],
  })  : elements = List.unmodifiable(elements),
        channels = List.unmodifiable(channels);

  final String schemaVersion;
  final String id;
  final String? name;
  final TimelineTime duration;
  final List<ReFusionSceneProgramElementSpec> elements;
  final List<ReFusionSceneProgramChannelSpec> channels;

  bool get hasEditableMotion => channels.isNotEmpty;
}

@immutable
class ReFusionSceneProgramValidationResult {
  const ReFusionSceneProgramValidationResult({
    required this.issues,
    this.document,
  });

  final ReFusionSceneProgramDocument? document;
  final List<ReFusionSceneProgramIssue> issues;

  bool get canApply {
    return document != null &&
        !issues.any(
          (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
        );
  }
}
