import '../../domain/services/professional_video_transition_compositor.dart';
import '../../domain/services/professional_video_transition_readiness_preflight.dart';

enum ProfessionalVideoTransitionReadinessDisplayState {
  ready,
  blocked,
}

class ProfessionalVideoTransitionReadinessDisplayModel {
  const ProfessionalVideoTransitionReadinessDisplayModel({
    required this.state,
    required this.title,
    required this.summary,
    required this.stages,
  });

  final ProfessionalVideoTransitionReadinessDisplayState state;
  final String title;
  final String summary;
  final List<ProfessionalVideoTransitionReadinessStageDisplayModel> stages;

  bool get canExposeTransition =>
      state == ProfessionalVideoTransitionReadinessDisplayState.ready;

  List<ProfessionalVideoTransitionReadinessStageDisplayModel>
      get blockingStages {
    return List<
        ProfessionalVideoTransitionReadinessStageDisplayModel>.unmodifiable(
      stages.where((stage) => !stage.ready),
    );
  }

  String get missingSummary {
    final blockers = blockingStages
        .expand((stage) =>
            stage.blockers.isEmpty ? <String>[stage.label] : stage.blockers)
        .toList(growable: false);
    if (blockers.isEmpty) {
      return 'No blockers.';
    }
    return blockers.join(', ');
  }
}

class ProfessionalVideoTransitionReadinessStageDisplayModel {
  const ProfessionalVideoTransitionReadinessStageDisplayModel({
    required this.id,
    required this.label,
    required this.ready,
    required this.blockers,
  });

  final String id;
  final String label;
  final bool ready;
  final List<String> blockers;
}

class ProfessionalVideoTransitionReadinessPresentationAdapter {
  const ProfessionalVideoTransitionReadinessPresentationAdapter();

  ProfessionalVideoTransitionReadinessDisplayModel fromCapabilities(
    ProfessionalVideoTransitionCompositorCapabilities capabilities,
  ) {
    final stages = <ProfessionalVideoTransitionReadinessStageDisplayModel>[
      _capability(
        id: 'dualVideoSampling',
        label: 'Dual-video sampling',
        ready: capabilities.dualVideoSampling,
      ),
      _capability(
        id: 'temporalMotionBlur',
        label: 'Temporal motion blur',
        ready: capabilities.temporalMotionBlur,
      ),
      _capability(
        id: 'mirrorEdgeTiling',
        label: 'Mirror-edge tiling',
        ready: capabilities.mirrorEdgeTiling,
      ),
      _capability(
        id: 'previewParity',
        label: 'Preview parity',
        ready: capabilities.previewParity,
      ),
      _capability(
        id: 'liveScrubParity',
        label: 'Live Scrub parity',
        ready: capabilities.liveScrubParity,
      ),
      _capability(
        id: 'playbackParity',
        label: 'Playback parity',
        ready: capabilities.playbackParity,
      ),
      _capability(
        id: 'exportParity',
        label: 'Export parity',
        ready: capabilities.exportParity,
      ),
    ];
    return ProfessionalVideoTransitionReadinessDisplayModel(
      state: capabilities.canExposeProfessionalVideoTransitions
          ? ProfessionalVideoTransitionReadinessDisplayState.ready
          : ProfessionalVideoTransitionReadinessDisplayState.blocked,
      title: capabilities.canExposeProfessionalVideoTransitions
          ? 'Professional compositor ready'
          : 'Professional compositor required',
      summary: capabilities.canExposeProfessionalVideoTransitions
          ? 'Transition authoring can use the native dual-video compositor.'
          : 'Transition authoring is locked until every native compositor capability is ready.',
      stages: List<
          ProfessionalVideoTransitionReadinessStageDisplayModel>.unmodifiable(
        stages,
      ),
    );
  }

  ProfessionalVideoTransitionReadinessDisplayModel fromPreflightReport(
    ProfessionalVideoTransitionReadinessReport report,
  ) {
    final stages = report.stages.map((stage) {
      return ProfessionalVideoTransitionReadinessStageDisplayModel(
        id: stage.id.name,
        label: stage.label,
        ready: stage.canPlan && stage.canAdvance,
        blockers: List<String>.unmodifiable(stage.blockers),
      );
    }).toList(growable: false);
    return ProfessionalVideoTransitionReadinessDisplayModel(
      state: report.canExposeTransition
          ? ProfessionalVideoTransitionReadinessDisplayState.ready
          : ProfessionalVideoTransitionReadinessDisplayState.blocked,
      title: report.canExposeTransition
          ? 'Professional compositor ready'
          : 'Professional compositor preflight blocked',
      summary: report.canExposeTransition
          ? 'The render plan has preview, scrub, playback, and export parity.'
          : 'The render plan cannot expose a transition until every preflight stage is ready.',
      stages: List<
          ProfessionalVideoTransitionReadinessStageDisplayModel>.unmodifiable(
        stages,
      ),
    );
  }

  static ProfessionalVideoTransitionReadinessStageDisplayModel _capability({
    required String id,
    required String label,
    required bool ready,
  }) {
    return ProfessionalVideoTransitionReadinessStageDisplayModel(
      id: id,
      label: label,
      ready: ready,
      blockers: ready ? const <String>[] : <String>[id],
    );
  }
}
