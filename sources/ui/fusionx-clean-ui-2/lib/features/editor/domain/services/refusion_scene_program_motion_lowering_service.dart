import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/motion_authoring_bundle_models.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_compilation_models.dart';
import '../models/professional_motion_models.dart';
import '../models/refusion_scene_program_models.dart';

enum ReFusionSceneProgramLoweringIssueCode {
  duplicateKeyframeTime,
  keyframeOutOfRange,
}

@immutable
class ReFusionSceneProgramLoweringIssue {
  const ReFusionSceneProgramLoweringIssue({
    required this.code,
    required this.message,
    this.path,
  });

  final ReFusionSceneProgramLoweringIssueCode code;
  final String message;
  final String? path;
}

@immutable
class ReFusionSceneProgramLoweringResult {
  const ReFusionSceneProgramLoweringResult({
    this.bundle,
    this.issues = const <ReFusionSceneProgramLoweringIssue>[],
  });

  final MotionAuthoringBundle? bundle;
  final List<ReFusionSceneProgramLoweringIssue> issues;

  bool get hasIssues => issues.isNotEmpty;

  bool get canApply => bundle != null && !hasIssues;
}

class ReFusionSceneProgramMotionLoweringService {
  const ReFusionSceneProgramMotionLoweringService();

  ReFusionSceneProgramLoweringResult lower({
    required ReFusionSceneProgramDocument document,
    required String projectId,
    required String sceneId,
    required String layerId,
  }) {
    final issues = <ReFusionSceneProgramLoweringIssue>[];
    final projectRange = TimelineTimeRange(
      start: TimelineTime.zero,
      endExclusive: document.duration,
    );
    final elements = _lowerElements(
      document,
      sceneId: sceneId,
      layerId: layerId,
      projectRange: projectRange,
    );
    final propertyChannels = <MotionPropertyChannelModel>[];
    for (var channelIndex = 0;
        channelIndex < document.channels.length;
        channelIndex += 1) {
      final channel = document.channels[channelIndex];
      final lowered = _lowerChannel(
        channel,
        channelIndex: channelIndex,
        projectId: projectId,
        sceneId: sceneId,
        layerId: layerId,
        projectRange: projectRange,
        issues: issues,
      );
      if (lowered != null) {
        propertyChannels.add(lowered);
      }
    }

    if (issues.isNotEmpty) {
      return ReFusionSceneProgramLoweringResult(
        issues: List<ReFusionSceneProgramLoweringIssue>.unmodifiable(issues),
      );
    }

    return ReFusionSceneProgramLoweringResult(
      bundle: MotionAuthoringBundle(
        origin: MotionAuthoringOrigin(
          kind: MotionAuthoringSourceKind.script,
          id: document.id,
          label: document.name,
          metadata: <String, String>{
            'schemaVersion': document.schemaVersion,
          },
        ),
        elements: elements,
        propertyChannels:
            List<MotionPropertyChannelModel>.unmodifiable(propertyChannels),
      ),
    );
  }

  List<MotionElementModel> _lowerElements(
    ReFusionSceneProgramDocument document, {
    required String sceneId,
    required String layerId,
    required TimelineTimeRange projectRange,
  }) {
    return List<MotionElementModel>.unmodifiable(
      document.elements.map((element) {
        return MotionElementModel(
          id: element.id,
          layerId: element.layerId ?? layerId,
          kind: element.kind,
          localRange: element.range ?? projectRange,
          name: element.text ?? element.id,
          sourceBinding: element.text == null
              ? null
              : MotionElementSourceBinding(
                  kind: MotionSourceKind.generatedText,
                  sourceId: element.id,
                  label: element.text,
                ),
        );
      }),
    );
  }

  MotionPropertyChannelModel? _lowerChannel(
    ReFusionSceneProgramChannelSpec channel, {
    required int channelIndex,
    required String projectId,
    required String sceneId,
    required String layerId,
    required TimelineTimeRange projectRange,
    required List<ReFusionSceneProgramLoweringIssue> issues,
  }) {
    final seenTimes = <int>{};
    final keyframes = <MotionKeyframeModel>[];
    for (var keyframeIndex = 0;
        keyframeIndex < channel.keyframes.length;
        keyframeIndex += 1) {
      final keyframe = channel.keyframes[keyframeIndex];
      final ticks = keyframe.time.inProjectTicks;
      final path = 'channels[$channelIndex].keyframes[$keyframeIndex]';
      if (!projectRange.contains(keyframe.time) &&
          keyframe.time != projectRange.endExclusive) {
        issues.add(
          ReFusionSceneProgramLoweringIssue(
            code: ReFusionSceneProgramLoweringIssueCode.keyframeOutOfRange,
            message:
                'Keyframe time ${keyframe.time.inMilliseconds}ms is outside the scene duration.',
            path: '$path.timeMs',
          ),
        );
        continue;
      }
      if (!seenTimes.add(ticks)) {
        issues.add(
          ReFusionSceneProgramLoweringIssue(
            code: ReFusionSceneProgramLoweringIssueCode.duplicateKeyframeTime,
            message:
                'Channel `${channel.id}` has more than one keyframe at the same timeline tick.',
            path: path,
          ),
        );
        continue;
      }
      keyframes.add(
        MotionKeyframeModel(
          id: '${channel.id}.keyframe.$keyframeIndex',
          channelId: channel.id,
          time: keyframe.time,
          value: keyframe.value,
          interpolationToNext: keyframe.interpolation,
        ),
      );
    }

    if (issues.isNotEmpty) {
      return null;
    }

    return MotionPropertyChannelModel(
      id: channel.id,
      target: MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: channel.targetId,
        projectId: projectId,
        sceneId: sceneId,
        layerId: layerId,
        elementId: channel.targetId,
      ),
      definition: channel.definition,
      activeRange: projectRange,
      keyframes: List<MotionKeyframeModel>.unmodifiable(keyframes),
    );
  }
}
