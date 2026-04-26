import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/motion_authoring_bundle_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_import_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_motion_lowering_service.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/motion_authoring_bundle_timeline_adapter.dart';

void main() {
  const importer = ReFusionSceneProgramImportService();
  const lowerer = ReFusionSceneProgramMotionLoweringService();
  const adapter = MotionAuthoringBundleTimelineAdapter();

  TimelineTime time(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(start: time(start), endExclusive: time(end));
  }

  test('projects a lowered scene program bundle into editable lanes', () {
    const source = '''
{
  "kind": "refusion.sceneProgram",
  "schemaVersion": "refusion.scene-program/v1",
  "id": "intro-pop",
  "durationMs": 1000,
  "elements": [
    {"id": "title", "kind": "text", "text": "FUSION"}
  ],
  "channels": [
    {
      "id": "title.opacity",
      "targetId": "title",
      "property": "visual.opacity",
      "keyframes": [
        {"timeMs": 0, "value": 0},
        {"timeMs": 1000, "value": 1}
      ]
    },
    {
      "id": "title.rotation",
      "targetId": "title",
      "property": "transform.rotation.degrees",
      "keyframes": [
        {"timeMs": 500, "value": 12}
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

    final projected = adapter.projectBundle(
      bundle: lowered.bundle!,
      window: range(0, 1),
      targetClipIdsByTargetId: const <String, String>{'title': 'clip-title'},
      labelsByChannelId: const <String, String>{
        'title.opacity': 'Opacity',
      },
    );

    expect(projected.hasIssues, isFalse);
    expect(projected.lanes.map((lane) => lane.id), <String>[
      'title.opacity',
      'title.rotation',
    ]);
    expect(projected.lanes.first.label, 'Opacity');
    expect(projected.lanes.first.targetClipId, 'clip-title');
    expect(projected.lanes.first.keyframeIds, <String>[
      'title.opacity.keyframe.0',
      'title.opacity.keyframe.1',
    ]);
    expect(projected.lanes.first.normalizedKeyframeStops, <double>[0, 1]);
    expect(projected.lanes.first.keyframeValues, <double>[0, 100]);
    expect(projected.lanes.last.label, 'rotation.degrees');
    expect(projected.lanes.last.normalizedKeyframeStops, <double>[0.5]);
    expect(projected.lanes.last.keyframeValues, <double>[12]);
  });

  test('reports unsupported bundle channels without dropping valid lanes', () {
    const target = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'title',
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer',
      elementId: 'title',
    );
    final bundle = MotionAuthoringBundle(
      origin: MotionAuthoringOrigin(
        kind: MotionAuthoringSourceKind.script,
        id: 'mixed',
      ),
      propertyChannels: <MotionPropertyChannelModel>[
        MotionPropertyChannelModel(
          id: 'title.opacity',
          target: target,
          definition: MotionPropertyCatalog.opacity,
          keyframes: <MotionKeyframeModel>[
            MotionKeyframeModel(
              id: 'opacity-0',
              channelId: 'title.opacity',
              time: time(0),
              value: const MotionPropertyValue.scalar(1),
              interpolationToNext: const MotionInterpolationSpec.linear(),
            ),
          ],
        ),
        MotionPropertyChannelModel(
          id: 'title.crop',
          target: target,
          definition: MotionPropertyCatalog.cropRect,
        ),
      ],
    );

    final projected = adapter.projectBundle(
      bundle: bundle,
      window: range(0, 1),
      targetClipIdsByTargetId: const <String, String>{'title': 'clip-title'},
    );

    expect(projected.hasIssues, isTrue);
    expect(projected.lanes.map((lane) => lane.id), <String>['title.opacity']);
    expect(projected.issues.single.channelId, 'title.crop');
    expect(projected.issues.single.targetId, 'title');
  });
}
