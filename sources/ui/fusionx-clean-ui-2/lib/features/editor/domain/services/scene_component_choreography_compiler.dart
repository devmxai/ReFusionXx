import '../models/refusion_motion_director_models.dart';
import 'scene_component_choreography_models.dart';
import 'scene_motion_recipe_compiler.dart';
import 'scene_motion_recipe_models.dart';

const String kSceneComponentChoreographyCompilerProofTag =
    'TF_SCENE_COMPONENT_CHOREOGRAPHY_COMPILER_PROOF';

class SceneComponentChoreographyCompileRequest {
  const SceneComponentChoreographyCompileRequest({
    required this.componentType,
    required this.beatId,
    required this.parentStartMs,
    required this.parentEndMs,
    required this.spans,
    required this.componentIdsByRole,
    this.requiredRoles = const <String>{},
    this.index = 0,
    this.staggerMs,
    this.allowChannelMerge = false,
    this.professionalStrict = true,
  });

  final String componentType;
  final String beatId;
  final int parentStartMs;
  final int parentEndMs;
  final List<SceneComponentChoreographySpan> spans;
  final Map<String, String> componentIdsByRole;
  final Set<String> requiredRoles;
  final int index;
  final int? staggerMs;
  final bool allowChannelMerge;
  final bool professionalStrict;
}

class SceneComponentChoreographyCompileResult {
  const SceneComponentChoreographyCompileResult({
    required this.primitives,
    required this.issues,
  });

