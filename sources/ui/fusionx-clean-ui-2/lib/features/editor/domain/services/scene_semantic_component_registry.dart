import 'dart:collection';

import '../models/refusion_scene_program_models.dart';
import '../models/scene_semantic_blueprint_models.dart';

const String kSceneComponentRegistryProofTag =
    'TF_SCENE_COMPONENT_REGISTRY_PROOF';
const String kSceneComponentHierarchyProofTag =
    'TF_SCENE_COMPONENT_HIERARCHY_PROOF';
const String kSceneSemanticRootParentType = 'sceneRoot';

enum SceneSemanticRuntimeNodeType {
  sceneRoot,
  beatScope,
  group,
  component,
  slot,
  shape,
  text,
  icon,
  image,
  video,
  effectAttachment,
}

enum SceneSemanticBoundsPolicy {
  finiteRequired,
  slotInherited,
  componentDerived,
  freeform,
}

enum SceneSemanticTransformPolicy {
  parentComposed,
  componentOwned,
  freeform,
}

enum SceneSemanticLifecyclePolicy {
  beatScoped,
  parentScoped,
  persistent,
}

enum SceneSemanticZOrderPolicy {
  slotOrder,
  explicitWithinParent,
  freeform,
}

enum SceneSemanticTextFitPolicy {
  requiredBounded,
  optionalBounded,
  freeform,
}

enum SceneSemanticMotionOwnershipPolicy {
  componentRootOnly,
  slotChildren,
  distributed,
}

class SceneSemanticSlotDefinition {
  const SceneSemanticSlotDefinition({
    required this.id,
    this.acceptsText = false,
    this.requiresBoundedText = false,
    this.allowedNodeTypes = const <SceneSemanticRuntimeNodeType>{},
  });

  final String id;
  final bool acceptsText;
  final bool requiresBoundedText;
  final Set<SceneSemanticRuntimeNodeType> allowedNodeTypes;
}

class SceneSemanticComponentDefinition {
  const SceneSemanticComponentDefinition({
    required this.id,
    required this.aliases,
    required this.requiredSlots,
    required this.optionalSlots,
    required this.allowedVariants,
    this.runtimeNodeType = SceneSemanticRuntimeNodeType.component,
    this.allowedParentTypes = const <String>{kSceneSemanticRootParentType},
    this.slotDefinitions = const <String, SceneSemanticSlotDefinition>{},
    this.boundsPolicy = SceneSemanticBoundsPolicy.componentDerived,
    this.transformPolicy = SceneSemanticTransformPolicy.parentComposed,
    this.lifecyclePolicy = SceneSemanticLifecyclePolicy.beatScoped,
    this.zOrderPolicy = SceneSemanticZOrderPolicy.slotOrder,
    this.textFitPolicy = SceneSemanticTextFitPolicy.requiredBounded,
    this.motionOwnershipPolicy =
        SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  });

  final String id;
  final Set<String> aliases;
  final Set<String> requiredSlots;
  final Set<String> optionalSlots;
  final Set<String> allowedVariants;
  final SceneSemanticRuntimeNodeType runtimeNodeType;
  final Set<String> allowedParentTypes;
  final Map<String, SceneSemanticSlotDefinition> slotDefinitions;
  final SceneSemanticBoundsPolicy boundsPolicy;
  final SceneSemanticTransformPolicy transformPolicy;
  final SceneSemanticLifecyclePolicy lifecyclePolicy;
  final SceneSemanticZOrderPolicy zOrderPolicy;
  final SceneSemanticTextFitPolicy textFitPolicy;
  final SceneSemanticMotionOwnershipPolicy motionOwnershipPolicy;

  bool supportsParentType(String? parentType) {
    final normalizedAllowed = allowedParentTypes
        .map((value) => SceneSemanticComponentRegistry.normalizeToken(value))
        .toSet();
    final candidate = SceneSemanticComponentRegistry.normalizeToken(
      parentType ?? kSceneSemanticRootParentType,
    );
    return normalizedAllowed.contains(candidate);
  }

