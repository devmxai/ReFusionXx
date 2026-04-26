import '../../domain/models/professional_normal_transition_models.dart';
import '../models/timeline_mock_models.dart';

class NormalTransitionScriptTimelineMappingResult {
  const NormalTransitionScriptTimelineMappingResult({
    required this.lanes,
    required this.effectIds,
    required this.parameterValues,
    required this.issues,
  });

  final List<TimelineAnimationLaneData> lanes;
  final List<String> effectIds;
  final Map<String, double> parameterValues;
  final List<NormalTransitionIssue> issues;

  bool get hasSupportedLanes => lanes.isNotEmpty;
}

class NormalTransitionScriptTimelineMapper {
  const NormalTransitionScriptTimelineMapper();

  NormalTransitionScriptTimelineMappingResult mapDefinition({
    required NormalTransitionDefinition definition,
    required String targetClipId,
  }) {
    final issues = <NormalTransitionIssue>[];
    final lanesById = <String, TimelineAnimationLaneData>{};

    for (var channelIndex = 0;
        channelIndex < definition.channels.length;
        channelIndex += 1) {
      final channel = definition.channels[channelIndex];
      final laneId = _laneIdForChannel(channel);
      if (laneId == null) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.warning,
            message:
                'Channel `${channel.target}.${channel.property}` is valid but not editable in the current transition scope yet.',
            path: 'channels[$channelIndex]',
          ),
        );
        continue;
      }

      final laneLabel = _laneLabel(laneId);
      final stops = <double>[];
      final values = <double>[];
      final keyframeIds = <String>[];
      for (var keyIndex = 0;
          keyIndex < channel.keyframes.length;
          keyIndex += 1) {
        final keyframe = channel.keyframes[keyIndex];
        final mappedValue = _mapValue(laneId, keyframe.value);
        if (mappedValue == null) {
          issues.add(
            NormalTransitionIssue(
              severity: NormalTransitionIssueSeverity.warning,
              message:
                  'Keyframe value for `${channel.target}.${channel.property}` must be numeric.',
              path: 'channels[$channelIndex].keyframes[$keyIndex].value',
            ),
          );
          continue;
        }
        final stop = keyframe.normalizedTime.clamp(0.0, 1.0).toDouble();
        stops.add(stop);
        values.add(mappedValue);
        keyframeIds.add(
          'script.${definition.definitionId}.$laneId.$keyIndex.${(stop * 1000).round()}',
        );
      }
      if (stops.isEmpty) {
        continue;
      }
      if (lanesById.containsKey(laneId)) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.warning,
            message:
                'Multiple script channels map to `$laneId`; the last channel was used.',
            path: 'channels[$channelIndex]',
          ),
        );
      }
      lanesById[laneId] = TimelineAnimationLaneData(
        id: laneId,
        label: laneLabel,
        targetClipId: targetClipId,
        normalizedKeyframeStops: List<double>.unmodifiable(stops),
        keyframeIds: List<String>.unmodifiable(keyframeIds),
        keyframeValues: List<double>.unmodifiable(values),
        trackSpanStartProgress: 0,
        trackSpanEndProgress: 1,
      );
    }

    if (lanesById.isEmpty) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message:
              'The script did not contain any currently supported transition channels.',
          path: 'channels',
        ),
      );
    }

    final parameterValues = <String, double>{
      for (final entry in definition.defaultParameterValues.entries)
        if (entry.value is num) entry.key: (entry.value as num).toDouble(),
      for (final lane in lanesById.values)
        lane.id: lane.keyframeValues.isEmpty
            ? _laneFallback(lane.id)
            : lane.keyframeValues.first,
    };

    return NormalTransitionScriptTimelineMappingResult(
      lanes: List<TimelineAnimationLaneData>.unmodifiable(lanesById.values),
      effectIds: List<String>.unmodifiable(lanesById.keys),
      parameterValues: Map<String, double>.unmodifiable(parameterValues),
      issues: List<NormalTransitionIssue>.unmodifiable(issues),
    );
  }

  String? _laneIdForChannel(NormalTransitionChannelSpec channel) {
    final target = _canonical(channel.target);
    final property = _canonical(channel.property);
    if (_knownLaneIds.containsKey(property)) {
      return _knownLaneIds[property];
    }
    if (target == 'from' || target == 'outgoing') {
      return switch (property) {
        'scale' ||
        'scalex' ||
        'scaley' ||
        'transformscale' =>
          'outgoingBoostScale',
        'x' ||
        'positionx' ||
        'translatex' ||
        'offsetx' ||
        'slidex' =>
          'outgoingOffsetX',
        'y' ||
        'positiony' ||
        'translatey' ||
        'offsety' ||
        'slidey' =>
          'outgoingOffsetY',
        'opacity' || 'alpha' => 'outgoingOpacity',
        'rotation' || 'rotate' || 'angle' => 'outgoingRotation',
        _ => null,
      };
    }
    if (target == 'to' || target == 'incoming') {
      return switch (property) {
        'scale' ||
        'scalex' ||
        'scaley' ||
        'transformscale' =>
          'incomingStartScale',
        'x' ||
        'positionx' ||
        'translatex' ||
        'offsetx' ||
        'slidex' =>
          'incomingOffsetX',
        'y' ||
        'positiony' ||
        'translatey' ||
        'offsety' ||
        'slidey' =>
          'incomingOffsetY',
        'opacity' || 'alpha' => 'incomingOpacity',
        'rotation' || 'rotate' || 'angle' => 'incomingRotation',
        _ => null,
      };
    }
    if (target == 'transition' || target.startsWith('transition')) {
      return switch (property) {
        'black' || 'blackmix' || 'blackpeak' || 'dipblack' => 'blackPeak',
        'darkness' || 'bridgedarkness' => 'bridgeDarkness',
        'flash' || 'whiteflash' || 'flashpeak' => 'whiteFlash',
        'blur' || 'bluramount' || 'maxblur' => 'blurAmount',
        _ => null,
      };
    }
    return null;
  }

  double? _mapValue(String laneId, Object value) {
    if (value is! num) {
      return null;
    }
    final raw = value.toDouble();
    final normalizedValue = switch (laneId) {
      'outgoingBoostScale' ||
      'incomingStartScale' =>
        raw <= 2.5 ? raw * 100.0 : raw,
      'outgoingOffsetX' ||
      'incomingOffsetX' =>
        raw.abs() <= 2.0 ? raw * 100.0 : raw,
      'outgoingOffsetY' ||
      'incomingOffsetY' =>
        raw.abs() <= 2.0 ? raw * 100.0 : raw,
      'blackPeak' ||
      'whiteFlash' ||
      'bridgeDarkness' =>
        raw <= 1.5 ? raw * 100.0 : raw,
      'outgoingOpacity' || 'incomingOpacity' => raw <= 1.5 ? raw * 100.0 : raw,
      'blurAmount' => raw,
      'outgoingRotation' || 'incomingRotation' => raw,
      _ => raw,
    };
    final range = _laneRanges[laneId];
    if (range == null) {
      return normalizedValue;
    }
    return normalizedValue.clamp(range.min, range.max).toDouble();
  }

  String _laneLabel(String laneId) {
    return switch (laneId) {
      'outgoingBoostScale' => 'Outgoing Scale',
      'incomingStartScale' => 'Incoming Scale',
      'outgoingOffsetX' => 'Outgoing Slide X',
      'incomingOffsetX' => 'Incoming Slide X',
      'outgoingOffsetY' => 'Outgoing Slide Y',
      'incomingOffsetY' => 'Incoming Slide Y',
      'entryDelay' => 'Entry Delay',
      'bridgeDarkness' => 'Bridge Darkness',
      'blackPeak' => 'Black Mix',
      'whiteFlash' => 'White Flash',
      'blurAmount' => 'Blur Amount',
      'outgoingOpacity' => 'Outgoing Opacity',
      'incomingOpacity' => 'Incoming Opacity',
      'outgoingRotation' => 'Outgoing Rotation',
      'incomingRotation' => 'Incoming Rotation',
      _ => laneId,
    };
  }

  double _laneFallback(String laneId) {
    return switch (laneId) {
      'outgoingBoostScale' || 'incomingStartScale' => 100.0,
      'outgoingOpacity' => 100.0,
      _ => 0.0,
    };
  }

  String _canonical(String input) {
    return input.trim().toLowerCase().replaceAll(
          RegExp(r'[\s_\-\.]'),
          '',
        );
  }

  static const Map<String, String> _knownLaneIds = <String, String>{
    'outgoingboostscale': 'outgoingBoostScale',
    'incomingstartscale': 'incomingStartScale',
    'outgoingoffsetx': 'outgoingOffsetX',
    'incomingoffsetx': 'incomingOffsetX',
    'outgoingoffsety': 'outgoingOffsetY',
    'incomingoffsety': 'incomingOffsetY',
    'entrydelay': 'entryDelay',
    'bridgedarkness': 'bridgeDarkness',
    'blackpeak': 'blackPeak',
    'blackmix': 'blackPeak',
    'whiteflash': 'whiteFlash',
    'bluramount': 'blurAmount',
    'outgoingopacity': 'outgoingOpacity',
    'incomingopacity': 'incomingOpacity',
    'outgoingrotation': 'outgoingRotation',
    'incomingrotation': 'incomingRotation',
  };

  static const Map<String, ({double min, double max})> _laneRanges =
      <String, ({double min, double max})>{
    'outgoingBoostScale': (min: 100.0, max: 125.0),
    'incomingStartScale': (min: 100.0, max: 145.0),
    'outgoingOffsetX': (min: -120.0, max: 120.0),
    'incomingOffsetX': (min: -120.0, max: 120.0),
    'outgoingOffsetY': (min: -120.0, max: 120.0),
    'incomingOffsetY': (min: -120.0, max: 120.0),
    'entryDelay': (min: 0.0, max: 48.0),
    'bridgeDarkness': (min: 0.0, max: 65.0),
    'blackPeak': (min: 0.0, max: 100.0),
    'whiteFlash': (min: 0.0, max: 100.0),
    'blurAmount': (min: 0.0, max: 24.0),
    'outgoingOpacity': (min: 0.0, max: 100.0),
    'incomingOpacity': (min: 0.0, max: 100.0),
    'outgoingRotation': (min: -45.0, max: 45.0),
    'incomingRotation': (min: -45.0, max: 45.0),
  };
}
