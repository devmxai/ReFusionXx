import '../models/refusion_motion_director_models.dart';
import '../models/scene_director_brief_models.dart';
import '../models/scene_semantic_blueprint_models.dart';

const String kSceneDirectorPlannerProofTag = 'TF_SCENE_DIRECTOR_PLANNER_PROOF';

class SceneDirectorBlueprintCompilerResult {
  const SceneDirectorBlueprintCompilerResult({
    required this.blueprint,
    required this.issues,
  });

  final SemanticSceneBlueprint blueprint;
  final List<ReFusionMotionDirectorIssue> issues;
}

class SceneDirectorBlueprintCompiler {
  const SceneDirectorBlueprintCompiler();

  SceneDirectorBlueprintCompilerResult compile({
    required ReFusionMotionDirectorPlan plan,
    SceneDirectorBrief? sourceBrief,
  }) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final primitivesByComponent =
        <String, List<ReFusionMotionDirectorPrimitive>>{};
    for (final primitive in plan.primitives) {
      primitivesByComponent
          .putIfAbsent(primitive.targetComponentId,
              () => <ReFusionMotionDirectorPrimitive>[])
          .add(primitive);
    }

    final components = plan.components.map((component) {
      final intents = _motionIntentsForComponent(
        primitivesByComponent[component.id] ??
            const <ReFusionMotionDirectorPrimitive>[],
      );
      final semanticType = _semanticTypeForRole(component.role);
      return SemanticSceneBlueprintComponent(
        id: component.id,
        type: semanticType,
        iconToken: _iconTokenForComponent(component, semanticType),
        brandToken: _brandTokenForComponent(component),
        motionRecipe: _motionRecipeForComponent(component, semanticType),
        componentChoreography:
            _defaultComponentChoreography(component, semanticType),
        fitPolicy: _fitPolicyForComponent(component),
        compositionIntent: _componentCompositionIntent(component, semanticType),
        microScene: _microSceneTokenForComponent(component, semanticType),
        tasteProfile: _tasteProfileForBrief(sourceBrief),
        properties: _sanitizeComponentProperties(
          <String, Object?>{
            ...component.properties,
            'directorRole': component.role,
            'directorLabel': component.label,
          },
        ),
        motionIntents: intents,
      );
    }).toList(growable: false);

    final beats = plan.beats.map((beat) {
      return SemanticSceneBlueprintBeat(
        id: beat.id,
        startMs: beat.startMs,
        endMs: beat.endMs,
        intent: beat.intent,
        componentRefs: beat.componentRefs,
      );
    }).toList(growable: false);

    final blueprint = SemanticSceneBlueprint(
      schemaVersion: 'refusion.semantic-blueprint/v5',
      name: plan.name,
      durationMs: plan.durationMs,
      frameRate: plan.frameRate,
      compositionIntent: _compositionIntentForBrief(sourceBrief),
      tasteProfile: _tasteProfileForBrief(sourceBrief),
      components: components,
      beats: beats,
      metadata: <String, Object?>{
        'source': 'directorBrief',
        'sourceSchema': SceneDirectorBrief.currentSchemaVersion,
        'directorPlanSchema': plan.schemaVersion,
        'directorIntent': sourceBrief?.intent,
        'directorMood': sourceBrief?.mood,
        'directorAspect': sourceBrief?.aspect,
      },
    );

