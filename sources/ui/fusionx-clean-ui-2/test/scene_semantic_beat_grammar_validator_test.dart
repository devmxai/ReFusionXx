import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_semantic_blueprint_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_beat_grammar_validator.dart';

void main() {
  const validator = SceneSemanticBeatGrammarValidator();

  test('fails closed when text beat hold is too short', () {
    final issues = validator.validate(
      beats: <SemanticSceneBlueprintBeat>[
        SemanticSceneBlueprintBeat(
          id: 'typing',
          startMs: 200,
          endMs: 500,
          intent: 'text typing',
          componentRefs: const <String>['prompt'],
        ),
      ],
      sceneDurationMs: 2000,
      components: <SemanticSceneBlueprintComponent>[
        SemanticSceneBlueprintComponent(id: 'prompt', type: 'PromptInputBar'),
      ],
    );

    expect(
      issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('not readable enough'),
      ),
      isTrue,
    );
  });

  test('fails closed when overlapping beats have no policy', () {
    final issues = validator.validate(
      beats: <SemanticSceneBlueprintBeat>[
        SemanticSceneBlueprintBeat(
          id: 'beat-a',
          startMs: 0,
          endMs: 1000,
          intent: 'card reveal',
          componentRefs: const <String>['card'],
        ),
        SemanticSceneBlueprintBeat(
          id: 'beat-b',
          startMs: 900,
          endMs: 2000,
          intent: 'card settle',
          componentRefs: const <String>['card'],
        ),
      ],
      sceneDurationMs: 2600,
      components: <SemanticSceneBlueprintComponent>[
        SemanticSceneBlueprintComponent(id: 'card', type: 'FeatureCard'),
      ],
    );

    expect(
      issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('without explicit overlap policy'),
      ),
      isTrue,
    );
  });

  test('fails closed for unknown beat component refs', () {
    final issues = validator.validate(
      beats: <SemanticSceneBlueprintBeat>[
        SemanticSceneBlueprintBeat(
          id: 'beat-a',
          startMs: 0,
          endMs: 1200,
          intent: 'panel intro',
          componentRefs: const <String>['missing-component'],
        ),
      ],
      sceneDurationMs: 2600,
      components: const <SemanticSceneBlueprintComponent>[],
    );

    expect(
      issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('references unknown component'),
      ),
      isTrue,
    );
  });

  test('accepts readable beats with allowed overlap policy and emits proof',
      () {
    final issues = validator.validate(
      beats: <SemanticSceneBlueprintBeat>[
        SemanticSceneBlueprintBeat(
          id: 'beat-a',
          startMs: 0,
          endMs: 1200,
          intent: 'panel intro',
          componentRefs: const <String>['panel'],
        ),
        SemanticSceneBlueprintBeat(
          id: 'beat-b',
          startMs: 1000,
          endMs: 2200,
          intent: 'panel handoff',
          overlapPolicy: 'handoff',
          componentRefs: const <String>['panel'],
        ),
      ],
      sceneDurationMs: 2600,
      components: <SemanticSceneBlueprintComponent>[
        SemanticSceneBlueprintComponent(id: 'panel', type: 'DashboardPanel'),
      ],
    );

    expect(issues.where((issue) => issue.severity.name == 'error'), isEmpty);
    expect(
      issues.any((issue) => issue.message.contains(kSceneBeatGrammarProofTag)),
      isTrue,
    );
  });
}
