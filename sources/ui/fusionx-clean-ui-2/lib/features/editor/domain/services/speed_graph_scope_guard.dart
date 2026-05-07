import 'dart:developer' as developer;

enum SpeedGraphScopeRequestKind {
  temporalGraph,
  spatialPath,
  clipSpeedRamp,
  timeRemap,
}

class SpeedGraphScopeGuardRequest {
  const SpeedGraphScopeGuardRequest({
    required this.requestKind,
    required this.propertyPath,
  });

  final SpeedGraphScopeRequestKind requestKind;
  final String propertyPath;
}

class SpeedGraphScopeGuardResult {
  const SpeedGraphScopeGuardResult({
    required this.accepted,
    required this.blockedReason,
    required this.routedToMotionInterpolationTruthCompiler,
    required this.futureContract,
  });

  final bool accepted;
  final String blockedReason;
  final bool routedToMotionInterpolationTruthCompiler;
  final String futureContract;
}

class SpeedGraphScopeGuard {
  const SpeedGraphScopeGuard();

  SpeedGraphScopeGuardResult evaluate(SpeedGraphScopeGuardRequest request) {
    final normalizedPath = request.propertyPath.trim().toLowerCase();
    final result = switch (request.requestKind) {
      SpeedGraphScopeRequestKind.temporalGraph =>
        _resolveTemporalGraph(normalizedPath),
      SpeedGraphScopeRequestKind.spatialPath =>
        const SpeedGraphScopeGuardResult(
          accepted: false,
          blockedReason: 'spatial_path_requires_future_spatial_bezier_contract',
          routedToMotionInterpolationTruthCompiler: false,
          futureContract: 'spatial_bezier_contract_v1',
        ),
      SpeedGraphScopeRequestKind.clipSpeedRamp =>
        const SpeedGraphScopeGuardResult(
          accepted: false,
          blockedReason:
              'clip_speed_ramp_is_not_a_motion_property_temporal_graph',
          routedToMotionInterpolationTruthCompiler: false,
          futureContract: 'clip_speed_ramp_contract_v1',
        ),
      SpeedGraphScopeRequestKind.timeRemap => const SpeedGraphScopeGuardResult(
          accepted: false,
          blockedReason: 'time_remap_requires_dedicated_time_mapping_contract',
          routedToMotionInterpolationTruthCompiler: false,
          futureContract: 'time_remap_contract_v1',
        ),
    };
    _emitProof(
      request: request,
      result: result,
    );
    return result;
  }

  SpeedGraphScopeGuardResult _resolveTemporalGraph(String propertyPath) {
    if (propertyPath.contains('path') ||
        propertyPath.contains('motionpath') ||
        propertyPath.contains('spatial')) {
      return const SpeedGraphScopeGuardResult(
        accepted: false,
        blockedReason: 'temporal_graph_rejects_spatial_path_property',
        routedToMotionInterpolationTruthCompiler: false,
        futureContract: 'spatial_bezier_contract_v1',
      );
    }
    if (propertyPath.contains('timeremap') ||
        propertyPath.contains('speedramp')) {
      return const SpeedGraphScopeGuardResult(
        accepted: false,
        blockedReason: 'temporal_graph_rejects_time_remap_property',
        routedToMotionInterpolationTruthCompiler: false,
        futureContract: 'clip_speed_ramp_contract_v1',
      );
    }
    return const SpeedGraphScopeGuardResult(
      accepted: true,
      blockedReason: 'none',
      routedToMotionInterpolationTruthCompiler: true,
      futureContract: 'none',
    );
  }

  void _emitProof({
    required SpeedGraphScopeGuardRequest request,
    required SpeedGraphScopeGuardResult result,
  }) {
    developer.log(
      'TF_SPEED_GRAPH_SCOPE_GUARD_PROOF '
      'requestKind=${request.requestKind.name} '
      'propertyPath=${request.propertyPath} '
      'accepted=${result.accepted} '
      'blockedReason=${result.blockedReason} '
      'routedToMotionInterpolationTruthCompiler='
      '${result.routedToMotionInterpolationTruthCompiler} '
      'futureContract=${result.futureContract}',
      name: 'ReFusionXx.SpeedGraph',
    );
  }
}
