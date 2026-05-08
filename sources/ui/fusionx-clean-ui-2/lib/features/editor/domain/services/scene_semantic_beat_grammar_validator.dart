import '../models/refusion_scene_program_models.dart';
import '../models/scene_semantic_blueprint_models.dart';
import 'scene_runtime_time_scope.dart';

const String kSceneBeatGrammarProofTag = 'TF_SCENE_BEAT_GRAMMAR_PROOF';
const String kSceneBeatTimeScopeProofTag = 'TF_SCENE_BEAT_TIME_SCOPE_PROOF';

class SceneSemanticBeatGrammarValidator {
  const SceneSemanticBeatGrammarValidator({
    SceneRuntimeTimeScopeService? timeScopeService,
  }) : _timeScopeService =
            timeScopeService ?? const SceneRuntimeTimeScopeService();

  final SceneRuntimeTimeScopeService _timeScopeService;

  List<ReFusionSceneProgramIssue> validate({
    required List<SemanticSceneBlueprintBeat> beats,
    required int sceneDurationMs,
    required List<SemanticSceneBlueprintComponent> components,
  }) {
    final issues = <ReFusionSceneProgramIssue>[];
    if (beats.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Beat grammar has no beats. Important motion should be owned by enter/hold/exit beats.',
          path: 'beats',
        ),
      );
      return issues;
    }

    final componentIds = components.map((it) => it.id).toSet();
    final sorted = beats.toList(growable: false)
      ..sort((left, right) => left.startMs.compareTo(right.startMs));
    for (var index = 0; index < sorted.length; index += 1) {
      final beat = sorted[index];
      final path = 'beats[$index]';
      final duration = beat.endMs - beat.startMs;
      if (beat.startMs < 0 || beat.endMs < 0 || beat.startMs >= beat.endMs) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Beat `${beat.id}` has invalid time window (`startMs < endMs` required).',
            path: '$path.startMs',
          ),
        );
        continue;
      }
      if (beat.endMs > sceneDurationMs) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Beat `${beat.id}` exceeds scene duration (`endMs > durationMs`).',
            path: '$path.endMs',
          ),
        );
      }

      final normalizedIntent = _normalize(beat.intent);
      var recommendedMinHold = 250;
      if (normalizedIntent.contains('text') ||
          normalizedIntent.contains('title') ||
          normalizedIntent.contains('type')) {
        recommendedMinHold = 500;
      }
      if (normalizedIntent.contains('card') ||
          normalizedIntent.contains('panel') ||
          normalizedIntent.contains('dashboard')) {
        recommendedMinHold = 900;
      }
      if (duration < recommendedMinHold) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Beat `${beat.id}` is not readable enough (`durationMs=$duration`, required >= $recommendedMinHold for intent `${beat.intent}`).',
            path: '$path.endMs',
          ),
        );
      }

      for (final componentId in beat.componentRefs) {
        if (!componentIds.contains(componentId)) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Beat `${beat.id}` references unknown component `$componentId`.',
              path: '$path.componentRefs',
            ),
          );
        }
      }

      if (index > 0) {
        final previous = sorted[index - 1];
        final overlap = previous.endMs > beat.startMs;
        if (overlap) {
          final policy = _normalize(beat.overlapPolicy ?? '');
          final allowed = policy == 'parallel' ||
              policy == 'while' ||
              policy == 'meanwhile' ||
              policy == 'alongside' ||
              policy == 'during' ||
              policy == 'handoff' ||
              policy == 'morph' ||
              policy == 'transform';
          if (!allowed) {
            issues.add(
              ReFusionSceneProgramIssue(
                severity: ReFusionSceneProgramIssueSeverity.error,
                message:
                    'Beat `${beat.id}` overlaps `${previous.id}` without explicit overlap policy.',
                path: '$path.overlapPolicy',
              ),
            );
          }
        }
      }

      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          message: '$kSceneBeatGrammarProofTag '
              'beatId=${beat.id} '
              'phase=intent '
              'startMs=${beat.startMs} '
              'endMs=${beat.endMs} '
              'holdMs=$duration '
              'readable=${(duration >= recommendedMinHold).toString()} '
              'overlapPolicy=${beat.overlapPolicy ?? 'none'}',
          path: path,
        ),
      );
      final midTime = beat.startMs + (duration ~/ 2);
      final scopeStart = _timeScopeService.evaluateBeat(
        beat: beat,
        timelineTimeMs: beat.startMs,
      );
      final scopeMid = _timeScopeService.evaluateBeat(
        beat: beat,
        timelineTimeMs: midTime,
      );
      final scopeEnd = _timeScopeService.evaluateBeat(
        beat: beat,
        timelineTimeMs: beat.endMs,
      );
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          message: '$kSceneBeatTimeScopeProofTag '
              'beatId=${beat.id} '
              'startLocal=${scopeStart.localTime.toStringAsFixed(3)} '
              'midLocal=${scopeMid.localTime.toStringAsFixed(3)} '
              'endLocal=${scopeEnd.localTime.toStringAsFixed(3)} '
              'startPhase=${scopeStart.phase.name} '
              'midPhase=${scopeMid.phase.name} '
              'endPhase=${scopeEnd.phase.name} '
              'enterBoundary=${scopeMid.enterBoundary.toStringAsFixed(3)} '
              'holdBoundary=${scopeMid.holdBoundary.toStringAsFixed(3)}',
          path: path,
        ),
      );
    }

    return issues;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
