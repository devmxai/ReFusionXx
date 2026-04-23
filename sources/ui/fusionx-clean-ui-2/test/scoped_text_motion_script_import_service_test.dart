import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/services/scoped_text_motion_script_import_service.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';

void main() {
  const service = ScopedTextMotionScriptImportService();

  test('parses JSON channel scripts without target ids', () {
    const source = '''
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Fade In",
  "channels": [
    {
      "property": "opacity",
      "keyframes": [
        { "timeMs": 0, "value": 0, "easing": "linear" },
        { "timeMs": 200, "value": 100, "easing": "easeOut" }
      ]
    }
  ]
}
''';

    final validation = service.validate(source: source);

    expect(validation.canApply, isTrue);
    expect(validation.document, isNotNull);
    expect(validation.document!.channels, hasLength(1));
    expect(validation.document!.channels.single.property, 'opacity');
    expect(validation.document!.channels.single.keyframes, hasLength(2));
  });

  test('parses YAML channel scripts', () {
    const source = '''
schemaVersion: refusion.scope-text-script/v1
name: Move Up
channels:
  - property: positionY
    keyframes:
      - timeMs: 0
        value: 60
      - timeMs: 800
        value: 0
        easing: easyEase
''';

    final validation = service.validate(source: source, fileName: 'move.yaml');

    expect(validation.canApply, isTrue);
    expect(validation.document, isNotNull);
    expect(validation.document!.channels.single.property, 'positionY');
    expect(
        validation.document!.channels.single.keyframes.last.time.inMilliseconds,
        800);
  });

  test('rejects JSX input with a clear validation error', () {
    const source = '''
export default function Scene() {
  return <Sequence from={0} durationInFrames={30}></Sequence>;
}
''';

    final validation = service.validate(source: source, fileName: 'scene.jsx');

    expect(validation.canApply, isFalse);
    expect(validation.document, isNull);
    expect(
      validation.issues.any(
        (issue) => issue.message.toLowerCase().contains('jsx'),
      ),
      isTrue,
    );
  });

  test('parses animationBlocks aliases and derives reveal metadata', () {
    const source = '''
{
  "name": "Word Reveal",
  "reveal": {
    "by": "word",
    "direction": "reverse"
  },
  "motions": [
    {
      "kind": "wordReveal",
      "startMs": 0,
      "durationMs": 900
    }
  ]
}
''';

    final validation = service.validate(source: source);

    expect(validation.canApply, isTrue);
    expect(validation.document, isNotNull);
    expect(validation.document!.animationBlocks, hasLength(1));
    expect(validation.document!.animationBlocks.single.kind,
        MotionTextAnimationKind.wordReveal);
    expect(validation.document!.revealUnit, MotionTextRevealUnit.word);
    expect(validation.document!.revealDirection,
        MotionTextRevealDirection.reverse);
  });

  test('parses named professional effect families with canonical defaults', () {
    const source = '''
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Family Pass",
  "animationBlocks": [
    {
      "kind": "bounceIn",
      "startMs": 0,
      "durationMs": 760
    },
    {
      "kind": "riseIn",
      "startMs": 760,
      "durationMs": 680
    },
    {
      "kind": "slideIn",
      "startMs": 1440,
      "durationMs": 720
    },
    {
      "kind": "elasticPop",
      "startMs": 2160,
      "durationMs": 620
    },
    {
      "kind": "blurRiseIn",
      "startMs": 2780,
      "durationMs": 760
    },
    {
      "kind": "rotateIn",
      "startMs": 3540,
      "durationMs": 720
    }
  ]
}
''';

    final validation = service.validate(source: source);

    expect(validation.canApply, isTrue);
    final blocks = validation.document!.animationBlocks;
    expect(blocks, hasLength(6));
    expect(blocks.first.kind, MotionTextAnimationKind.bounceIn);
    expect(blocks.first.interpolation.kind, MotionInterpolationKind.bounce);
    expect(blocks.first.interpolation.bounce, isNotNull);
    expect(blocks[1].kind, MotionTextAnimationKind.riseIn);
    expect(blocks[1].interpolation.kind, MotionInterpolationKind.spring);
    expect(blocks[1].interpolation.spring, isNotNull);
    expect(blocks[2].kind, MotionTextAnimationKind.slideIn);
    expect(blocks[2].interpolation.kind, MotionInterpolationKind.spring);
    expect(blocks[2].interpolation.spring, isNotNull);
    expect(blocks[3].kind, MotionTextAnimationKind.elasticPop);
    expect(blocks[3].interpolation.kind, MotionInterpolationKind.elastic);
    expect(blocks[3].interpolation.elastic, isNotNull);
    expect(blocks[4].kind, MotionTextAnimationKind.blurRiseIn);
    expect(blocks[4].interpolation.kind, MotionInterpolationKind.spring);
    expect(blocks[4].interpolation.spring, isNotNull);
    expect(blocks.last.kind, MotionTextAnimationKind.rotateIn);
    expect(blocks.last.interpolation.kind, MotionInterpolationKind.spring);
    expect(blocks.last.interpolation.spring, isNotNull);
  });

  test('parses canonical spring, bounce, and elastic interpolation specs', () {
    const source = '''
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Boing Entrance",
  "channels": [
    {
      "property": "scale",
      "keyframes": [
        { "timeMs": 0, "value": 40, "easing": "spring" },
        {
          "timeMs": 260,
          "value": 112,
          "easing": {
            "kind": "bounce",
            "amplitude": 0.22,
            "bounces": 4,
            "decay": 6.0
          }
        },
        {
          "timeMs": 420,
          "value": 100,
          "easing": {
            "kind": "elastic",
            "amplitude": 0.14,
            "period": 0.3,
            "decay": 7.5
          }
        }
      ]
    }
  ]
}
''';

    final validation = service.validate(source: source);

    expect(validation.canApply, isTrue);
    final keyframes = validation.document!.channels.single.keyframes;
    expect(keyframes.first.interpolation.kind, MotionInterpolationKind.spring);
    expect(keyframes.first.interpolation.spring, isNotNull);
    expect(keyframes.first.interpolation.spring!.stiffness, 220);

    expect(keyframes[1].interpolation.kind, MotionInterpolationKind.bounce);
    expect(keyframes[1].interpolation.bounce, isNotNull);
    expect(keyframes[1].interpolation.bounce!.amplitude, 0.22);
    expect(keyframes[1].interpolation.bounce!.bounces, 4);
    expect(keyframes[1].interpolation.bounce!.decay, 6.0);

    expect(keyframes[2].interpolation.kind, MotionInterpolationKind.elastic);
    expect(keyframes[2].interpolation.elastic, isNotNull);
    expect(keyframes[2].interpolation.elastic!.amplitude, 0.14);
    expect(keyframes[2].interpolation.elastic!.period, 0.3);
    expect(keyframes[2].interpolation.elastic!.decay, 7.5);
  });
}
