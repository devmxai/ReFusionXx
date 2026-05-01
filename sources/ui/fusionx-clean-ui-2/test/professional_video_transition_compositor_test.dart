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
          .canExposeProfessionalVideoTransitions,
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
    expect(partial.canExposeProfessionalVideoTransitions, isFalse);
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
    expect(complete.canExposeProfessionalVideoTransitions, isTrue);
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
        'registeredDefinitions': <String>[
          'crossDissolve',
          'fadeBlack',
          'zoomInCamera',
        ],
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
    expect(capabilities.registeredDefinitions, <String>[
      'crossDissolve',
      'fadeBlack',
      'zoomInCamera',
    ]);
  });

  test('generic render plan serializes transition-agnostic native contract',
      () {
    final plan = ProfessionalVideoTransitionRenderPlan(
      definitionId: 'whip_pan_left',
      transitionId: 'transition-1',
      canvasWidth: 1080,
      canvasHeight: 1920,
      boundaryTime: TimelineTime.fromMilliseconds(10000),
      leadingDuration: TimelineTime.fromMilliseconds(1200),
      trailingDuration: TimelineTime.fromMilliseconds(1200),
      sources: <ProfessionalVideoTransitionCompositorSource>[
        ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-a',
          assetId: 'asset-a',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(10000),
          ),
          sourceStartTime: TimelineTime.fromMilliseconds(1500),
          sourceDuration: TimelineTime.fromMilliseconds(10000),
        ),
        ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-b',
          assetId: 'asset-b',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.fromMilliseconds(10000),
            endExclusive: TimelineTime.fromMilliseconds(18000),
          ),
          sourceStartTime: TimelineTime.fromMilliseconds(750),
          sourceDuration: TimelineTime.fromMilliseconds(8000),
        ),
      ],
      requiredCapabilities: const <String>[
        'dualVideoSampling',
        'temporalMotionBlur',
        'mirrorEdgeTiling',
      ],
      parameters: const <String, Object?>{
        'direction': 'left',
        'distance': 1.0,
      },
      samplingPolicy: const <String, Object?>{
        'sourceCount': 2,
      },
      edgePolicy: const <String, Object?>{
        'mode': 'mirrorTile',
      },
      motionBlurPolicy: const <String, Object?>{
        'mode': 'temporalShutter',
      },
    );

    final payload = plan.toPlatformMap();
    expect(payload['definitionId'], 'whip_pan_left');
    expect(payload['transitionId'], 'transition-1');
    expect(payload['canvasWidth'], 1080);
    expect(payload['canvasHeight'], 1920);
    expect(payload['boundaryTimeMs'], 10000);
    expect(payload['leadingDurationMs'], 1200);
    expect(payload['trailingDurationMs'], 1200);
    expect(payload['requiredCapabilities'], <String>[
      'dualVideoSampling',
      'temporalMotionBlur',
      'mirrorEdgeTiling',
    ]);
    expect(payload['parameters'], containsPair('direction', 'left'));
    expect(payload['samplingPolicy'], containsPair('sourceCount', 2));
    expect(payload['edgePolicy'], containsPair('mode', 'mirrorTile'));
    expect(
        payload['motionBlurPolicy'], containsPair('mode', 'temporalShutter'));

    final sources = payload['sources']! as List<Object?>;
    final outgoing = sources.first! as Map<String, Object?>;
    final incoming = sources.last! as Map<String, Object?>;
    expect(outgoing['clipId'], 'clip-a');
    expect(outgoing['timelineEndMs'], 10000);
    expect(outgoing['sourceStartMs'], 1500);
    expect(incoming['clipId'], 'clip-b');
    expect(incoming['timelineStartMs'], 10000);
    expect(incoming['sourceStartMs'], 750);
  });

  test('cross dissolve planner blends live sources across covered window', () {
    const planner = ProfessionalCrossDissolveCompositorPlanner();
    final plan = ProfessionalVideoTransitionRenderPlan(
      definitionId:
          ProfessionalVideoTransitionCompositorKind.crossDissolve.name,
      transitionId: 'dissolve-1',
      canvasWidth: 1080,
      canvasHeight: 1920,
      boundaryTime: TimelineTime.fromMilliseconds(10000),
      leadingDuration: TimelineTime.fromMilliseconds(2000),
      trailingDuration: TimelineTime.fromMilliseconds(2000),
      sources: <ProfessionalVideoTransitionCompositorSource>[
        ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-a',
          assetId: 'asset-a',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.fromMilliseconds(8000),
            endExclusive: TimelineTime.fromMilliseconds(12000),
          ),
          sourceStartTime: TimelineTime.fromMilliseconds(20000),
          sourceDuration: TimelineTime.fromMilliseconds(4000),
        ),
        ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-b',
          assetId: 'asset-b',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.fromMilliseconds(8000),
            endExclusive: TimelineTime.fromMilliseconds(12000),
          ),
          sourceStartTime: TimelineTime.fromMilliseconds(30000),
          sourceDuration: TimelineTime.fromMilliseconds(4000),
        ),
      ],
      requiredCapabilities: const <String>[
        'dualVideoSampling',
        'previewParity',
        'liveScrubParity',
        'playbackParity',
        'exportParity',
      ],
    );

    final frame = planner.planFrame(
      renderPlan: plan,
      timelineTime: TimelineTime.fromMilliseconds(9000),
    );

    expect(frame.transitionId, 'dissolve-1');
    expect(frame.progress, closeTo(0.25, 0.0001));
    expect(frame.outgoingOpacity, closeTo(0.75, 0.0001));
    expect(frame.incomingOpacity, closeTo(0.25, 0.0001));
    expect(frame.outgoingSourceTime.inMilliseconds, 21000);
    expect(frame.incomingSourceTime.inMilliseconds, 31000);
    expect(frame.hasFullSourceCoverage, isTrue);
  });

  test('cross dissolve planner rejects frozen-frame coverage gaps', () {
    const planner = ProfessionalCrossDissolveCompositorPlanner();
    final plan = ProfessionalVideoTransitionRenderPlan(
      definitionId:
          ProfessionalVideoTransitionCompositorKind.crossDissolve.name,
      transitionId: 'dissolve-coverage-gap',
      canvasWidth: 1080,
      canvasHeight: 1920,
      boundaryTime: TimelineTime.fromMilliseconds(10000),
      leadingDuration: TimelineTime.fromMilliseconds(2000),
      trailingDuration: TimelineTime.fromMilliseconds(2000),
      sources: <ProfessionalVideoTransitionCompositorSource>[
        ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-a',
          assetId: 'asset-a',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(10000),
          ),
          sourceStartTime: TimelineTime.zero,
          sourceDuration: TimelineTime.fromMilliseconds(10000),
        ),
        ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-b',
          assetId: 'asset-b',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.fromMilliseconds(10000),
            endExclusive: TimelineTime.fromMilliseconds(18000),
          ),
          sourceStartTime: TimelineTime.fromMilliseconds(5000),
          sourceDuration: TimelineTime.fromMilliseconds(8000),
        ),
      ],
      requiredCapabilities: const <String>[
        'dualVideoSampling',
        'previewParity',
        'liveScrubParity',
        'playbackParity',
        'exportParity',
      ],
    );

    final frame = planner.planFrame(
      renderPlan: plan,
      timelineTime: TimelineTime.fromMilliseconds(9500),
    );

    expect(frame.progress, closeTo(0.375, 0.0001));
    expect(frame.incomingSourceTime.inMilliseconds, 5000);
    expect(frame.hasFullSourceCoverage, isFalse);
  });

  test('cross dissolve planner requires two source videos', () {
    const planner = ProfessionalCrossDissolveCompositorPlanner();
    final plan = ProfessionalVideoTransitionRenderPlan(
      definitionId:
          ProfessionalVideoTransitionCompositorKind.crossDissolve.name,
      transitionId: 'dissolve-invalid',
      canvasWidth: 1080,
      canvasHeight: 1920,
      boundaryTime: TimelineTime.fromMilliseconds(10000),
      leadingDuration: TimelineTime.fromMilliseconds(1000),
      trailingDuration: TimelineTime.fromMilliseconds(1000),
      sources: const <ProfessionalVideoTransitionCompositorSource>[],
      requiredCapabilities: const <String>['dualVideoSampling'],
    );

    expect(
      () => planner.planFrame(
        renderPlan: plan,
        timelineTime: TimelineTime.fromMilliseconds(10000),
      ),
      throwsArgumentError,
    );
  });

  test('zoom camera render plan lowers into the generic native contract', () {
    final plan = ProfessionalZoomCameraRenderPlan(
      canvasWidth: 1080,
      canvasHeight: 1920,
      request: ProfessionalZoomCameraPlanRequest(
        transitionId: 'zoom-native-1',
        timelineTime: TimelineTime.fromMilliseconds(10000),
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
          sourceStartTime: TimelineTime.fromMilliseconds(1500),
          sourceDuration: TimelineTime.fromMilliseconds(10000),
        ),
        incoming: ProfessionalVideoTransitionCompositorSource(
          clipId: 'clip-b',
          assetId: 'asset-b',
          timelineRange: TimelineTimeRange(
            start: TimelineTime.fromMilliseconds(10000),
            endExclusive: TimelineTime.fromMilliseconds(18000),
          ),
          sourceStartTime: TimelineTime.fromMilliseconds(750),
          sourceDuration: TimelineTime.fromMilliseconds(8000),
        ),
      ),
    );

    final payload = plan.toPlatformMap();
    expect(payload['definitionId'], 'zoomInCamera');
    expect(payload['transitionId'], 'zoom-native-1');
    expect(payload['canvasWidth'], 1080);
    expect(payload['canvasHeight'], 1920);
    expect(payload['boundaryTimeMs'], 10000);
    expect(payload['leadingDurationMs'], 2000);
    expect(payload['trailingDurationMs'], 2000);
    expect(payload['requiredCapabilities'], contains('dualVideoSampling'));
    expect(payload['requiredCapabilities'], contains('temporalMotionBlur'));
    expect(payload['requiredCapabilities'], contains('mirrorEdgeTiling'));
    expect(
      payload['parameters'],
      containsPair('outgoingBoostScale', 3.0),
    );
    expect(
      payload['edgePolicy'],
      containsPair('outputScaleX', 4.0),
    );
    expect(
      payload['motionBlurPolicy'],
      containsPair('sampleCount', 8),
    );

    final sources = payload['sources']! as List<Object?>;
    final outgoing = sources.first! as Map<String, Object?>;
    final incoming = sources.last! as Map<String, Object?>;
    expect(outgoing['clipId'], 'clip-a');
    expect(outgoing['timelineEndMs'], 10000);
    expect(outgoing['sourceStartMs'], 1500);
    expect(incoming['clipId'], 'clip-b');
    expect(incoming['timelineStartMs'], 10000);
    expect(incoming['sourceStartMs'], 750);
  });

  test('method channel prepare zoom maps unsupported native renderer',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'prepareRenderPlan');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['sources'], isA<List<Object?>>());
      expect(arguments['parameters'], isA<Map<Object?, Object?>>());
      expect(arguments['edgePolicy'], isA<Map<Object?, Object?>>());
      expect(arguments['motionBlurPolicy'], isA<Map<Object?, Object?>>());
      return <String, Object?>{
        'status': 'unsupported',
        'reason': 'missing_renderer_capabilities',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'missingCapabilities': <String>[
          'dualVideoSampling',
          'temporalMotionBlur',
        ],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).prepareZoomInCameraRenderPlan(
      ProfessionalZoomCameraRenderPlan(
        canvasWidth: 1080,
        canvasHeight: 1920,
        request: ProfessionalZoomCameraPlanRequest(
          transitionId: 'zoom-native-1',
          timelineTime: TimelineTime.fromMilliseconds(10000),
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
            sourceStartTime: TimelineTime.zero,
            sourceDuration: TimelineTime.fromMilliseconds(8000),
          ),
        ),
      ),
    );

    expect(
      result.status,
      ProfessionalVideoTransitionCompositorPrepareStatus.unsupported,
    );
    expect(result.canRender, isFalse);
    expect(result.reason, 'missing_renderer_capabilities');
    expect(result.rendererVersion, 'foundation');
    expect(result.definitionId, 'zoomInCamera');
    expect(result.missingCapabilities, <String>[
      'dualVideoSampling',
      'temporalMotionBlur',
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
