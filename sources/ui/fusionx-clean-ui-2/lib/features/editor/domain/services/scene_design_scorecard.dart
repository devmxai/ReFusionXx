import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import 'evaluated_frame_truth.dart';
import 'scene_coordinate_system.dart';
import 'scene_evaluation_pipeline.dart';
import 'scene_icon_registry.dart';

const String kSceneDesignScorecardProofTag = 'TF_SCENE_DESIGN_SCORECARD_PROOF';

class SceneDesignScorecard {
  const SceneDesignScorecard({
    required this.typographyHierarchy,
    required this.spacingRhythm,
    required this.componentCohesion,
    required this.visualHierarchy,
    required this.iconTextProportion,
    required this.motionPolish,
    required this.responsiveAdaptation,
    required this.densityNegativeSpace,
    required this.brandLegalCorrectness,
    required this.renderApplyTruthAlignment,
  });

  final int typographyHierarchy;
  final int spacingRhythm;
  final int componentCohesion;
  final int visualHierarchy;
  final int iconTextProportion;
  final int motionPolish;
  final int responsiveAdaptation;
  final int densityNegativeSpace;
  final int brandLegalCorrectness;
  final int renderApplyTruthAlignment;

  int get overallScore {
    final values = <int>[
      typographyHierarchy,
      spacingRhythm,
      componentCohesion,
      visualHierarchy,
      iconTextProportion,
      motionPolish,
      responsiveAdaptation,
      densityNegativeSpace,
      brandLegalCorrectness,
      renderApplyTruthAlignment,
    ];
    if (values.isEmpty) {
      return 0;
    }
    final sum = values.fold<int>(0, (left, right) => left + right);
    return (sum / values.length).round().clamp(0, 100);
  }
}

