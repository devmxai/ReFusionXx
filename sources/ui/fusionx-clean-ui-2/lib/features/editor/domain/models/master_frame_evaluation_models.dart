import 'package:flutter/foundation.dart';

import 'master_time_models.dart';
import 'master_value_truth_models.dart';

@immutable
class MasterEvaluatedPropertyValue {
  const MasterEvaluatedPropertyValue({
    required this.targetId,
    required this.propertyDefinitionId,
    required this.domain,
    required this.mapping,
    required this.sourceChannelId,
    required this.status,
  });

  final String targetId;
  final String propertyDefinitionId;
  final MasterTimeDomain domain;
  final MasterPropertyValueMapping mapping;
  final String sourceChannelId;
  final String status;
}

@immutable
class MasterFrameEvaluation {
  MasterFrameEvaluation({
    required this.time,
    List<MasterTimeProjection> projections = const <MasterTimeProjection>[],
    List<String> visibleLayerIds = const <String>[],
    List<String> activeTransitionIds = const <String>[],
    List<MasterEvaluatedPropertyValue> evaluatedChannels =
        const <MasterEvaluatedPropertyValue>[],
    Map<String, MasterPropertyValueMapping> effectParameters =
        const <String, MasterPropertyValueMapping>{},
    List<String> diagnostics = const <String>[],
  })  : projections = List.unmodifiable(projections),
        visibleLayerIds = List.unmodifiable(visibleLayerIds),
        activeTransitionIds = List.unmodifiable(activeTransitionIds),
        evaluatedChannels = List.unmodifiable(evaluatedChannels),
        effectParameters = Map.unmodifiable(effectParameters),
        diagnostics = List.unmodifiable(diagnostics);

  final MasterTimeSnapshot time;
  final List<MasterTimeProjection> projections;
  final List<String> visibleLayerIds;
  final List<String> activeTransitionIds;
  final List<MasterEvaluatedPropertyValue> evaluatedChannels;
  final Map<String, MasterPropertyValueMapping> effectParameters;
  final List<String> diagnostics;
}
