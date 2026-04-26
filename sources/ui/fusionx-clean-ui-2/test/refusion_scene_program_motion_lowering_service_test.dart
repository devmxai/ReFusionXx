import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_import_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_motion_lowering_service.dart';

void main() {
  const importer = ReFusionSceneProgramImportService();
  const lowerer = ReFusionSceneProgramMotionLoweringService();

  test('lowers a valid scene program into an editable authoring bundle', () {
    const source = '''
{
  "kind": "refusion.sceneProgram",
  "schemaVersion": "refusion.scene-program/v1",
  "id": "intro-pop",
  "name": "Intro Pop",
  "durationMs": 2000,
  "elements": [
    {"id": "title", "kind": "text", "text": "FUSION"}
  ],
  "channels": [
    {
      "id": "title.opacity",
      "targetId": "title",
      "property": "visual.opacity",
      "keyframes": [
        {"timeMs": 0, "value": 0, "interpolation": "linear"},
        {"timeMs": 350, "value": 1, "interpolation": "easeOut"}
      ]
    }
  ]
}
''';

    final imported = importer.validate(source: source);
    final lowered = lowerer.lower(
      document: imported.document!,
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer',
    );

    expect(lowered.canApply, isTrue);
    final bundle = lowered.bundle!;
    expect(bundle.origin.kind, MotionAuthoringSourceKind.script);
    expect(bundle.origin.id, 'intro-pop');
    expect(
        bundle.origin.metadata['schemaVersion'], 'refusion.scene-program/v1');
    expect(bundle.elements.single.id, 'title');
    expect(bundle.elements.single.kind, MotionElementKind.text);
    expect(bundle.elements.single.sourceBinding!.kind,
        MotionSourceKind.generatedText);
    expect(bundle.propertyChannels.single.id, 'title.opacity');
    expect(bundle.propertyChannels.single.target.targetId, 'title');
    expect(bundle.propertyChannels.single.definition.id,
        MotionPropertyCatalog.opacity.id);
    expect(
      bundle.propertyChannels.single.keyframes.map((keyframe) => keyframe.id),
      <String>['title.opacity.keyframe.0', 'title.opacity.keyframe.1'],
    );
    expect(
      bundle.propertyChannels.single.keyframes.last.interpolationToNext.kind,
      MotionInterpolationKind.easeOut,
    );
  });

  test('rejects duplicate keyframe times before creating a bundle', () {
    const source = '''
{
  "kind": "refusion.sceneProgram",
  "schemaVersion": "refusion.scene-program/v1",
  "id": "duplicate-time",
  "durationMs": 1000,
  "channels": [
    {
      "id": "title.opacity",
      "targetId": "title",
      "property": "visual.opacity",
      "keyframes": [
        {"timeMs": 0, "value": 0},
        {"timeMs": 0, "value": 1}
      ]
    }
  ]
}
''';

    final imported = importer.validate(source: source);
    final lowered = lowerer.lower(
      document: imported.document!,
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer',
    );

    expect(lowered.canApply, isFalse);
    expect(lowered.bundle, isNull);
    expect(
      lowered.issues.single.code,
      ReFusionSceneProgramLoweringIssueCode.duplicateKeyframeTime,
    );
  });

  test('rejects keyframes outside the scene duration', () {
    const source = '''
{
  "kind": "refusion.sceneProgram",
  "schemaVersion": "refusion.scene-program/v1",
  "id": "out-of-range",
  "durationMs": 1000,
  "channels": [
    {
      "id": "title.opacity",
      "targetId": "title",
      "property": "visual.opacity",
      "keyframes": [
        {"timeMs": 1200, "value": 1}
      ]
    }
  ]
}
''';

    final imported = importer.validate(source: source);
    final lowered = lowerer.lower(
      document: imported.document!,
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer',
    );

    expect(lowered.canApply, isFalse);
    expect(lowered.bundle, isNull);
    expect(
      lowered.issues.single.code,
      ReFusionSceneProgramLoweringIssueCode.keyframeOutOfRange,
    );
  });
}
