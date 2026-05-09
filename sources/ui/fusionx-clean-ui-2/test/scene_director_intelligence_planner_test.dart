import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_director_brief_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_director_intelligence_planner.dart';

void main() {
  const planner = SceneDirectorIntelligencePlanner();

  test('plans beats, components, and primitives from director brief', () {
    final brief = SceneDirectorBrief(
      intent: 'Show four premium product features',
      audience: 'content creators',
      mood: 'energetic professional',
      primaryFocus: 'feature cards',
      rhythm: 'intro -> cascade -> outro',
      aspect: r'$canvas.vertical9x16',
      durationIntent: r'$duration.deliberate',
      elements: <SceneDirectorBriefElement>[
        SceneDirectorBriefElement(
          id: 'title',
          kind: 'title',
          importance: 'primary',
          text: 'Everything your launch needs',
        ),
        SceneDirectorBriefElement(
          id: 'cards',
          kind: 'featureCardGroup',
          importance: 'supporting',
          cards: const <SceneDirectorBriefCard>[
            SceneDirectorBriefCard(
              label: 'Fast',
              body: 'Polish edits in minutes',
              iconToken: r'$icon.montage',
            ),
            SceneDirectorBriefCard(
              label: 'Voice',
              body: 'Clean voiceovers in one tap',
              iconToken: r'$icon.audioEngineering',
            ),
            SceneDirectorBriefCard(
              label: 'Smart',
              body: 'Readable kinetic captions',
              iconToken: r'$icon.captions',
            ),
            SceneDirectorBriefCard(
              label: 'Image+',
              body: 'Retouch, grade, and color',
              iconToken: r'$icon.imageRetouch',
            ),
          ],
        ),
      ],
    );

    final result = planner.planFromBrief(brief);

    expect(result.isValid, isTrue);
    expect(result.plan, isNotNull);
    expect(result.plan!.beats, hasLength(3));
    expect(result.plan!.components, isNotEmpty);
    expect(result.plan!.primitives, isNotEmpty);
    expect(
      result.plan!.components.any((component) => component.id == 'background'),
      isTrue,
    );
    expect(
      result.plan!.components.any(
        (component) => component.id == 'background-micro-scene',
      ),
      isTrue,
    );
    expect(
      result.plan!.components
          .where((component) => component.id.contains('feature-card-'))
          .length,
      greaterThanOrEqualTo(16),
    );
    expect(
      result.plan!.components
          .where((component) => component.id.endsWith('-motif'))
          .length,
      4,
    );
    final primitiveKinds =
        result.plan!.primitives.map((primitive) => primitive.kind).toSet();
    expect(primitiveKinds.contains('scale'), isTrue);
    expect(
      result.plan!.primitives.any((primitive) => primitive.kind == 'slide'),
      isTrue,
    );

    final bodyComponent = result.plan!.components.firstWhere(
      (component) => component.id.endsWith('-body'),
    );
    final textFrame =
        bodyComponent.properties['textFrame'] as Map<String, Object?>?;
    expect(textFrame, isNotNull);
    expect(textFrame!['fitPolicy'], 'shrinkToFit');
    expect(textFrame['overflow'], 'ellipsis');
  });

  test('maps widescreen aspect to 1920x1080 canvas', () {
    final brief = SceneDirectorBrief(
      intent: 'Widescreen teaser',
      audience: 'general',
      mood: 'clean',
      primaryFocus: 'headline',
      rhythm: 'intro hold outro',
      aspect: r'$canvas.widescreen16x9',
      durationIntent: r'$duration.medium',
      elements: <SceneDirectorBriefElement>[
        SceneDirectorBriefElement(
          kind: 'title',
          importance: 'primary',
          text: 'Widescreen',
        ),
      ],
    );

    final result = planner.planFromBrief(brief);
    expect(result.isValid, isTrue);
    expect(result.plan!.canvasWidth, 1920);
    expect(result.plan!.canvasHeight, 1080);
  });

  test('adds warning for unsupported element kinds', () {
    final brief = SceneDirectorBrief(
      intent: 'Unknown kind sample',
      audience: 'general',
      mood: 'neutral',
      primaryFocus: 'headline',
      rhythm: 'intro hold outro',
      aspect: r'$canvas.vertical9x16',
      durationIntent: r'$duration.medium',
      elements: <SceneDirectorBriefElement>[
        SceneDirectorBriefElement(
          kind: 'title',
          importance: 'primary',
          text: 'Hello',
        ),
        SceneDirectorBriefElement(
          kind: 'unsupportedWidget',
          importance: 'supporting',
        ),
      ],
    );

    final result = planner.planFromBrief(brief);
    expect(result.plan, isNotNull);
    expect(
      result.issues.any(
        (issue) => issue.message.contains('unsupported element kind'),
      ),
      isTrue,
    );
  });

  test('injects brand-aware motion profile on branded feature cards', () {
    final brief = SceneDirectorBrief(
      intent: 'Brand profile check',
      audience: 'general',
      mood: 'energetic professional',
      primaryFocus: 'cards',
      rhythm: 'intro -> cascade -> outro',
      aspect: r'$canvas.vertical9x16',
      durationIntent: r'$duration.medium',
      elements: <SceneDirectorBriefElement>[
        SceneDirectorBriefElement(
          kind: 'title',
          importance: 'primary',
          text: 'Brands',
        ),
        SceneDirectorBriefElement(
          kind: 'featureCardGroup',
          importance: 'supporting',
          cards: const <SceneDirectorBriefCard>[
            SceneDirectorBriefCard(
              label: 'ChatGPT',
              body: 'AI workflow',
              brandToken: r'$brand.chatgpt',
            ),
          ],
        ),
      ],
    );

    final result = planner.planFromBrief(brief);
    expect(result.isValid, isTrue);
    final shell = result.plan!.components.firstWhere(
      (component) => component.id.endsWith('-shell'),
    );
    expect(shell.properties['brandMotionProfile'], r'$motion.brand.tech');
  });
}
