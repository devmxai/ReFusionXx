import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_mention_index.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const index = SceneMentionIndex();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: ms(startMs),
      endExclusive: ms(endMs),
    );
  }

  MotionProjectModel project({
    String firstName = 'Logo',
    bool includeSecondElement = true,
  }) {
    final first = MotionElementModel(
      id: 'shape-logo',
      layerId: 'shape-layer',
      kind: MotionElementKind.shape,
      shapeKind: MotionShapeKind.circle,
      localRange: range(0, 3000),
      name: firstName,
    );
    final second = MotionElementModel(
      id: 'text-logo',
      layerId: 'text-layer',
      kind: MotionElementKind.text,
      localRange: range(0, 3000),
      name: 'Logo',
    );

    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'root',
          projectRange: range(0, 6000),
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'shape-layer',
              sceneId: 'root',
              kind: MotionLayerKind.shape,
              visibleRange: range(0, 3000),
              name: 'Shape Layer',
              elements: <MotionElementModel>[first],
            ),
            MotionLayerModel(
              id: 'text-layer',
              sceneId: 'root',
              kind: MotionLayerKind.text,
              visibleRange: range(0, 3000),
              name: 'Text Layer',
              elements: includeSecondElement
                  ? <MotionElementModel>[second]
                  : const <MotionElementModel>[],
            ),
          ],
        ),
      ],
    );
  }

  test('indexes scene clips and animatable scene elements', () {
    final result = index.buildForScene(
      project: project(firstName: 'Reveal Dot'),
      sceneId: 'root',
      sceneClips: <CompositionSceneClipModel>[
        CompositionSceneClipModel(
          id: 'scene-clip',
          sourceSceneId: 'nested',
          name: 'Intro Scene',
          startTime: ms(0),
          durationTime: ms(3000),
        ),
      ],
    );

    expect(result.hasIssues, isFalse);
    expect(
      result.entities.map((entity) => entity.mentionId),
      containsAll(<String>[
        'sceneClip:scene-clip',
        'element:shape-logo',
        'element:text-logo',
      ]),
    );

    final shape = result.entityByMentionId('element:shape-logo')!;
    expect(shape.displayName, 'Reveal Dot');
    expect(shape.typeLabel, 'Circle');
    expect(
        shape.supportedProperties.map((property) => property.id),
        containsAll(
          <String>[
            MotionPropertyCatalog.positionX.id,
            MotionPropertyCatalog.width.id,
            MotionPropertyCatalog.opacity.id,
          ],
        ));

    final text = result.entityByMentionId('element:text-logo')!;
    expect(text.typeLabel, 'Text');
    expect(
      text.supportedProperties.map((property) => property.id),
      contains(MotionPropertyCatalog.revealProgress.id),
    );
  });

  test('disambiguates duplicate display names without changing stable IDs', () {
    final result = index.buildForScene(
      project: project(),
      sceneId: 'root',
    );

    expect(result.issues.single.code,
        SceneMentionIndexIssueCode.duplicateDisplayName);
    expect(result.entityByMentionId('element:shape-logo')!.displayName,
        'Logo (1)');
    expect(
        result.entityByMentionId('element:text-logo')!.displayName, 'Logo (2)');
    expect(
        result.entityByMentionId('element:shape-logo')!.targetId, 'shape-logo');
  });

  test('renaming changes labels but preserves mention IDs', () {
    final before = index.buildForScene(
      project: project(firstName: 'Logo'),
      sceneId: 'root',
    );
    final after = index.buildForScene(
      project: project(firstName: 'Brand Dot'),
      sceneId: 'root',
    );

    expect(before.containsMentionId('element:shape-logo'), isTrue);
    expect(after.containsMentionId('element:shape-logo'), isTrue);
    expect(after.entityByMentionId('element:shape-logo')!.displayName,
        'Brand Dot');
  });

  test('deleted elements become invalid mentions in the rebuilt index', () {
    final before = index.buildForScene(
      project: project(),
      sceneId: 'root',
    );
    final mentionId = before.entityByMentionId('element:text-logo')!.mentionId;

    final after = index.buildForScene(
      project: project(includeSecondElement: false),
      sceneId: 'root',
    );

    expect(after.entityByMentionId(mentionId), isNull);
  });

  test('missing scene reports a typed issue', () {
    final result = index.buildForScene(
      project: project(),
      sceneId: 'missing',
    );

    expect(result.entities, isEmpty);
    expect(result.issues.single.code, SceneMentionIndexIssueCode.missingScene);
  });
}
