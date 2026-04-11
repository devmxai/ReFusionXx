import 'package:flutter_test/flutter_test.dart';

import 'package:refusion_app/features/editor/domain/models/professional_motion_text_preset_serialization.dart';

void main() {
  test('motion-only preset JSON auto-generates required preset fields', () {
    const source = '''
{
  "text": "Hello Motion",
  "animationBlocks": [
    {
      "kind": "fadeIn",
      "startMs": 0,
      "durationMs": 600
    }
  ]
}
''';

    final preset = MotionTextPresetJsonCodec.parsePresetString(source);

    expect(preset.id, startsWith('custom.generated.'));
    expect(preset.kind.name, 'custom');
    expect(preset.label, 'Hello Motion');
    expect(preset.defaultText, 'Hello Motion');
    expect(preset.animationBlocks, hasLength(1));
    expect(preset.animationBlocks.first.id, 'fadeIn_0');
  });

  test(
      'motion-only preset JSON supports blocks alias and start/duration aliases',
      () {
    const source = '''
{
  "text": "Alias Test",
  "blocks": [
    {
      "kind": "scaleIn",
      "start": 120,
      "duration": 500
    }
  ]
}
''';

    final preset = MotionTextPresetJsonCodec.parsePresetString(source);

    expect(preset.defaultText, 'Alias Test');
    expect(
      preset.animationBlocks.first.relativeRange.start.inMilliseconds,
      120,
    );
    expect(
      preset.animationBlocks.first.relativeRange.endExclusive.inMilliseconds,
      620,
    );
  });

  test('parser accepts markdown fenced JSON and stringified animationBlocks',
      () {
    const source = '''
```json
{
  "text": "Fence Test",
  "animationBlocks": "[{\\"kind\\":\\"fadeIn\\",\\"startMs\\":0,\\"durationMs\\":400}]"
}
```
''';

    final preset = MotionTextPresetJsonCodec.parsePresetString(source);

    expect(preset.defaultText, 'Fence Test');
    expect(preset.animationBlocks, hasLength(1));
    expect(preset.animationBlocks.first.kind.name, 'fadeIn');
  });
}
