import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_import_service.dart';

void main() {
  const service = ReFusionSceneProgramImportService();

  test('parses a strict editable JSON scene program', () {
    const source = '''
{
  "kind": "refusion.sceneProgram",
  "schemaVersion": "refusion.scene-program/v1",
  "id": "intro-pop",
  "name": "Intro Pop",
  "durationMs": 2000,
  "elements": [
    {
      "id": "title",
      "kind": "text",
      "text": "FUSION",
      "range": {"startMs": 0, "endMs": 2000}
    }
  ],
  "channels": [
    {
      "id": "title.opacity",
      "targetId": "title",
      "property": "visual.opacity",
      "keyframes": [
        {"timeMs": 0, "value": 0, "interpolation": "linear"},
        {"timeMs": 350, "value": 1, "interpolation": {"kind": "spring", "stiffness": 260, "damping": 22}}
      ]
    }
  ]
}
''';

    final result = service.validate(source: source, fileName: 'intro.json');

    expect(result.canApply, isTrue);
    expect(result.issues, isEmpty);
    final document = result.document!;
    expect(document.schemaVersion, kReFusionSceneProgramSchemaVersion);
    expect(document.id, 'intro-pop');
    expect(document.name, 'Intro Pop');
    expect(document.duration.inMilliseconds, 2000);
    expect(document.elements.single.id, 'title');
    expect(document.elements.single.kind, MotionElementKind.text);
    expect(document.elements.single.range!.start.inMilliseconds, 0);
    expect(document.elements.single.range!.endExclusive.inMilliseconds, 2000);
    expect(document.channels.single.id, 'title.opacity');
    expect(document.channels.single.targetId, 'title');
    expect(document.channels.single.definition.id,
        MotionPropertyCatalog.opacity.id);
    expect(document.channels.single.keyframes.first.time.inMilliseconds, 0);
    expect(document.channels.single.keyframes.first.value.rawValue, 0);
    expect(
      document.channels.single.keyframes.last.interpolation.kind,
      MotionInterpolationKind.spring,
    );
  });

  test('requires schemaVersion instead of silently guessing a schema', () {
    const source = '''
{
  "kind": "refusion.sceneProgram",
  "id": "missing-schema",
  "durationMs": 1000
}
''';

    final result = service.validate(source: source);

    expect(result.canApply, isFalse);
    expect(result.document, isNull);
    expect(
      result.issues.single.code,
      ReFusionSceneProgramIssueCode.missingSchemaVersion,
    );
  });

  test('rejects executable fields anywhere in the program', () {
    const source = '''
{
  "kind": "refusion.sceneProgram",
  "schemaVersion": "refusion.scene-program/v1",
  "id": "bad",
  "durationMs": 1000,
  "channels": [
    {
      "id": "bad.opacity",
      "targetId": "title",
      "property": "visual.opacity",
      "keyframes": [
        {"timeMs": 0, "value": 0, "eval": "danger()"}
      ]
    }
  ]
}
''';

    final result = service.validate(source: source);

    expect(result.canApply, isFalse);
    expect(
      result.issues.map((issue) => issue.code),
      contains(ReFusionSceneProgramIssueCode.executableField),
    );
  });

  test('rejects unsupported properties with clear paths', () {
    const source = '''
{
  "kind": "refusion.sceneProgram",
  "schemaVersion": "refusion.scene-program/v1",
  "id": "bad-property",
  "durationMs": 1000,
  "channels": [
    {
      "id": "bad",
      "targetId": "title",
      "property": "unknown.magic",
      "keyframes": [
        {"timeMs": 0, "value": 0}
      ]
    }
  ]
}
''';

    final result = service.validate(source: source);

    expect(result.canApply, isFalse);
    expect(
      result.issues
          .singleWhere(
            (issue) =>
                issue.code == ReFusionSceneProgramIssueCode.unsupportedProperty,
          )
          .path,
      'channels[0].property',
    );
  });

  test('accepts fenced JSON without allowing non-json uploads', () {
    const source = '''
```json
{
  "kind": "refusion.sceneProgram",
  "schemaVersion": "refusion.scene-program/v1",
  "id": "fenced",
  "durationSeconds": 1
}
```
''';

    final result = service.validate(source: source, fileName: 'scene.json');
    final badFile = service.validate(source: source, fileName: 'scene.jsx');

    expect(result.canApply, isTrue);
    expect(result.document!.duration.inMilliseconds, 1000);
    expect(badFile.canApply, isFalse);
    expect(
      badFile.issues.single.code,
      ReFusionSceneProgramIssueCode.invalidFileType,
    );
  });
}