class SceneDesignScorecardResult {
  SceneDesignScorecardResult({
    required this.scorecard,
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List<ReFusionSceneProgramIssue>.unmodifiable(issues);

  final SceneDesignScorecard scorecard;
  final List<ReFusionSceneProgramIssue> issues;

  bool get passesProfessionalGate => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneDesignScorecardEvaluator {
  const SceneDesignScorecardEvaluator({
    SceneEvaluationPipeline evaluationPipeline =
        const SceneEvaluationPipeline(),
    SceneIconRegistry iconRegistry = const SceneIconRegistry(),
    this.minProfessionalOverallScore = 74,
    this.minProfessionalMetricScore = 62,
  })  : _evaluationPipeline = evaluationPipeline,
        _iconRegistry = iconRegistry;

  final SceneEvaluationPipeline _evaluationPipeline;
  final SceneIconRegistry _iconRegistry;
  final int minProfessionalOverallScore;
  final int minProfessionalMetricScore;

  SceneDesignScorecardResult evaluate(
    ReFusionSceneProgram program, {
    required bool strictProfessional,
  }) {
    final issues = <ReFusionSceneProgramIssue>[];
    final elementRefs = _collectElementRefs(program);
    final evaluation = _evaluationPipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: program,
        globalTimeMs: (program.durationMs * 0.55).round(),
      ),
    );

    final typographyHierarchy = _scoreTypography(elementRefs);
    final spacingRhythm = _scoreSpacingRhythm(evaluation.truth);
    final componentCohesion = _scoreComponentCohesion(
      elementRefs: elementRefs,
      program: program,
    );
    final visualHierarchy = _scoreVisualHierarchy(
      elementRefs: elementRefs,
      truth: evaluation.truth,
      issues: issues,
      strictProfessional: strictProfessional,
    );
    final iconTextProportion = _scoreIconTextProportion(elementRefs);
    final motionPolish = _scoreMotionPolish(program);
    final responsiveAdaptation = _scoreResponsiveAdaptation(elementRefs);
    final densityNegativeSpace = _scoreDensityNegativeSpace(evaluation.truth);
    final brandLegalCorrectness = _scoreBrandLegalCorrectness(
      elementRefs: elementRefs,
      issues: issues,
    );
    final renderApplyTruthAlignment =
        _scoreRenderApplyTruthAlignment(evaluation.truth);

    final scorecard = SceneDesignScorecard(
      typographyHierarchy: typographyHierarchy,
      spacingRhythm: spacingRhythm,
      componentCohesion: componentCohesion,
      visualHierarchy: visualHierarchy,
      iconTextProportion: iconTextProportion,
      motionPolish: motionPolish,
      responsiveAdaptation: responsiveAdaptation,
      densityNegativeSpace: densityNegativeSpace,
      brandLegalCorrectness: brandLegalCorrectness,
      renderApplyTruthAlignment: renderApplyTruthAlignment,
    );

    if (strictProfessional) {
      _emitThresholdIssues(
        scorecard: scorecard,
        strictProfessional: true,
        issues: issues,
      );
      _emitSimultaneousAnimationDensityIssues(
        program: program,
        strictProfessional: true,
        issues: issues,
      );
      _emitCardGroupChoreographyIssue(
        elementRefs: elementRefs,
        strictProfessional: true,
        issues: issues,
      );
    }

    issues.add(
      ReFusionSceneProgramIssue(
        severity: issues.any(
          (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
        )
            ? ReFusionSceneProgramIssueSeverity.error
            : ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneDesignScorecardProofTag '
            'overall=${scorecard.overallScore} '
            'strictProfessional=$strictProfessional '
            'typography=${scorecard.typographyHierarchy} '
            'spacing=${scorecard.spacingRhythm} '
            'cohesion=${scorecard.componentCohesion} '
            'visual=${scorecard.visualHierarchy} '
            'iconText=${scorecard.iconTextProportion} '
            'motion=${scorecard.motionPolish} '
            'responsive=${scorecard.responsiveAdaptation} '
            'density=${scorecard.densityNegativeSpace} '
            'brandLegal=${scorecard.brandLegalCorrectness} '
            'truth=${scorecard.renderApplyTruthAlignment}',
        path: 'scene.designScorecard',
      ),
    );
    return SceneDesignScorecardResult(
      scorecard: scorecard,
      issues: issues,
    );
  }

  void _emitThresholdIssues({
    required SceneDesignScorecard scorecard,
    required bool strictProfessional,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final metrics = <String, int>{
      'TYPOGRAPHY_HIERARCHY': scorecard.typographyHierarchy,
      'SPACING_RHYTHM': scorecard.spacingRhythm,
      'COMPONENT_COHESION': scorecard.componentCohesion,
      'VISUAL_HIERARCHY': scorecard.visualHierarchy,
      'ICON_TEXT_PROPORTION': scorecard.iconTextProportion,
      'MOTION_POLISH': scorecard.motionPolish,
      'RESPONSIVE_ADAPTATION': scorecard.responsiveAdaptation,
      'DENSITY_NEGATIVE_SPACE': scorecard.densityNegativeSpace,
      'BRAND_LEGAL_CORRECTNESS': scorecard.brandLegalCorrectness,
      'RENDER_APPLY_TRUTH_ALIGNMENT': scorecard.renderApplyTruthAlignment,
    };

    for (final entry in metrics.entries) {
      if (entry.value >= minProfessionalMetricScore) {
        continue;
      }
      issues.add(
        ReFusionSceneProgramIssue(
          severity: strictProfessional
              ? ReFusionSceneProgramIssueSeverity.error
              : ReFusionSceneProgramIssueSeverity.warning,
          message: 'DESIGN_SCORECARD::${entry.key}_LOW '
              '${entry.key.toLowerCase()}=${entry.value} '
              'minimum=$minProfessionalMetricScore',
          path: 'scene.designScorecard.${entry.key.toLowerCase()}',
        ),
      );
    }

    if (scorecard.overallScore < minProfessionalOverallScore) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: strictProfessional
              ? ReFusionSceneProgramIssueSeverity.error
              : ReFusionSceneProgramIssueSeverity.warning,
          message: 'DESIGN_SCORECARD::OVERALL_LOW '
              'overall=${scorecard.overallScore} '
              'minimum=$minProfessionalOverallScore',
          path: 'scene.designScorecard.overall',
        ),
      );
    }
  }