    issues.add(
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.info,
        message: '$kSceneDirectorPlannerProofTag '
            'name=${_token(plan.name)} '
            'componentCount=${components.length} '
            'beatCount=${beats.length} '
            'source=${sourceBrief == null ? 'director_plan' : 'director_brief'} '
            'fallbackReason=none',
        path: 'directorBlueprintCompiler',
      ),
    );

    return SceneDirectorBlueprintCompilerResult(
      blueprint: blueprint,
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  Map<String, Object?> _motionIntentsForComponent(
    List<ReFusionMotionDirectorPrimitive> primitives,
  ) {
    if (primitives.isEmpty) {
      return const <String, Object?>{};
    }
    final timeline = primitives
        .map(
          (primitive) => <String, Object?>{
            'id': primitive.id,
            'beatId': primitive.beatId,
            'kind': primitive.kind,
            'property': primitive.property,
            'startMs': primitive.startMs,
            'endMs': primitive.endMs,
            'easing': primitive.easing,
            'from': primitive.fromValue,
            'to': primitive.toValue,
          },
        )
        .toList(growable: false);
    return <String, Object?>{
      'timeline': timeline,
      'count': timeline.length,
    };
  }

  String _semanticTypeForRole(String role) {
    final normalized = role.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (normalized == 'background') {
      return 'SceneBackground';
    }
    if (normalized == 'backgroundmotif' || normalized == 'featuremotif') {
      return 'DecorativeMotif';
    }
    if (normalized == 'shapecard') {
      return 'FeatureCard';
    }
    if (normalized.startsWith('text')) {
      return 'MotionTextBlock';
    }
    if (normalized == 'icon') {
      return 'IconGlyph';
    }
    return 'GenericComponent';
  }

  String _iconTokenForComponent(
    ReFusionMotionDirectorComponent component,
    String semanticType,
  ) {
    final explicit = (component.properties['iconToken'] as String?)?.trim();
    if (explicit != null && explicit.startsWith(r'$icon.')) {
      return explicit;
    }
    if (semanticType == 'FeatureCard' || semanticType == 'IconGlyph') {
      return r'$icon.module';
    }
    if (semanticType == 'SceneBackground') {
      return r'$icon.grid';
    }
    return r'$icon.spark';
  }

  String _brandTokenForComponent(ReFusionMotionDirectorComponent component) {
    final explicit = (component.properties['brandToken'] as String?)?.trim();
    if (explicit != null && explicit.startsWith(r'$brand.')) {
      return explicit;
    }
    return r'$brand.generic';
  }

  String _motionRecipeForComponent(
    ReFusionMotionDirectorComponent component,
    String semanticType,
  ) {
    final explicit = (component.properties['motionRecipe'] as String?)?.trim();
    if (explicit != null && explicit.startsWith(r'$motion.')) {
      return explicit;
    }
    if (semanticType == 'FeatureCard') {
      return r'$motion.cardSpringEntrance';
    }
    if (semanticType == 'MotionTextBlock') {
      return r'$motion.wordCascadeUp';
    }
    if (semanticType == 'SceneBackground') {
      return r'$motion.softFadeUp';
    }
    return r'$motion.scaleIn';
  }

  Map<String, Object?> _defaultComponentChoreography(
    ReFusionMotionDirectorComponent component,
    String semanticType,
  ) {
    final raw = component.properties['componentChoreography'];
    if (raw is Map<String, Object?>) {
      return raw;
    }
    if (semanticType == 'FeatureCard') {
      return const <String, Object?>{
        'enterRecipe': r'$motion.cardSpringEntrance',
        'exitRecipe': r'$motion.fadeCollapse',
      };
    }
    if (semanticType == 'MotionTextBlock') {
      return const <String, Object?>{
        'enterRecipe': r'$motion.wordCascadeUp',
        'exitRecipe': r'$motion.fadeCollapse',
      };
    }
    return const <String, Object?>{
      'enterRecipe': r'$motion.scaleIn',
      'exitRecipe': r'$motion.fadeCollapse',
    };
  }

  String _fitPolicyForComponent(ReFusionMotionDirectorComponent component) {
    final explicit = (component.properties['fitPolicy'] as String?)?.trim();
    if (explicit != null && explicit.startsWith(r'$textFit.')) {
      return explicit;
    }
    return r'$textFit.wrapToLines';
  }

  String _componentCompositionIntent(
    ReFusionMotionDirectorComponent component,
    String semanticType,
  ) {
    final explicit =
        (component.properties['compositionIntent'] as String?)?.trim();
    if (explicit != null && explicit.startsWith(r'$composition.')) {
      return explicit;
    }
    if (semanticType == 'SceneBackground') {
      return r'$composition.backgroundSupport';
    }
    if (semanticType == 'FeatureCard') {
      return r'$composition.featureGrid';
    }
    if (semanticType == 'MotionTextBlock') {
      return r'$composition.heroFocus';
    }
    return r'$composition.supporting';
  }

  String _microSceneTokenForComponent(
    ReFusionMotionDirectorComponent component,
    String semanticType,
  ) {
    final explicit = (component.properties['microScene'] as String?)?.trim() ??
        (component.properties['microSceneId'] as String?)?.trim();
    if (explicit != null && explicit.startsWith(r'$microScene.')) {
      return explicit;
    }
    if (semanticType == 'SceneBackground') {
      return r'$microScene.gridSoft';
    }
    if (semanticType == 'FeatureCard') {
      return r'$microScene.modulePulse';
    }
    return r'$microScene.none';
  }

  String _compositionIntentForBrief(SceneDirectorBrief? brief) {
    final focus = (brief?.primaryFocus ?? '').toLowerCase();
    if (focus.contains('feature')) {
      return r'$composition.featureShowcase';
    }
    if (focus.contains('title') || focus.contains('hero')) {
      return r'$composition.heroFocus';
    }
    return r'$composition.supporting';
  }

  String _tasteProfileForBrief(SceneDirectorBrief? brief) {
    final mood = (brief?.mood ?? '').toLowerCase();
    if (mood.contains('luxury') ||
        mood.contains('minimal') ||
        mood.contains('calm')) {
      return r'$taste.luxuryCalm';
    }
    return r'$taste.modernProfessional';
  }

  String _token(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), '_');
    return compact.isEmpty ? 'none' : compact;
  }

  Map<String, Object?> _sanitizeComponentProperties(
    Map<String, Object?> source,
  ) {
    final disallowedChildGeometryKeys = <String>{
      'children',
      'child',
      'childnodes',
      'childcomponents',
      'parentid',
      'parent',
      'childcoordinates',
      'childposition',
      'childx',
      'childy',
      'slotchildren',
      'localx',
      'localy',
      'childlayout',
      'childbounds',
    };
    final output = <String, Object?>{};
    source.forEach((key, value) {
      final normalized = key
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '');
      if (disallowedChildGeometryKeys.contains(normalized)) {
        return;
      }
      output[key] = value;
    });
    return output;
  }
}
