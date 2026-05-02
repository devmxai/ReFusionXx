import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_keyframe_value_evaluator.dart';
import 'package:refusion_app/features/editor/domain/services/master_value_truth_registry.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  final evaluator = MasterKeyframeValueEvaluator(
    registry: MasterValueTruthRegistry(),
  );

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MasterTimeSnapshot snapshotAt(int milliseconds) {
    return MasterTimeSnapshot(
      rootTime: ms(milliseconds),
      presentationTime: ms(milliseconds),
      frameIndex: 30,
      frameRate: 30,
      commitFrameNumber: 3,
      monotonicTimeUs: 1000,
      phase: MasterClockPhase.paused,
      authority: MasterClockAuthority.none,
      renderMode: MasterRenderMode.preview,
      sourceScope: MasterTimeScope.scene,
    );
  }

  MotionPropertyChannelModel opacityChannel() {
    return MotionPropertyChannelModel(
      id: 'opacity.channel',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project-1',
        sceneId: 'scene-1',
        layerId: 'layer-1',
        elementId: 'element-1',
      ),
      definition: MotionPropertyCatalog.opacity,
      activeRange: TimelineTimeRange(start: ms(0), endExclusive: ms(1000)),
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'k0',
          channelId: 'opacity.channel',
          time: ms(0),
          value: const MotionPropertyValue.scalar(0),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
        MotionKeyframeModel(
          id: 'k1',
          channelId: 'opacity.channel',
          time: ms(1000),
          value: const MotionPropertyValue.scalar(100),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  MotionPropertyChannelModel holdScaleChannel() {
    return MotionPropertyChannelModel(
      id: 'scale.channel',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project-1',
        sceneId: 'scene-1',
        layerId: 'layer-1',
        elementId: 'element-1',
      ),
      definition: MotionPropertyCatalog.scaleX,
      activeRange: TimelineTimeRange(start: ms(0), endExclusive: ms(2000)),
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 's0',
          channelId: 'scale.channel',
          time: ms(0),
          value: const MotionPropertyValue.scalar(0),
          interpolationToNext: const MotionInterpolationSpec.hold(),
        ),
        MotionKeyframeModel(
          id: 's1',
          channelId: 'scale.channel',
          time: ms(2000),
          value: const MotionPropertyValue.scalar(100),
          interpolationToNext: const MotionInterpolationSpec.hold(),
        ),
      ],
    );
  }

  MasterTimeProjection projectionAt(int msValue) {
    return MasterTimeProjection(
      fromDomain: const MasterTimeDomain.root(),
      toDomain: const MasterTimeDomain.scene('scene-1'),
      inputTime: ms(msValue),
      outputTime: ms(msValue),
      validRange: TimelineTimeRange(start: ms(0), endExclusive: ms(2000)),
      policy: MasterTimeProjectionPolicy.clamp,
      reason: 'test_projection',
      isValid: true,
    );
  }

  test('evaluates linear scalar interpolation to mapped renderer value', () {
    final result = evaluator.evaluate(
      MasterKeyframeEvaluationRequest(
        channel: opacityChannel(),
        time: snapshotAt(500),
        domainProjection: projectionAt(500),
      ),
    );

    expect(result.status, MasterKeyframeEvaluationStatus.resolved);
    expect(result.rawValue, isNotNull);
    expect(result.rawValue!.kind, MotionPropertyValueKind.scalar);
    expect(result.rawValue!.rawValue as double, closeTo(50.0, 0.001));
    expect(result.mapping!.renderer.scalar, closeTo(0.5, 0.001));
  });

  test('hold interpolation keeps first keyframe value until next keyframe', () {
    final result = evaluator.evaluate(
      MasterKeyframeEvaluationRequest(
        channel: holdScaleChannel(),
        time: snapshotAt(1000),
        domainProjection: projectionAt(1000),
      ),
    );

    expect(result.status, MasterKeyframeEvaluationStatus.resolved);
    expect(result.rawValue!.rawValue as double, 0);
    expect(result.mapping!.engine.scalar, closeTo(1.0, 0.001));
  });

  test('invalid projection rejects evaluation', () {
    final invalidProjection = MasterTimeProjection(
      fromDomain: const MasterTimeDomain.root(),
      toDomain: const MasterTimeDomain.scene('scene-1'),
      inputTime: ms(2500),
      outputTime: ms(2000),
      validRange: TimelineTimeRange(start: ms(0), endExclusive: ms(2000)),
      policy: MasterTimeProjectionPolicy.rejectOutsideRange,
      reason: 'outside',
      isValid: false,
    );
    final result = evaluator.evaluate(
      MasterKeyframeEvaluationRequest(
        channel: opacityChannel(),
        time: snapshotAt(2500),
        domainProjection: invalidProjection,
      ),
    );
    expect(result.status, MasterKeyframeEvaluationStatus.outOfRange);
  });

  test('transition-local request can use explicit transition progress', () {
    final result = evaluator.evaluate(
      MasterKeyframeEvaluationRequest(
        channel: opacityChannel(),
        time: snapshotAt(500),
        domainProjection: projectionAt(500),
        transitionProgress: 0.75,
      ),
    );
    expect(result.rawValue!.rawValue as double, closeTo(75, 0.001));
  });
}
