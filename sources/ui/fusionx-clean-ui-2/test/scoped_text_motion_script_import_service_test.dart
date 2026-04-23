import 'package:flutter_test/flutter_test.dart';
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
}
