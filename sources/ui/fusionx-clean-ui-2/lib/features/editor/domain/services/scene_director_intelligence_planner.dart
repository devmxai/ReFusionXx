import '../models/refusion_motion_director_models.dart';
import '../models/scene_director_brief_models.dart';

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
  const SceneDirectorIntelligencePlanner();

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
        easing: 'linear',
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
        primitives.addAll(
          <ReFusionMotionDirectorPrimitive>[
            ReFusionMotionDirectorPrimitive(
              id: '$id-enter-opacity',
              beatId: 'intro',
              targetComponentId: id,
              kind: 'enter',
              property: 'opacity',
              startMs: 0,
              endMs: (introEnd * 0.55).round(),
              fromValue: 0.0,
              toValue: 1.0,
              easing: 'slowFastSlow',
            ),
            ReFusionMotionDirectorPrimitive(
              id: '$id-enter-position',
              beatId: 'intro',
              targetComponentId: id,
              kind: 'slide',
              property: 'position',
              startMs: 0,
              endMs: (introEnd * 0.55).round(),
              fromValue: <String, double>{
                'x': 0,
                'y': -(canvas.height * 0.27),
              },
              toValue: <String, double>{
                'x': 0,
                'y': -(canvas.height * 0.31),
              },
              easing: 'slowFastSlow',
            ),
          ],
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
        primitives.add(
          ReFusionMotionDirectorPrimitive(
            id: '$id-enter-opacity',
            beatId: 'intro',
            targetComponentId: id,
            kind: 'enter',
            property: 'opacity',
            startMs: (introEnd * 0.28).round(),
            endMs: (introEnd * 0.7).round(),
            fromValue: 0.0,
            toValue: 1.0,
            easing: 'fastSlow',
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

          components.addAll(
            <ReFusionMotionDirectorComponent>[
              ReFusionMotionDirectorComponent(
                id: shellId,
                role: 'shape.card',
                label: 'Feature Card Shell',
                properties: <String, Object?>{
                  'shapeKind': 'roundedRectangle',
                  'width': canvas.width >= 1500 ? 520 : 430,
                  'height': canvas.width >= 1500 ? 280 : 236,
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
                },
              ),
            ],
          );

          primitives.addAll(
            <ReFusionMotionDirectorPrimitive>[
              ReFusionMotionDirectorPrimitive(
                id: '$shellId-enter-scale',
                beatId: 'features',
                targetComponentId: shellId,
                kind: 'scale',
                property: 'scale',
                startMs: enterStart,
                endMs: enterEnd,
                fromValue: 0.88,
                toValue: 1.0,
                easing: index.isEven ? 'slowFastSlow' : 'fastSlow',
              ),
              ReFusionMotionDirectorPrimitive(
                id: '$shellId-enter-opacity',
                beatId: 'features',
                targetComponentId: shellId,
                kind: 'enter',
                property: 'opacity',
                startMs: enterStart,
                endMs: enterEnd,
                fromValue: 0.0,
                toValue: 1.0,
                easing: 'fastSlow',
              ),
              ReFusionMotionDirectorPrimitive(
                id: '$iconId-enter-opacity',
                beatId: 'features',
                targetComponentId: iconId,
                kind: 'enter',
                property: 'opacity',
                startMs: enterStart + 70,
                endMs: enterEnd,
                fromValue: 0.0,
                toValue: 1.0,
                easing: 'fastSlow',
              ),
              ReFusionMotionDirectorPrimitive(
                id: '$labelId-enter-opacity',
                beatId: 'features',
                targetComponentId: labelId,
                kind: 'enter',
                property: 'opacity',
                startMs: enterStart + 110,
                endMs: enterEnd + 80,
                fromValue: 0.0,
                toValue: 1.0,
                easing: 'fastSlow',
              ),
              ReFusionMotionDirectorPrimitive(
                id: '$bodyId-enter-opacity',
                beatId: 'features',
                targetComponentId: bodyId,
                kind: 'enter',
                property: 'opacity',
                startMs: enterStart + 170,
                endMs: enterEnd + 140,
                fromValue: 0.0,
                toValue: 1.0,
                easing: 'fastSlow',
              ),
              ReFusionMotionDirectorPrimitive(
                id: '$shellId-exit',
                beatId: 'outro',
                targetComponentId: shellId,
                kind: 'fade',
                property: 'opacity',
                startMs: featuresEnd,
                endMs: durationMs,
                fromValue: 1.0,
                toValue: 0.0,
                easing: 'fastSlow',
              ),
              ReFusionMotionDirectorPrimitive(
                id: '$iconId-exit',
                beatId: 'outro',
                targetComponentId: iconId,
                kind: 'fade',
                property: 'opacity',
                startMs: featuresEnd,
                endMs: durationMs,
                fromValue: 1.0,
                toValue: 0.0,
                easing: 'fastSlow',
              ),
              ReFusionMotionDirectorPrimitive(
                id: '$labelId-exit',
                beatId: 'outro',
                targetComponentId: labelId,
                kind: 'fade',
                property: 'opacity',
                startMs: featuresEnd,
                endMs: durationMs,
                fromValue: 1.0,
                toValue: 0.0,
                easing: 'fastSlow',
              ),
              ReFusionMotionDirectorPrimitive(
                id: '$bodyId-exit',
                beatId: 'outro',
                targetComponentId: bodyId,
                kind: 'fade',
                property: 'opacity',
                startMs: featuresEnd,
                endMs: durationMs,
                fromValue: 1.0,
                toValue: 0.0,
                easing: 'fastSlow',
              ),
            ],
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
