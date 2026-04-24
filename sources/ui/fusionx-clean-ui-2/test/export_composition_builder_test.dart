import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/export_authored_visual_surface_models.dart';
import 'package:refusion_app/features/editor/domain/models/export_composition_builder.dart';
import 'package:refusion_app/features/editor/domain/models/export_composition_models.dart';
import 'package:refusion_app/features/editor/domain/models/export_motion_text_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_fx_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_raster_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_render_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const builder = ExportCompositionBuilder();

  ExportProjectFormatDescriptor format({double durationSeconds = 5}) {
    return ExportProjectFormatDescriptor(
      canvasWidth: 1080,
      canvasHeight: 1920,
      pixelAspectRatio: 1.0,
      frameRateNumerator: 30,
      frameRateDenominator: 1,
      durationTime: TimelineTime.fromSecondsDouble(durationSeconds),
    );
  }

  test('builds sequential timeline ranges for clip seeds', () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-1',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-a',
            kind: ExportAssetKind.video,
            label: 'A',
            sourceUri: '/tmp/a.mp4',
          ),
          ExportAssetDescriptor(
            assetId: 'asset-b',
            kind: ExportAssetKind.video,
            label: 'B',
            sourceUri: '/tmp/b.mp4',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.video,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-a',
                assetId: 'asset-a',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(2),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(2),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
              ExportClipSeed(
                clipId: 'clip-b',
                assetId: 'asset-b',
                timelineStartTime: TimelineTime.fromSecondsDouble(2),
                timelineDurationTime: TimelineTime.fromSecondsDouble(3),
                sourceStartTime: TimelineTime.fromSecondsDouble(1),
                sourceDurationTime: TimelineTime.fromSecondsDouble(3),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
      ),
    );

    final clips = composition.tracks.single.clips;
    expect(clips, hasLength(2));
    expect(clips.first.timelineRange.start, TimelineTime.zero);
    expect(
      clips.first.timelineRange.endExclusive,
      TimelineTime.fromSecondsDouble(2),
    );
    expect(
      clips.last.timelineRange.start,
      TimelineTime.fromSecondsDouble(2),
    );
    expect(
      clips.last.timelineRange.endExclusive,
      TimelineTime.fromSecondsDouble(5),
    );
    expect(composition.hasErrors, isFalse);
    expect(composition.isFirstBaselineEligible, isTrue);
    expect(composition.graphSchemaVersion, kExportGraphSchemaVersion);
  });

  test(
      'marks first export baseline blockers for audio-only timelines and curve speed',
      () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-2',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-audio',
            kind: ExportAssetKind.audio,
            label: 'Audio',
            sourceUri: '/tmp/audio.m4a',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.audio,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-audio',
                assetId: 'asset-audio',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 0.8,
                speedMode: ExportClipSpeedMode.curve,
              ),
            ],
          ),
        ],
      ),
    );

    expect(composition.isFirstBaselineEligible, isFalse);
    expect(composition.expectedHasAudio, isTrue);
    expect(
      composition.firstBaselineBlockingReasons,
      contains('export composition contains no visual baseline track'),
    );
    expect(
      composition.firstBaselineBlockingReasons,
      contains('curve speed is not in the first export baseline'),
    );
    expect(
      composition.currentParityLimitations,
      contains('curve speed export parity is not implemented'),
    );
  });

  test('accepts a single audio track alongside a single visual baseline track',
      () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-audio-baseline',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-video',
            kind: ExportAssetKind.video,
            label: 'Video',
            sourceUri: '/tmp/video.mp4',
          ),
          ExportAssetDescriptor(
            assetId: 'asset-audio',
            kind: ExportAssetKind.audio,
            label: 'Audio',
            sourceUri: '/tmp/audio.m4a',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.video,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-video',
                assetId: 'asset-video',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(5),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(5),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
          ExportTrackSeed(
            kind: ExportTrackKind.audio,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-audio',
                assetId: 'asset-audio',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(5),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(5),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
      ),
    );

    expect(composition.isFirstBaselineEligible, isTrue);
    expect(composition.expectedHasAudio, isTrue);
    expect(composition.currentParityLimitations, isEmpty);
  });

  test(
      'serializes a structured motion render contract into the export bridge payload',
      () {
    TimelineTimeRange range(double startSeconds, double endSeconds) {
      return TimelineTimeRange(
        start: TimelineTime.fromSecondsDouble(startSeconds),
        endExclusive: TimelineTime.fromSecondsDouble(endSeconds),
      );
    }

    const projectTarget = MotionPropertyTarget(
      kind: MotionTargetKind.project,
      targetId: 'project-motion',
      projectId: 'project-motion',
    );
    const elementTarget = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'element-1',
      sceneId: 'scene-1',
      layerId: 'layer-1',
      elementId: 'element-1',
    );
    final projectOpacity = MotionPropertyDefinition(
      id: 'project-opacity',
      path: const MotionPropertyPath(
        group: MotionPropertyGroup.visual,
        name: 'opacity',
      ),
      valueKind: MotionPropertyValueKind.scalar,
      supportedTargets: const <MotionTargetKind>[MotionTargetKind.project],
      defaultValue: const MotionPropertyValue.scalar(1.0),
    );
    final elementOpacity = MotionPropertyDefinition(
      id: 'element-opacity',
      path: const MotionPropertyPath(
        group: MotionPropertyGroup.visual,
        name: 'opacity',
      ),
      valueKind: MotionPropertyValueKind.scalar,
      supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
      defaultValue: const MotionPropertyValue.scalar(1.0),
    );
    final elementScale = MotionPropertyDefinition(
      id: 'element-scale',
      path: const MotionPropertyPath(
        group: MotionPropertyGroup.transform,
        name: 'scale',
      ),
      valueKind: MotionPropertyValueKind.scalar,
      supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
      defaultValue: const MotionPropertyValue.scalar(1.0),
    );

    final globalChannel = MotionResolvedPropertyChannel(
      channel: MotionPropertyChannelModel(
        id: 'global-opacity-channel',
        target: projectTarget,
        definition: projectOpacity,
        baseValue: const MotionPropertyValue.scalar(0.96),
        keyframes: const <MotionKeyframeModel>[
          MotionKeyframeModel(
            id: 'global-kf-1',
            channelId: 'global-opacity-channel',
            time: TimelineTime.zero,
            value: MotionPropertyValue.scalar(0.96),
            interpolationToNext: MotionInterpolationSpec.easeInOut(),
          ),
        ],
      ),
      projectRange: range(0, 2),
      targetAddress: projectTarget.canonicalAddress,
    );

    final elementChannel = MotionResolvedPropertyChannel(
      channel: MotionPropertyChannelModel(
        id: 'element-scale-channel',
        target: elementTarget,
        definition: elementScale,
        activeRange: range(0, 2),
        baseValue: const MotionPropertyValue.scalar(1.0),
        keyframes: <MotionKeyframeModel>[
          const MotionKeyframeModel(
            id: 'element-kf-1',
            channelId: 'element-scale-channel',
            time: TimelineTime.zero,
            value: MotionPropertyValue.scalar(0.82),
            interpolationToNext: MotionInterpolationSpec.easeOut(),
          ),
          MotionKeyframeModel(
            id: 'element-kf-2',
            channelId: 'element-scale-channel',
            time: TimelineTime.fromSecondsDouble(1.2),
            value: const MotionPropertyValue.scalar(1.0),
            interpolationToNext: const MotionInterpolationSpec.linear(),
          ),
        ],
      ),
      projectRange: range(0, 2),
      targetAddress: elementTarget.canonicalAddress,
    );

    final element = MotionResolvedElementModel(
      id: 'element-1',
      sourceElementId: 'source-element-1',
      sceneId: 'scene-1',
      layerId: 'layer-1',
      kind: MotionElementKind.text,
      projectRange: range(0, 2),
      localRange: range(0, 2),
      name: 'Hero text',
      sourceBinding: MotionElementSourceBinding(
        kind: MotionSourceKind.generatedText,
        sourceId: 'text-source-1',
        assetId: 'asset-text-1',
        label: 'Heading',
        sourceRange: range(0, 2),
        metadata: const <String, String>{'style': 'cinematic'},
      ),
      staticProperties: <MotionPropertyAssignment>[
        MotionPropertyAssignment(
          target: elementTarget,
          definition: elementOpacity,
          value: const MotionPropertyValue.scalar(1.0),
        ),
      ],
      propertyChannels: <MotionResolvedPropertyChannel>[elementChannel],
    );

    final scene = MotionResolvedSceneModel(
      id: 'scene-1',
      sourceSceneId: 'source-scene-1',
      projectRange: range(0, 2),
      name: 'Scene 1',
      layers: <MotionResolvedLayerModel>[
        MotionResolvedLayerModel(
          id: 'layer-1',
          sourceLayerId: 'source-layer-1',
          sceneId: 'scene-1',
          kind: MotionLayerKind.text,
          projectRange: range(0, 2),
          name: 'Text Layer',
          zIndex: 3,
          elements: <MotionResolvedElementModel>[element],
          staticProperties: const <MotionPropertyAssignment>[],
          propertyChannels: const <MotionResolvedPropertyChannel>[],
        ),
      ],
      staticProperties: const <MotionPropertyAssignment>[],
      propertyChannels: const <MotionResolvedPropertyChannel>[],
      metadata: const <String, String>{'sceneRole': 'intro'},
    );

    final composition = ExportComposition(
      contractVersion: 'v1alpha1',
      projectId: 'project-motion',
      format: format(),
      assets: const <ExportAssetDescriptor>[],
      tracks: const <ExportTrackDescriptor>[],
      issues: const <ExportCompositionIssue>[],
      canonicalEffectsGraph: ExportCanonicalEffectsGraph(
        schemaVersion: kExportGraphSchemaVersion,
        nodes: const <ExportCanonicalEffectsNodeDescriptor>[],
        operations: const <ExportCanonicalEffectOperationDescriptor>[],
      ),
      motionComposition: MotionNormalizedComposition(
        projectId: 'project-motion',
        projectRange: range(0, 2),
        format: const MotionProjectFormat(
          canvasSize: MotionSize2D(width: 1080, height: 1920),
          pixelAspectRatio: 1.0,
        ),
        frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
        scenes: <MotionResolvedSceneModel>[scene],
        globalChannels: <MotionResolvedPropertyChannel>[globalChannel],
        effects: <MotionResolvedEffectModel>[
          MotionResolvedEffectModel(
            id: 'effect-1',
            kind: MotionEffectKind.glow,
            targetAddress: elementTarget.canonicalAddress,
            projectRange: range(0, 2),
            parameters: const <String, MotionPropertyValue>{
              'intensity': MotionPropertyValue.scalar(0.6),
            },
            name: 'Glow',
          ),
        ],
        transitions: <MotionResolvedTransitionModel>[
          MotionResolvedTransitionModel(
            id: 'transition-1',
            kind: MotionTransitionKind.fade,
            leftTargetId: 'element-1',
            rightTargetId: 'element-1',
            projectRange: range(0, 0.4),
            parameters: const <String, MotionPropertyValue>{
              'mix': MotionPropertyValue.scalar(1.0),
            },
            name: 'Fade',
          ),
        ],
        cameras: <MotionResolvedCameraModel>[
          MotionResolvedCameraModel(
            id: 'camera-1',
            scope: MotionCameraBindingScope.scene,
            targetAddress: 'scene:scene-1',
            projectRange: range(0, 2),
            name: 'Camera 1',
            staticProperties: const <MotionPropertyAssignment>[],
            propertyChannels: const <MotionResolvedPropertyChannel>[],
          ),
        ],
        textAnimations: <MotionResolvedTextAnimationModel>[
          MotionResolvedTextAnimationModel(
            id: 'text-anim-1',
            targetElementId: 'element-1',
            targetAddress: elementTarget.canonicalAddress,
            projectRange: range(0, 1.2),
            animationKinds: const <MotionTextAnimationKind>[
              MotionTextAnimationKind.blurIn,
            ],
            generatedChannelIds: const <String>['element-scale-channel'],
            parameterValues: const <String, MotionPropertyValue>{
              'fromBlur': MotionPropertyValue.scalar(18),
            },
            presetId: 'cinematic-in',
          ),
        ],
        authoringOrigins: <MotionAuthoringOrigin>[
          MotionAuthoringOrigin(
            kind: MotionAuthoringSourceKind.preset,
            id: 'preset-origin',
            label: 'Cinematic',
          ),
        ],
        metadata: const <String, String>{'pipeline': 'motion-export'},
      ),
    );

    final bridgeMap = composition.toBridgeMap();
    final motion = bridgeMap['motion'] as Map<String, Object?>;
    final scenes = motion['scenes'] as List<Object?>;
    final layers =
        (scenes.first as Map<String, Object?>)['layers'] as List<Object?>;
    final elements =
        (layers.first as Map<String, Object?>)['elements'] as List<Object?>;
    final elementMap = elements.first as Map<String, Object?>;
    final propertyChannels = elementMap['propertyChannels'] as List<Object?>;
    final keyframes = (propertyChannels.first
        as Map<String, Object?>)['keyframes'] as List<Object?>;
    final textAnimations = motion['textAnimations'] as List<Object?>;
    final effects = motion['effects'] as List<Object?>;
    final cameras = motion['cameras'] as List<Object?>;

    expect(motion['contractVersion'], 'motion.v1alpha1');
    expect(motion['sceneCount'], 1);
    expect(motion['globalChannelCount'], 1);
    expect(cameras, hasLength(1));
    expect(
      (elementMap['sourceBinding'] as Map<String, Object?>)['assetId'],
      'asset-text-1',
    );
    expect(
      ((propertyChannels.first as Map<String, Object?>)['definition']
          as Map<String, Object?>)['id'],
      'element-scale',
    );
    expect(keyframes, hasLength(2));
    expect(
      (((keyframes.first as Map<String, Object?>)['value']
          as Map<String, Object?>)['raw'] as num),
      0.82,
    );
    expect(
      ((textAnimations.first as Map<String, Object?>)['parameterValues']
              as Map<String, Object?>)
          .containsKey('fromBlur'),
      isTrue,
    );
    expect(
      ((effects.first as Map<String, Object?>)['parameters']
              as Map<String, Object?>)
          .containsKey('intensity'),
      isTrue,
    );
  });

  test('accepts a single image visual track in the first export baseline', () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-image',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-image',
            kind: ExportAssetKind.image,
            label: 'Still',
            sourceUri: '/tmp/still.jpg',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.image,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-image',
                assetId: 'asset-image',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(3),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(3),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
      ),
    );

    expect(composition.isFirstBaselineEligible, isTrue);
    expect(composition.firstBaselineBlockingReasons, isEmpty);
  });

  test(
      'exposes machine-readable export graph metadata and supports advanced interpolation kinds',
      () {
    final composition = ExportComposition(
      contractVersion: 'v1alpha1',
      projectId: 'project-graph',
      format: format(),
      assets: const <ExportAssetDescriptor>[
        ExportAssetDescriptor(
          assetId: 'asset-video',
          kind: ExportAssetKind.video,
          label: 'Video',
          sourceUri: '/tmp/video.mp4',
        ),
      ],
      tracks: <ExportTrackDescriptor>[
        ExportTrackDescriptor(
          kind: ExportTrackKind.video,
          clips: <ExportClipDescriptor>[
            ExportClipDescriptor(
              clipId: 'clip-video',
              trackKind: ExportTrackKind.video,
              assetId: 'asset-video',
              timelineRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromSecondsDouble(2),
              ),
              sourceRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromSecondsDouble(2),
              ),
              playbackRate: 1.0,
              speedMode: ExportClipSpeedMode.normal,
            ),
          ],
        ),
      ],
      issues: const <ExportCompositionIssue>[],
      canonicalEffectsGraph: ExportCanonicalEffectsGraph(
        schemaVersion: kExportGraphSchemaVersion,
        nodes: const <ExportCanonicalEffectsNodeDescriptor>[],
        operations: const <ExportCanonicalEffectOperationDescriptor>[],
      ),
      motionTextProgram: ExportMotionTextProgram(
        canvasSize: const MotionSize2D(width: 1080, height: 1920),
        nodes: <ExportMotionTextProgramNode>[
          ExportMotionTextProgramNode(
            id: 'node-1',
            targetElementId: 'element-1',
            sceneId: 'scene-1',
            layerId: 'layer-1',
            projectRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromSecondsDouble(2),
            ),
            fullText: 'Hello',
            revealUnit: 'character',
            basePositionX: 0,
            basePositionY: 0,
            baseScaleX: 1,
            baseScaleY: 1,
            baseRotationDegrees: 0,
            baseOpacity: 1,
            baseBlurAmount: 0,
            baseFontSize: 64,
            baseLetterSpacing: 0,
            layerOpacity: 1,
            colorArgb: 0xFFFFFFFF,
            fontFamily: null,
            fontWeight: 700,
            fontStyle: 'normal',
            lineHeight: 1.0,
            textAlignment: 'center',
            anchor: 'center',
            blendMode: 'normal',
            zIndex: 1,
            animationKinds: const <String>['cinematicEntrance'],
            animationBlocks: <ExportMotionTextProgramAnimationBlock>[
              ExportMotionTextProgramAnimationBlock(
                id: 'block-1',
                kind: 'cinematicEntrance',
                projectRange: TimelineTimeRange(
                  start: TimelineTime.zero,
                  endExclusive: TimelineTime.fromSecondsDouble(2),
                ),
                interpolation: const ExportMotionInterpolationSpec(
                  kind: 'spring',
                  spring: ExportMotionSpringSpec(
                    stiffness: 180,
                    damping: 20,
                    mass: 1,
                    initialVelocity: 0,
                  ),
                ),
                parameters: const <String, MotionPropertyValue>{
                  'fromScale': MotionPropertyValue.scalar(0.5),
                },
              ),
            ],
            channels: <ExportMotionScalarChannel>[
              ExportMotionScalarChannel(
                id: 'channel-1',
                propertyId: 'transform.scale.x',
                projectRange: TimelineTimeRange(
                  start: TimelineTime.zero,
                  endExclusive: TimelineTime.fromSecondsDouble(2),
                ),
                activeRange: TimelineTimeRange(
                  start: TimelineTime.zero,
                  endExclusive: TimelineTime.fromSecondsDouble(2),
                ),
                beforeStart: 'clamp',
                afterEnd: 'clamp',
                fallbackValue: 1.0,
                keyframes: <ExportMotionScalarKeyframe>[
                  const ExportMotionScalarKeyframe(
                    time: TimelineTime.zero,
                    value: 0.5,
                    interpolation: ExportMotionInterpolationSpec(
                      kind: 'cubicBezier',
                      bezier: ExportMotionBezierControlPoints(
                        x1: 0.15,
                        y1: 0.0,
                        x2: 0.85,
                        y2: 1.0,
                      ),
                    ),
                  ),
                  ExportMotionScalarKeyframe(
                    time: TimelineTime.fromSecondsDouble(1),
                    value: 1.0,
                    interpolation: const ExportMotionInterpolationSpec(
                      kind: 'linear',
                    ),
                  ),
                ],
              ),
            ],
            layerChannels: const <ExportMotionScalarChannel>[],
          ),
        ],
      ),
    );

    expect(composition.graphSchemaVersion, 'export-graph.v1alpha1');
    expect(
      composition.backendProfile.primaryBackendId,
      'media3_transformer',
    );
    expect(
      composition.truthSources.any(
        (source) =>
            source.kind == ExportTruthSourceKind.motionTextProgram &&
            source.role == ExportTruthSourceRole.primary,
      ),
      isTrue,
    );
    expect(
      composition.firstBaselineBlockingCodes,
      isNot(contains(ExportBaselineBlockerCode.unsupportedInterpolationKind)),
    );
    expect(composition.unsupportedInterpolationKinds, isEmpty);
    expect(
      composition.interpolationRegistry.any(
        (entry) =>
            entry.kind == 'spring' &&
            entry.status == ExportCapabilityStatus.supported &&
            entry.encountered,
      ),
      isTrue,
    );
    expect(
      composition.capabilityMatrix.any(
        (entry) =>
            entry.id == 'fallback.motion_text_render_track' &&
            entry.status == ExportCapabilityStatus.fallbackOnly,
      ),
      isTrue,
    );
    expect(
      composition.propertyCapabilityMatrix.any(
        (entry) =>
            entry.propertyId == 'text.fontFamily' &&
            entry.status == ExportCapabilityStatus.blocked,
      ),
      isTrue,
    );
    expect(
      composition.rendererOwnershipMatrix.any(
        (entry) =>
            entry.id == 'renderer.motion_text_program' &&
            entry.fallbackAllowed &&
            entry.fallbackRendererId == 'motion_text_render_track_fallback',
      ),
      isTrue,
    );
    expect(
      composition.interpolationContractRegistry.any(
        (entry) =>
            entry.kind == 'spring' &&
            entry.status == ExportCapabilityStatus.supported &&
            entry.requiredParameters.contains('stiffness'),
      ),
      isTrue,
    );
    final bridgeMap = composition.toBridgeMap();
    final motionTextProgram =
        bridgeMap['motionTextProgram'] as Map<Object?, Object?>;
    final node = (motionTextProgram['nodes'] as List<Object?>).single
        as Map<Object?, Object?>;
    final animationBlock = (node['animationBlocks'] as List<Object?>).single
        as Map<Object?, Object?>;
    expect(animationBlock['kind'], 'cinematicEntrance');
    expect(animationBlock['interpolationKind'], 'spring');
    final blockInterpolation =
        animationBlock['interpolation'] as Map<Object?, Object?>;
    final blockSpring = blockInterpolation['spring'] as Map<Object?, Object?>;
    expect(blockSpring['stiffness'], 180.0);
    final parameters = animationBlock['parameters'] as Map<Object?, Object?>;
    final fromScale = parameters['fromScale'] as Map<Object?, Object?>;
    expect(fromScale['kind'], MotionPropertyValueKind.scalar.name);
    final channels = node['channels'] as List<Object?>;
    final channel = channels.single as Map<Object?, Object?>;
    final keyframes = channel['keyframes'] as List<Object?>;
    final firstKeyframe = keyframes.first as Map<Object?, Object?>;
    final firstInterpolation =
        firstKeyframe['interpolation'] as Map<Object?, Object?>;
    final firstBezier = firstInterpolation['bezier'] as Map<Object?, Object?>;
    expect(firstBezier['x1'], 0.15);
  });

  test('normalizes motion text render-track node ids to canonical export ids',
      () {
    final exportNode = ExportMotionTextRenderNode.fromSnapshotNode(
      MotionTextRenderNode(
        id: 'text-preview:element-42',
        targetElementId: 'element-42',
        sceneId: 'scene-1',
        layerId: 'layer-1',
        projectRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromSecondsDouble(2),
        ),
        isActive: true,
        text: 'Hello',
        fullText: 'Hello',
        revealUnit: MotionTextRevealUnit.wholeText,
        revealProgress: 1,
        hasRevealAnimation: false,
        animationKinds: const <MotionTextAnimationKind>[],
        animationProgressByKind: const <MotionTextAnimationKind, double>{},
        canvasOffset: const MotionPoint2D(x: 0, y: 0),
        scaleX: 1,
        scaleY: 1,
        rotationDegrees: 0,
        opacity: 1,
        blurAmount: 0,
        fontSize: 64,
        letterSpacing: 0,
        colorArgb: 0xFFFFFFFF,
        fontFamily: null,
        fontWeight: 700,
        fontStyle: 'normal',
        lineHeight: 1,
        textAlignment: 'center',
        anchor: 'center',
        blendMode: MotionBlendMode.normal,
        zIndex: 1,
      ),
    );

    expect(exportNode.id, buildExportMotionTextNodeId('element-42'));
  });

  test(
      'sampled motion text fallback alone is not baseline-eligible when canonical program is missing',
      () {
    final composition = ExportComposition(
      contractVersion: 'v1alpha1',
      projectId: 'project-fallback-only',
      format: format(),
      assets: const <ExportAssetDescriptor>[
        ExportAssetDescriptor(
          assetId: 'asset-video',
          kind: ExportAssetKind.video,
          label: 'Video',
          sourceUri: '/tmp/video.mp4',
        ),
      ],
      tracks: <ExportTrackDescriptor>[
        ExportTrackDescriptor(
          kind: ExportTrackKind.video,
          clips: <ExportClipDescriptor>[
            ExportClipDescriptor(
              clipId: 'clip-video',
              trackKind: ExportTrackKind.video,
              assetId: 'asset-video',
              timelineRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromSecondsDouble(2),
              ),
              sourceRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromSecondsDouble(2),
              ),
              playbackRate: 1.0,
              speedMode: ExportClipSpeedMode.normal,
            ),
          ],
        ),
      ],
      issues: const <ExportCompositionIssue>[],
      canonicalEffectsGraph: ExportCanonicalEffectsGraph(
        schemaVersion: kExportGraphSchemaVersion,
        nodes: const <ExportCanonicalEffectsNodeDescriptor>[],
        operations: const <ExportCanonicalEffectOperationDescriptor>[],
      ),
      motionComposition: MotionNormalizedComposition(
        projectId: 'project-fallback-only',
        projectRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromSecondsDouble(2),
        ),
        format: const MotionProjectFormat(
          canvasSize: MotionSize2D(width: 1080, height: 1920),
          pixelAspectRatio: 1.0,
        ),
        frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
        scenes: <MotionResolvedSceneModel>[
          MotionResolvedSceneModel(
            id: 'scene-1',
            sourceSceneId: 'source-scene-1',
            projectRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromSecondsDouble(2),
            ),
            name: 'Scene 1',
            layers: <MotionResolvedLayerModel>[
              MotionResolvedLayerModel(
                id: 'layer-1',
                sourceLayerId: 'source-layer-1',
                sceneId: 'scene-1',
                kind: MotionLayerKind.text,
                projectRange: TimelineTimeRange(
                  start: TimelineTime.zero,
                  endExclusive: TimelineTime.fromSecondsDouble(2),
                ),
                name: 'Text Layer',
                zIndex: 1,
                elements: <MotionResolvedElementModel>[
                  MotionResolvedElementModel(
                    id: 'element-1',
                    sourceElementId: 'source-element-1',
                    sceneId: 'scene-1',
                    layerId: 'layer-1',
                    kind: MotionElementKind.text,
                    projectRange: TimelineTimeRange(
                      start: TimelineTime.zero,
                      endExclusive: TimelineTime.fromSecondsDouble(2),
                    ),
                    localRange: TimelineTimeRange(
                      start: TimelineTime.zero,
                      endExclusive: TimelineTime.fromSecondsDouble(2),
                    ),
                    staticProperties: const <MotionPropertyAssignment>[],
                    propertyChannels: const <MotionResolvedPropertyChannel>[],
                  ),
                ],
                staticProperties: const <MotionPropertyAssignment>[],
                propertyChannels: const <MotionResolvedPropertyChannel>[],
              ),
            ],
            staticProperties: const <MotionPropertyAssignment>[],
            propertyChannels: const <MotionResolvedPropertyChannel>[],
          ),
        ],
        globalChannels: const <MotionResolvedPropertyChannel>[],
        effects: const <MotionResolvedEffectModel>[],
        transitions: const <MotionResolvedTransitionModel>[],
        cameras: const <MotionResolvedCameraModel>[],
        textAnimations: const <MotionResolvedTextAnimationModel>[],
        authoringOrigins: const <MotionAuthoringOrigin>[],
        metadata: const <String, String>{},
      ),
      motionTextRenderTrack: ExportMotionTextRenderTrack(
        canvasSize: const MotionSize2D(width: 1080, height: 1920),
        sampleStepMs: 33,
        samples: <ExportMotionTextRenderSample>[
          ExportMotionTextRenderSample(
            time: TimelineTime.zero,
            nodes: const <ExportMotionTextRenderNode>[],
          ),
        ],
      ),
    );

    expect(composition.isFirstBaselineEligible, isFalse);
    expect(
      composition.firstBaselineBlockingCodes,
      contains(ExportBaselineBlockerCode.missingMotionTextProgram),
    );
  });

  test(
      'builds a visual compositor graph for single visual media plus motion text overlay',
      () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-visual-graph',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-video',
            kind: ExportAssetKind.video,
            label: 'Video',
            sourceUri: '/tmp/video.mp4',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.video,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-video',
                assetId: 'asset-video',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
        motionTextProgram: ExportMotionTextProgram(
          canvasSize: const MotionSize2D(width: 1080, height: 1920),
          nodes: <ExportMotionTextProgramNode>[
            ExportMotionTextProgramNode(
              id: 'node-1',
              targetElementId: 'element-1',
              sceneId: 'scene-1',
              layerId: 'layer-1',
              projectRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromSecondsDouble(2),
              ),
              fullText: 'Hello',
              revealUnit: 'wholeText',
              basePositionX: 0,
              basePositionY: 0,
              baseScaleX: 1,
              baseScaleY: 1,
              baseRotationDegrees: 0,
              baseOpacity: 1,
              baseBlurAmount: 0,
              baseFontSize: 64,
              baseLetterSpacing: 0,
              layerOpacity: 1,
              colorArgb: 0xFFFFFFFF,
              fontFamily: null,
              fontWeight: 700,
              fontStyle: 'normal',
              lineHeight: 1.0,
              textAlignment: 'center',
              anchor: 'center',
              blendMode: 'normal',
              zIndex: 1,
              animationKinds: const <String>['typewriter'],
              animationBlocks: <ExportMotionTextProgramAnimationBlock>[
                ExportMotionTextProgramAnimationBlock(
                  id: 'block-1',
                  kind: 'typewriter',
                  projectRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromMilliseconds(800),
                  ),
                  interpolation: const ExportMotionInterpolationSpec(
                    kind: 'easeInOut',
                  ),
                  parameters: const <String, MotionPropertyValue>{
                    'fromOpacity': MotionPropertyValue.scalar(0),
                    'toOpacity': MotionPropertyValue.scalar(1),
                  },
                  revealUnit: 'letter',
                  revealStagger: TimelineTime.fromMilliseconds(40),
                ),
              ],
              channels: <ExportMotionScalarChannel>[
                ExportMotionScalarChannel(
                  id: 'channel-1',
                  propertyId: 'text.letterSpacing',
                  projectRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromSecondsDouble(2),
                  ),
                  activeRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromMilliseconds(900),
                  ),
                  beforeStart: 'clamp',
                  afterEnd: 'clamp',
                  baseValue: 24,
                  fallbackValue: 0,
                  keyframes: <ExportMotionScalarKeyframe>[
                    const ExportMotionScalarKeyframe(
                      time: TimelineTime.zero,
                      value: 24,
                      interpolation: ExportMotionInterpolationSpec(
                        kind: 'easeOut',
                      ),
                    ),
                    ExportMotionScalarKeyframe(
                      time: TimelineTime.fromMilliseconds(900),
                      value: 0,
                      interpolation: const ExportMotionInterpolationSpec(
                        kind: 'linear',
                      ),
                    ),
                  ],
                ),
              ],
              layerChannels: <ExportMotionScalarChannel>[
                ExportMotionScalarChannel(
                  id: 'layer-channel-1',
                  propertyId: 'visual.opacity',
                  projectRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromSecondsDouble(2),
                  ),
                  activeRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromSecondsDouble(2),
                  ),
                  beforeStart: 'clamp',
                  afterEnd: 'clamp',
                  baseValue: 1,
                  fallbackValue: 1,
                  keyframes: const <ExportMotionScalarKeyframe>[
                    ExportMotionScalarKeyframe(
                      time: TimelineTime.zero,
                      value: 1,
                      interpolation: ExportMotionInterpolationSpec(
                        kind: 'linear',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final graph = composition.visualCompositorGraph;
    expect(graph.layerCount, 2);
    expect(graph.mediaLayerCount, 1);
    expect(graph.authoredLayerCount, 1);
    expect(graph.requiresVisualCompositor, isFalse);
    expect(graph.maxConcurrentVisualSegments, 2);
    expect(graph.compositorWindowExecutionPlanCount, 0);
    expect(graph.mediaOnlyWindowCount, 1);
    expect(graph.mediaWithAuthoredOverlayWindowCount, 1);
    expect(graph.compositorRequiredWindowCount, 0);
    expect(graph.windows, hasLength(3));
    expect(
      graph.windows.first.policy,
      ExportVisualAssemblyPolicyKind.mediaWithAuthoredOverlay,
    );
    expect(
      graph.windows[1].policy,
      ExportVisualAssemblyPolicyKind.mediaOnly,
    );
    expect(
      graph.windows.last.policy,
      ExportVisualAssemblyPolicyKind.gap,
    );
    expect(
      graph.layers.any(
        (layer) =>
            layer.kind == ExportVisualLayerKind.motionTextOverlay &&
            layer.rendererOwnerId == 'app_motion_text_program_renderer',
      ),
      isTrue,
    );
    final bridgeMap = composition.toBridgeMap();
    final visualGraph =
        bridgeMap['visualCompositorGraph'] as Map<Object?, Object?>;
    final layers = visualGraph['layers'] as List<Object?>;
    final segments = visualGraph['segments'] as List<Object?>;
    final windows = visualGraph['windows'] as List<Object?>;
    expect(layers, hasLength(2));
    expect(segments, hasLength(2));
    expect(windows, hasLength(3));
    final compositorPlans =
        visualGraph['compositorWindowExecutionPlans'] as List<Object?>;
    expect(compositorPlans, isEmpty);
    final firstWindow = windows.first as Map<Object?, Object?>;
    expect(firstWindow['policy'], 'mediaWithAuthoredOverlay');
    expect(firstWindow['executionOwner'], 'media3BaselineRoute');
  });

  test('bridges motion text raster contract for native export consumers', () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-raster-contract',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-video',
            kind: ExportAssetKind.video,
            label: 'Video',
            sourceUri: '/tmp/video.mp4',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.video,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-video',
                assetId: 'asset-video',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
        motionTextProgram: ExportMotionTextProgram(
          canvasSize: const MotionSize2D(width: 1080, height: 1920),
          nodes: <ExportMotionTextProgramNode>[
            ExportMotionTextProgramNode(
              id: 'node-1',
              targetElementId: 'element-1',
              sceneId: 'scene-1',
              layerId: 'layer-1',
              projectRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromSecondsDouble(2),
              ),
              fullText: 'Hello',
              revealUnit: 'wholeText',
              basePositionX: 0,
              basePositionY: 0,
              baseScaleX: 1,
              baseScaleY: 1,
              baseRotationDegrees: 0,
              baseOpacity: 1,
              baseBlurAmount: 0,
              baseFontSize: 64,
              baseLetterSpacing: 0,
              layerOpacity: 1,
              colorArgb: 0xFFFFFFFF,
              fontFamily: null,
              fontWeight: 700,
              fontStyle: 'normal',
              lineHeight: 1.0,
              textAlignment: 'center',
              anchor: 'center',
              blendMode: 'normal',
              zIndex: 1,
              animationKinds: const <String>['typewriter'],
              animationBlocks: <ExportMotionTextProgramAnimationBlock>[
                ExportMotionTextProgramAnimationBlock(
                  id: 'block-1',
                  kind: 'typewriter',
                  projectRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromMilliseconds(800),
                  ),
                  interpolation: const ExportMotionInterpolationSpec(
                    kind: 'easeInOut',
                  ),
                  parameters: const <String, MotionPropertyValue>{
                    'fromOpacity': MotionPropertyValue.scalar(0),
                    'toOpacity': MotionPropertyValue.scalar(1),
                  },
                  revealUnit: 'letter',
                  revealStagger: TimelineTime.fromMilliseconds(40),
                ),
              ],
              channels: <ExportMotionScalarChannel>[
                ExportMotionScalarChannel(
                  id: 'channel-1',
                  propertyId: 'text.letterSpacing',
                  projectRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromSecondsDouble(2),
                  ),
                  activeRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromMilliseconds(900),
                  ),
                  beforeStart: 'clamp',
                  afterEnd: 'clamp',
                  baseValue: 24,
                  fallbackValue: 0,
                  keyframes: <ExportMotionScalarKeyframe>[
                    const ExportMotionScalarKeyframe(
                      time: TimelineTime.zero,
                      value: 24,
                      interpolation: ExportMotionInterpolationSpec(
                        kind: 'easeOut',
                      ),
                    ),
                    ExportMotionScalarKeyframe(
                      time: TimelineTime.fromMilliseconds(900),
                      value: 0,
                      interpolation: const ExportMotionInterpolationSpec(
                        kind: 'linear',
                      ),
                    ),
                  ],
                ),
              ],
              layerChannels: <ExportMotionScalarChannel>[
                ExportMotionScalarChannel(
                  id: 'layer-channel-1',
                  propertyId: 'visual.opacity',
                  projectRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromSecondsDouble(2),
                  ),
                  activeRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromSecondsDouble(2),
                  ),
                  beforeStart: 'clamp',
                  afterEnd: 'clamp',
                  baseValue: 1,
                  fallbackValue: 1,
                  keyframes: const <ExportMotionScalarKeyframe>[
                    ExportMotionScalarKeyframe(
                      time: TimelineTime.zero,
                      value: 1,
                      interpolation: ExportMotionInterpolationSpec(
                        kind: 'linear',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(composition.motionTextRasterContract, isNotNull);
    expect(
      composition.motionTextRasterContract?.contractVersion,
      kMotionTextRasterContractVersion,
    );
    expect(composition.motionTextRasterProgram, isNotNull);
    expect(composition.motionTextRasterProgram?.nodes, hasLength(1));
    final bridgeMap = composition.toBridgeMap();
    final rasterContract =
        bridgeMap['motionTextRasterContract'] as Map<Object?, Object?>;
    expect(rasterContract['contractVersion'], kMotionTextRasterContractVersion);
    final policy =
        rasterContract['rasterizationPolicy'] as Map<Object?, Object?>;
    expect(policy['blurSigmaScale'], kMotionTextRasterBlurSigmaScale);
    expect(
      policy['blurSpreadMultiplier'],
      kMotionTextRasterBlurSpreadMultiplier,
    );
    final rasterProgram =
        bridgeMap['motionTextRasterProgram'] as Map<Object?, Object?>;
    expect(rasterProgram['contractVersion'], kMotionTextRasterContractVersion);
    final rasterNodes = rasterProgram['nodes'] as List<Object?>;
    expect(rasterNodes, hasLength(1));
    final rasterNode = rasterNodes.single as Map<Object?, Object?>;
    expect(rasterNode['fullText'], 'Hello');
    expect(rasterNode['animationKinds'], <String>['typewriter']);
    final animationBlocks = rasterNode['animationBlocks'] as List<Object?>;
    expect(animationBlocks, hasLength(1));
    final animationBlock = animationBlocks.single as Map<Object?, Object?>;
    expect(animationBlock['kind'], 'typewriter');
    expect(animationBlock['revealUnit'], 'letter');
    final channels = rasterNode['channels'] as List<Object?>;
    expect(channels, hasLength(1));
    final channel = channels.single as Map<Object?, Object?>;
    expect(channel['propertyId'], 'text.letterSpacing');
    final layerChannels = rasterNode['layerChannels'] as List<Object?>;
    expect(layerChannels, hasLength(1));
    final layerChannel = layerChannels.single as Map<Object?, Object?>;
    expect(layerChannel['propertyId'], 'visual.opacity');
  });

  test('declares compositor requirements for multiple visual media tracks', () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-multi-visual',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-video',
            kind: ExportAssetKind.video,
            label: 'Video',
            sourceUri: '/tmp/video.mp4',
          ),
          ExportAssetDescriptor(
            assetId: 'asset-image',
            kind: ExportAssetKind.image,
            label: 'Image',
            sourceUri: '/tmp/image.png',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.video,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-video',
                assetId: 'asset-video',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
          ExportTrackSeed(
            kind: ExportTrackKind.image,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-image',
                assetId: 'asset-image',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
      ),
    );

    final graph = composition.visualCompositorGraph;
    expect(graph.requiresVisualCompositor, isTrue);
    expect(graph.mediaLayerCount, 2);
    expect(graph.compositorWindowExecutionPlanCount, 1);
    expect(
        composition.firstBaselineBlockingCodes,
        isNot(contains(
            ExportBaselineBlockerCode.compositorRequiredVisualWindow)));
    expect(composition.firstBaselineBlockingCodes,
        isNot(contains(ExportBaselineBlockerCode.multipleVisualTracks)));
    expect(graph.windows, hasLength(2));
    expect(
      graph.windows.first.policy,
      ExportVisualAssemblyPolicyKind.compositorRequired,
    );
    expect(graph.windows.first.supportsCurrentBackend, isTrue);
    expect(
      graph.windows.last.policy,
      ExportVisualAssemblyPolicyKind.gap,
    );
    expect(graph.supportedCompositorWindowCount, 1);
    expect(graph.unsupportedCompositorWindowCount, 0);
    expect(
      graph.requirementReasons,
      contains('multiple_visual_media_tracks'),
    );
    final compositorPlan = graph.compositorWindowExecutionPlans.single;
    expect(compositorPlan.windowId, 'visual.window.0');
    expect(
      compositorPlan.executionOwner,
      ExportVisualExecutionOwnerKind.nativeVisualCompositor,
    );
    expect(compositorPlan.orderedLayerIds, hasLength(2));
    expect(compositorPlan.orderedSegmentIds, hasLength(2));
    final bridgeMap = composition.toBridgeMap();
    final visualGraph =
        bridgeMap['visualCompositorGraph'] as Map<Object?, Object?>;
    expect(visualGraph['requiresVisualCompositor'], isTrue);
    expect(visualGraph['mediaOnlyWindowCount'], 0);
    expect(visualGraph['mediaWithAuthoredOverlayWindowCount'], 0);
    expect(visualGraph['compositorRequiredWindowCount'], 1);
    expect(visualGraph['supportedCompositorWindowCount'], 1);
    expect(visualGraph['unsupportedCompositorWindowCount'], 0);
    expect(visualGraph['compositorWindowExecutionPlanCount'], 1);
    expect(visualGraph['gapWindowCount'], 1);
    final windows = visualGraph['windows'] as List<Object?>;
    final firstWindow = windows.first as Map<Object?, Object?>;
    expect(firstWindow['executionOwner'], 'nativeVisualCompositor');
    expect(firstWindow['supportsCurrentBackend'], true);
    final bridgePlans =
        visualGraph['compositorWindowExecutionPlans'] as List<Object?>;
    expect(bridgePlans, hasLength(1));
    final firstPlan = bridgePlans.single as Map<Object?, Object?>;
    expect(firstPlan['windowId'], 'visual.window.0');
    expect(firstPlan['executionOwner'], 'nativeVisualCompositor');
  });

  test(
      'treats image overlay stacks as current-backend-supported compositor windows',
      () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-image-overlay-stack',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-video',
            kind: ExportAssetKind.video,
            label: 'Video',
            sourceUri: '/tmp/video.mp4',
          ),
          ExportAssetDescriptor(
            assetId: 'asset-image-a',
            kind: ExportAssetKind.image,
            label: 'Image A',
            sourceUri: '/tmp/image-a.png',
          ),
          ExportAssetDescriptor(
            assetId: 'asset-image-b',
            kind: ExportAssetKind.image,
            label: 'Image B',
            sourceUri: '/tmp/image-b.png',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.video,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-video',
                assetId: 'asset-video',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
          ExportTrackSeed(
            kind: ExportTrackKind.image,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-image-a',
                assetId: 'asset-image-a',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
          ExportTrackSeed(
            kind: ExportTrackKind.image,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-image-b',
                assetId: 'asset-image-b',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
      ),
    );

    final graph = composition.visualCompositorGraph;
    expect(graph.requiresVisualCompositor, isTrue);
    expect(graph.supportedCompositorWindowCount, 1);
    expect(graph.unsupportedCompositorWindowCount, 0);
    expect(
      composition.firstBaselineBlockingCodes,
      isNot(contains(ExportBaselineBlockerCode.multipleVisualTracks)),
    );
    final compositorPlan = graph.compositorWindowExecutionPlans.single;
    expect(compositorPlan.mediaSegmentIds, hasLength(3));
    expect(
      compositorPlan.executionInputs
          .map((input) => input.role)
          .toList(growable: false),
      const <ExportCompositorExecutionInputRoleKind>[
        ExportCompositorExecutionInputRoleKind.baseMedia,
        ExportCompositorExecutionInputRoleKind.overlayMedia,
        ExportCompositorExecutionInputRoleKind.overlayMedia,
      ],
    );
  });

  test('keeps authored overlay inputs inside compositor execution plans', () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-compositor-with-authored-overlay',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-video',
            kind: ExportAssetKind.video,
            label: 'Video',
            sourceUri: '/tmp/video.mp4',
          ),
          ExportAssetDescriptor(
            assetId: 'asset-image',
            kind: ExportAssetKind.image,
            label: 'Image',
            sourceUri: '/tmp/image.png',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.video,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-video',
                assetId: 'asset-video',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
          ExportTrackSeed(
            kind: ExportTrackKind.image,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-image',
                assetId: 'asset-image',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
        motionTextProgram: ExportMotionTextProgram(
          canvasSize: const MotionSize2D(width: 1080, height: 1920),
          nodes: <ExportMotionTextProgramNode>[
            ExportMotionTextProgramNode(
              id: 'text-program:element-1',
              targetElementId: 'element-1',
              sceneId: 'scene-1',
              layerId: 'layer-1',
              projectRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromSecondsDouble(2),
              ),
              fullText: 'Overlay',
              revealUnit: 'wholeText',
              basePositionX: 0,
              basePositionY: 0,
              baseScaleX: 1,
              baseScaleY: 1,
              baseRotationDegrees: 0,
              baseOpacity: 1,
              baseBlurAmount: 0,
              baseFontSize: 64,
              baseLetterSpacing: 0,
              layerOpacity: 1,
              colorArgb: 0xFFFFFFFF,
              fontFamily: null,
              fontWeight: 700,
              fontStyle: 'normal',
              lineHeight: 1.0,
              textAlignment: 'center',
              anchor: 'center',
              blendMode: 'normal',
              zIndex: 3,
              animationKinds: const <String>[],
              animationBlocks: const <ExportMotionTextProgramAnimationBlock>[],
              channels: const <ExportMotionScalarChannel>[],
              layerChannels: const <ExportMotionScalarChannel>[],
            ),
          ],
        ),
      ),
    );

    final graph = composition.visualCompositorGraph;
    expect(graph.requiresVisualCompositor, isTrue);
    expect(graph.compositorWindowExecutionPlans, hasLength(2));
    expect(graph.supportedCompositorWindowCount, 2);
    expect(graph.unsupportedCompositorWindowCount, 0);
    expect(graph.compositorWindowExecutionPlans.first.mediaSegmentIds,
        hasLength(2));
    expect(graph.compositorWindowExecutionPlans.first.authoredSegmentIds,
        hasLength(1));
    expect(
      graph.compositorWindowExecutionPlans.first.executionInputs
          .map((input) => input.role)
          .toList(growable: false),
      const <ExportCompositorExecutionInputRoleKind>[
        ExportCompositorExecutionInputRoleKind.baseMedia,
        ExportCompositorExecutionInputRoleKind.overlayMedia,
        ExportCompositorExecutionInputRoleKind.authoredOverlay,
      ],
    );
    expect(
        composition.firstBaselineBlockingCodes,
        isNot(contains(
            ExportBaselineBlockerCode.compositorRequiredVisualWindow)));
    final bridgeMap = composition.toBridgeMap();
    final visualGraph =
        bridgeMap['visualCompositorGraph'] as Map<Object?, Object?>;
    expect(visualGraph['supportedCompositorWindowCount'], 2);
    expect(visualGraph['unsupportedCompositorWindowCount'], 0);
    final bridgePlans =
        visualGraph['compositorWindowExecutionPlans'] as List<Object?>;
    final firstPlan = bridgePlans.first as Map<Object?, Object?>;
    expect(firstPlan['authoredSegmentIds'], hasLength(1));
    expect(firstPlan['executionInputs'], hasLength(3));
    expect(firstPlan['orderedSegmentIds'], hasLength(3));
  });

  test('treats authored-only tail windows as compositor-required', () {
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-authored-tail',
        projectFormat: format(durationSeconds: 8),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-video',
            kind: ExportAssetKind.video,
            label: 'Video',
            sourceUri: '/tmp/video.mp4',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.video,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-video',
                assetId: 'asset-video',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
        motionTextProgram: ExportMotionTextProgram(
          canvasSize: const MotionSize2D(width: 1080, height: 1920),
          nodes: <ExportMotionTextProgramNode>[
            ExportMotionTextProgramNode(
              id: 'text-program:element-tail',
              targetElementId: 'element-tail',
              sceneId: 'scene-1',
              layerId: 'layer-1',
              projectRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromSecondsDouble(8),
              ),
              fullText: 'Tail',
              revealUnit: 'wholeText',
              basePositionX: 0,
              basePositionY: 0,
              baseScaleX: 1,
              baseScaleY: 1,
              baseRotationDegrees: 0,
              baseOpacity: 1,
              baseBlurAmount: 0,
              baseFontSize: 64,
              baseLetterSpacing: 0,
              layerOpacity: 1,
              colorArgb: 0xFFFFFFFF,
              fontFamily: null,
              fontWeight: 700,
              fontStyle: 'normal',
              lineHeight: 1.0,
              textAlignment: 'center',
              anchor: 'center',
              blendMode: 'normal',
              zIndex: 1,
              animationKinds: const <String>[],
              animationBlocks: const <ExportMotionTextProgramAnimationBlock>[],
              channels: const <ExportMotionScalarChannel>[],
              layerChannels: const <ExportMotionScalarChannel>[],
            ),
          ],
        ),
      ),
    );

    final graph = composition.visualCompositorGraph;
    expect(
      graph.windows.any(
        (window) =>
            window.timelineRange.start == TimelineTime.fromSecondsDouble(4) &&
            window.timelineRange.endExclusive ==
                TimelineTime.fromSecondsDouble(8) &&
            window.policy == ExportVisualAssemblyPolicyKind.compositorRequired,
      ),
      isTrue,
    );
    expect(
      composition.firstBaselineBlockingCodes,
      contains(ExportBaselineBlockerCode.compositorRequiredVisualWindow),
    );
  });

  test(
      'projects non-text authored visuals into compositor-owned overlay segments',
      () {
    TimelineTimeRange range(double startSeconds, double endSeconds) {
      return TimelineTimeRange(
        start: TimelineTime.fromSecondsDouble(startSeconds),
        endExclusive: TimelineTime.fromSecondsDouble(endSeconds),
      );
    }

    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-authored-image-shape',
        projectFormat: format(durationSeconds: 4),
        assets: const <ExportAssetDescriptor>[
          ExportAssetDescriptor(
            assetId: 'asset-video',
            kind: ExportAssetKind.video,
            label: 'Video',
            sourceUri: '/tmp/video.mp4',
          ),
        ],
        timelineTracks: <ExportTrackSeed>[
          ExportTrackSeed(
            kind: ExportTrackKind.video,
            clips: <ExportClipSeed>[
              ExportClipSeed(
                clipId: 'clip-video',
                assetId: 'asset-video',
                timelineStartTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(4),
                sourceStartTime: TimelineTime.zero,
                sourceDurationTime: TimelineTime.fromSecondsDouble(4),
                playbackRate: 1.0,
                speedMode: ExportClipSpeedMode.normal,
              ),
            ],
          ),
        ],
        motionComposition: MotionNormalizedComposition(
          projectId: 'project-authored-image-shape',
          projectRange: range(0, 4),
          format: const MotionProjectFormat(
            canvasSize: MotionSize2D(width: 1080, height: 1920),
            pixelAspectRatio: 1.0,
          ),
          frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
          scenes: <MotionResolvedSceneModel>[
            MotionResolvedSceneModel(
              id: 'scene-1',
              sourceSceneId: 'scene-source-1',
              projectRange: range(0, 4),
              layers: <MotionResolvedLayerModel>[
                MotionResolvedLayerModel(
                  id: 'layer-image',
                  sourceLayerId: 'layer-source-image',
                  sceneId: 'scene-1',
                  kind: MotionLayerKind.image,
                  projectRange: range(0, 4),
                  zIndex: 2,
                  elements: <MotionResolvedElementModel>[
                    MotionResolvedElementModel(
                      id: 'image-1',
                      sourceElementId: 'image-source-1',
                      sceneId: 'scene-1',
                      layerId: 'layer-image',
                      kind: MotionElementKind.image,
                      projectRange: range(0, 4),
                      localRange: range(0, 4),
                      sourceBinding: MotionElementSourceBinding(
                        kind: MotionSourceKind.image,
                        sourceId: 'image-source',
                        assetId: 'asset-image-generated',
                        sourceRange: range(0, 4),
                      ),
                      staticProperties: const <MotionPropertyAssignment>[],
                      propertyChannels: const <MotionResolvedPropertyChannel>[],
                    ),
                  ],
                  staticProperties: const <MotionPropertyAssignment>[],
                  propertyChannels: const <MotionResolvedPropertyChannel>[],
                ),
                MotionResolvedLayerModel(
                  id: 'layer-shape',
                  sourceLayerId: 'layer-source-shape',
                  sceneId: 'scene-1',
                  kind: MotionLayerKind.shape,
                  projectRange: range(1, 4),
                  zIndex: 4,
                  elements: <MotionResolvedElementModel>[
                    MotionResolvedElementModel(
                      id: 'shape-1',
                      sourceElementId: 'shape-source-1',
                      sceneId: 'scene-1',
                      layerId: 'layer-shape',
                      kind: MotionElementKind.shape,
                      projectRange: range(1, 4),
                      localRange: range(0, 3),
                      shapeKind: MotionShapeKind.roundedRectangle,
                      sourceBinding: MotionElementSourceBinding(
                        kind: MotionSourceKind.generatedShape,
                        sourceId: 'shape-source',
                        sourceRange: range(0, 3),
                      ),
                      staticProperties: const <MotionPropertyAssignment>[],
                      propertyChannels: const <MotionResolvedPropertyChannel>[],
                    ),
                  ],
                  staticProperties: const <MotionPropertyAssignment>[],
                  propertyChannels: const <MotionResolvedPropertyChannel>[],
                ),
              ],
              staticProperties: const <MotionPropertyAssignment>[],
              propertyChannels: const <MotionResolvedPropertyChannel>[],
            ),
          ],
          globalChannels: const <MotionResolvedPropertyChannel>[],
          effects: const <MotionResolvedEffectModel>[],
          transitions: const <MotionResolvedTransitionModel>[],
          cameras: const <MotionResolvedCameraModel>[],
          textAnimations: const <MotionResolvedTextAnimationModel>[],
        ),
      ),
    );

    final graph = composition.visualCompositorGraph;
    final surfaceProgram = composition.authoredVisualSurfaceProgram;
    expect(surfaceProgram, isNotNull);
    expect(surfaceProgram!.nodes, hasLength(2));
    expect(
      surfaceProgram.nodes.map((node) => node.id).toSet(),
      containsAll(<String>[
        buildExportAuthoredVisualSurfaceNodeId('image-1'),
        buildExportAuthoredVisualSurfaceNodeId('shape-1'),
      ]),
    );
    expect(
      graph.layers
          .where((layer) => layer.kind == ExportVisualLayerKind.authoredOverlay)
          .map((layer) => layer.rendererOwnerId)
          .toSet(),
      contains('app_authored_visual_surface_renderer'),
    );
    expect(
      graph.segments.map((segment) => segment.id).toSet(),
      containsAll(
          <String>['authored.segment.image-1', 'authored.segment.shape-1']),
    );
    expect(graph.requiresVisualCompositor, isTrue);
    expect(graph.supportedCompositorWindowCount, 0);
    expect(graph.unsupportedCompositorWindowCount, greaterThan(0));
    expect(
      graph.requirementReasons,
      contains('non_text_authored_visuals_present'),
    );
    expect(
      composition.firstBaselineBlockingCodes,
      contains(ExportBaselineBlockerCode.compositorRequiredVisualWindow),
    );
    expect(
      composition.firstBaselineBlockingCodes,
      contains(ExportBaselineBlockerCode.unsupportedNonTextMotion),
    );

    final authoredSegmentIds = graph.compositorWindowExecutionPlans
        .expand((plan) => plan.authoredSegmentIds)
        .toSet();
    expect(authoredSegmentIds, contains('authored.segment.image-1'));
    expect(authoredSegmentIds, contains('authored.segment.shape-1'));
    expect(
      graph.compositorWindowExecutionPlans
          .expand((plan) => plan.executionInputs)
          .where(
            (input) =>
                input.role ==
                ExportCompositorExecutionInputRoleKind.authoredOverlay,
          )
          .map((input) => input.rendererOwnerId)
          .toSet(),
      contains('app_authored_visual_surface_renderer'),
    );

    final bridgeMap = composition.toBridgeMap();
    expect(
      bridgeMap['authoredVisualSurfaceProgram'],
      isA<Map<Object?, Object?>>(),
    );
    final visualGraph =
        bridgeMap['visualCompositorGraph'] as Map<Object?, Object?>;
    expect(visualGraph['unsupportedCompositorWindowCount'], greaterThan(0));
    expect(
      visualGraph['requirementReasons'] as List<Object?>,
      contains('non_text_authored_visuals_present'),
    );
  });
}