  final List<ReFusionMotionDirectorPrimitive> primitives;
  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class SceneComponentChoreographyCompiler {
  const SceneComponentChoreographyCompiler({
    SceneMotionRecipeCompiler recipeCompiler =
        const SceneMotionRecipeCompiler(),
  }) : _recipeCompiler = recipeCompiler;

  final SceneMotionRecipeCompiler _recipeCompiler;

  SceneComponentChoreographyCompileResult compile(
    SceneComponentChoreographyCompileRequest request,
  ) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final compiled = <ReFusionMotionDirectorPrimitive>[];

    if (request.parentEndMs <= request.parentStartMs) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'CHILD_TIMING_OUTSIDE_PARENT parent timing window is invalid.',
          path: 'componentChoreography.parentWindow',
        ),
      );
      return SceneComponentChoreographyCompileResult(
        primitives: const <ReFusionMotionDirectorPrimitive>[],
        issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
      );
    }

    if (request.spans.isEmpty) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'GROUP_EXIT_INCOHERENT choreography spans are empty.',
          path: 'componentChoreography.spans',
        ),
      );
      return SceneComponentChoreographyCompileResult(
        primitives: const <ReFusionMotionDirectorPrimitive>[],
        issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
      );
    }

    final sortedSpans = request.spans.toList(growable: false)
      ..sort(_compareSpansStable);

    if (request.professionalStrict && _isFadeOnlyPlan(sortedSpans)) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'FADE_ONLY_PROFESSIONAL_RECIPE `${request.componentType}` choreography cannot use fade-only recipes.',
          path: 'componentChoreography.recipes',
        ),
      );
    }

    for (var spanIndex = 0; spanIndex < sortedSpans.length; spanIndex += 1) {
      final span = sortedSpans[spanIndex];
      if (span.startMs < request.parentStartMs ||
          span.endMs > request.parentEndMs ||
          span.endMs <= span.startMs) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'CHILD_TIMING_OUTSIDE_PARENT span role `${span.role}` phase `${span.phase}` is outside parent window '
                '[${request.parentStartMs}, ${request.parentEndMs}].',
            path: 'componentChoreography.spans[$spanIndex]',
          ),
        );
        continue;
      }

      final componentId = request.componentIdsByRole[span.role];
      if (componentId == null) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'GROUP_EXIT_INCOHERENT missing component role mapping for `${span.role}` in `${request.componentType}`.',
            path: 'componentChoreography.roleMap.${span.role}',
          ),
        );
        continue;
      }

      final compiledRecipe = _recipeCompiler.compile(
        SceneMotionRecipeCompileRequest(
          recipeId: span.recipeId,
          targetComponentId: componentId,
          targetScope: span.targetScope,
          beatId: request.beatId,
          startMs: span.startMs,
          endMs: span.endMs,
          index: request.index,
          staggerMs: request.staggerMs,
          idPrefix:
              '${_sanitize(request.componentType)}-${_sanitize(span.phase)}-$componentId',
        ),
      );
      issues.addAll(compiledRecipe.issues);
      for (final primitive in compiledRecipe.primitives) {
        compiled.add(primitive);
      }
    }

    _validateRequiredRoles(
      request: request,
      spans: sortedSpans,
      issues: issues,
    );
    _validateExitCoherence(
      request: request,
      spans: sortedSpans,
      issues: issues,
    );
    _validateChannelOverlap(
      compiled: compiled,
      allowChannelMerge: request.allowChannelMerge,
      issues: issues,
    );

    issues.add(
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.info,
        message: '$kSceneComponentChoreographyCompilerProofTag '
            'component=${request.componentType} '
            'beat=${request.beatId} '
            'spanCount=${sortedSpans.length} '
            'primitiveCount=${compiled.length} '
            'strict=${request.professionalStrict} '
            'allowMerge=${request.allowChannelMerge}',
        path: 'componentChoreography',
      ),
    );

    return SceneComponentChoreographyCompileResult(
      primitives: List<ReFusionMotionDirectorPrimitive>.unmodifiable(
        compiled,
      ),
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  void _validateRequiredRoles({
    required SceneComponentChoreographyCompileRequest request,
    required List<SceneComponentChoreographySpan> spans,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    if (request.requiredRoles.isEmpty) {
      return;
    }
    final presentRoles = spans.map((span) => span.role).toSet();
    final missingRoles = request.requiredRoles.difference(presentRoles);
    if (missingRoles.isEmpty) {
      return;
    }
    issues.add(
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.error,
        message:
            'GROUP_EXIT_INCOHERENT missing choreography roles: ${missingRoles.join(', ')}.',
        path: 'componentChoreography.requiredRoles',
      ),
    );
  }

  void _validateExitCoherence({
    required SceneComponentChoreographyCompileRequest request,
    required List<SceneComponentChoreographySpan> spans,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    final exitSpans =
        spans.where((span) => _normalize(span.phase) == 'exit').toList();
    if (exitSpans.length <= 1) {
      return;
    }
    var minEnd = exitSpans.first.endMs;
    var maxEnd = exitSpans.first.endMs;
    for (final span in exitSpans.skip(1)) {
      if (span.endMs < minEnd) {
        minEnd = span.endMs;
      }
      if (span.endMs > maxEnd) {
        maxEnd = span.endMs;
      }
    }
    if (maxEnd - minEnd > 220) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'GROUP_EXIT_INCOHERENT exit spans diverge by ${maxEnd - minEnd}ms for `${request.componentType}`.',
          path: 'componentChoreography.exit',
        ),
      );
    }
  }

  void _validateChannelOverlap({
    required List<ReFusionMotionDirectorPrimitive> compiled,
    required bool allowChannelMerge,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    final grouped = <String, List<ReFusionMotionDirectorPrimitive>>{};
    for (final primitive in compiled) {
      final property = primitive.property ?? primitive.kind;
      final key = '${primitive.targetComponentId}|${_normalize(property)}';
      grouped
          .putIfAbsent(key, () => <ReFusionMotionDirectorPrimitive>[])
          .add(primitive);
    }

    for (final entries in grouped.values) {
      entries.sort((a, b) {
        final startCompare = a.startMs.compareTo(b.startMs);
        if (startCompare != 0) {
          return startCompare;
        }
        return a.endMs.compareTo(b.endMs);
      });
      for (var index = 1; index < entries.length; index += 1) {
        final previous = entries[index - 1];
        final current = entries[index];
        if (current.startMs >= previous.endMs) {
          continue;
        }
        if (allowChannelMerge && _isMergeEquivalent(previous, current)) {
          continue;
        }
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'DUPLICATE_CHANNEL_OVERLAP target=${current.targetComponentId} '
                'property=${current.property ?? current.kind} '
                'first=${previous.id} second=${current.id}.',
            path: 'componentChoreography.channels',
          ),
        );
      }
    }
  }

  bool _isMergeEquivalent(
    ReFusionMotionDirectorPrimitive a,
    ReFusionMotionDirectorPrimitive b,
  ) {
    return a.kind == b.kind &&
        a.property == b.property &&
        a.startMs == b.startMs &&
        a.endMs == b.endMs &&
        a.fromValue == b.fromValue &&
        a.toValue == b.toValue &&
        _normalize(a.easing) == _normalize(b.easing);
  }

  bool _isFadeOnlyPlan(List<SceneComponentChoreographySpan> spans) {
    if (spans.isEmpty) {
      return false;
    }
    return spans.every((span) {
      final recipe = _normalize(span.recipeId);
      return recipe.contains('fade');
    });
  }

  int _compareSpansStable(
    SceneComponentChoreographySpan a,
    SceneComponentChoreographySpan b,
  ) {
    final startCompare = a.startMs.compareTo(b.startMs);
    if (startCompare != 0) {
      return startCompare;
    }
    final endCompare = a.endMs.compareTo(b.endMs);
    if (endCompare != 0) {
      return endCompare;
    }
    final phaseCompare = _normalize(a.phase).compareTo(_normalize(b.phase));
    if (phaseCompare != 0) {
      return phaseCompare;
    }
    final roleCompare = _normalize(a.role).compareTo(_normalize(b.role));
    if (roleCompare != 0) {
      return roleCompare;
    }
    final scopeCompare =
        _normalize(a.targetScope).compareTo(_normalize(b.targetScope));
    if (scopeCompare != 0) {
      return scopeCompare;
    }
    return _normalize(a.recipeId).compareTo(_normalize(b.recipeId));
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _sanitize(String value) {
    final normalized = _normalize(value);
    return normalized.isEmpty ? 'component' : normalized;
  }
}
