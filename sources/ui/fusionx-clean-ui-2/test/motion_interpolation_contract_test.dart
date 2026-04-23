import 'package:flutter_test/flutter_test.dart';

import 'package:refusion_app/features/editor/domain/models/export_motion_text_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_interpolation_evaluator.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_preset_serialization.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_runtime_helpers.dart';
import 'package:refusion_app/features/editor/domain/services/scoped_text_motion_script_import_service.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  test('core interpolation spec exposes canonical bounce and elastic payloads',
      () {
    const bounce = MotionInterpolationSpec.bounce(
      bounce: MotionBounceSpec(
        amplitude: 0.2,
        bounces: 4,
        decay: 6.0,
      ),
    );
    const elastic = MotionInterpolationSpec.elastic(
      elastic: MotionElasticSpec(
        amplitude: 0.12,
        period: 0.3,
        decay: 7.0,
      ),
    );

    expect(bounce.kind, MotionInterpolationKind.bounce);
    expect(bounce.bounce, isNotNull);
    expect(bounce.bounce!.bounces, 4);

    expect(elastic.kind, MotionInterpolationKind.elastic);
    expect(elastic.elastic, isNotNull);
    expect(elastic.elastic!.period, 0.3);
  });

  test('export interpolation bridge preserves bounce and elastic params', () {
    const interpolation = ExportMotionInterpolationSpec(
      kind: 'bounce',
      bounce: ExportMotionBounceSpec(
        amplitude: 0.22,
        bounces: 3,
        decay: 5.5,
      ),
    );
    const elastic = ExportMotionInterpolationSpec(
      kind: 'elastic',
      elastic: ExportMotionElasticSpec(
        amplitude: 0.14,
        period: 0.28,
        decay: 7.25,
      ),
    );

    final bounceMap = interpolation.toBridgeMap();
    final elasticMap = elastic.toBridgeMap();

    expect((bounceMap['bounce'] as Map<Object?, Object?>)['amplitude'], 0.22);
    expect((bounceMap['bounce'] as Map<Object?, Object?>)['bounces'], 3);
    expect((bounceMap['bounce'] as Map<Object?, Object?>)['decay'], 5.5);

    expect((elasticMap['elastic'] as Map<Object?, Object?>)['amplitude'], 0.14);
    expect((elasticMap['elastic'] as Map<Object?, Object?>)['period'], 0.28);
    expect((elasticMap['elastic'] as Map<Object?, Object?>)['decay'], 7.25);
  });

  test('spring evaluator produces a non-linear overshoot for underdamped specs',
      () {
    const interpolation = MotionInterpolationSpec.spring(
      spring: MotionSpringSpec(
        stiffness: 220,
        damping: 18,
        mass: 1,
        initialVelocity: 0,
      ),
    );

    final sample = evaluateMotionCurveProgress(interpolation, 0.25);

    expect(sample, greaterThan(1.0));
  });

  test('bounce evaluator stays anchored while differing from linear', () {
    const interpolation = MotionInterpolationSpec.bounce(
      bounce: MotionBounceSpec(
        amplitude: 0.22,
        bounces: 3,
        decay: 6.0,
      ),
    );

    expect(evaluateMotionCurveProgress(interpolation, 0.0), 0.0);
    expect(evaluateMotionCurveProgress(interpolation, 1.0), 1.0);
    expect(
      evaluateMotionCurveProgress(interpolation, 0.65),
      greaterThan(0.65),
    );
  });

  test('elastic evaluator oscillates and lands on the target', () {
    const interpolation = MotionInterpolationSpec.elastic(
      elastic: MotionElasticSpec(
        amplitude: 0.14,
        period: 0.28,
        decay: 8.0,
      ),
    );

    final mid = evaluateMotionCurveProgress(interpolation, 0.2);
    final nearEnd = evaluateMotionCurveProgress(interpolation, 1.0);

    expect(mid, isNot(closeTo(0.2, 0.0001)));
    expect(nearEnd, closeTo(1.0, 0.0001));
  });

  test('bounceIn effect family lowers into editable canonical channels', () {
    final range = TimelineTimeRange(
      start: TimelineTime.zero,
      endExclusive: TimelineTime.fromSecondsDouble(3),
    );
    const target = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'text-1',
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer',
      elementId: 'text-1',
    );
    final project = MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 60, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene',
          projectRange: range,
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'layer',
              sceneId: 'scene',
              kind: MotionLayerKind.text,
              visibleRange: range,
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'text-1',
                  layerId: 'layer',
                  kind: MotionElementKind.text,
                  localRange: range,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final result = BasicMotionTextPresetCompiler().compileBindings(
      request: MotionCompileRequest(
        project: project,
        textAnimationBindings: <MotionTextAnimationBindingModel>[
          MotionTextAnimationBindingModel(
            id: 'binding',
            elementTarget: target,
            activeRange: range,
            animationBlocks: <MotionTextAnimationBlock>[
              MotionTextAnimationBlock(
                id: 'family.bounce_in',
                kind: MotionTextAnimationKind.bounceIn,
                relativeRange: TimelineTimeRange(
                  start: TimelineTime.zero,
                  endExclusive: TimelineTime.fromMilliseconds(760),
                ),
                interpolation: const MotionInterpolationSpec.bounce(
                  bounce: MotionBounceSpec(
                    amplitude: 0.24,
                    bounces: 3,
                    decay: 6.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      elementsById: <String, MotionElementModel>{
        'text-1': project.scenes.single.layers.single.elements.single,
      },
    );

    expect(result.issues, isEmpty);
    final channelsByProperty = <String, MotionPropertyChannelModel>{
      for (final channel in result.generatedChannels)
        channel.definition.id: channel,
    };
    expect(
      channelsByProperty.keys,
      containsAll(<String>[
        MotionPropertyCatalog.opacity.id,
        MotionPropertyCatalog.scaleX.id,
        MotionPropertyCatalog.scaleY.id,
        MotionPropertyCatalog.positionY.id,
      ]),
    );
    final scaleX = channelsByProperty[MotionPropertyCatalog.scaleX.id]!;
    final positionY = channelsByProperty[MotionPropertyCatalog.positionY.id]!;
    final opacity = channelsByProperty[MotionPropertyCatalog.opacity.id]!;

    expect(scaleX.keyframes, hasLength(2));
    expect(scaleX.keyframes.first.value.rawValue, 0.68);
    expect(scaleX.keyframes.last.value.rawValue, 1.0);
    expect(
      scaleX.keyframes.first.interpolationToNext.kind,
      MotionInterpolationKind.bounce,
    );
    expect(positionY.keyframes.first.value.rawValue, 56);
    expect(positionY.keyframes.last.value.rawValue, 0);
    expect(
      positionY.keyframes.first.interpolationToNext.kind,
      MotionInterpolationKind.bounce,
    );
    expect(
      opacity.keyframes.first.interpolationToNext.kind,
      MotionInterpolationKind.easeOut,
    );
  });

  test('preset and scoped script import share the same interpolation parsing',
      () {
    const presetSource = '''
{
  "text": "Shared",
  "animationBlocks": [
    {
      "kind": "scaleIn",
      "startMs": 0,
      "durationMs": 400,
      "interpolation": "easy-ease"
    },
    {
      "kind": "blurIn",
      "startMs": 400,
      "durationMs": 300,
      "interpolation": {
        "kind": "SPRING",
        "stiffness": 260
      }
    }
  ]
}
''';
    const scriptSource = '''
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Shared",
  "channels": [
    {
      "property": "scale",
      "keyframes": [
        { "timeMs": 0, "value": 50, "easing": "easy-ease" },
        { "timeMs": 400, "value": 100 }
      ]
    },
    {
      "property": "opacity",
      "keyframes": [
        {
          "timeMs": 400,
          "value": 0,
          "easing": { "kind": "SPRING", "stiffness": 260 }
        },
        { "timeMs": 700, "value": 100 }
      ]
    }
  ]
}
''';

    final preset = MotionTextPresetJsonCodec.parsePresetString(presetSource);
    const service = ScopedTextMotionScriptImportService();
    final script = service.validate(source: scriptSource).document!;

    final presetEasyEase = preset.animationBlocks.first.interpolation;
    final scriptEasyEase = script.channels.first.keyframes.first.interpolation;
    expect(presetEasyEase.kind, MotionInterpolationKind.cubicBezier);
    expect(scriptEasyEase.kind, MotionInterpolationKind.cubicBezier);
    expect(
        presetEasyEase.bezier!.x1, closeTo(scriptEasyEase.bezier!.x1, 0.0001));
    expect(
        presetEasyEase.bezier!.x2, closeTo(scriptEasyEase.bezier!.x2, 0.0001));

    final presetSpring = preset.animationBlocks.last.interpolation;
    final scriptSpring = script.channels.last.keyframes.first.interpolation;
    expect(presetSpring.kind, MotionInterpolationKind.spring);
    expect(scriptSpring.kind, MotionInterpolationKind.spring);
    expect(presetSpring.spring!.stiffness, 260);
    expect(scriptSpring.spring!.stiffness, 260);
    expect(presetSpring.spring!.damping, scriptSpring.spring!.damping);
  });
}
