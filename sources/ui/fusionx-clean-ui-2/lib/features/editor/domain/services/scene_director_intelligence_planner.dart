import 'dart:math' as math;

import '../models/refusion_motion_director_models.dart';
import '../models/scene_director_brief_models.dart';
import 'scene_background_semantic_pairing.dart';
import 'scene_brand_motion_mapping.dart';
import 'scene_component_choreography_compiler.dart';
import 'scene_component_choreography_engine.dart';
import 'scene_component_choreography_models.dart';
import 'scene_composition_solver.dart';
import 'scene_feature_visual_motifs.dart';
import 'scene_icon_registry.dart';
import 'scene_inter_component_choreography.dart';
import 'scene_motion_recipe_compiler.dart';
import 'scene_motion_recipe_models.dart';

class SceneDirectorIntelligencePlanResult {
  const SceneDirectorIntelligencePlanResult({
    required this.issues,
    this.plan,
  });

  final ReFusionMotionDirectorPlan? plan;
  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid =>
      plan != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class SceneDirectorIntelligencePlanner {
  const SceneDirectorIntelligencePlanner({
    SceneMotionRecipeCompiler recipeCompiler =
        const SceneMotionRecipeCompiler(),
    SceneIconRegistry iconRegistry = const SceneIconRegistry(),
    SceneBrandMotionMapping brandMotionMapping =
        const SceneBrandMotionMapping(),
    SceneComponentChoreographyEngine componentChoreographyEngine =
        const SceneComponentChoreographyEngine(),
    SceneComponentChoreographyCompiler choreographyCompiler =
        const SceneComponentChoreographyCompiler(),
    SceneInterComponentChoreographySolver interComponentSolver =
        const SceneInterComponentChoreographySolver(),
    SceneBackgroundSemanticPairing backgroundPairing =
        const SceneBackgroundSemanticPairing(),
    SceneFeatureVisualMotifs featureVisualMotifs =
        const SceneFeatureVisualMotifs(),
    SceneCompositionSolver compositionSolver = const SceneCompositionSolver(),
  })  : _recipeCompiler = recipeCompiler,
        _iconRegistry = iconRegistry,
        _brandMotionMapping = brandMotionMapping,
        _componentChoreographyEngine = componentChoreographyEngine,
        _choreographyCompiler = choreographyCompiler,
        _interComponentSolver = interComponentSolver,
        _backgroundPairing = backgroundPairing,
        _featureVisualMotifs = featureVisualMotifs,
        _compositionSolver = compositionSolver;

  final SceneMotionRecipeCompiler _recipeCompiler;
  final SceneIconRegistry _iconRegistry;
  final SceneBrandMotionMapping _brandMotionMapping;
  final SceneComponentChoreographyEngine _componentChoreographyEngine;
  final SceneComponentChoreographyCompiler _choreographyCompiler;
  final SceneInterComponentChoreographySolver _interComponentSolver;
  final SceneBackgroundSemanticPairing _backgroundPairing;
  final SceneFeatureVisualMotifs _featureVisualMotifs;
  final SceneCompositionSolver _compositionSolver;

  SceneDirectorIntelligencePlanResult planFromBrief(
    SceneDirectorBrief brief,
  ) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final canvas = _canvasForAspect(brief.aspect);
    final durationMs = _durationForIntent(brief.durationIntent);
    final introEnd = (durationMs * 0.25).round();
    final featuresEnd = (durationMs * 0.8).round();
    final maxFeatureCards = brief.elements
        .where((element) => _normalize(element.kind) == 'featurecardgroup')
        .fold<int>(0, (max, element) => math.max(max, element.cards.length));
    final composition = _compositionSolver.solve(
      canvasWidth: canvas.width.toDouble(),
      canvasHeight: canvas.height.toDouble(),
      featureCardCount: maxFeatureCards,
    );
    final backgroundPairing = _backgroundPairing.resolve(brief);
    issues.addAll(composition.issues);
    issues.addAll(backgroundPairing.issues);

    final components = <ReFusionMotionDirectorComponent>[
      ReFusionMotionDirectorComponent(
        id: 'background',
        role: 'background',
        label: 'Background',
        properties: <String, Object?>{
          'color': backgroundPairing.spec.backgroundColor,
          'accentColor': backgroundPairing.spec.accentColor,
          'topic': backgroundPairing.spec.topic,
          'opacity': 1.0,
        },
      ),
    ];
    final primitives = <ReFusionMotionDirectorPrimitive>[
      const ReFusionMotionDirectorPrimitive(
        id: 'background-hold',
        beatId: 'intro',
        targetComponentId: 'background',
        kind: 'fade',
        property: 'opacity',
        startMs: 0,
        endMs: 1,
        fromValue: 1.0,
        toValue: 1.0,
        easing: 'fastSlow',
      ),
    ];
    final microScene = backgroundPairing.microScene;
    if (microScene != null) {
      final backgroundMotifId = 'background-micro-scene';
      components.add(
        ReFusionMotionDirectorComponent(
          id: backgroundMotifId,
          role: 'background.motif',
          label: 'Background Micro Scene',
          properties: <String, Object?>{
            'shapeKind': 'roundedRectangle',
            'width': microScene.width,
            'height': microScene.height,
            'x': 0.0,
            'y': canvas.height * 0.31,
            'color': backgroundPairing.spec.accentColor,
            'opacity': microScene.opacity,
            'microSceneKind': microScene.kind,
            'microSceneId': microScene.id,
          },
        ),
      );
      _appendRecipe(
        primitives: primitives,
        issues: issues,
        request: SceneMotionRecipeCompileRequest(
          recipeId: microScene.motionRecipe,
          targetComponentId: backgroundMotifId,
          targetScope: 'background',
          beatId: 'intro',
          startMs: (introEnd * 0.15).round(),
          endMs: introEnd,
          idPrefix: '$backgroundMotifId-enter',
        ),
      );
      _appendRecipe(
        primitives: primitives,
        issues: issues,
        request: SceneMotionRecipeCompileRequest(
          recipeId: r'$motion.fadeCollapse',
          targetComponentId: backgroundMotifId,
          targetScope: 'component',
          beatId: 'outro',
          startMs: featuresEnd,
          endMs: durationMs,
          idPrefix: '$backgroundMotifId-exit',
        ),
      );
    }

    var hasTitle = false;
    var hasFeatureGroup = false;
    var featureCardIndex = 0;
    var textBlockIndex = 0;

    for (final element in brief.elements) {
      final kind = _normalize(element.kind);
      if (kind == 'title') {
        final id = element.id ?? 'title-${textBlockIndex + 1}';
        textBlockIndex += 1;
        hasTitle = true;
        components.add(
          ReFusionMotionDirectorComponent(
            id: id,
            role: 'text.headline',
            label: 'Title',
            properties: <String, Object?>{
              'text': element.text ?? brief.intent,
              'fontSize': canvas.width >= 1500 ? 72 : 58,
              'x': 0.0,
              'y': composition.titleY,
              'color': '#FFFFFF',
            },
          ),
        );
        _appendRecipe(
          primitives: primitives,
          issues: issues,
          request: SceneMotionRecipeCompileRequest(
            recipeId: r'$motion.headlineBlurSettle',
            targetComponentId: id,
            targetScope: 'title',
            beatId: 'intro',
            startMs: 0,
            endMs: (introEnd * 0.62).round(),
            idPrefix: '$id-enter',
          ),
        );
        continue;
      }

      if (kind == 'subtitle') {
        final id = element.id ?? 'subtitle-${textBlockIndex + 1}';
        textBlockIndex += 1;
        components.add(
          ReFusionMotionDirectorComponent(
            id: id,
            role: 'text.copy',
            label: 'Subtitle',
            properties: <String, Object?>{
              'text': element.text ?? '',
              'fontSize': 32,
              'x': 0.0,
              'y': composition.subtitleY,
              'color': '#C8CFDF',
            },
          ),
        );
        _appendRecipe(
          primitives: primitives,
          issues: issues,
          request: SceneMotionRecipeCompileRequest(
            recipeId: r'$motion.wordCascadeUp',
            targetComponentId: id,
            targetScope: 'body',
            beatId: 'intro',
            startMs: (introEnd * 0.28).round(),
            endMs: (introEnd * 0.72).round(),
            idPrefix: '$id-enter',
          ),
        );
        continue;
      }

      if (kind == 'featurecardgroup') {
        hasFeatureGroup = true;
        final cards = element.cards;
        if (cards.isEmpty) {
          issues.add(
            const ReFusionMotionDirectorIssue(
              severity: ReFusionMotionDirectorIssueSeverity.warning,
              message:
                  'Director planner skipped empty feature card group payload.',
              path: 'directorBrief.elements.cards',
            ),
          );
          continue;
        }
        final grid = composition.featureCards;
        final staggerMs = (durationMs * 0.025).round().clamp(60, 120);
        for (var index = 0; index < cards.length; index += 1) {
          featureCardIndex += 1;
          final card = cards[index];
          final center = grid.isEmpty
              ? const SceneCompositionCardFrame(
                  centerX: 0.0,
                  centerY: 0.0,
                  width: 420.0,
                  height: 236.0,
                  cornerRadius: 36.0,
                  iconSize: 48.0,
                  labelFontSize: 34.0,
                  bodyFontSize: 24.0,
                  labelFrameWidth: 224.0,
                  bodyFrameWidth: 336.0,
                  bodyFrameHeight: 110.0,
                )
              : grid[index % grid.length];
          final cardBaseId = 'feature-card-$featureCardIndex';
          final shellId = '$cardBaseId-shell';
          final iconId = '$cardBaseId-icon';
          final labelId = '$cardBaseId-label';
          final bodyId = '$cardBaseId-body';
          final motifId = '$cardBaseId-motif';
          final motifSpec =
              _featureVisualMotifs.resolve(label: card.label, body: card.body);

          final enterStart = introEnd + (index * staggerMs);
          final enterEnd = (enterStart + (durationMs * 0.18).round())
              .clamp(enterStart + 120, featuresEnd - 100);
          final motionMapping = _brandMotionMapping.resolve(
            brandToken: card.brandToken,
            mood: brief.mood,
            label: card.label,
            body: card.body,
          );
          issues.addAll(motionMapping.issues);
          final motionProfile = motionMapping.profile;
          final choreography = _componentChoreographyEngine.planFeatureCard(
            enterStartMs: enterStart,
            enterEndMs: enterEnd,
            outroStartMs: featuresEnd,
            outroEndMs: durationMs,
            motionProfile: motionProfile,
          );
          issues.addAll(choreography.issues);

          final cardWidth = center.width;
          final cardHeight = center.height;
          final labelFrameWidth = center.labelFrameWidth;
          final bodyFrameWidth = center.bodyFrameWidth;
          final bodyFrameHeight = center.bodyFrameHeight;

          components.addAll(
            <ReFusionMotionDirectorComponent>[
              ReFusionMotionDirectorComponent(
                id: shellId,
                role: 'shape.card',
                label: 'Feature Card Shell',
                properties: <String, Object?>{
                  'shapeKind': 'roundedRectangle',
                  'width': cardWidth,
                  'height': cardHeight,
                  'cornerRadius': center.cornerRadius.round(),
                  'x': center.centerX,
                  'y': center.centerY,
                  'color': '#161A23',
                  'opacity': 0.0,
                  'brandMotionProfile': motionProfile.id,
                },
              ),
              ReFusionMotionDirectorComponent(
                id: iconId,
                role: 'icon',
                label: 'Feature Icon',
                properties: <String, Object?>{
                  'icon': _iconRegistry.resolveIconName(
                    iconToken: card.iconToken,
                    brandToken: card.brandToken,
                    fallbackText: card.label,
                    issues: issues,
                  ),
                  'width': center.iconSize.round(),
                  'height': center.iconSize.round(),
                  'x': center.centerX - (cardWidth / 2) + 54,
                  'y': center.centerY - (cardHeight / 2) + 48,
                  'color': '#FFFFFF',
                  'opacity': 0.0,
                },
              ),
              ReFusionMotionDirectorComponent(
                id: labelId,
                role: 'text.label',
                label: 'Feature Label',
                properties: <String, Object?>{
                  'text': card.label,
                  'fontSize': center.labelFontSize.round(),
                  'x': center.centerX -
                      (cardWidth / 2) +
                      54 +
                      center.iconSize +
                      18,
                  'y': center.centerY - (cardHeight / 2) + 48,
                  'color': '#FFFFFF',
                  'opacity': 0.0,
                  'textFrame': <String, Object?>{
                    'width': labelFrameWidth,
                    'height': (center.iconSize + 6).round(),
                    'maxLines': 1,
                    'overflow': 'ellipsis',
                    'fitPolicy': 'shrinkToFit',
                  },
                },
              ),
              ReFusionMotionDirectorComponent(
                id: bodyId,
                role: 'text.copy',
                label: 'Feature Body',
                properties: <String, Object?>{
                  'text': card.body,
                  'fontSize': center.bodyFontSize.round(),
                  'x': center.centerX - (cardWidth / 2) + 36,
                  'y': center.centerY - (cardHeight / 2) + 96,
                  'color': '#B4BED2',
                  'opacity': 0.0,
                  'textFrame': <String, Object?>{
                    'width': bodyFrameWidth,
                    'height': bodyFrameHeight,
                    'maxLines': 3,
                    'overflow': 'ellipsis',
                    'fitPolicy': 'shrinkToFit',
                  },
                },
              ),
              ReFusionMotionDirectorComponent(
                id: motifId,
                role: 'feature.motif',
                label: 'Feature Motif',
                properties: <String, Object?>{
                  'icon': _iconRegistry.resolveIconName(
                    iconToken: motifSpec.iconToken,
                    fallbackText: card.label,
                    issues: issues,
                  ),
                  'width': 30,
                  'height': 30,
                  'x': center.centerX + (cardWidth / 2) - 44,
                  'y': center.centerY - (cardHeight / 2) + 38,
                  'color': '#FFFFFF',
                  'opacity': motifSpec.opacity,
                },
              ),
            ],
          );

          final componentIdsByRole = <String, String>{
            'shell': shellId,
            'icon': iconId,
            'label': labelId,
            'body': bodyId,
          };
          final enterCompilation = _choreographyCompiler.compile(
            SceneComponentChoreographyCompileRequest(
              componentType: 'FeatureCard',
              beatId: 'features',
              parentStartMs: enterStart,
              parentEndMs: featuresEnd,
              spans: choreography.enterSpans,
              componentIdsByRole: componentIdsByRole,
              requiredRoles: const <String>{'shell', 'icon', 'label', 'body'},
              index: index,
              professionalStrict: true,
            ),
          );
          primitives.addAll(enterCompilation.primitives);
          issues.addAll(enterCompilation.issues);

          final exitCompilation = _choreographyCompiler.compile(
            SceneComponentChoreographyCompileRequest(
              componentType: 'FeatureCard',
              beatId: 'outro',
              parentStartMs: featuresEnd,
              parentEndMs: durationMs,
              spans: choreography.exitSpans,
              componentIdsByRole: componentIdsByRole,
              requiredRoles: const <String>{'shell', 'icon', 'label', 'body'},
              index: index,
              professionalStrict: true,
            ),
          );
          primitives.addAll(exitCompilation.primitives);
          issues.addAll(exitCompilation.issues);
          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: motifSpec.recipeId,
              targetComponentId: motifId,
              targetScope: 'icon',
              beatId: 'features',
              startMs: enterStart + 120,
              endMs: enterEnd + 60,
              idPrefix: '$motifId-enter',
            ),
          );
          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: r'$motion.fadeCollapse',
              targetComponentId: motifId,
              targetScope: 'icon',
              beatId: 'outro',
              startMs: featuresEnd,
              endMs: durationMs,
              idPrefix: '$motifId-exit',
            ),
          );
        }
        continue;
      }

      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Director planner skipped unsupported element kind `${element.kind}`.',
          path: 'directorBrief.elements.kind',
        ),
      );
    }

    if (!hasTitle) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Director planner did not receive a title element; using primary intent as fallback text focus.',
          path: 'directorBrief.elements',
        ),
      );
    }
    if (!hasFeatureGroup) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Director planner did not receive a feature card group; output will be minimal.',
          path: 'directorBrief.elements',
        ),
      );
    }

    final interResult = _interComponentSolver.solve(
      components: components,
      primitives: primitives,
      featureBeatId: 'features',
      outroBeatId: 'outro',
    );
    issues.addAll(interResult.issues);
    final finalComponents = interResult.components;
    final finalPrimitives = interResult.primitives;

    final refsByBeat = <String, Set<String>>{};
    for (final primitive in finalPrimitives) {
      refsByBeat.putIfAbsent(primitive.beatId, () => <String>{}).add(
            primitive.targetComponentId,
          );
    }

    final beats = <ReFusionMotionDirectorBeat>[
      ReFusionMotionDirectorBeat(
        id: 'intro',
        label: 'Intro',
        startMs: 0,
        endMs: introEnd,
        intent: 'Establish primary focus and scene mood.',
        componentRefs:
            (refsByBeat['intro'] ?? const <String>{}).toList(growable: false),
      ),
      ReFusionMotionDirectorBeat(
        id: 'features',
        label: 'Features',
        startMs: introEnd,
        endMs: featuresEnd,
        intent: 'Showcase supporting cards with staggered rhythm.',
        componentRefs: (refsByBeat['features'] ?? const <String>{})
            .toList(growable: false),
      ),
      ReFusionMotionDirectorBeat(
        id: 'outro',
        label: 'Outro',
        startMs: featuresEnd,
        endMs: durationMs,
        intent: 'Resolve the scene with clean exit coherence.',
        componentRefs:
            (refsByBeat['outro'] ?? const <String>{}).toList(growable: false),
      ),
    ];

    final plan = ReFusionMotionDirectorPlan(
      schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
      name: _briefToName(brief.intent),
      durationMs: durationMs,
      frameRate: 30,
      canvasWidth: canvas.width,
      canvasHeight: canvas.height,
      beats: beats,
      components: finalComponents,
      primitives: finalPrimitives,
    );

    return SceneDirectorIntelligencePlanResult(
      plan: plan,
      issues: List.unmodifiable(issues),
    );
  }

  _CanvasSpec _canvasForAspect(String aspectToken) {
    final token = _normalize(aspectToken);
    if (token.contains('16x9') ||
        token.contains('youtube') ||
        token.contains('widescreen')) {
      return const _CanvasSpec(width: 1920, height: 1080);
    }
    if (token.contains('1x1') || token.contains('square')) {
      return const _CanvasSpec(width: 1080, height: 1080);
    }
    if (token.contains('4x5') || token.contains('feed')) {
      return const _CanvasSpec(width: 1080, height: 1350);
    }
    return const _CanvasSpec(width: 1080, height: 1920);
  }

  int _durationForIntent(String durationIntent) {
    final token = _normalize(durationIntent);
    if (token.contains('deliberate') || token.contains('slow')) {
      return 5200;
    }
    if (token.contains('fast')) {
      return 2600;
    }
    return 3600;
  }

  String _briefToName(String intent) {
    final cleaned = intent.trim();
    if (cleaned.isEmpty) {
      return 'Director Brief Scene';
    }
    if (cleaned.length <= 64) {
      return cleaned;
    }
    return '${cleaned.substring(0, 61)}...';
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  void _appendRecipe({
    required List<ReFusionMotionDirectorPrimitive> primitives,
    required List<ReFusionMotionDirectorIssue> issues,
    required SceneMotionRecipeCompileRequest request,
  }) {
    final result = _recipeCompiler.compile(request);
    primitives.addAll(result.primitives);
    issues.addAll(result.issues);
  }
}

class _CanvasSpec {
  const _CanvasSpec({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}