  void _emitSimultaneousAnimationDensityIssues({
    required ReFusionSceneProgram program,
    required bool strictProfessional,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final boundaries = <int>{0, program.durationMs};
    for (final layer in program.layers) {
      boundaries.add(layer.startMs.clamp(0, program.durationMs));
      boundaries.add(
        (layer.startMs + layer.durationMs).clamp(0, program.durationMs),
      );
      for (final channel in layer.channels) {
        for (final keyframe in channel.keyframes) {
          boundaries.add(keyframe.timeMs.clamp(0, program.durationMs));
        }
      }
      for (final element in layer.elements) {
        for (final channel in element.channels) {
          for (final keyframe in channel.keyframes) {
            boundaries.add(keyframe.timeMs.clamp(0, program.durationMs));
          }
        }
      }
    }
    final sorted = boundaries.toList(growable: false)..sort();
    var maxSimultaneous = 0;
    for (var index = 0; index < sorted.length - 1; index += 1) {
      final mid = ((sorted[index] + sorted[index + 1]) / 2).round();
      final activeAnimated = <String>{};
      for (final layer in program.layers) {
        final layerStart = layer.startMs;
        final layerEnd = layer.startMs + layer.durationMs;
        if (mid < layerStart || mid >= layerEnd) {
          continue;
        }
        for (final channel in layer.channels) {
          if (channel.keyframes.length < 2) {
            continue;
          }
          final normalized = _normalize(channel.property);
          final major = normalized == 'x' ||
              normalized == 'y' ||
              normalized == 'positionx' ||
              normalized == 'positiony' ||
              normalized == 'position.x' ||
              normalized == 'position.y' ||
              normalized == 'scale' ||
              normalized == 'scalex' ||
              normalized == 'scaley' ||
              normalized == 'rotation' ||
              normalized == 'rotationdeg' ||
              normalized == 'width' ||
              normalized == 'height' ||
              normalized == 'opacity' ||
              normalized == 'alpha';
          if (!major) {
            continue;
          }
          activeAnimated.add('${layer.id}::${channel.target}');
        }
        for (final element in layer.elements) {
          for (final channel in element.channels) {
            if (channel.keyframes.length < 2) {
              continue;
            }
            final normalized = _normalize(channel.property);
            final major = normalized == 'x' ||
                normalized == 'y' ||
                normalized == 'positionx' ||
                normalized == 'positiony' ||
                normalized == 'position.x' ||
                normalized == 'position.y' ||
                normalized == 'scale' ||
                normalized == 'scalex' ||
                normalized == 'scaley' ||
                normalized == 'rotation' ||
                normalized == 'rotationdeg' ||
                normalized == 'width' ||
                normalized == 'height' ||
                normalized == 'opacity' ||
                normalized == 'alpha';
            if (!major) {
              continue;
            }
            activeAnimated.add('${layer.id}::${element.id}');
          }
        }
      }
      maxSimultaneous = math.max(maxSimultaneous, activeAnimated.length);
    }
    if (maxSimultaneous <= 5) {
      return;
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: strictProfessional
            ? ReFusionSceneProgramIssueSeverity.error
            : ReFusionSceneProgramIssueSeverity.warning,
        message: 'DESIGN_SCORECARD::SIMULTANEOUS_ANIMATION_DENSITY_HIGH '
            'maxSimultaneous=$maxSimultaneous budget=5',
        path: 'scene.designScorecard.motionDensity',
      ),
    );
  }

