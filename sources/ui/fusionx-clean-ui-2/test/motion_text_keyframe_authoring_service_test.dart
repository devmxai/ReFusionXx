import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_runtime_helpers.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_keyframe_authoring_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const service = TextMotionKeyframeAuthoringService();
  const target = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'text-1',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'layer',
    elementId: 'text-1',
  );
  const duplicateTarget = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'text-2',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'layer',
    elementId: 'text-2',
  );

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: TimelineTime.fromSecondsDouble(start),
      endExclusive: TimelineTime.fromSecondsDouble(end),
    );
  }

  test('creates anchored scalar keyframes for first mid-range edit', () {
    final channels = service.setScalarKeyframes(
      TextMotionScalarKeyframeAuthoringRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(0, 5),
        time: TimelineTime.fromSecondsDouble(2),
        scalarValues: <MotionPropertyDefinition, double>{
          MotionPropertyCatalog.positionY: -240,
        },
        baseScalarValues: const <String, double>{
          'transform.position.y': 0,
        },
      ),
    );

    expect(channels, hasLength(1));
    expect(channels.single.activeRange?.start, TimelineTime.zero);
    expect(channels.single.activeRange?.endExclusive,
        TimelineTime.fromSecondsDouble(5));
    expect(channels.single.keyframes, hasLength(2));
    expect(channels.single.keyframes[0].time, TimelineTime.zero);
    expect(channels.single.keyframes[0].value.rawValue, 0);
    expect(
        channels.single.keyframes[1].time, TimelineTime.fromSecondsDouble(2));
    expect(channels.single.keyframes[1].value.rawValue, -240);
  });

  test('updates an existing keyframe at the same time instead of duplicating',
      () {
    final initial = service.setScalarKeyframes(
      TextMotionScalarKeyframeAuthoringRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(0, 5),
        time: TimelineTime.fromSecondsDouble(2),
        scalarValues: <MotionPropertyDefinition, double>{
          MotionPropertyCatalog.scaleX: 1.5,
        },
        baseScalarValues: const <String, double>{
          'transform.scale.x': 1,
        },
      ),
    );
    final updated = service.setScalarKeyframes(
      TextMotionScalarKeyframeAuthoringRequest(
        channels: initial,
        target: target,
        activeRange: range(0, 5),
        time: TimelineTime.fromSecondsDouble(2),
        scalarValues: <MotionPropertyDefinition, double>{
          MotionPropertyCatalog.scaleX: 2,
        },
        baseScalarValues: const <String, double>{
          'transform.scale.x': 1,
        },
      ),
    );

    expect(updated.single.keyframes, hasLength(2));
    expect(updated.single.keyframes.last.value.rawValue, 2);
  });

  test('retimes channels with their owning text range', () {
    final initial = service.setScalarKeyframes(
      TextMotionScalarKeyframeAuthoringRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(1, 5),
        time: TimelineTime.fromSecondsDouble(3),
        scalarValues: <MotionPropertyDefinition, double>{
          MotionPropertyCatalog.rotationDegrees: 45,
        },
        baseScalarValues: const <String, double>{
          'transform.rotation.degrees': 0,
        },
      ),
    );

    final retimed = service.retimeChannelsForTarget(
      TextMotionChannelRetimingRequest(
        channels: initial,
        targetId: 'text-1',
        previousRange: range(1, 5),
        nextRange: range(4, 8),
      ),
    );

    expect(
        retimed.single.activeRange?.start, TimelineTime.fromSecondsDouble(4));
    expect(retimed.single.keyframes[0].time, TimelineTime.fromSecondsDouble(4));
    expect(retimed.single.keyframes[1].time, TimelineTime.fromSecondsDouble(6));
  });

  test('duplicates channels onto a new target and preserves local timing', () {
    final initial = service.setScalarKeyframes(
      TextMotionScalarKeyframeAuthoringRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(1, 4),
        time: TimelineTime.fromSecondsDouble(2),
        scalarValues: <MotionPropertyDefinition, double>{
          MotionPropertyCatalog.positionX: 120,
        },
        baseScalarValues: const <String, double>{
          'transform.position.x': 0,
        },
      ),
    );

    final duplicated = service.duplicateChannelsForTarget(
      TextMotionChannelDuplicationRequest(
        channels: initial,
        sourceTargetId: 'text-1',
        nextTarget: duplicateTarget,
        sourceRange: range(1, 4),
        nextRange: range(6, 9),
      ),
    );

    expect(duplicated, hasLength(2));
    final copied = duplicated.last;
    expect(copied.target.targetId, 'text-2');
    expect(copied.keyframes[0].time, TimelineTime.fromSecondsDouble(6));
    expect(copied.keyframes[1].time, TimelineTime.fromSecondsDouble(7));
    expect(copied.keyframes[1].value.rawValue, 120);
  });

  test('manual channels override generated text animation channels', () {
    final projectRange = range(0, 5);
    final manualChannels = service.setScalarKeyframes(
      TextMotionScalarKeyframeAuthoringRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: projectRange,
        time: TimelineTime.fromMilliseconds(200),
        scalarValues: <MotionPropertyDefinition, double>{
          MotionPropertyCatalog.opacity: 0.72,
        },
        baseScalarValues: const <String, double>{
          'visual.opacity': 1,
        },
      ),
    );
    final project = MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene',
          projectRange: projectRange,
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'layer',
              sceneId: 'scene',
              kind: MotionLayerKind.text,
              visibleRange: projectRange,
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'text-1',
                  layerId: 'layer',
                  kind: MotionElementKind.text,
                  localRange: projectRange,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final compileResult = BasicMotionCompositionCompiler().compile(
      MotionCompileRequest(
        project: project,
        propertyChannels: manualChannels,
        textAnimationBindings: <MotionTextAnimationBindingModel>[
          MotionTextAnimationBindingModel(
            id: 'binding',
            elementTarget: target,
            activeRange: projectRange,
            animationBlocks: <MotionTextAnimationBlock>[
              MotionTextAnimationBlock(
                id: 'fade',
                kind: MotionTextAnimationKind.fadeIn,
                relativeRange: range(0, 1),
              ),
            ],
          ),
        ],
      ),
    );
    expect(compileResult.composition, isNotNull);
    final composition = compileResult.composition!;
    final snapshot = const BasicMotionRuntimeEvaluator().evaluate(
      MotionEvaluationRequest(
        composition: composition,
        time: TimelineTime.fromMilliseconds(200),
      ),
    );
    final textElement = snapshot.scenes.single.layers.single.elements.single;
    final opacity = textElement.properties.singleWhere(
      (property) => property.definition.id == MotionPropertyCatalog.opacity.id,
    );

    expect(opacity.channelId, manualChannels.single.id);
    expect(opacity.value.rawValue, 0.72);
  });

  test('manual reveal blocks keep text semantics without hidden keyframes', () {
    final projectRange = range(0, 5);
    final project = MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene',
          projectRange: projectRange,
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'layer',
              sceneId: 'scene',
              kind: MotionLayerKind.text,
              visibleRange: projectRange,
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'text-1',
                  layerId: 'layer',
                  kind: MotionElementKind.text,
                  localRange: projectRange,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final compileResult = BasicMotionCompositionCompiler().compile(
      MotionCompileRequest(
        project: project,
        propertyChannels: const <MotionPropertyChannelModel>[],
        textAnimationBindings: <MotionTextAnimationBindingModel>[
          MotionTextAnimationBindingModel(
            id: 'binding',
            elementTarget: target,
            activeRange: projectRange,
            animationBlocks: <MotionTextAnimationBlock>[
              MotionTextAnimationBlock(
                id: 'type-on',
                kind: MotionTextAnimationKind.typewriter,
                relativeRange: projectRange,
                parameters: const <String, MotionPropertyValue>{
                  'manualRevealProgress': MotionPropertyValue.boolean(true),
                },
              ),
            ],
          ),
        ],
      ),
    );

    expect(compileResult.composition, isNotNull);
    final composition = compileResult.composition!;
    expect(composition.textAnimations.single.animationKinds,
        contains(MotionTextAnimationKind.typewriter));
    expect(
      composition.allPropertyChannels.where(
        (channel) =>
            channel.channel.definition.id ==
            MotionPropertyCatalog.revealProgress.id,
      ),
      isEmpty,
    );
  });
}
