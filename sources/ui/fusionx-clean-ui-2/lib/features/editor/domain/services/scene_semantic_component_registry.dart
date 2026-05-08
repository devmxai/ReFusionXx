import 'dart:collection';

import '../models/refusion_scene_program_models.dart';
import '../models/scene_semantic_blueprint_models.dart';

const String kSceneComponentRegistryProofTag =
    'TF_SCENE_COMPONENT_REGISTRY_PROOF';

class SceneSemanticComponentDefinition {
  const SceneSemanticComponentDefinition({
    required this.id,
    required this.aliases,
    required this.requiredSlots,
    required this.optionalSlots,
    required this.allowedVariants,
  });

  final String id;
  final Set<String> aliases;
  final Set<String> requiredSlots;
  final Set<String> optionalSlots;
  final Set<String> allowedVariants;
}

class SceneSemanticComponentRegistry {
  SceneSemanticComponentRegistry({
    Map<String, SceneSemanticComponentDefinition>? definitions,
  }) : _definitions =
            UnmodifiableMapView<String, SceneSemanticComponentDefinition>(
          definitions ?? _defaultDefinitions,
        );

  final Map<String, SceneSemanticComponentDefinition> _definitions;

  SceneSemanticComponentDefinition? findByType(String type) {
    final normalizedType = _normalize(type);
    for (final definition in _definitions.values) {
      if (_normalize(definition.id) == normalizedType) {
        return definition;
      }
      if (definition.aliases
          .any((alias) => _normalize(alias) == normalizedType)) {
        return definition;
      }
    }
    return null;
  }

  List<ReFusionSceneProgramIssue> validateComponent({
    required SemanticSceneBlueprintComponent component,
    required int index,
  }) {
    final issues = <ReFusionSceneProgramIssue>[];
    final pathPrefix = 'components[$index]';
    final definition = findByType(component.type);
    if (definition == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Unsupported semantic component `${component.type}`. Register it in Component Registry v2 before use.',
          path: '$pathPrefix.type',
        ),
      );
      return issues;
    }

    final requestedVariant = component.variant?.trim();
    if (requestedVariant != null && requestedVariant.isNotEmpty) {
      final normalized = _normalize(requestedVariant);
      final allowed = definition.allowedVariants.any(
        (it) => _normalize(it) == normalized,
      );
      if (!allowed) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Unsupported variant `$requestedVariant` for component `${definition.id}`.',
            path: '$pathPrefix.variant',
          ),
        );
      }
    }

    for (final requiredSlot in definition.requiredSlots) {
      if (!component.slots.containsKey(requiredSlot)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Component `${definition.id}` requires slot `$requiredSlot`.',
            path: '$pathPrefix.slots.$requiredSlot',
          ),
        );
      }
    }

    final allowedSlots = <String>{
      ...definition.requiredSlots,
      ...definition.optionalSlots,
    };
    for (final providedSlot in component.slots.keys) {
      if (!allowedSlots.contains(providedSlot)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Slot `$providedSlot` is not supported by component `${definition.id}`.',
            path: '$pathPrefix.slots.$providedSlot',
          ),
        );
      }
    }

    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneComponentRegistryProofTag '
            'componentId=${component.id} '
            'componentType=${component.type} '
            'canonicalType=${definition.id} '
            'variant=${requestedVariant ?? 'default'} '
            'requiredSlots=${definition.requiredSlots.length} '
            'providedSlots=${component.slots.length} '
            'errors='
            '${issues.where((it) => it.severity == ReFusionSceneProgramIssueSeverity.error).length}',
        path: pathPrefix,
      ),
    );
    return issues;
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

const Set<String> _defaultVariants = <String>{
  'default',
  'focused',
  'loading',
  'disabled',
  'error',
  'success',
  'selected',
};

final Map<String, SceneSemanticComponentDefinition> _defaultDefinitions =
    <String, SceneSemanticComponentDefinition>{
  'PromptInputBar': SceneSemanticComponentDefinition(
    id: 'PromptInputBar',
    aliases: const <String>{'prompt_input_bar', 'prompt-bar', 'chatInputBar'},
    requiredSlots: const <String>{'primaryText', 'trailingAccessory'},
    optionalSlots: const <String>{'leadingAccessory', 'placeholder'},
    allowedVariants: _defaultVariants,
  ),
  'FeedbackCard': SceneSemanticComponentDefinition(
    id: 'FeedbackCard',
    aliases: const <String>{'feedback-card', 'reviewCard'},
    requiredSlots: const <String>{'leadingIcon', 'title', 'body'},
    optionalSlots: const <String>{'meta', 'badge'},
    allowedVariants: _defaultVariants,
  ),
  'FeatureCard': SceneSemanticComponentDefinition(
    id: 'FeatureCard',
    aliases: const <String>{'feature-card'},
    requiredSlots: const <String>{'title', 'body'},
    optionalSlots: const <String>{'media', 'badge', 'cta'},
    allowedVariants: _defaultVariants,
  ),
  'ResultCard': SceneSemanticComponentDefinition(
    id: 'ResultCard',
    aliases: const <String>{'result-card'},
    requiredSlots: const <String>{'title', 'summary'},
    optionalSlots: const <String>{'media', 'metrics', 'cta'},
    allowedVariants: _defaultVariants,
  ),
  'DashboardPanel': SceneSemanticComponentDefinition(
    id: 'DashboardPanel',
    aliases: const <String>{'dashboard-panel'},
    requiredSlots: const <String>{'header', 'body'},
    optionalSlots: const <String>{'footer', 'badge'},
    allowedVariants: _defaultVariants,
  ),
  'AppIconIntro': SceneSemanticComponentDefinition(
    id: 'AppIconIntro',
    aliases: const <String>{'app-icon-intro', 'iconIntro'},
    requiredSlots: const <String>{'icon'},
    optionalSlots: const <String>{'label'},
    allowedVariants: _defaultVariants,
  ),
  'CTAButton': SceneSemanticComponentDefinition(
    id: 'CTAButton',
    aliases: const <String>{'cta-button', 'actionButton'},
    requiredSlots: const <String>{'label'},
    optionalSlots: const <String>{'leadingIcon', 'trailingIcon'},
    allowedVariants: _defaultVariants,
  ),
  'IconButton': SceneSemanticComponentDefinition(
    id: 'IconButton',
    aliases: const <String>{'icon-button'},
    requiredSlots: const <String>{'icon'},
    optionalSlots: const <String>{'badge'},
    allowedVariants: _defaultVariants,
  ),
  'MotionTextBlock': SceneSemanticComponentDefinition(
    id: 'MotionTextBlock',
    aliases: const <String>{'motion-text-block', 'textBlock'},
    requiredSlots: const <String>{'text'},
    optionalSlots: const <String>{'subtitle', 'kicker'},
    allowedVariants: _defaultVariants,
  ),
  'FloatingWindowCard': SceneSemanticComponentDefinition(
    id: 'FloatingWindowCard',
    aliases: const <String>{'floating-window-card', 'windowCard'},
    requiredSlots: const <String>{'title', 'body'},
    optionalSlots: const <String>{'leadingIcon', 'trailingBadge'},
    allowedVariants: _defaultVariants,
  ),
  'OrbitalFeatureRing': SceneSemanticComponentDefinition(
    id: 'OrbitalFeatureRing',
    aliases: const <String>{'orbital-feature-ring', 'featureRing'},
    requiredSlots: const <String>{'centerLabel', 'orbitNodeA', 'orbitNodeB'},
    optionalSlots: const <String>{'orbitNodeC', 'orbitNodeD'},
    allowedVariants: _defaultVariants,
  ),
};
