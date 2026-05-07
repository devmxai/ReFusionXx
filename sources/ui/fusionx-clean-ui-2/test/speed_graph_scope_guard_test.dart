import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/speed_graph_scope_guard.dart';
import 'dart:io';

void main() {
  const guard = SpeedGraphScopeGuard();

  test('temporal scalar channel request is accepted', () {
    final result = guard.evaluate(
      const SpeedGraphScopeGuardRequest(
        requestKind: SpeedGraphScopeRequestKind.temporalGraph,
        propertyPath: 'transform.rotation',
      ),
    );
    expect(result.accepted, isTrue);
    expect(result.routedToMotionInterpolationTruthCompiler, isTrue);
    expect(result.blockedReason, 'none');
  });

  test('temporal position x/y channels are accepted', () {
    final x = guard.evaluate(
      const SpeedGraphScopeGuardRequest(
        requestKind: SpeedGraphScopeRequestKind.temporalGraph,
        propertyPath: 'transform.position.x',
      ),
    );
    final y = guard.evaluate(
      const SpeedGraphScopeGuardRequest(
        requestKind: SpeedGraphScopeRequestKind.temporalGraph,
        propertyPath: 'transform.position.y',
      ),
    );
    expect(x.accepted, isTrue);
    expect(y.accepted, isTrue);
  });

  test('spatial path request is blocked with explicit reason', () {
    final result = guard.evaluate(
      const SpeedGraphScopeGuardRequest(
        requestKind: SpeedGraphScopeRequestKind.spatialPath,
        propertyPath: 'transform.motionPath',
      ),
    );
    expect(result.accepted, isFalse);
    expect(
      result.blockedReason,
      'spatial_path_requires_future_spatial_bezier_contract',
    );
    expect(result.routedToMotionInterpolationTruthCompiler, isFalse);
  });

  test('time remapping request is blocked with explicit reason', () {
    final result = guard.evaluate(
      const SpeedGraphScopeGuardRequest(
        requestKind: SpeedGraphScopeRequestKind.timeRemap,
        propertyPath: 'clip.timeRemap.speed',
      ),
    );
    expect(result.accepted, isFalse);
    expect(
      result.blockedReason,
      'time_remap_requires_dedicated_time_mapping_contract',
    );
    expect(result.routedToMotionInterpolationTruthCompiler, isFalse);
  });

  test('clip speed ramp request is blocked with explicit reason', () {
    final result = guard.evaluate(
      const SpeedGraphScopeGuardRequest(
        requestKind: SpeedGraphScopeRequestKind.clipSpeedRamp,
        propertyPath: 'clip.speedRamp',
      ),
    );
    expect(result.accepted, isFalse);
    expect(
      result.blockedReason,
      'clip_speed_ramp_is_not_a_motion_property_temporal_graph',
    );
    expect(result.routedToMotionInterpolationTruthCompiler, isFalse);
  });

  test('temporal request rejects spatial-like property path', () {
    final result = guard.evaluate(
      const SpeedGraphScopeGuardRequest(
        requestKind: SpeedGraphScopeRequestKind.temporalGraph,
        propertyPath: 'transform.position.path',
      ),
    );
    expect(result.accepted, isFalse);
    expect(
      result.blockedReason,
      'temporal_graph_rejects_spatial_path_property',
    );
    expect(result.routedToMotionInterpolationTruthCompiler, isFalse);
  });

  test('clip speed bottom sheet does not route through truth compiler', () {
    final source = File(
      '/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/clip_speed_bottom_sheet.dart',
    ).readAsStringSync();
    expect(source.contains('MotionInterpolationTruthCompiler'), isFalse);
  });
}