  void _emitCardGroupChoreographyIssue({
    required List<_ElementRef> elementRefs,
    required bool strictProfessional,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final cardRoots = elementRefs.where((ref) {
      final componentType = _normalize(
        _stringFromMap(
              ref.element.properties,
              const <String>['componentType', 'layout.componentType'],
            ) ??
            '',
      );
      final role = _normalize(
        _stringFromMap(
              ref.element.properties,
              const <String>['layoutRole', 'role'],
            ) ??
            '',
      );
      return componentType == 'featurecard' &&
          (role == 'container' || role == 'shell' || role == 'root');
    }).toList(growable: false);

    if (cardRoots.length < 3) {
      return;
    }
    final starts = cardRoots
        .map((ref) => ref.layer.startMs)
        .toSet()
        .toList(growable: false)
      ..sort();
    if (starts.length > 1) {
      return;
    }
    final hasGroupRecipe = cardRoots.any((ref) {
      final recipe = _normalize(
        _stringFromMap(
              ref.element.properties,
              const <String>['groupMotionRecipe', 'motionRecipe', 'recipeId'],
            ) ??
            '',
      );
      return recipe.contains('cascade') ||
          recipe.contains('group') ||
          recipe.contains('stagger');
    });
    if (hasGroupRecipe) {
      return;
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: strictProfessional
            ? ReFusionSceneProgramIssueSeverity.error
            : ReFusionSceneProgramIssueSeverity.warning,
        message:
            'DESIGN_SCORECARD::CARD_GROUP_MISSING_CHOREOGRAPHY group feature cards need stagger or group choreography.',
        path: 'scene.designScorecard.cardGroup',
      ),
    );
  }

  int _scoreTypography(List<_ElementRef> refs) {
    final fontSizes = <double>[];
    for (final ref in refs) {
      if (_normalize(ref.element.kind) != 'text') {
        continue;
      }
      final value = _doubleFromMap(
        ref.element.properties,
        const <String>['fontSize'],
      );
      if (value != null && value > 0) {
        fontSizes.add(value);
      }
    }
    if (fontSizes.isEmpty) {
      return 70;
    }
    final minFont = fontSizes.reduce(math.min);
    final maxFont = fontSizes.reduce(math.max);
    final ratio = maxFont / math.max(1.0, minFont);
    var score = 90;
    if (ratio < 1.18 || ratio > 3.4) {
      score -= 26;
    }
    if (maxFont > 78 || minFont < 11) {
      score -= 18;
    }
    return score.clamp(0, 100).toInt();
  }

  int _scoreSpacingRhythm(EvaluatedFrameTruth truth) {
    final roots = truth.nodesById.values.where((node) {
      return node.active &&
          node.visible &&
          node.parentNodeId == '__scene_root__' &&
          node.nodeType != 'background';
    }).toList(growable: false);
    if (roots.length < 3) {
      return 84;
    }
    final centers = roots
        .map((node) => node.worldBoundsCenter.centerY)
        .toList(growable: false)
      ..sort();
    final gaps = <double>[];
    for (var index = 1; index < centers.length; index += 1) {
      gaps.add((centers[index] - centers[index - 1]).abs());
    }
    if (gaps.isEmpty) {
      return 84;
    }
    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    if (mean <= 1.0) {
      return 72;
    }
    final variance = gaps
            .map((gap) => math.pow(gap - mean, 2))
            .fold<double>(0.0, (sum, value) => sum + value) /
        gaps.length;
    final stdDev = math.sqrt(variance);
    final coeff = stdDev / mean;
    return (92 - (coeff * 70)).clamp(0, 100).round();
  }

  int _scoreComponentCohesion({
    required List<_ElementRef> elementRefs,
    required ReFusionSceneProgram program,
  }) {
    final byComponent = <String, List<_ElementRef>>{};
    for (final ref in elementRefs) {
      final componentId = _stringFromMap(
        ref.element.properties,
        const <String>['componentId', 'layout.componentId'],
      );
      if (componentId == null || componentId.trim().isEmpty) {
        continue;
      }
      byComponent.putIfAbsent(componentId, () => <_ElementRef>[]).add(ref);
    }
    if (byComponent.isEmpty) {
      return 60;
    }
    var penalty = 0;
    for (final refs in byComponent.values) {
      final rootCount = refs.where((ref) {
        final role = _normalize(
          _stringFromMap(
                ref.element.properties,
                const <String>['layoutRole', 'role'],
              ) ??
              '',
        );
        return role == 'container' || role == 'shell' || role == 'root';
      }).length;
      if (rootCount != 1) {
        penalty += 12;
      }
      final starts = refs.map((ref) => ref.layer.startMs).toSet();
      final ends = refs.map((ref) => ref.layer.startMs + ref.layer.durationMs).toSet();
      if (starts.length > 2) {
        penalty += 8;
      }
      if (ends.length > 2) {
        penalty += 8;
      }
      final rawChildren = refs.where((ref) {
        final hasParent = _stringFromMap(
          ref.element.properties,
          const <String>['parentId', 'parent', 'containerId', 'parentGroup'],
        );
        if (hasParent == null || hasParent.isEmpty) {
          return false;
        }
        final slot = _stringFromMap(
          ref.element.properties,
          const <String>['slotId', 'layout.slotId'],
        );
        return slot == null || slot.isEmpty;
      }).length;
      if (rawChildren > 0) {
        penalty += math.min(20, rawChildren * 4);
      }
    }
    return (94 - penalty).clamp(0, 100).toInt();
  }