  SceneSemanticSlotDefinition? slotDefinitionFor(String slotId) {
    final normalized = SceneSemanticComponentRegistry.normalizeToken(slotId);
    for (final entry in slotDefinitions.entries) {
      if (SceneSemanticComponentRegistry.normalizeToken(entry.key) ==
          normalized) {
        return entry.value;
      }
    }
    return null;
  }
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
    final normalizedType = normalizeToken(type);
    for (final definition in _definitions.values) {
      if (normalizeToken(definition.id) == normalizedType) {
        return definition;
      }
      if (definition.aliases
          .any((alias) => normalizeToken(alias) == normalizedType)) {
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
      final normalized = normalizeToken(requestedVariant);
      final allowed = definition.allowedVariants
          .any((variant) => normalizeToken(variant) == normalized);
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

    final parentType = _readParentType(component.properties);
    if (!definition.supportsParentType(parentType)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Component `${definition.id}` does not allow parent type `${parentType ?? kSceneSemanticRootParentType}`.',
          path: '$pathPrefix.properties.parentType',
        ),
      );
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
        continue;
      }
      final slotDefinition = definition.slotDefinitionFor(providedSlot);
      if (slotDefinition == null) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Slot `$providedSlot` is missing a typed hierarchy contract in component `${definition.id}`.',
            path: '$pathPrefix.slots.$providedSlot',
          ),
        );
        continue;
      }
      _validateSlotNodeType(
        component: component,
        definition: definition,
        slotDefinition: slotDefinition,
        slotId: providedSlot,
        slotValue: component.slots[providedSlot],
        pathPrefix: pathPrefix,
        issues: issues,
      );
    }

    final errorCount = issues
        .where((issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error)
        .length;
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
            'errors=$errorCount',
        path: pathPrefix,
      ),
    );
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneComponentHierarchyProofTag '
            'componentId=${component.id} '
            'canonicalType=${definition.id} '
            'runtimeNodeType=${definition.runtimeNodeType.name} '
            'parentType=${parentType ?? kSceneSemanticRootParentType} '
            'boundsPolicy=${definition.boundsPolicy.name} '
            'transformPolicy=${definition.transformPolicy.name} '
            'lifecyclePolicy=${definition.lifecyclePolicy.name} '
            'zOrderPolicy=${definition.zOrderPolicy.name} '
            'textFitPolicy=${definition.textFitPolicy.name} '
            'motionOwnershipPolicy=${definition.motionOwnershipPolicy.name}',
        path: pathPrefix,
      ),
    );
    return issues;
  }

  void _validateSlotNodeType({
    required SemanticSceneBlueprintComponent component,
    required SceneSemanticComponentDefinition definition,
    required SceneSemanticSlotDefinition slotDefinition,
    required String slotId,
    required Object? slotValue,
    required String pathPrefix,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    if (slotValue is! Map<String, Object?>) {
      return;
    }
    final nodeTypeRaw = slotValue['nodeType'];
    if (nodeTypeRaw is! String || nodeTypeRaw.trim().isEmpty) {
      return;
    }
    final nodeType = _parseNodeType(nodeTypeRaw);
    if (nodeType == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Unsupported slot nodeType `$nodeTypeRaw` in `$slotId` for component `${definition.id}`.',
          path: '$pathPrefix.slots.$slotId.nodeType',
        ),
      );
      return;
    }
    if (!slotDefinition.allowedNodeTypes.contains(nodeType)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Slot `$slotId` in component `${definition.id}` does not allow node type `${nodeType.name}`.',
          path: '$pathPrefix.slots.$slotId.nodeType',
        ),
      );
    }
    if (slotDefinition.acceptsText &&
        slotDefinition.requiresBoundedText &&
        nodeType == SceneSemanticRuntimeNodeType.text &&
        !_slotHasTextFrame(slotValue)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Text slot `$slotId` in component `${definition.id}` requires `textFrame` contract for bounded rendering.',
          path: '$pathPrefix.slots.$slotId.textFrame',
        ),
      );
    }
  }

  bool _slotHasTextFrame(Map<String, Object?> slotValue) {
    final textFrame = slotValue['textFrame'];
    if (textFrame is! Map) {
      return false;
    }
    final width = textFrame['width'];
    final height = textFrame['height'];
    return width is num &&
        width > 0 &&
        height is num &&
        height > 0 &&
        width.isFinite &&
        height.isFinite;
  }

  SceneSemanticRuntimeNodeType? _parseNodeType(String raw) {
    final normalized = normalizeToken(raw);
    for (final value in SceneSemanticRuntimeNodeType.values) {
      if (normalizeToken(value.name) == normalized) {
        return value;
      }
    }
    return null;
  }

  String? _readParentType(Map<String, Object?> properties) {
    final explicit = properties['parentType'];
    if (explicit is String && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }
    final parent = properties['parent'];
    if (parent is Map<String, Object?>) {
      final parentType = parent['type'];
      if (parentType is String && parentType.trim().isNotEmpty) {
        return parentType.trim();
      }
    }
    return null;
  }

  static String normalizeToken(String value) =>
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

