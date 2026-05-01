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
          sourceUri: 'file:///tmp/clip-a.mp4',
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
          sourceUri: 'file:///tmp/clip-b.mp4',
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
    expect(outgoing['sourceUri'], 'file:///tmp/clip-a.mp4');
    expect(outgoing['timelineEndMs'], 10000);
    expect(outgoing['sourceStartMs'], 1500);
    expect(incoming['clipId'], 'clip-b');
    expect(incoming['sourceUri'], 'file:///tmp/clip-b.mp4');
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
        'renderSessionId': 'transition-session:zoom-native-1',
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'sourceRoles': <String>['outgoing', 'incoming'],
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
    expect(result.renderSessionId, 'transition-session:zoom-native-1');
    expect(result.transitionStartTime!.inMilliseconds, 8000);
    expect(result.transitionEndTime!.inMilliseconds, 12000);
    expect(result.sourceRoles, <String>['outgoing', 'incoming']);
    expect(result.missingCapabilities, <String>[
      'dualVideoSampling',
      'temporalMotionBlur',
    ]);
  });

  test('method channel frame sample planning maps native source samples',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planFrameSamples');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      expect(arguments['motionBlurPolicy'], isA<Map<Object?, Object?>>());
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'progress': 0.5,
        'sourceRoles': <String>['outgoing', 'incoming'],
        'outgoingSourceTimeMs': 30000,
        'incomingSourceTimeMs': 40000,
        'temporalSampleTimelineTimesMs': <int>[
          9983,
          9994,
          10006,
          10017,
        ],
        'outgoingTemporalSourceTimesMs': <int>[
          29983,
          29994,
          30006,
          30017,
        ],
        'incomingTemporalSourceTimesMs': <int>[
          39983,
          39994,
          40006,
          40017,
        ],
        'motionBlurMode': 'temporalShutter',
        'shutterAngleDegrees': 360.0,
        'frameRate': 30.0,
        'shutterSampleCount': 4,
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planFrameSamples(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          shutterSampleCount: 4,
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.renderSessionId, 'transition-session:zoom-native-1');
    expect(result.transitionStartTime!.inMilliseconds, 8000);
    expect(result.transitionEndTime!.inMilliseconds, 12000);
    expect(result.timelineTime!.inMilliseconds, 10000);
    expect(result.progress, 0.5);
    expect(result.sourceRoles, <String>['outgoing', 'incoming']);
    expect(result.outgoingSourceTime!.inMilliseconds, 30000);
    expect(result.incomingSourceTime!.inMilliseconds, 40000);
    expect(result.temporalSampleTimelineTimes, hasLength(4));
    expect(result.outgoingTemporalSourceTimes.first.inMilliseconds, 29983);
    expect(result.incomingTemporalSourceTimes.last.inMilliseconds, 40017);
    expect(result.motionBlurMode, 'temporalShutter');
    expect(result.shutterAngleDegrees, 360);
    expect(result.frameRate, 30);
    expect(result.shutterSampleCount, 4);
  });

  test('method channel source binding planning requires concrete source uris',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planVideoSourceBindings');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      final sources = arguments['sources']! as List<Object?>;
      final outgoing = sources.first! as Map<Object?, Object?>;
      final incoming = sources.last! as Map<Object?, Object?>;
      expect(outgoing['sourceUri'], 'file:///tmp/outgoing.mp4');
      expect(incoming['sourceUri'], 'file:///tmp/incoming.mp4');
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'requiresConcreteSourceUri': true,
        'allSourcesBound': true,
        'allowAssetIdOnlyDecode': false,
        'allowGeneratedProxyDecode': false,
        'bindings': <Map<String, Object?>>[
          <String, Object?>{
            'role': 'outgoing',
            'clipId': 'clip-a',
            'assetId': 'asset-a',
            'sourceUri': 'file:///tmp/outgoing.mp4',
            'sourceUriBound': true,
            'timelineStartMs': 8000,
            'timelineEndMs': 12000,
            'sourceStartMs': 28000,
            'sourceDurationMs': 4000,
            'requiresConcreteSourceUri': true,
            'allowAssetIdOnlyDecode': false,
            'allowGeneratedProxyDecode': false,
          },
          <String, Object?>{
            'role': 'incoming',
            'clipId': 'clip-b',
            'assetId': 'asset-b',
            'sourceUri': 'file:///tmp/incoming.mp4',
            'sourceUriBound': true,
            'timelineStartMs': 8000,
            'timelineEndMs': 12000,
            'sourceStartMs': 38000,
            'sourceDurationMs': 4000,
            'requiresConcreteSourceUri': true,
            'allowAssetIdOnlyDecode': false,
            'allowGeneratedProxyDecode': false,
          },
        ],
        'blockedReasons': <String>[],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planVideoSourceBindings(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
            sourceUri: 'file:///tmp/outgoing.mp4',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            sourceUri: 'file:///tmp/incoming.mp4',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.canBind, isTrue);
    expect(result.requiresConcreteSourceUri, isTrue);
    expect(result.allSourcesBound, isTrue);
    expect(result.allowAssetIdOnlyDecode, isFalse);
    expect(result.allowGeneratedProxyDecode, isFalse);
    expect(result.bindings.map((binding) => binding.role), <String>[
      'outgoing',
      'incoming',
    ]);
    expect(result.bindings.first.sourceUri, 'file:///tmp/outgoing.mp4');
    expect(result.bindings.last.sourceUri, 'file:///tmp/incoming.mp4');
    expect(result.bindings.every((binding) => binding.sourceUriBound), isTrue);
    expect(result.blockedReasons, isEmpty);
  });

  test('method channel source probe blocks decoder readiness until real probe',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planVideoSourceProbe');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'requiresRealVideoSource': true,
        'probeImplemented': false,
        'allSourcesProbeable': false,
        'allowSyntheticSource': false,
        'probes': <Map<String, Object?>>[
          <String, Object?>{
            'role': 'outgoing',
            'clipId': 'clip-a',
            'assetId': 'asset-a',
            'sourceUri': 'file:///tmp/outgoing.mp4',
            'uriScheme': 'file',
            'sourceUriBound': true,
            'requiresRealVideoSource': true,
            'probeImplemented': false,
            'canOpenSource': false,
            'hasVideoTrack': false,
            'videoMimeType': '',
            'videoWidth': 0,
            'videoHeight': 0,
            'videoDurationUs': 0,
            'videoFrameRate': 0,
            'allowSyntheticSource': false,
            'blockedReasons': <String>['native_video_source_probe_missing'],
          },
          <String, Object?>{
            'role': 'incoming',
            'clipId': 'clip-b',
            'assetId': 'asset-b',
            'sourceUri': 'content://media/incoming.mp4',
            'uriScheme': 'content',
            'sourceUriBound': true,
            'requiresRealVideoSource': true,
            'probeImplemented': false,
            'canOpenSource': false,
            'hasVideoTrack': false,
            'videoMimeType': '',
            'videoWidth': 0,
            'videoHeight': 0,
            'videoDurationUs': 0,
            'videoFrameRate': 0,
            'allowSyntheticSource': false,
            'blockedReasons': <String>['native_video_source_probe_missing'],
          },
        ],
        'blockedReasons': <String>['native_video_source_probe_missing'],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planVideoSourceProbe(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
            sourceUri: 'file:///tmp/outgoing.mp4',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            sourceUri: 'content://media/incoming.mp4',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.canProbe, isFalse);
    expect(result.requiresRealVideoSource, isTrue);
    expect(result.probeImplemented, isFalse);
    expect(result.allowSyntheticSource, isFalse);
    expect(result.probes.map((probe) => probe.uriScheme), <String>[
      'file',
      'content',
    ]);
    expect(result.blockedReasons, <String>[
      'native_video_source_probe_missing',
    ]);
  });

  test('frame sample planning mapper preserves invalid native issues', () {
    final result =
        ProfessionalVideoTransitionFrameSamplePlanResultMapper.fromMap(
      <String, Object?>{
        'status': 'invalidRequest',
        'reason': 'timeline_time_outside_transition_render_session',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'issues': <Map<String, Object?>>[
          <String, Object?>{
            'path': 'timelineTimeMs',
            'message': 'Frame time must be inside the transition window.',
          },
        ],
      },
    );

    expect(result.canPlan, isFalse);
    expect(
      result.status,
      ProfessionalVideoTransitionFrameSamplePlanStatus.invalidRequest,
    );
    expect(result.reason, 'timeline_time_outside_transition_render_session');
    expect(result.issues.single['path'], 'timelineTimeMs');
  });

  test('method channel frame decode planning forbids thumbnail fallbacks',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planFrameDecodeRequests');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'progress': 0.5,
        'decodeMode': 'exactVideoFrame',
        'allowThumbnailFallback': false,
        'allowBoundaryFreeze': false,
        'requiresRealVideoFrame': true,
        'decodeRequests': <Map<String, Object?>>[
          <String, Object?>{
            'decodeRequestId':
                'transition-session:zoom-native-1:outgoing:0:29983',
            'role': 'outgoing',
            'clipId': 'clip-a',
            'assetId': 'asset-a',
            'sourceUri': 'file:///tmp/outgoing.mp4',
            'sampleIndex': 0,
            'timelineTimeMs': 9983,
            'sourceTimeMs': 29983,
            'decodeMode': 'exactVideoFrame',
            'temporalSample': true,
            'centerSample': false,
            'allowThumbnailFallback': false,
            'allowBoundaryFreeze': false,
          },
          <String, Object?>{
            'decodeRequestId':
                'transition-session:zoom-native-1:incoming:1:40017',
            'role': 'incoming',
            'clipId': 'clip-b',
            'assetId': 'asset-b',
            'sourceUri': 'file:///tmp/incoming.mp4',
            'sampleIndex': 1,
            'timelineTimeMs': 10017,
            'sourceTimeMs': 40017,
            'decodeMode': 'exactVideoFrame',
            'temporalSample': true,
            'centerSample': true,
            'allowThumbnailFallback': false,
            'allowBoundaryFreeze': false,
          },
        ],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planFrameDecodeRequests(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
            sourceUri: 'file:///tmp/outgoing.mp4',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            sourceUri: 'file:///tmp/incoming.mp4',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.decodeMode, 'exactVideoFrame');
    expect(result.allowThumbnailFallback, isFalse);
    expect(result.allowBoundaryFreeze, isFalse);
    expect(result.requiresRealVideoFrame, isTrue);
    expect(result.decodeRequests, hasLength(2));
    expect(result.decodeRequests.first.role, 'outgoing');
    expect(result.decodeRequests.first.assetId, 'asset-a');
    expect(result.decodeRequests.first.sourceUri, 'file:///tmp/outgoing.mp4');
    expect(result.decodeRequests.first.sourceTime.inMilliseconds, 29983);
    expect(result.decodeRequests.first.allowThumbnailFallback, isFalse);
    expect(result.decodeRequests.last.role, 'incoming');
    expect(result.decodeRequests.last.sourceUri, 'file:///tmp/incoming.mp4');
    expect(result.decodeRequests.last.centerSample, isTrue);
    expect(result.decodeRequests.last.sourceTime.inMilliseconds, 40017);
  });

  test('method channel decoder session stays blocked until dual decoder',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planDualVideoDecoderSession');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'decoderSessionId': 'transition-session:zoom-native-1:decoder:10000',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'requiresDualVideoDecoder': true,
        'requiresExactFrameDecode': true,
        'allowThumbnailFallback': false,
        'allowBoundaryFreeze': false,
        'decoderImplemented': false,
        'tracks': <Map<String, Object?>>[
          <String, Object?>{
            'role': 'outgoing',
            'clipId': 'clip-a',
            'assetId': 'asset-a',
            'sourceUri': 'file:///tmp/outgoing.mp4',
            'decodeRequestIds': <String>[
              'transition-session:zoom-native-1:outgoing:0:29983',
              'transition-session:zoom-native-1:outgoing:1:30017',
            ],
            'sampleCount': 2,
            'requiresExactFrameDecode': true,
            'allowThumbnailFallback': false,
            'allowBoundaryFreeze': false,
            'sourceProbeReady': true,
            'videoMimeType': 'video/avc',
            'videoWidth': 1080,
            'videoHeight': 1920,
            'videoDurationUs': 60000000,
            'videoFrameRate': 30,
            'centerSampleSourceTimeMs': 30017,
            'exactFrameDecodeProbeImplemented': true,
            'sampleDecodeProbeImplemented': true,
            'requestedSampleCount': 2,
            'decodedSampleCount': 2,
            'allSamplesDecodable': true,
            'canDecodeCenterFrame': true,
            'decodedCenterFrameTimeMs': 30017,
            'decodedOutputMimeType': 'video/avc',
            'decodedOutputWidth': 1080,
            'decodedOutputHeight': 1920,
          },
          <String, Object?>{
            'role': 'incoming',
            'clipId': 'clip-b',
            'assetId': 'asset-b',
            'sourceUri': 'file:///tmp/incoming.mp4',
            'decodeRequestIds': <String>[
              'transition-session:zoom-native-1:incoming:0:39983',
              'transition-session:zoom-native-1:incoming:1:40017',
            ],
            'sampleCount': 2,
            'requiresExactFrameDecode': true,
            'allowThumbnailFallback': false,
            'allowBoundaryFreeze': false,
            'sourceProbeReady': true,
            'videoMimeType': 'video/hevc',
            'videoWidth': 1080,
            'videoHeight': 1920,
            'videoDurationUs': 60000000,
            'videoFrameRate': 30,
            'centerSampleSourceTimeMs': 40017,
            'exactFrameDecodeProbeImplemented': true,
            'sampleDecodeProbeImplemented': true,
            'requestedSampleCount': 2,
            'decodedSampleCount': 1,
            'allSamplesDecodable': false,
            'canDecodeCenterFrame': false,
            'decodedCenterFrameTimeMs': 0,
            'decodeProbeReason': 'native_exact_frame_decode_timeout',
          },
        ],
        'blockedReasons': <String>['native_dual_video_decoder_missing'],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planDualVideoDecoderSession(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
            sourceUri: 'file:///tmp/outgoing.mp4',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            sourceUri: 'file:///tmp/incoming.mp4',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.canDecode, isFalse);
    expect(result.requiresDualVideoDecoder, isTrue);
    expect(result.requiresExactFrameDecode, isTrue);
    expect(result.allowThumbnailFallback, isFalse);
    expect(result.allowBoundaryFreeze, isFalse);
    expect(result.decoderImplemented, isFalse);
    expect(result.tracks.map((track) => track.role), <String>[
      'outgoing',
      'incoming',
    ]);
    expect(result.tracks.first.sampleCount, 2);
    expect(result.tracks.first.sourceUri, 'file:///tmp/outgoing.mp4');
    expect(result.tracks.first.sourceProbeReady, isTrue);
    expect(result.tracks.first.videoMimeType, 'video/avc');
    expect(result.tracks.first.decodedSampleCount, 2);
    expect(result.tracks.first.allSamplesDecodable, isTrue);
    expect(result.tracks.first.canDecodeCenterFrame, isTrue);
    expect(result.tracks.first.decodedCenterFrameTimeMs, 30017);
    expect(result.tracks.last.assetId, 'asset-b');
    expect(result.tracks.last.sourceUri, 'file:///tmp/incoming.mp4');
    expect(result.tracks.last.videoMimeType, 'video/hevc');
    expect(result.tracks.last.decodedSampleCount, 1);
    expect(result.tracks.last.allSamplesDecodable, isFalse);
    expect(result.tracks.last.canDecodeCenterFrame, isFalse);
    expect(
      result.tracks.last.decodeProbeReason,
      'native_exact_frame_decode_timeout',
    );
    expect(
      result.blockedReasons,
      contains('native_dual_video_decoder_missing'),
    );
  });

  test('method channel temporal accumulator forbids fake motion blur',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planTemporalSampleAccumulator');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'decoderSessionId': 'transition-session:zoom-native-1:decoder:10000',
        'temporalAccumulatorSessionId':
            'transition-session:zoom-native-1:accumulator-session:10000',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'motionBlurMode': 'temporalShutter',
        'shutterSampleCount': 2,
        'requiresTemporalAccumulation': true,
        'requiresExactFrameDecode': true,
        'allowGaussianFallback': false,
        'allowDecorativeSpeedLines': false,
        'accumulatorImplemented': false,
        'accumulators': <Map<String, Object?>>[
          <String, Object?>{
            'accumulatorId':
                'transition-session:zoom-native-1:accumulator:outgoing:10000',
            'role': 'outgoing',
            'inputTrackRole': 'outgoing',
            'sampleCount': 2,
            'decodedSampleCount': 2,
            'inputSamplesDecodable': true,
            'sampleWeights': <double>[0.5, 0.5],
            'normalization': 'weightedAverage',
            'requiresTemporalShutter': true,
            'requiresExactFrameDecode': true,
            'allowGaussianFallback': false,
            'allowDecorativeSpeedLines': false,
          },
          <String, Object?>{
            'accumulatorId':
                'transition-session:zoom-native-1:accumulator:incoming:10000',
            'role': 'incoming',
            'inputTrackRole': 'incoming',
            'sampleCount': 2,
            'decodedSampleCount': 1,
            'inputSamplesDecodable': false,
            'sampleWeights': <double>[0.5, 0.5],
            'normalization': 'weightedAverage',
            'requiresTemporalShutter': true,
            'requiresExactFrameDecode': true,
            'allowGaussianFallback': false,
            'allowDecorativeSpeedLines': false,
          },
        ],
        'blockedReasons': <String>[
          'native_temporal_sample_decode_not_ready',
          'native_temporal_sample_accumulator_missing',
        ],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planTemporalSampleAccumulator(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.canAccumulate, isFalse);
    expect(result.motionBlurMode, 'temporalShutter');
    expect(result.requiresTemporalAccumulation, isTrue);
    expect(result.requiresExactFrameDecode, isTrue);
    expect(result.allowGaussianFallback, isFalse);
    expect(result.allowDecorativeSpeedLines, isFalse);
    expect(result.accumulatorImplemented, isFalse);
    expect(result.accumulators.map((accumulator) => accumulator.role),
        <String>['outgoing', 'incoming']);
    expect(result.accumulators.first.sampleWeights, <double>[0.5, 0.5]);
    expect(result.accumulators.first.decodedSampleCount, 2);
    expect(result.accumulators.first.inputSamplesDecodable, isTrue);
    expect(result.accumulators.first.requiresExactFrameDecode, isTrue);
    expect(result.accumulators.first.allowGaussianFallback, isFalse);
    expect(result.accumulators.last.decodedSampleCount, 1);
    expect(result.accumulators.last.inputSamplesDecodable, isFalse);
    expect(result.accumulators.last.allowDecorativeSpeedLines, isFalse);
    expect(
      result.blockedReasons,
      contains('native_temporal_sample_decode_not_ready'),
    );
    expect(
      result.blockedReasons,
      contains('native_temporal_sample_accumulator_missing'),
    );
  });

  test('method channel mirror edge tiling blocks black-border fallbacks',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planMirrorEdgeTiling');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'temporalAccumulatorSessionId':
            'transition-session:zoom-native-1:accumulator-session:10000',
        'mirrorEdgeTilingSessionId':
            'transition-session:zoom-native-1:mirror-edge:10000',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'edgeMode': 'mirrorTile',
        'outputScaleX': 4.0,
        'outputScaleY': 3.5,
        'requiresMirrorEdgeTiling': true,
        'requiresTemporalAccumulator': true,
        'allowBlackBorders': false,
        'allowFlutterOverlay': false,
        'allowTimelineOverlay': false,
        'tilerImplemented': false,
        'tiles': <Map<String, Object?>>[
          <String, Object?>{
            'tileId':
                'transition-session:zoom-native-1:mirror-tile:outgoing:10000',
            'role': 'outgoing',
            'inputAccumulatorId':
                'transition-session:zoom-native-1:accumulator:outgoing:10000',
            'sampleCount': 2,
            'decodedSampleCount': 2,
            'inputSamplesDecodable': true,
            'edgeMode': 'mirrorTile',
            'outputScaleX': 4.0,
            'outputScaleY': 3.5,
            'mirrorEdges': true,
            'clipToCanvas': true,
            'allowBlackBorders': false,
          },
          <String, Object?>{
            'tileId':
                'transition-session:zoom-native-1:mirror-tile:incoming:10000',
            'role': 'incoming',
            'inputAccumulatorId':
                'transition-session:zoom-native-1:accumulator:incoming:10000',
            'sampleCount': 2,
            'decodedSampleCount': 1,
            'inputSamplesDecodable': false,
            'edgeMode': 'mirrorTile',
            'outputScaleX': 4.0,
            'outputScaleY': 3.5,
            'mirrorEdges': true,
            'clipToCanvas': true,
            'allowBlackBorders': false,
          },
        ],
        'blockedReasons': <String>[
          'native_mirror_edge_input_samples_not_ready',
          'native_mirror_edge_tiler_missing',
        ],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planMirrorEdgeTiling(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.canTile, isFalse);
    expect(result.edgeMode, 'mirrorTile');
    expect(result.outputScaleX, 4.0);
    expect(result.outputScaleY, 3.5);
    expect(result.requiresMirrorEdgeTiling, isTrue);
    expect(result.requiresTemporalAccumulator, isTrue);
    expect(result.allowBlackBorders, isFalse);
    expect(result.allowFlutterOverlay, isFalse);
    expect(result.allowTimelineOverlay, isFalse);
    expect(result.tilerImplemented, isFalse);
    expect(result.tiles.map((tile) => tile.role), <String>[
      'outgoing',
      'incoming',
    ]);
    expect(result.tiles.first.mirrorEdges, isTrue);
    expect(result.tiles.first.decodedSampleCount, 2);
    expect(result.tiles.first.inputSamplesDecodable, isTrue);
    expect(result.tiles.last.decodedSampleCount, 1);
    expect(result.tiles.last.inputSamplesDecodable, isFalse);
    expect(result.tiles.first.clipToCanvas, isTrue);
    expect(result.tiles.first.allowBlackBorders, isFalse);
    expect(
      result.blockedReasons,
      contains('native_mirror_edge_input_samples_not_ready'),
    );
    expect(
      result.blockedReasons,
      contains('native_mirror_edge_tiler_missing'),
    );
  });

  test('method channel render pass graph stays planning-only until renderer',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planRenderPassGraph');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'renderPassGraphId': 'transition-session:zoom-native-1:graph:10000',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'progress': 0.5,
        'requiresExactVideoDecode': true,
        'requiresTemporalAccumulation': true,
        'requiresMirrorEdgeTiling': true,
        'requiresGpuComposition': true,
        'rendererImplemented': false,
        'passes': <Map<String, Object?>>[
          <String, Object?>{
            'passId': 'decode-pass',
            'type': 'decodeExactVideoFrames',
            'role': 'both',
            'inputs': <String>[
              'transition-session:zoom-native-1:outgoing:0:29983',
              'transition-session:zoom-native-1:incoming:0:39983',
            ],
            'parameters': <String, Object?>{
              'decodeMode': 'exactVideoFrame',
              'allowThumbnailFallback': false,
              'allowBoundaryFreeze': false,
            },
          },
          <String, Object?>{
            'passId': 'transition-pass',
            'type': 'transitionShaderEvaluation',
            'role': 'both',
            'inputs': <String>['decode-pass'],
            'parameters': <String, Object?>{
              'definitionId': 'zoomInCamera',
              'progress': 0.5,
            },
          },
        ],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planRenderPassGraph(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.canRender, isFalse);
    expect(result.renderPassGraphId,
        'transition-session:zoom-native-1:graph:10000');
    expect(result.requiresExactVideoDecode, isTrue);
    expect(result.requiresTemporalAccumulation, isTrue);
    expect(result.requiresMirrorEdgeTiling, isTrue);
    expect(result.requiresGpuComposition, isTrue);
    expect(result.rendererImplemented, isFalse);
    expect(result.passes, hasLength(2));
    expect(result.passes.first.type, 'decodeExactVideoFrames');
    expect(result.passes.first.inputs, hasLength(2));
    expect(result.passes.first.parameters['allowThumbnailFallback'], isFalse);
    expect(result.passes.last.type, 'transitionShaderEvaluation');
  });

  test('method channel output surface forbids overlay fallbacks until renderer',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planOutputSurface');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'renderPassGraphId': 'transition-session:zoom-native-1:graph:10000',
        'outputSurfaceId':
            'transition-session:zoom-native-1:surface:transition-output:10000',
        'outputTarget': 'nativeTransitionCanvasSurface',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'canvasWidth': 1080,
        'canvasHeight': 1920,
        'clipToCanvas': true,
        'requiresNativeTexture': true,
        'allowFlutterOverlay': false,
        'allowTimelineOverlay': false,
        'allowPlatformViewTransform': false,
        'rendererImplemented': false,
        'blockedReasons': <String>[
          'native_transition_output_surface_renderer_missing',
        ],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planOutputSurface(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.canRender, isFalse);
    expect(result.outputTarget, 'nativeTransitionCanvasSurface');
    expect(result.clipToCanvas, isTrue);
    expect(result.requiresNativeTexture, isTrue);
    expect(result.allowFlutterOverlay, isFalse);
    expect(result.allowTimelineOverlay, isFalse);
    expect(result.allowPlatformViewTransform, isFalse);
    expect(result.rendererImplemented, isFalse);
    expect(result.blockedReasons,
        contains('native_transition_output_surface_renderer_missing'));
  });

  test('method channel parity outputs lock every playback mode until renderer',
      () async {
    const channel = MethodChannel(
        'com.refusion.app/professional_video_transition_compositor');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'planParityOutputs');
      final arguments = call.arguments! as Map<Object?, Object?>;
      expect(arguments['definitionId'], 'zoomInCamera');
      expect(arguments['timelineTimeMs'], 10000);
      return <String, Object?>{
        'status': 'planned',
        'reason': '',
        'rendererVersion': 'foundation',
        'definitionId': 'zoomInCamera',
        'renderSessionId': 'transition-session:zoom-native-1',
        'renderPassGraphId': 'transition-session:zoom-native-1:graph:10000',
        'outputSurfaceId':
            'transition-session:zoom-native-1:surface:transition-output:10000',
        'timelineTimeMs': 10000,
        'transitionStartMs': 8000,
        'transitionEndMs': 12000,
        'rendererImplemented': false,
        'sameOutputContractForAllModes': true,
        'allModesRenderable': false,
        'outputs': <Map<String, Object?>>[
          <String, Object?>{
            'mode': 'preview',
            'outputSurfaceId':
                'transition-session:zoom-native-1:surface:transition-output:10000',
            'outputTarget': 'nativeTransitionCanvasSurface',
            'rendererImplemented': false,
            'canRender': false,
            'blockedReasons': <String>[
              'native_transition_preview_renderer_missing',
            ],
          },
          <String, Object?>{
            'mode': 'liveScrub',
            'outputSurfaceId':
                'transition-session:zoom-native-1:surface:transition-output:10000',
            'outputTarget': 'nativeTransitionCanvasSurface',
            'rendererImplemented': false,
            'canRender': false,
            'blockedReasons': <String>[
              'native_transition_liveScrub_renderer_missing',
            ],
          },
          <String, Object?>{
            'mode': 'playback',
            'outputSurfaceId':
                'transition-session:zoom-native-1:surface:transition-output:10000',
            'outputTarget': 'nativeTransitionCanvasSurface',
            'rendererImplemented': false,
            'canRender': false,
            'blockedReasons': <String>[
              'native_transition_playback_renderer_missing',
            ],
          },
          <String, Object?>{
            'mode': 'export',
            'outputSurfaceId':
                'transition-session:zoom-native-1:surface:transition-output:10000',
            'outputTarget': 'nativeTransitionCanvasSurface',
            'rendererImplemented': false,
            'canRender': false,
            'blockedReasons': <String>[
              'native_transition_export_renderer_missing',
            ],
          },
        ],
        'blockedReasons': <String>[
          'native_transition_preview_renderer_missing',
          'native_transition_liveScrub_renderer_missing',
          'native_transition_playback_renderer_missing',
          'native_transition_export_renderer_missing',
        ],
      };
    });

    final result =
        await const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(
      channel: channel,
    ).planParityOutputs(
      timelineTime: TimelineTime.fromMilliseconds(10000),
      plan: ProfessionalZoomCameraRenderPlan(
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
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(28000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
          incoming: ProfessionalVideoTransitionCompositorSource(
            clipId: 'clip-b',
            assetId: 'asset-b',
            timelineRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(8000),
              endExclusive: TimelineTime.fromMilliseconds(12000),
            ),
            sourceStartTime: TimelineTime.fromMilliseconds(38000),
            sourceDuration: TimelineTime.fromMilliseconds(4000),
          ),
        ),
      ).toGenericRenderPlan(),
    );

    expect(result.canPlan, isTrue);
    expect(result.canRender, isFalse);
    expect(result.sameOutputContractForAllModes, isTrue);
    expect(result.allModesRenderable, isFalse);
    expect(result.outputs.map((output) => output.mode), <String>[
      'preview',
      'liveScrub',
      'playback',
      'export',
    ]);
    expect(result.outputs.every((output) => !output.canRender), isTrue);
    expect(result.blockedReasons,
        contains('native_transition_playback_renderer_missing'));
    expect(
      result.outputs.map((output) => output.outputSurfaceId).toSet(),
      hasLength(1),
    );
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