  int _scoreVisualHierarchy({
    required List<_ElementRef> elementRefs,
    required EvaluatedFrameTruth truth,
    required List<ReFusionSceneProgramIssue> issues,
    required bool strictProfessional,
  }) {
    final primaries = elementRefs.where((ref) {
      final role = _normalize(
        _stringFromMap(
              ref.element.properties,
              const <String>['role', 'layoutRole'],
            ) ??
            '',
      );
      return role == 'primary' || role == 'headline' || role == 'hero';
    }).toList(growable: false);
    if (primaries.length > 1) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: strictProfessional
              ? ReFusionSceneProgramIssueSeverity.error
              : ReFusionSceneProgramIssueSeverity.warning,
          message: 'DESIGN_SCORECARD::MULTIPLE_PRIMARY_FOCAL_ELEMENTS '
              'count=${primaries.length} expected=1',
          path: 'scene.designScorecard.visualHierarchy',
        ),
      );
    }
    final activeNodes = truth.nodesById.values.where((node) {
      return node.active &&
          node.visible &&
          node.parentNodeId == '__scene_root__' &&
          node.nodeType != 'background';
    }).toList(growable: false);
    if (activeNodes.isEmpty) {
      return primaries.length <= 1 ? 82 : 58;
    }
    final areas = activeNodes
        .map((node) => node.worldBoundsCenter.width * node.worldBoundsCenter.height)
        .where((area) => area > 0)
        .toList(growable: false);
    if (areas.isEmpty) {
      return 74;
    }
    final total = areas.fold<double>(0.0, (sum, area) => sum + area);
    final maxArea = areas.reduce(math.max);
    final dominantRatio = maxArea / math.max(1.0, total);
    var score = 90;
    if (dominantRatio < 0.25 || dominantRatio > 0.70) {
      score -= 24;
    }
    if (primaries.length > 1) {
      score -= 20;
    }
    return score.clamp(0, 100).toInt();
  }

  int _scoreIconTextProportion(List<_ElementRef> refs) {
    final byComponent = <String, List<_ElementRef>>{};
    for (final ref in refs) {
      final componentId = _stringFromMap(
        ref.element.properties,
        const <String>['componentId', 'layout.componentId'],
      );
      if (componentId == null || componentId.trim().isEmpty) {
        continue;
      }
      byComponent.putIfAbsent(componentId, () => <_ElementRef>[]).add(ref);
    }
    final ratios = <double>[];
    for (final group in byComponent.values) {
      final icon = group.firstWhereOrNull(
        (ref) => _normalize(ref.element.kind) == 'icon',
      );
      final text = group.firstWhereOrNull(
        (ref) => _normalize(ref.element.kind) == 'text',
      );
      if (icon == null || text == null) {
        continue;
      }
      final iconSize = _doubleFromMap(
            icon.element.properties,
            const <String>['width', 'size'],
          ) ??
          _doubleFromMap(icon.element.properties, const <String>['height']);
      final fontSize =
          _doubleFromMap(text.element.properties, const <String>['fontSize']);
      if (iconSize == null || fontSize == null || fontSize <= 0) {
        continue;
      }
      ratios.add(iconSize / fontSize);
    }
    if (ratios.isEmpty) {
      return 78;
    }
    var score = 92;
    for (final ratio in ratios) {
      if (ratio < 0.9 || ratio > 1.9) {
        score -= 12;
      }
    }
    return score.clamp(0, 100).toInt();
  }

  int _scoreMotionPolish(ReFusionSceneProgram program) {
    final signatures = <String>{};
    var keyframeBurstPenalty = 0;
    for (final layer in program.layers) {
      for (final channel in layer.channels) {
        signatures.add(_motionSignature(channel));
        keyframeBurstPenalty += _keyframeBurstPenalty(channel);
      }
      for (final element in layer.elements) {
        for (final channel in element.channels) {
          signatures.add(_motionSignature(channel));
          keyframeBurstPenalty += _keyframeBurstPenalty(channel);
        }
      }
    }
    var score = 88;
    if (signatures.length <= 2) {
      score -= 20;
    } else if (signatures.length <= 4) {
      score -= 8;
    }
    score -= keyframeBurstPenalty;
    return score.clamp(0, 100).toInt();
  }

  int _scoreResponsiveAdaptation(List<_ElementRef> refs) {
    if (refs.isEmpty) {
      return 70;
    }
    var componentBacked = 0;
    var slotBackedText = 0;
    var textCount = 0;
    for (final ref in refs) {
      final componentId = _stringFromMap(
        ref.element.properties,
        const <String>['componentId', 'layout.componentId'],
      );
      if (componentId != null && componentId.trim().isNotEmpty) {
        componentBacked += 1;
      }
      if (_normalize(ref.element.kind) == 'text') {
        textCount += 1;
        final slotId = _stringFromMap(
          ref.element.properties,
          const <String>['slotId', 'layout.slotId'],
        );
        final textFrame = _mapFromMap(
          ref.element.properties,
          const <String>['textFrame', 'layoutTextFrame'],
        );
        if (slotId != null && slotId.trim().isNotEmpty && textFrame != null) {
          slotBackedText += 1;
        }
      }
    }
    final componentRatio = componentBacked / refs.length;
    final textRatio = textCount == 0 ? 1.0 : slotBackedText / textCount;
    final score = 40 + (componentRatio * 35) + (textRatio * 25);
    return score.clamp(0, 100).round();
  }

  int _scoreDensityNegativeSpace(EvaluatedFrameTruth truth) {
    final canvasArea = truth.canvas.width * truth.canvas.height;
    if (canvasArea <= 0) {
      return 60;
    }
    final activeNodes = truth.nodesById.values.where((node) {
      if (!node.active || !node.visible) {
        return false;
      }
      if (node.nodeType == 'background') {
        return false;
      }
      return node.parentNodeId == '__scene_root__';
    }).toList(growable: false);
    if (activeNodes.isEmpty) {
      return 72;
    }
    final occupied = activeNodes.fold<double>(0.0, (sum, node) {
      final rect = node.viewportBounds;
      return sum + (rect.width * rect.height);
    });
    final coverage = occupied / canvasArea;
    final targetMin = 0.30;
    final targetMax = 0.60;
    if (coverage >= targetMin && coverage <= targetMax) {
      return 92;
    }
    final distance = coverage < targetMin
        ? targetMin - coverage
        : coverage - targetMax;
    return (92 - (distance * 220)).clamp(0, 100).round();
  }

  int _scoreBrandLegalCorrectness({
    required List<_ElementRef> elementRefs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    var score = 94;
    for (final ref in elementRefs) {
      final properties = ref.element.properties;
      final brandToken = _stringFromMap(
        properties,
        const <String>['brandToken', 'brand', 'brandId'],
      );
      if (brandToken == null || brandToken.trim().isEmpty) {
        continue;
      }
      final normalized = _normalize(brandToken);
      if (!normalized.startsWith('brand')) {
        score -= 20;
        issues.add(
          const ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.warning,
            message:
                r'DESIGN_SCORECARD::BRAND_TOKEN_NON_CANONICAL use `$brand.*` tokens only.',
            path: 'scene.designScorecard.brand',
          ),
        );
        continue;
      }
      final known = _iconRegistry.findBrandToken(brandToken) != null;
      if (!known) {
        score -= 28;
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'DESIGN_SCORECARD::BRAND_TOKEN_UNKNOWN brand token `$brandToken` is not registered.',
            path: 'scene.designScorecard.brand',
          ),
        );
      }
      final overrideColor = _stringFromMap(
        properties,
        const <String>['brandColorOverride', 'iconColorOverride'],
      );
      if (overrideColor != null && overrideColor.trim().isNotEmpty) {
        score -= 16;
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.warning,
            message:
                'DESIGN_SCORECARD::BRAND_COLOR_OVERRIDE raw brand color override on `${ref.element.id}`.',
            path: 'scene.designScorecard.brand',
          ),
        );
      }
    }
    return score.clamp(0, 100).toInt();
  }

  int _scoreRenderApplyTruthAlignment(EvaluatedFrameTruth truth) {
    var score = 100;
    if (truth.coordinateSystem != SceneCoordinateSystem.canonical) {
      score -= 42;
    }
    if (truth.geometryHash.trim().isEmpty || truth.frameHash.trim().isEmpty) {
      score -= 26;
    }
    if (truth.nodesById.isEmpty) {
      score -= 26;
    }
    return score.clamp(0, 100).toInt();
  }

  List<_ElementRef> _collectElementRefs(ReFusionSceneProgram program) {
    final refs = <_ElementRef>[];
    for (final layer in program.layers) {
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex += 1) {
        refs.add(
          _ElementRef(
            layer: layer,
            element: layer.elements[elementIndex],
          ),
        );
      }
    }
    return refs;
  }

  int _keyframeBurstPenalty(ReFusionSceneProgramChannel channel) {
    if (channel.keyframes.length < 2) {
      return 0;
    }
    final sorted = channel.keyframes.toList(growable: false)
      ..sort((left, right) => left.timeMs.compareTo(right.timeMs));
    var penalty = 0;
    for (var index = 1; index < sorted.length; index += 1) {
      final delta = sorted[index].timeMs - sorted[index - 1].timeMs;
      if (delta < 90) {
        penalty += 2;
      }
      if (delta > 2200) {
        penalty += 2;
      }
    }
    return penalty;
  }

  String _motionSignature(ReFusionSceneProgramChannel channel) {
    final property = _normalize(channel.property);
    if (property == 'opacity' || property == 'alpha') {
      return 'fade';
    }
    if (property == 'x' || property == 'positionx' || property == 'position.x') {
      return 'slideX';
    }
    if (property == 'y' || property == 'positiony' || property == 'position.y') {
      return 'slideY';
    }
    if (property == 'scale' ||
        property == 'scalex' ||
        property == 'scaley' ||
        property == 'width' ||
        property == 'height') {
      return 'scale';
    }
    if (property == 'rotation' || property == 'rotationdeg') {
      return 'rotate';
    }
    return property;
  }

  String? _stringFromMap(
    Map<String, Object?> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final direct = map[key];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }
      if (!key.contains('.')) {
        continue;
      }
      final parts = key.split('.');
      Map<String, Object?>? cursor = map;
      for (var index = 0; index < parts.length - 1; index += 1) {
        final child = cursor?[parts[index]];
        if (child is Map<String, Object?>) {
          cursor = child;
          continue;
        }
        cursor = null;
        break;
      }
      if (cursor == null) {
        continue;
      }
      final nested = cursor[parts.last];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }
    return null;
  }

  Map<String, Object?>? _mapFromMap(
    Map<String, Object?> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map<String, Object?>) {
        return value;
      }
    }
    return null;
  }

  double? _doubleFromMap(
    Map<String, Object?> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\.]+'), '');
}

class _ElementRef {
  const _ElementRef({
    required this.layer,
    required this.element,
  });

  final ReFusionSceneProgramLayer layer;
  final ReFusionSceneProgramElement element;
}

extension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E value) predicate) {
    for (final value in this) {
      if (predicate(value)) {
        return value;
      }
    }
    return null;
  }
}