const Set<SceneSemanticRuntimeNodeType> _textNodes =
    <SceneSemanticRuntimeNodeType>{SceneSemanticRuntimeNodeType.text};
const Set<SceneSemanticRuntimeNodeType> _iconNodes =
    <SceneSemanticRuntimeNodeType>{SceneSemanticRuntimeNodeType.icon};
const Set<SceneSemanticRuntimeNodeType> _shapeNodes =
    <SceneSemanticRuntimeNodeType>{SceneSemanticRuntimeNodeType.shape};
const Set<SceneSemanticRuntimeNodeType> _shapeAndTextNodes =
    <SceneSemanticRuntimeNodeType>{
  SceneSemanticRuntimeNodeType.shape,
  SceneSemanticRuntimeNodeType.text,
};
const Set<SceneSemanticRuntimeNodeType> _shapeIconTextNodes =
    <SceneSemanticRuntimeNodeType>{
  SceneSemanticRuntimeNodeType.shape,
  SceneSemanticRuntimeNodeType.icon,
  SceneSemanticRuntimeNodeType.text,
};

final Map<String, SceneSemanticComponentDefinition> _defaultDefinitions =
    <String, SceneSemanticComponentDefinition>{
  'PromptInputBar': SceneSemanticComponentDefinition(
    id: 'PromptInputBar',
    aliases: const <String>{'prompt_input_bar', 'prompt-bar', 'chatInputBar'},
    requiredSlots: const <String>{'primaryText', 'trailingAccessory'},
    optionalSlots: const <String>{'leadingAccessory', 'placeholder'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{
      kSceneSemanticRootParentType,
      'DashboardPanel',
      'FeatureCard',
    },
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'primaryText': SceneSemanticSlotDefinition(
        id: 'primaryText',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'trailingAccessory': SceneSemanticSlotDefinition(
        id: 'trailingAccessory',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
      'leadingAccessory': SceneSemanticSlotDefinition(
        id: 'leadingAccessory',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
      'placeholder': SceneSemanticSlotDefinition(
        id: 'placeholder',
        acceptsText: true,
        requiresBoundedText: false,
        allowedNodeTypes: _textNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.requiredBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  ),
  'FeedbackCard': SceneSemanticComponentDefinition(
    id: 'FeedbackCard',
    aliases: const <String>{'feedback-card', 'reviewCard'},
    requiredSlots: const <String>{'leadingIcon', 'title', 'body'},
    optionalSlots: const <String>{'meta', 'badge'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{
      kSceneSemanticRootParentType,
      'DashboardPanel',
      'FloatingWindowCard',
    },
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'leadingIcon': SceneSemanticSlotDefinition(
        id: 'leadingIcon',
        allowedNodeTypes: _iconNodes,
      ),
      'title': SceneSemanticSlotDefinition(
        id: 'title',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'body': SceneSemanticSlotDefinition(
        id: 'body',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'meta': SceneSemanticSlotDefinition(
        id: 'meta',
        acceptsText: true,
        requiresBoundedText: false,
        allowedNodeTypes: _shapeAndTextNodes,
      ),
      'badge': SceneSemanticSlotDefinition(
        id: 'badge',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.requiredBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  ),
  'FeatureCard': SceneSemanticComponentDefinition(
    id: 'FeatureCard',
    aliases: const <String>{'feature-card'},
    requiredSlots: const <String>{'title', 'body'},
    optionalSlots: const <String>{'media', 'badge', 'cta'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{
      kSceneSemanticRootParentType,
      'DashboardPanel',
    },
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'title': SceneSemanticSlotDefinition(
        id: 'title',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'body': SceneSemanticSlotDefinition(
        id: 'body',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'media': SceneSemanticSlotDefinition(
        id: 'media',
        allowedNodeTypes: <SceneSemanticRuntimeNodeType>{
          SceneSemanticRuntimeNodeType.image,
          SceneSemanticRuntimeNodeType.video,
          SceneSemanticRuntimeNodeType.shape,
        },
      ),
      'badge': SceneSemanticSlotDefinition(
        id: 'badge',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
      'cta': SceneSemanticSlotDefinition(
        id: 'cta',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.requiredBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  ),
  'ResultCard': SceneSemanticComponentDefinition(
    id: 'ResultCard',
    aliases: const <String>{'result-card'},
    requiredSlots: const <String>{'title', 'summary'},
    optionalSlots: const <String>{'media', 'metrics', 'cta'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{kSceneSemanticRootParentType},
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'title': SceneSemanticSlotDefinition(
        id: 'title',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'summary': SceneSemanticSlotDefinition(
        id: 'summary',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'media': SceneSemanticSlotDefinition(
        id: 'media',
        allowedNodeTypes: <SceneSemanticRuntimeNodeType>{
          SceneSemanticRuntimeNodeType.image,
          SceneSemanticRuntimeNodeType.video,
          SceneSemanticRuntimeNodeType.shape,
        },
      ),
      'metrics': SceneSemanticSlotDefinition(
        id: 'metrics',
        allowedNodeTypes: _shapeAndTextNodes,
      ),
      'cta': SceneSemanticSlotDefinition(
        id: 'cta',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.requiredBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  ),
  'DashboardPanel': SceneSemanticComponentDefinition(
    id: 'DashboardPanel',
    aliases: const <String>{'dashboard-panel'},
    requiredSlots: const <String>{'header', 'body'},
    optionalSlots: const <String>{'footer', 'badge'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{kSceneSemanticRootParentType},
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'header': SceneSemanticSlotDefinition(
        id: 'header',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _shapeIconTextNodes,
      ),
      'body': SceneSemanticSlotDefinition(
        id: 'body',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _shapeIconTextNodes,
      ),
      'footer': SceneSemanticSlotDefinition(
        id: 'footer',
        acceptsText: true,
        requiresBoundedText: false,
        allowedNodeTypes: _shapeIconTextNodes,
      ),
      'badge': SceneSemanticSlotDefinition(
        id: 'badge',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.requiredBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.distributed,
  ),
  'AppIconIntro': SceneSemanticComponentDefinition(
    id: 'AppIconIntro',
    aliases: const <String>{'app-icon-intro', 'iconIntro'},
    requiredSlots: const <String>{'icon'},
    optionalSlots: const <String>{'label'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{kSceneSemanticRootParentType},
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'icon': SceneSemanticSlotDefinition(
        id: 'icon',
        allowedNodeTypes: _iconNodes,
      ),
      'label': SceneSemanticSlotDefinition(
        id: 'label',
        acceptsText: true,
        requiresBoundedText: false,
        allowedNodeTypes: _textNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.optionalBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  ),
  'CTAButton': SceneSemanticComponentDefinition(
    id: 'CTAButton',
    aliases: const <String>{'cta-button', 'actionButton'},
    requiredSlots: const <String>{'label'},
    optionalSlots: const <String>{'leadingIcon', 'trailingIcon'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{
      kSceneSemanticRootParentType,
      'PromptInputBar',
      'FeatureCard',
      'ResultCard',
      'DashboardPanel',
    },
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'label': SceneSemanticSlotDefinition(
        id: 'label',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'leadingIcon': SceneSemanticSlotDefinition(
        id: 'leadingIcon',
        allowedNodeTypes: _iconNodes,
      ),
      'trailingIcon': SceneSemanticSlotDefinition(
        id: 'trailingIcon',
        allowedNodeTypes: _iconNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.requiredBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  ),
  'IconButton': SceneSemanticComponentDefinition(
    id: 'IconButton',
    aliases: const <String>{'icon-button'},
    requiredSlots: const <String>{'icon'},
    optionalSlots: const <String>{'badge'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{
      kSceneSemanticRootParentType,
      'PromptInputBar',
      'FeatureCard',
      'ResultCard',
      'DashboardPanel',
    },
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'icon': SceneSemanticSlotDefinition(
        id: 'icon',
        allowedNodeTypes: _iconNodes,
      ),
      'badge': SceneSemanticSlotDefinition(
        id: 'badge',
        allowedNodeTypes: _shapeAndTextNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.optionalBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  ),
  'MotionTextBlock': SceneSemanticComponentDefinition(
    id: 'MotionTextBlock',
    aliases: const <String>{'motion-text-block', 'textBlock'},
    requiredSlots: const <String>{'text'},
    optionalSlots: const <String>{'subtitle', 'kicker'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{kSceneSemanticRootParentType},
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'text': SceneSemanticSlotDefinition(
        id: 'text',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'subtitle': SceneSemanticSlotDefinition(
        id: 'subtitle',
        acceptsText: true,
        requiresBoundedText: false,
        allowedNodeTypes: _textNodes,
      ),
      'kicker': SceneSemanticSlotDefinition(
        id: 'kicker',
        acceptsText: true,
        requiresBoundedText: false,
        allowedNodeTypes: _textNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.requiredBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  ),
  'FloatingWindowCard': SceneSemanticComponentDefinition(
    id: 'FloatingWindowCard',
    aliases: const <String>{'floating-window-card', 'windowCard'},
    requiredSlots: const <String>{'title', 'body'},
    optionalSlots: const <String>{'leadingIcon', 'trailingBadge'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{kSceneSemanticRootParentType},
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'title': SceneSemanticSlotDefinition(
        id: 'title',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'body': SceneSemanticSlotDefinition(
        id: 'body',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'leadingIcon': SceneSemanticSlotDefinition(
        id: 'leadingIcon',
        allowedNodeTypes: _iconNodes,
      ),
      'trailingBadge': SceneSemanticSlotDefinition(
        id: 'trailingBadge',
        allowedNodeTypes: _shapeAndTextNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.requiredBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.componentRootOnly,
  ),
  'OrbitalFeatureRing': SceneSemanticComponentDefinition(
    id: 'OrbitalFeatureRing',
    aliases: const <String>{'orbital-feature-ring', 'featureRing'},
    requiredSlots: const <String>{'centerLabel', 'orbitNodeA', 'orbitNodeB'},
    optionalSlots: const <String>{'orbitNodeC', 'orbitNodeD'},
    allowedVariants: _defaultVariants,
    allowedParentTypes: const <String>{kSceneSemanticRootParentType},
    slotDefinitions: const <String, SceneSemanticSlotDefinition>{
      'centerLabel': SceneSemanticSlotDefinition(
        id: 'centerLabel',
        acceptsText: true,
        requiresBoundedText: true,
        allowedNodeTypes: _textNodes,
      ),
      'orbitNodeA': SceneSemanticSlotDefinition(
        id: 'orbitNodeA',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
      'orbitNodeB': SceneSemanticSlotDefinition(
        id: 'orbitNodeB',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
      'orbitNodeC': SceneSemanticSlotDefinition(
        id: 'orbitNodeC',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
      'orbitNodeD': SceneSemanticSlotDefinition(
        id: 'orbitNodeD',
        allowedNodeTypes: _shapeIconTextNodes,
      ),
    },
    boundsPolicy: SceneSemanticBoundsPolicy.componentDerived,
    transformPolicy: SceneSemanticTransformPolicy.parentComposed,
    lifecyclePolicy: SceneSemanticLifecyclePolicy.beatScoped,
    zOrderPolicy: SceneSemanticZOrderPolicy.slotOrder,
    textFitPolicy: SceneSemanticTextFitPolicy.requiredBounded,
    motionOwnershipPolicy: SceneSemanticMotionOwnershipPolicy.slotChildren,
  ),
};
