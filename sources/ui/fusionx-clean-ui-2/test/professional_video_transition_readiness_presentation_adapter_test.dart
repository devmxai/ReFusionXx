import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/professional_video_transition_compositor.dart';
import 'package:refusion_app/features/editor/domain/services/professional_video_transition_readiness_preflight.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/professional_video_transition_readiness_presentation_adapter.dart';

void main() {
  const adapter = ProfessionalVideoTransitionReadinessPresentationAdapter();

  test(
      'capability view keeps transition authoring blocked until all parity is ready',
      () {
    const capabilities = ProfessionalVideoTransitionCompositorCapabilities(
      dualVideoSampling: true,
      temporalMotionBlur: false,
      mirrorEdgeTiling: false,
      previewParity: true,
      liveScrubParity: false,
      playbackParity: true,
      exportParity: false,
    );

    final display = adapter.fromCapabilities(capabilities);

    expect(display.canExposeTransition, isFalse);
    expect(display.title, 'Professional compositor required');
    expect(
      display.blockingStages.map((stage) => stage.id),
      <String>[
        'temporalMotionBlur',
        'mirrorEdgeTiling',
        'liveScrubParity',
        'exportParity',
      ],
    );
    expect(
      display.missingSummary,
      'temporalMotionBlur, mirrorEdgeTiling, liveScrubParity, exportParity',
    );
  });

  test('preflight view preserves exact blocking stage order', () {
    const report = ProfessionalVideoTransitionReadinessReport(
      definitionId: 'zoomInCamera',
      transitionId: 'transition-1',
      timelineTime: TimelineTime.zero,
      stages: <ProfessionalVideoTransitionReadinessStage>[
        ProfessionalVideoTransitionReadinessStage(
          id: ProfessionalVideoTransitionReadinessStageId.capabilityGate,
          label: 'Native compositor capabilities',
          canPlan: true,
          canAdvance: true,
        ),
        ProfessionalVideoTransitionReadinessStage(
          id: ProfessionalVideoTransitionReadinessStageId.frameDecode,
          label: 'Exact frame decode requests',
          canPlan: true,
          canAdvance: false,
          blockers: <String>['decoderImplemented=false'],
        ),
        ProfessionalVideoTransitionReadinessStage(
          id: ProfessionalVideoTransitionReadinessStageId.parityOutputs,
          label: 'Preview/scrub/playback/export parity',
          canPlan: false,
          canAdvance: false,
          blockers: <String>['exportParity=false'],
        ),
      ],
    );

    final display = adapter.fromPreflightReport(report);

    expect(display.canExposeTransition, isFalse);
    expect(display.title, 'Professional compositor preflight blocked');
    expect(
      display.blockingStages.map((stage) => stage.label),
      <String>[
        'Exact frame decode requests',
        'Preview/scrub/playback/export parity',
      ],
    );
    expect(
      display.missingSummary,
      'decoderImplemented=false, exportParity=false',
    );
  });

  test('ready capabilities expose a ready display model', () {
    const capabilities = ProfessionalVideoTransitionCompositorCapabilities(
      dualVideoSampling: true,
      temporalMotionBlur: true,
      mirrorEdgeTiling: true,
      previewParity: true,
      liveScrubParity: true,
      playbackParity: true,
      exportParity: true,
    );

    final display = adapter.fromCapabilities(capabilities);

    expect(display.canExposeTransition, isTrue);
    expect(display.title, 'Professional compositor ready');
    expect(display.blockingStages, isEmpty);
    expect(display.missingSummary, 'No blockers.');
  });
}
