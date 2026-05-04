import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_frame_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_live_scrub_program_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/master_value_truth_registry.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  test('builds video-backed live scrub program with renderer-unit transforms',
      () {
    final registry = MasterValueTruthRegistry();
    const adapter = MasterLiveScrubProgramAdapter();
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(8000),
      initialTime: ms(2500),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );

    MasterPropertyValueMapping mapping(String id, MotionPropertyValue value) {
      final definition = registry.definitionById(id)!;
      return registry.mapValue(definition: definition, value: value);
    }

    final channels = <MotionPropertyChannelModel>[
      MotionPropertyChannelModel(
        id: 'ch.position.x',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.positionX,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.position.y',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.positionY,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.scale.x',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.scaleX,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.scale.y',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.scaleY,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.rotation',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.rotationDegrees,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.opacity',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.opacity,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.blur',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.blurAmount,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.motion.blur',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.blurAmount,
        keyframes: const <MotionKeyframeModel>[],
      ),
    ];

    final frame = MasterFrameEvaluation(
      time: time,
      activeTransitionIds: const <String>['transition-1'],
      evaluatedChannels: <MasterEvaluatedPropertyValue>[
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'position',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping('position', const MotionPropertyValue.scalar(120)),
          sourceChannelId: 'ch.position.x',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'position',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping('position', const MotionPropertyValue.scalar(-32)),
          sourceChannelId: 'ch.position.y',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'scale',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping('scale', const MotionPropertyValue.scalar(1.25)),
          sourceChannelId: 'ch.scale.x',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'scale',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping('scale', const MotionPropertyValue.scalar(0.8)),
          sourceChannelId: 'ch.scale.y',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'rotation',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping('rotation', const MotionPropertyValue.scalar(90)),
          sourceChannelId: 'ch.rotation',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'opacity',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping('opacity', const MotionPropertyValue.scalar(75)),
          sourceChannelId: 'ch.opacity',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'gaussianBlur',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping:
              mapping('gaussianBlur', const MotionPropertyValue.scalar(10)),
          sourceChannelId: 'ch.blur',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'motionBlurAmount',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping:
              mapping('motionBlurAmount', const MotionPropertyValue.scalar(35)),
          sourceChannelId: 'ch.motion.blur',
          status: 'resolved',
        ),
      ],
      effectParameters: <String, MasterPropertyValueMapping>{
        'tileOutputScale':
            mapping('tileOutputScale', const MotionPropertyValue.scalar(1.2)),
      },
    );

    final program = adapter.build(
      frame: frame,
      channels: channels,
      sourcesByTargetId: const <String, LiveScrubSurfaceSource>{
        'element-1': LiveScrubSurfaceSource(
          targetId: 'element-1',
          kind: LiveScrubSourceKind.video,
          sourceUri: '/media/video-a.mp4',
          scrubStoreKey: 'clip-1',
          sourceWidth: 1080,
          sourceHeight: 1920,
        ),
      },
      transitionRolesByTargetId: const <String, LiveScrubTransitionRole>{
        'element-1': LiveScrubTransitionRole.outgoing,
      },
    );

    expect(program.surfaces.length, 1);
    final surface = program.surfaces.single;
    expect(surface.sourceKind, LiveScrubSourceKind.video);
    expect(surface.source?.sourceUri, '/media/video-a.mp4');
    expect(surface.opacity, closeTo(0.75, 0.0001));
    expect(surface.transform.positionX, closeTo(120.0, 0.0001));
    expect(surface.transform.positionY, closeTo(-32.0, 0.0001));
    expect(surface.transform.scaleX, closeTo(1.25, 0.0001));
    expect(surface.transform.scaleY, closeTo(0.8, 0.0001));
    expect(surface.transform.rotationRadians, closeTo(math.pi / 2.0, 0.0001));
    expect(surface.transitionRole, LiveScrubTransitionRole.outgoing);
    expect(
        surface.effects.any((effect) => effect.id == 'gaussianBlur'), isTrue);
    expect(
      surface.effects.any((effect) => effect.id == 'motionBlurAmount'),
      isTrue,
    );
    expect(
      surface.effects.any((effect) => effect.id == 'tileOutputScale'),
      isTrue,
    );

    expect(program.transitionState.hasTransitionWindow, isTrue);
    expect(program.transitionState.hasRenderableTransitionPixels, isFalse);
    expect(program.transitionState.reason, 'phase1_domain_contract_only');
    expect(program.sourceRevision.startsWith('msr:'), isTrue);
    expect(program.renderGraphRevision.startsWith('mrg:'), isTrue);
    expect(
      program.diagnostics.any(
        (entry) => entry.startsWith('master_render_graph_revision:'),
      ),
      isFalse,
    );
    expect(
      program.diagnostics.any(
        (entry) => entry.startsWith('master_render_graph_nodes:'),
      ),
      isTrue,
    );
    expect(
      program.diagnostics.any(
        (entry) => entry.startsWith('master_source_revision:'),
      ),
      isFalse,
    );
    expect(
      program.diagnostics.any(
        (entry) => entry.startsWith('renderer_mode:liveScrub'),
      ),
      isTrue,
    );
    expect(
      program.diagnostics.any(
        (entry) => entry.startsWith('renderer_frame_match_state:'),
      ),
      isTrue,
    );
    expect(
      program.diagnostics.any(
        (entry) => entry.startsWith(
            'renderer_frame_match_reason:awaiting_liveScrub_native_ack'),
      ),
      isTrue,
    );

    expect(
      program.blockers
          .where((blocker) => blocker.contains('unsupported_effect')),
      isEmpty,
    );
    expect(program.canRenderTruthfully, isTrue);
  });
}
