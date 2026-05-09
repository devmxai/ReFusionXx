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
      return SemanticSceneBlueprintComponent(
        id: component.id,
        type: _semanticTypeForRole(component.role),
        properties: <String, Object?>{
          ...component.properties,
          'directorRole': component.role,
          'directorLabel': component.label,
        },
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
      schemaVersion: 'refusion.semantic-blueprint/v1',
      name: plan.name,
      durationMs: plan.durationMs,
      frameRate: plan.frameRate,
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

  String _token(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), '_');
    return compact.isEmpty ? 'none' : compact;
  }
}
