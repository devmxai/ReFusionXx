import '../models/refusion_motion_director_models.dart';
import 'scene_motion_recipe_library.dart';
import 'scene_motion_recipe_models.dart';

class SceneMotionRecipeCompiler {
  const SceneMotionRecipeCompiler({
    SceneMotionRecipeLibrary library = const SceneMotionRecipeLibrary(),
  }) : _library = library;

  final SceneMotionRecipeLibrary _library;

  SceneMotionRecipeCompileResult compile(
    SceneMotionRecipeCompileRequest request,
  ) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final recipe = _library.find(request.recipeId);
    if (recipe == null) {
      return SceneMotionRecipeCompileResult(
        primitives: const <ReFusionMotionDirectorPrimitive>[],
        issues: <ReFusionMotionDirectorIssue>[
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Unknown motion recipe `${request.recipeId}`.',
            path: 'motionRecipe',
          ),
        ],
      );
    }

    final normalizedScope = _normalize(request.targetScope);
    final supportsScope = recipe.allowedTargets.any(
      (target) =>
          _normalize(target) == normalizedScope ||
          _normalize(target) == 'component',
    );
    if (!supportsScope) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'Motion recipe `${recipe.id}` does not support target scope `${request.targetScope}`.',
          path: 'motionRecipe.targetScope',
        ),
      );
      return SceneMotionRecipeCompileResult(
        primitives: const <ReFusionMotionDirectorPrimitive>[],
        issues: issues,
      );
    }

    final duration = request.endMs - request.startMs;
    if (duration <= 0) {
      return SceneMotionRecipeCompileResult(
        primitives: const <ReFusionMotionDirectorPrimitive>[],
        issues: <ReFusionMotionDirectorIssue>[
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Motion recipe `${recipe.id}` requires a positive compile window.',
            path: 'motionRecipe.duration',
          ),
        ],
      );
    }

    final staggerMs = request.staggerMs ?? recipe.staggerMs;
    final staggerOffset = request.index <= 0 ? 0 : (request.index * staggerMs);
    final shiftedStart = request.startMs + staggerOffset;
    final shiftedEnd = request.endMs + staggerOffset;
    if (shiftedEnd <= shiftedStart) {
      return SceneMotionRecipeCompileResult(
        primitives: const <ReFusionMotionDirectorPrimitive>[],
        issues: <ReFusionMotionDirectorIssue>[
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Motion recipe `${recipe.id}` produced invalid staggered timing window.',
            path: 'motionRecipe.staggerMs',
          ),
        ],
      );
    }

    final effectiveDuration = shiftedEnd - shiftedStart;
    final primitivePrefix = request.idPrefix ??
        '${_sanitize(request.targetComponentId)}-${_sanitize(recipe.id)}';
    final primitives = <ReFusionMotionDirectorPrimitive>[];
    for (var index = 0; index < recipe.channels.length; index += 1) {
      final channel = recipe.channels[index];
      final startFraction = channel.startFraction.clamp(0.0, 1.0);
      final endFraction = channel.endFraction.clamp(0.0, 1.0);
      if (endFraction <= startFraction) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Motion recipe `${recipe.id}` channel `${channel.property}` has invalid timing fractions.',
            path: 'motionRecipe.channels[$index]',
          ),
        );
        continue;
      }
      final channelStart =
          shiftedStart + (effectiveDuration * startFraction).round();
      final channelEnd =
          shiftedStart + (effectiveDuration * endFraction).round();
      final sanitizedEnd =
          channelEnd <= channelStart ? channelStart + 1 : channelEnd;
      final easing = _resolveEasing(
        recipe: recipe,
        channel: channel,
        issues: issues,
        path: 'motionRecipe.channels[$index].easing',
      );
      primitives.add(
        ReFusionMotionDirectorPrimitive(
          id: '$primitivePrefix-${_sanitize(channel.kind)}-$index',
          beatId: request.beatId,
          targetComponentId: request.targetComponentId,
          kind: channel.kind,
          property: channel.property,
          startMs: channelStart,
          endMs: sanitizedEnd,
          fromValue: channel.fromValue,
          toValue: channel.toValue,
          easing: easing,
          note: channel.note ?? recipe.tasteNotes,
        ),
      );
    }

    return SceneMotionRecipeCompileResult(
      primitives:
          List<ReFusionMotionDirectorPrimitive>.unmodifiable(primitives),
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  String _resolveEasing({
    required SceneMotionRecipeDefinition recipe,
    required SceneMotionRecipeChannel channel,
    required List<ReFusionMotionDirectorIssue> issues,
    required String path,
  }) {
    final channelEasing = channel.easing?.trim() ?? '';
    if (channelEasing.isNotEmpty) {
      return channelEasing;
    }
    final recipePreset = recipe.speedyGraphPreset.trim();
    if (recipePreset.isNotEmpty) {
      return recipePreset;
    }
    issues.add(
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.error,
        message:
            'Motion recipe `${recipe.id}` is missing SpeedyGraph easing. Linear fallback is not allowed.',
        path: path,
      ),
    );
    return 'slowFastSlow';
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  String _sanitize(String value) {
    final normalized = _normalize(value);
    return normalized.isEmpty ? 'motion' : normalized;
  }
}
