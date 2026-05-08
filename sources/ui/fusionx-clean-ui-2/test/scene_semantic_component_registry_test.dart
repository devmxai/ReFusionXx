import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_semantic_blueprint_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_component_registry.dart';

void main() {
  final registry = SceneSemanticComponentRegistry();

  test('resolves component aliases to canonical component ids', () {
    final definition = registry.findByType('feedback-card');
    expect(definition, isNotNull);
    expect(definition!.id, 'FeedbackCard');
  });

  test('fails closed for unknown component type', () {
    final issues = registry.validateComponent(
      component: SemanticSceneBlueprintComponent(
        id: 'unknown',
        type: 'UnknownThing',
      ),
      index: 0,
    );
    expect(
      issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('Unsupported semantic component'),
      ),
      isTrue,
    );
  });

  test('fails closed for unsupported variant', () {
    final issues = registry.validateComponent(
      component: SemanticSceneBlueprintComponent(
        id: 'prompt',
        type: 'PromptInputBar',
        variant: 'hoveredGlow',
        slots: const <String, Object?>{
          'primaryText': 'hello',
          'trailingAccessory': 'send',
        },
      ),
      index: 0,
    );
    expect(
      issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('Unsupported variant'),
      ),
      isTrue,
    );
  });

  test('fails closed when required slot is missing', () {
    final issues = registry.validateComponent(
      component: SemanticSceneBlueprintComponent(
        id: 'prompt',
        type: 'PromptInputBar',
        slots: const <String, Object?>{
          'primaryText': 'hello',
        },
      ),
      index: 0,
    );
    expect(
      issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('requires slot `trailingAccessory`'),
      ),
      isTrue,
    );
  });

  test('fails closed when unsupported slot is provided', () {
    final issues = registry.validateComponent(
      component: SemanticSceneBlueprintComponent(
        id: 'feature',
        type: 'FeatureCard',
        slots: const <String, Object?>{
          'title': 'A',
          'body': 'B',
          'random': 'C',
        },
      ),
      index: 0,
    );
    expect(
      issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('Slot `random` is not supported'),
      ),
      isTrue,
    );
  });

  test('accepts valid component slot contract and emits proof', () {
    final issues = registry.validateComponent(
      component: SemanticSceneBlueprintComponent(
        id: 'feedback-1',
        type: 'FeedbackCard',
        variant: 'default',
        slots: const <String, Object?>{
          'leadingIcon': 'gmail',
          'title': 'Gmail',
          'body': 'Feedback body',
        },
      ),
      index: 0,
    );
    expect(issues.where((issue) => issue.severity.name == 'error'), isEmpty);
    expect(
      issues.any(
        (issue) => issue.message.contains(kSceneComponentRegistryProofTag),
      ),
      isTrue,
    );
  });
}
