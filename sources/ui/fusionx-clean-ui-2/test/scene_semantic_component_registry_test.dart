import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_semantic_blueprint_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_component_registry.dart';

void main() {
  final registry = SceneSemanticComponentRegistry();

  test('exposes component library v1 vocabulary for director authoring', () {
    final ids = registry.supportedComponentIds;
    expect(ids.length, greaterThanOrEqualTo(30));
    expect(
      ids,
      containsAll(<String>[
        'PromptInputBar',
        'SearchBar',
        'TextField',
        'FeatureCard',
        'StatCard',
        'TestimonialCard',
        'ProductCard',
        'ImageCard',
        'CTAButton',
        'IconButton',
        'FAB',
        'ToggleButton',
        'DashboardPanel',
        'FeatureGrid',
        'FeatureList',
        'HeroSection',
        'AppIconIntro',
        'BrandLogo',
        'AvatarBadge',
        'Toast',
        'AlertCard',
        'ProgressIndicator',
        'VideoPlayer',
        'AudioWaveform',
        'ColorGradePanel',
        'MotionTextBlock',
        'KineticTitle',
        'TypingPrompt',
        'QuoteBlock',
        'OrbitalRing',
      ]),
    );
  });

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
    expect(
      issues.any(
        (issue) => issue.message.contains(kSceneComponentHierarchyProofTag),
      ),
      isTrue,
    );
  });

  test('fails closed when parent type is not allowed for component', () {
    final issues = registry.validateComponent(
      component: SemanticSceneBlueprintComponent(
        id: 'prompt',
        type: 'PromptInputBar',
        properties: const <String, Object?>{
          'parentType': 'OrbitalFeatureRing',
        },
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
            issue.path == 'components[0].properties.parentType' &&
            issue.message.contains('does not allow parent type'),
      ),
      isTrue,
    );
  });

  test('fails closed when slot nodeType violates typed hierarchy contract', () {
    final issues = registry.validateComponent(
      component: SemanticSceneBlueprintComponent(
        id: 'feedback-1',
        type: 'FeedbackCard',
        slots: const <String, Object?>{
          'leadingIcon': <String, Object?>{
            'nodeType': 'text',
            'text': 'gmail',
          },
          'title': <String, Object?>{
            'nodeType': 'text',
            'text': 'Gmail',
            'textFrame': <String, Object?>{'width': 420, 'height': 46},
          },
          'body': <String, Object?>{
            'nodeType': 'text',
            'text': 'Body',
            'textFrame': <String, Object?>{'width': 520, 'height': 180},
          },
        },
      ),
      index: 0,
    );
    expect(
      issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.path == 'components[0].slots.leadingIcon.nodeType' &&
            issue.message.contains('does not allow node type'),
      ),
      isTrue,
    );
  });

  test('instantiates executable runtime template for valid component', () {
    final runtime = registry.instantiateRuntimeTemplate(
      component: SemanticSceneBlueprintComponent(
        id: 'prompt-1',
        type: 'PromptInputBar',
        variant: 'focused',
        slots: const <String, Object?>{
          'primaryText': <String, Object?>{
            'nodeType': 'text',
            'text': 'Generate new offer',
            'textFrame': <String, Object?>{
              'width': 480.0,
              'height': 44.0,
            },
          },
          'trailingAccessory': <String, Object?>{
            'nodeType': 'icon',
            'icon': 'send',
          },
        },
      ),
      index: 0,
    );

    expect(runtime.isValid, isTrue,
        reason: runtime.issues.map((issue) => issue.message).join('\n'));
    expect(runtime.nodes, isNotNull);
    final nodes = runtime.nodes!;
    expect(nodes.first.id, 'prompt-1');
    expect(nodes.first.parentId, isNull);
    expect(
      nodes.where((node) => node.nodeType.name == 'slot').length,
      2,
    );
    expect(
      runtime.issues.any(
        (issue) =>
            issue.severity.name == 'info' &&
            issue.message.contains(kSceneComponentHierarchyProofTag) &&
            issue.message.contains('instantiatedRuntimeTemplate=true'),
      ),
      isTrue,
    );
  });
}
