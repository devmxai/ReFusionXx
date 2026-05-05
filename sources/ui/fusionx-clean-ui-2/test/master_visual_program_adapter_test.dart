import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_frame_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_value_truth_registry.dart';
import 'package:refusion_app/features/editor/domain/services/master_visual_program_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  test('builds master visual program with renderer-unit transforms and effects',
      () {
    final registry = MasterValueTruthRegistry();
    const adapter = MasterVisualProgramAdapter();
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
        id: 'ch.trim.start',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.trimStart,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.shape.width',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.width,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.text.fontSize',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.fontSize,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.text.fontFamily',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.fontFamily,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.crop.rect',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.cropRect,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.shadow.opacity',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.shadowOpacity,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.shadow.color',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyCatalog.shadowColor,
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.visual.color',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyDefinition(
          id: 'visual.color',
          path: const MotionPropertyPath(
            group: MotionPropertyGroup.visual,
            name: 'color',
          ),
          valueKind: MotionPropertyValueKind.colorArgb,
          supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
          defaultValue: const MotionPropertyValue.colorArgb(0xFFFFFFFF),
        ),
        keyframes: const <MotionKeyframeModel>[],
      ),
      MotionPropertyChannelModel(
        id: 'ch.mask.reveal',
        target: const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
        definition: MotionPropertyDefinition(
          id: 'mask.revealProgress',
          path: const MotionPropertyPath(
            group: MotionPropertyGroup.shape,
            name: 'maskRevealProgress',
          ),
          valueKind: MotionPropertyValueKind.scalar,
          supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
          defaultValue: const MotionPropertyValue.scalar(0),
        ),
        keyframes: const <MotionKeyframeModel>[],
      ),
    ];

    final frame = MasterFrameEvaluation(
      time: time,
      visibleLayerIds: const <String>['element-2', 'element-1'],
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
          propertyDefinitionId: 'trimStart',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping('trimStart', const MotionPropertyValue.scalar(25)),
          sourceChannelId: 'ch.trim.start',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'shapeWidth',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping('shapeWidth', const MotionPropertyValue.scalar(640)),
          sourceChannelId: 'ch.shape.width',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'textFontSize',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping:
              mapping('textFontSize', const MotionPropertyValue.scalar(48)),
          sourceChannelId: 'ch.text.fontSize',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'textFontFamily',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping(
            'textFontFamily',
            const MotionPropertyValue.stringValue('Inter'),
          ),
          sourceChannelId: 'ch.text.fontFamily',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'cropRect',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping(
            'cropRect',
            const MotionPropertyValue.rect(
              MotionRect(left: 0.1, top: 0.2, width: 0.7, height: 0.6),
            ),
          ),
          sourceChannelId: 'ch.crop.rect',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'shadowOpacity',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping:
              mapping('shadowOpacity', const MotionPropertyValue.scalar(40)),
          sourceChannelId: 'ch.shadow.opacity',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'shadowColor',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping(
            'shadowColor',
            const MotionPropertyValue.colorArgb(0xFF112233),
          ),
          sourceChannelId: 'ch.shadow.color',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'visualColor',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping(
            'visualColor',
            const MotionPropertyValue.colorArgb(0xFFABCDEF),
          ),
          sourceChannelId: 'ch.visual.color',
          status: 'resolved',
        ),
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'maskRevealProgress',
          domain: const MasterTimeDomain.scene('scene-1'),
          mapping: mapping(
            'maskRevealProgress',
            const MotionPropertyValue.scalar(65),
          ),
          sourceChannelId: 'ch.mask.reveal',
          status: 'resolved',
        ),
      ],
      effectParameters: <String, MasterPropertyValueMapping>{
        'tileOutputScale':
            mapping('tileOutputScale', const MotionPropertyValue.scalar(1.2)),
        'motionBlurEnabled': mapping(
          'motionBlurEnabled',
          const MotionPropertyValue.boolean(true),
        ),
        'motionBlurAmount':
            mapping('motionBlurAmount', const MotionPropertyValue.scalar(80)),
        'motionBlurShutterAngle': mapping(
          'motionBlurShutterAngle',
          const MotionPropertyValue.scalar(270),
        ),
        'motionBlurShutterPhase': mapping(
          'motionBlurShutterPhase',
          const MotionPropertyValue.scalar(-135),
        ),
        'motionBlurSamples':
            mapping('motionBlurSamples', const MotionPropertyValue.integer(12)),
        'motionBlurAdaptiveSampleLimit': mapping(
          'motionBlurAdaptiveSampleLimit',
          const MotionPropertyValue.integer(24),
        ),
        'motionBlurMaxTrailPx': mapping(
          'motionBlurMaxTrailPx',
          const MotionPropertyValue.scalar(360),
        ),
        'motionBlurAffectRotation': mapping(
          'motionBlurAffectRotation',
          const MotionPropertyValue.boolean(false),
        ),
      },
    );

    final program = adapter.build(
      frame: frame,
      channels: channels,
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-2': MasterVisualSourceBinding(
          targetId: 'element-2',
          kind: MasterVisualSourceKind.image,
          sourceUri: '/media/image-b.png',
          scrubStoreKey: 'clip-2',
          sourceWidth: 1080,
          sourceHeight: 1080,
        ),
        'element-1': MasterVisualSourceBinding(
          targetId: 'element-1',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/video-a.mp4',
          scrubStoreKey: 'clip-1',
          sourceWidth: 1080,
          sourceHeight: 1920,
        ),
      },
      transitionRolesByTargetId: const <String, MasterVisualTransitionRole>{
        'element-1': MasterVisualTransitionRole.outgoing,
      },
    );

    expect(program.surfaces.length, 2);
    expect(program.surfaces.first.targetId, 'element-2');
    expect(program.surfaces.first.drawOrder, 0);
    final surface = program.surfaces
        .firstWhere((candidate) => candidate.targetId == 'element-1');
    expect(surface.drawOrder, 1);
    expect(surface.sourceKind, MasterVisualSourceKind.video);
    expect(surface.source?.sourceUri, '/media/video-a.mp4');
    expect(surface.opacity, closeTo(0.75, 0.0001));
    expect(surface.transform.positionX, closeTo(120.0, 0.0001));
    expect(surface.transform.positionY, closeTo(-32.0, 0.0001));
    expect(surface.transform.scaleX, closeTo(1.25, 0.0001));
    expect(surface.transform.scaleY, closeTo(0.8, 0.0001));
    expect(surface.transform.rotationRadians, closeTo(math.pi / 2.0, 0.0001));
    expect(surface.crop.rect?.left, closeTo(0.1, 0.0001));
    expect(surface.crop.rect?.top, closeTo(0.2, 0.0001));
    expect(surface.crop.rect?.width, closeTo(0.7, 0.0001));
    expect(surface.crop.rect?.height, closeTo(0.6, 0.0001));
    expect(surface.mask.revealProgress, closeTo(0.65, 0.0001));
    expect(surface.mask.hasMask, isTrue);
    expect(surface.colors.visualColorArgb, 0xFFABCDEF);
    expect(surface.colors.shadowColorArgb, 0xFF112233);
    expect(surface.colors.hasColorStyle, isTrue);
    expect(surface.textStyle.fontSize, closeTo(48.0, 0.0001));
    expect(surface.textStyle.fontFamily, 'Inter');
    expect(surface.textStyle.hasTextStyle, isTrue);
    expect(surface.shapeStyle.width, closeTo(640.0, 0.0001));
    expect(surface.shapeStyle.trimStart, closeTo(0.25, 0.0001));
    expect(surface.shapeStyle.hasShapeStyle, isTrue);
    expect(surface.transitionRole, MasterVisualTransitionRole.outgoing);
    expect(surface.motionBlur.isEnabled, isTrue);
    expect(surface.motionBlur.amount, closeTo(0.8, 0.0001));
    expect(surface.motionBlur.shutterAngleDegrees, closeTo(270, 0.0001));
    expect(surface.motionBlur.shutterPhaseDegrees, closeTo(-135, 0.0001));
    expect(surface.motionBlur.samples, 12);
    expect(surface.motionBlur.adaptiveSampleLimit, 24);
    expect(surface.motionBlur.maxTrailPx, closeTo(360, 0.0001));
    expect(surface.motionBlur.affectPosition, isTrue);
    expect(surface.motionBlur.affectScale, isTrue);
    expect(surface.motionBlur.affectRotation, isFalse);
    expect(
        surface.effects.any((effect) => effect.id == 'gaussianBlur'), isTrue);
    expect(
      surface.effects.any((effect) => effect.id == 'motionBlurAmount'),
      isFalse,
    );
    expect(
        surface.effects.any((effect) => effect.id == 'shadowOpacity'), isTrue);
    expect(surface.effects.any((effect) => effect.id == 'tileOutputScale'),
        isTrue);
    expect(program.transitionState.hasTransitionWindow, isTrue);
    expect(program.transitionState.reason, 'phase1_domain_contract_only');
    expect(program.canRenderTruthfully, isTrue);
  });
}
