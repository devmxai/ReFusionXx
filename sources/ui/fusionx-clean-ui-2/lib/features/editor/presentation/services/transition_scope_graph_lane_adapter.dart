import '../../domain/services/composition_timeline_projection.dart';
import '../../domain/services/normal_transition_graph_authoring_service.dart';
import '../models/timeline_mock_models.dart';
import 'unified_scope_timeline_projection_adapter.dart';

enum TransitionScopeGraphLaneIssueCode {
  nonTransitionScope,
  transitionWindowMismatch,
  missingBundleChannel,
}

class TransitionScopeGraphLaneIssue {
  const TransitionScopeGraphLaneIssue({
    required this.code,
    required this.message,
    this.channelId,
  });

  final TransitionScopeGraphLaneIssueCode code;
  final String message;
  final String? channelId;
}

class TransitionScopeGraphLaneBinding {
  TransitionScopeGraphLaneBinding({
    required this.laneId,
    required this.channelId,
    required this.role,
    required Map<String, String> metadata,
  }) : metadata = Map.unmodifiable(metadata);

  final String laneId;
  final String channelId;
  final NormalTransitionGraphChannelRole role;
  final Map<String, String> metadata;
}

class TransitionScopeGraphLaneProjection {
  TransitionScopeGraphLaneProjection({
    required this.animationGroupId,
    required this.presetId,
    required this.transitionWindowId,
    required List<TimelineAnimationLaneData> lanes,
    required List<TransitionScopeGraphLaneBinding> bindings,
    List<TransitionScopeGraphLaneIssue> issues =
        const <TransitionScopeGraphLaneIssue>[],
  })  : lanes = List.unmodifiable(lanes),
        bindings = List.unmodifiable(bindings),
        issues = List.unmodifiable(issues);

  final String animationGroupId;
  final String presetId;
  final String transitionWindowId;
  final List<TimelineAnimationLaneData> lanes;
  final List<TransitionScopeGraphLaneBinding> bindings;
  final List<TransitionScopeGraphLaneIssue> issues;

  bool get hasIssues => issues.isNotEmpty;

  TransitionScopeGraphLaneBinding? bindingForLane(String laneId) {
    for (final binding in bindings) {
      if (binding.laneId == laneId) {
        return binding;
      }
    }
    return null;
  }

  List<TimelineAnimationLaneData> lanesForRole(
    NormalTransitionGraphChannelRole role,
  ) {
    final laneIds = bindings
        .where((binding) => binding.role == role)
        .map((binding) => binding.laneId)
        .toSet();
    return lanes
        .where((lane) => laneIds.contains(lane.id))
        .toList(growable: false);
  }
}

class TransitionScopeGraphLaneAdapter {
  const TransitionScopeGraphLaneAdapter({
    this.scopeLaneAdapter = const UnifiedScopeTimelineProjectionAdapter(),
  });

  final UnifiedScopeTimelineProjectionAdapter scopeLaneAdapter;

  TransitionScopeGraphLaneProjection lanesForBundle({
    required ScopeProjection projection,
    required NormalTransitionGraphAuthoringBundle bundle,
    String? targetClipId,
  }) {
    final issues = <TransitionScopeGraphLaneIssue>[];
    if (projection.mode != CompositionScopeMode.transition) {
      issues.add(
        const TransitionScopeGraphLaneIssue(
          code: TransitionScopeGraphLaneIssueCode.nonTransitionScope,
          message: 'Transition graph lanes require a transition scope.',
        ),
      );
      return _emptyProjection(bundle: bundle, issues: issues);
    }
    if (projection.transitionWindowId != bundle.transitionWindowId) {
      issues.add(
        TransitionScopeGraphLaneIssue(
          code: TransitionScopeGraphLaneIssueCode.transitionWindowMismatch,
          message:
              'Scope transition window `${projection.transitionWindowId}` does not match bundle `${bundle.transitionWindowId}`.',
        ),
      );
      return _emptyProjection(bundle: bundle, issues: issues);
    }

    final projectedLanes = scopeLaneAdapter.animationLanesForScope(
      projection,
      targetClipId: targetClipId ?? bundle.transitionWindowId,
    );
    final lanesById = <String, TimelineAnimationLaneData>{
      for (final lane in projectedLanes) lane.id: lane,
    };

    final laneEntries = <_TransitionLaneEntry>[];
    for (final binding in bundle.channelBindings) {
      final lane = lanesById[binding.channelId];
      if (lane == null) {
        issues.add(
          TransitionScopeGraphLaneIssue(
            code: TransitionScopeGraphLaneIssueCode.missingBundleChannel,
            message:
                'Bundle channel `${binding.channelId}` was not projected into a lane.',
            channelId: binding.channelId,
          ),
        );
        continue;
      }
      final roleLabel = _roleLabel(binding.role);
      laneEntries.add(
        _TransitionLaneEntry(
          role: binding.role,
          lane: lane.copyWith(label: '$roleLabel ${lane.label}'),
          binding: TransitionScopeGraphLaneBinding(
            laneId: lane.id,
            channelId: binding.channelId,
            role: binding.role,
            metadata: bundle.metadataForChannel(binding.channelId),
          ),
        ),
      );
    }

    laneEntries.sort(_compareLaneEntries);

    return TransitionScopeGraphLaneProjection(
      animationGroupId: bundle.animationGroupId,
      presetId: bundle.presetId,
      transitionWindowId: bundle.transitionWindowId,
      lanes: laneEntries.map((entry) => entry.lane).toList(growable: false),
      bindings:
          laneEntries.map((entry) => entry.binding).toList(growable: false),
      issues: issues,
    );
  }

  TransitionScopeGraphLaneProjection _emptyProjection({
    required NormalTransitionGraphAuthoringBundle bundle,
    required List<TransitionScopeGraphLaneIssue> issues,
  }) {
    return TransitionScopeGraphLaneProjection(
      animationGroupId: bundle.animationGroupId,
      presetId: bundle.presetId,
      transitionWindowId: bundle.transitionWindowId,
      lanes: const <TimelineAnimationLaneData>[],
      bindings: const <TransitionScopeGraphLaneBinding>[],
      issues: issues,
    );
  }

  int _compareLaneEntries(
      _TransitionLaneEntry left, _TransitionLaneEntry right) {
    final roleCompare = _roleOrder(left.role).compareTo(_roleOrder(right.role));
    if (roleCompare != 0) {
      return roleCompare;
    }
    return left.lane.label.compareTo(right.lane.label);
  }

  int _roleOrder(NormalTransitionGraphChannelRole role) {
    return switch (role) {
      NormalTransitionGraphChannelRole.outgoing => 0,
      NormalTransitionGraphChannelRole.incoming => 1,
    };
  }

  String _roleLabel(NormalTransitionGraphChannelRole role) {
    return switch (role) {
      NormalTransitionGraphChannelRole.outgoing => 'Outgoing',
      NormalTransitionGraphChannelRole.incoming => 'Incoming',
    };
  }
}

class _TransitionLaneEntry {
  const _TransitionLaneEntry({
    required this.role,
    required this.lane,
    required this.binding,
  });

  final NormalTransitionGraphChannelRole role;
  final TimelineAnimationLaneData lane;
  final TransitionScopeGraphLaneBinding binding;
}
