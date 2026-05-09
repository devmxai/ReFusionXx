import '../models/refusion_motion_director_models.dart';
import '../models/scene_director_brief_models.dart';
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
  }) : _recipeCompiler = recipeCompiler;

  final SceneMotionRecipeCompiler _recipeCompiler;

  SceneDirectorIntelligencePlanResult planFromBrief(
    SceneDirectorBrief brief,
  ) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final canvas = _canvasForAspect(brief.aspect);
    final durationMs = _durationForIntent(brief.durationIntent);
    final introEnd = (durationMs * 0.25).round();
    final featuresEnd = (durationMs * 0.8).round();

    final components = <ReFusionMotionDirectorComponent>[
      ReFusionMotionDirectorComponent(
        id: 'background',
        role: 'background',
        label: 'Background',
        properties: <String, Object?>{
          'color': _backgroundColorForMood(brief.mood),
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
              'y': -(canvas.height * 0.31),
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
              'y': -(canvas.height * 0.21),
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
        final grid = _featureGridCenters(
          canvasWidth: canvas.width.toDouble(),
          canvasHeight: canvas.height.toDouble(),
          count: cards.length,
        );
        final staggerMs = (durationMs * 0.025).round().clamp(60, 120);
        for (var index = 0; index < cards.length; index += 1) {
          featureCardIndex += 1;
          final card = cards[index];
          final center = grid[index % grid.length];
          final cardBaseId = 'feature-card-$featureCardIndex';
          final shellId = '$cardBaseId-shell';
          final iconId = '$cardBaseId-icon';
          final labelId = '$cardBaseId-label';
          final bodyId = '$cardBaseId-body';

          final enterStart = introEnd + (index * staggerMs);
          final enterEnd = (enterStart + (durationMs * 0.18).round())
              .clamp(enterStart + 120, featuresEnd - 100);

          final cardWidth = canvas.width >= 1500 ? 520.0 : 430.0;
          final cardHeight = canvas.width >= 1500 ? 280.0 : 236.0;
          final labelFrameWidth = (cardWidth - 196).clamp(120.0, 420.0);
          final bodyFrameWidth = (cardWidth - 84).clamp(220.0, 500.0);
          final bodyFrameHeight = (cardHeight - 106).clamp(88.0, 160.0);

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
                  'cornerRadius': 36,
                  'x': center.x,
                  'y': center.y,
                  'color': '#161A23',
                  'opacity': 0.0,
                },
              ),
              ReFusionMotionDirectorComponent(
                id: iconId,
                role: 'icon',
                label: 'Feature Icon',
                properties: <String, Object?>{
                  'icon': _iconNameFromCard(card),
                  'width': 48,
                  'height': 48,
                  'x': center.x - 140,
                  'y': center.y - 72,
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
                  'fontSize': 34,
                  'x': center.x - 24,
                  'y': center.y - 72,
                  'color': '#FFFFFF',
                  'opacity': 0.0,
                  'textFrame': <String, Object?>{
                    'width': labelFrameWidth,
                    'height': 48,
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
                  'fontSize': 24,
                  'x': center.x - 140,
                  'y': center.y - 20,
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
            ],
          );

          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: _featureShellEnterRecipeFor(index),
              targetComponentId: shellId,
              targetScope: 'cardShell',
              beatId: 'features',
              startMs: enterStart,
              endMs: enterEnd,
              index: index,
              staggerMs: 0,
              idPrefix: '$shellId-enter',
            ),
          );
          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: r'$motion.iconPop',
              targetComponentId: iconId,
              targetScope: 'icon',
              beatId: 'features',
              startMs: enterStart + 70,
              endMs: enterEnd,
              idPrefix: '$iconId-enter',
            ),
          );
          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: r'$motion.wordCascadeUp',
              targetComponentId: labelId,
              targetScope: 'body',
              beatId: 'features',
              startMs: enterStart + 110,
              endMs: enterEnd + 80,
              idPrefix: '$labelId-enter',
            ),
          );
          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: r'$motion.wordCascadeUp',
              targetComponentId: bodyId,
              targetScope: 'body',
              beatId: 'features',
              startMs: enterStart + 170,
              endMs: enterEnd + 140,
              idPrefix: '$bodyId-enter',
            ),
          );

          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: _featureShellExitRecipeFor(index),
              targetComponentId: shellId,
              targetScope: 'cardShell',
              beatId: 'outro',
              startMs: featuresEnd,
              endMs: durationMs,
              idPrefix: '$shellId-exit',
            ),
          );
          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: r'$motion.fadeCollapse',
              targetComponentId: iconId,
              targetScope: 'icon',
              beatId: 'outro',
              startMs: featuresEnd,
              endMs: durationMs,
              idPrefix: '$iconId-exit',
            ),
          );
          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: r'$motion.fadeCollapse',
              targetComponentId: labelId,
              targetScope: 'body',
              beatId: 'outro',
              startMs: featuresEnd,
              endMs: durationMs,
              idPrefix: '$labelId-exit',
            ),
          );
          _appendRecipe(
            primitives: primitives,
            issues: issues,
            request: SceneMotionRecipeCompileRequest(
              recipeId: r'$motion.fadeCollapse',
              targetComponentId: bodyId,
              targetScope: 'body',
              beatId: 'outro',
              startMs: featuresEnd,
              endMs: durationMs,
              idPrefix: '$bodyId-exit',
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

    final refsByBeat = <String, Set<String>>{};
    for (final primitive in primitives) {
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
      components: components,
      primitives: primitives,
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

  String _backgroundColorForMood(String mood) {
    final token = _normalize(mood);
    if (token.contains('light') || token.contains('clean')) {
      return '#F4F6FA';
    }
    if (token.contains('luxury') || token.contains('minimal')) {
      return '#0D1018';
    }
    return '#10141E';
  }

  String _iconNameFromCard(SceneDirectorBriefCard card) {
    final token = _normalize(card.iconToken ?? card.brandToken ?? card.label);
    if (token.contains('audio') || token.contains('voice')) {
      return 'mic';
    }
    if (token.contains('caption') || token.contains('text')) {
      return 'title';
    }
    if (token.contains('color') || token.contains('grade')) {
      return 'palette';
    }
    if (token.contains('image') || token.contains('retouch')) {
      return 'image';
    }
    if (token.contains('chat') || token.contains('prompt')) {
      return 'message';
    }
    if (token.contains('send')) {
      return 'send';
    }
    return 'sparkles';
  }

  String _featureShellEnterRecipeFor(int index) {
    switch (index % 4) {
      case 0:
        return r'$motion.cardSpringEntrance';
      case 1:
        return r'$motion.slideInFromLeft';
      case 2:
        return r'$motion.slideInFromRight';
      default:
        return r'$motion.popInSpring';
    }
  }

  String _featureShellExitRecipeFor(int index) {
    switch (index % 4) {
      case 0:
        return r'$motion.slideOutToBottom';
      case 1:
        return r'$motion.slideOutToLeft';
      case 2:
        return r'$motion.slideOutToRight';
      default:
        return r'$motion.pushBack';
    }
  }

  List<_Point> _featureGridCenters({
    required double canvasWidth,
    required double canvasHeight,
    required int count,
  }) {
    final twoColumn = count >= 4;
    final horizontalGap = twoColumn ? canvasWidth * 0.34 : 0.0;
    final verticalGap = canvasHeight * 0.18;
    final baseY = canvasHeight * 0.08;
    if (twoColumn) {
      return <_Point>[
        _Point(x: -horizontalGap / 2, y: baseY - (verticalGap / 2)),
        _Point(x: horizontalGap / 2, y: baseY - (verticalGap / 2)),
        _Point(x: -horizontalGap / 2, y: baseY + (verticalGap / 2)),
        _Point(x: horizontalGap / 2, y: baseY + (verticalGap / 2)),
      ];
    }
    final centers = <_Point>[];
    for (var index = 0; index < count; index += 1) {
      centers.add(
        _Point(
          x: 0.0,
          y: baseY + ((index - ((count - 1) / 2.0)) * verticalGap),
        ),
      );
    }
    return centers;
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

class _Point {
  const _Point({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;
}
