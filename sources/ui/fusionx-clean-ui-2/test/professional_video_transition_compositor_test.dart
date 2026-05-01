import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/professional_video_transition_compositor.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('current compositor gate does not expose professional zoom yet', () {
    expect(
      kCurrentProfessionalVideoTransitionCompositorCapabilities
          .canExposeProfessionalZoomInCamera,
      isFalse,
    );
    expect(
      kCurrentProfessionalVideoTransitionCompositorCapabilities
          .missingForProfessionalZoomInCamera,
      containsAll(<String>[
        'dualVideoSampling',
        'temporalMotionBlur',
        'mirrorEdgeTiling',
        'previewParity',
        'liveScrubParity',
        'playbackParity',
        'exportParity',
      ]),
    );
  });

  test('capability mapper requires every professional zoom feature', () {
    final partial =
        ProfessionalVideoTransitionCompositorCapabilitiesMapper.fromMap(
      <String, Object?>{
        'dualVideoSampling': true,
        'temporalMotionBlur': true,
        'mirrorEdgeTiling': true,
        'previewParity': true,
        'liveScrubParity': false,
        'playbackParity': true,
        'exportParity': true,
      },
    );

    expect(partial.canExposeProfessionalZoomInCamera, isFalse);
    expect(partial.missingForProfessionalZoomInCamera, <String>[
      'liveScrubParity',
    ]);

    final complete =
        ProfessionalVideoTransitionCompositorCapabilitiesMapper.fromMap(
      <String, Object?>{
        'dualVideoSampling': true,
        'temporalMotionBlur': true,
        'mirrorEdgeTiling': true,
        'previewParity': true,
        'liveScrubParity': true,
        'playbackParity': true,
        'exportParity': true,
      },
    );

    expect(complete.canExposeProfessionalZoomInCamera, isTrue);
  });

  test('method channel capability provider maps native capabilities', () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getCapabilities');
      return <String, Object?>{
        'dualVideoSampling': true,
        'temporalMotionBlur': true,
        'mirrorEdgeTiling': true,
        'previewParity': true,
        'liveScrubParity': true,
        'playbackParity': true,
        'exportParity': false,
      };
    });

    final capabilities =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).loadCapabilities();

    expect(capabilities.canExposeProfessionalZoomInCamera, isFalse);
    expect(capabilities.missingForProfessionalZoomInCamera, <String>[
      'exportParity',
    ]);
  });

  test('zoom camera plan maps to live source times around the seam', () {
    const planner = ProfessionalZoomCameraCompositorPlanner();
    final plan = planner.planFrame(
      ProfessionalZoomCameraPlanRequest(
        transitionId: 'zoom-1',
        timelineTime: TimelineTime.fromMilliseconds(9500),
        boundaryTime: TimelineTime.fromMilliseconds(10000),
        leadingDuration: TimelineTime.fromMilliseconds(2000),
        trailingDuration: TimelineTime.fromMilliseconds(2000),
        outgoing: ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-a',
          assetId: 'asset-a',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(10000),
          ),
          sourceStartTime: TimelineTime.fromMilliseconds(5000),
          sourceDuration: TimelineTime.fromMilliseconds(10000),
        ),
        incoming: ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-b',
          assetId: 'asset-b',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.fromMilliseconds(10000),
            endExclusive: TimelineTime.fromMilliseconds(18000),
          ),
          sourceStartTime: TimelineTime.fromMilliseconds(1200),
          sourceDuration: TimelineTime.fromMilliseconds(8000),
        ),
      ),
    );

    expect(plan.progress, closeTo(0.375, 0.0001));
    expect(plan.seamProgress, closeTo(0.5, 0.0001));
    expect(plan.outgoingSourceTime.inMilliseconds, 14500);
    expect(plan.incomingSourceTime.inMilliseconds, 1200);
    expect(plan.outgoingScale, greaterThan(1.0));
    expect(plan.incomingScale, 0.28);
  });

  test('zoom camera plan advances incoming video after the seam', () {
    const planner = ProfessionalZoomCameraCompositorPlanner();
    final plan = planner.planFrame(
      ProfessionalZoomCameraPlanRequest(
        transitionId: 'zoom-1',
        timelineTime: TimelineTime.fromMilliseconds(11250),
        boundaryTime: TimelineTime.fromMilliseconds(10000),
        leadingDuration: TimelineTime.fromMilliseconds(2000),
        trailingDuration: TimelineTime.fromMilliseconds(2000),
        outgoing: ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-a',
          assetId: 'asset-a',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(10000),
          ),
          sourceStartTime: TimelineTime.zero,
          sourceDuration: TimelineTime.fromMilliseconds(10000),
        ),
        incoming: ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-b',
          assetId: 'asset-b',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.fromMilliseconds(10000),
            endExclusive: TimelineTime.fromMilliseconds(18000),
          ),
          sourceStartTime: TimelineTime.fromMilliseconds(3000),
          sourceDuration: TimelineTime.fromMilliseconds(8000),
        ),
      ),
    );

    expect(plan.outgoingSourceTime.inMilliseconds, 10000);
    expect(plan.incomingSourceTime.inMilliseconds, 4250);
    expect(plan.incomingScale, greaterThan(0.28));
    expect(plan.incomingScale, lessThanOrEqualTo(1.0));
  });

  test('zoom camera plan requires mirror edge tiling and shutter samples', () {
    const planner = ProfessionalZoomCameraCompositorPlanner();
    final plan = planner.planFrame(
      ProfessionalZoomCameraPlanRequest(
        transitionId: 'zoom-1',
        timelineTime: TimelineTime.fromMilliseconds(10000),
        boundaryTime: TimelineTime.fromMilliseconds(10000),
        leadingDuration: TimelineTime.fromMilliseconds(2000),
        trailingDuration: TimelineTime.fromMilliseconds(2000),
        shutterAngleDegrees: 360,
        frameRate: 30,
        shutterSampleCount: 8,
        outgoing: ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-a',
          assetId: 'asset-a',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(10000),
          ),
          sourceStartTime: TimelineTime.zero,
          sourceDuration: TimelineTime.fromMilliseconds(10000),
        ),
        incoming: ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-b',
          assetId: 'asset-b',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.fromMilliseconds(10000),
            endExclusive: TimelineTime.fromMilliseconds(18000),
          ),
          sourceStartTime: TimelineTime.zero,
          sourceDuration: TimelineTime.fromMilliseconds(8000),
        ),
      ),
    );

    expect(plan.motionTile.enabled, isTrue);
    expect(plan.motionTile.mirrorEdges, isTrue);
    expect(plan.motionTile.outputScaleX, 4.0);
    expect(plan.motionTile.outputScaleY, 3.5);
    expect(plan.shutter.shutterAngleDegrees, 360);
    expect(plan.shutter.sampleCount, 8);
    expect(plan.shutter.sampleTimes, hasLength(8));
    expect(
        plan.shutter.sampleTimes.first < plan.shutter.sampleTimes.last, isTrue);
  });
}
