import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_visual_closure_loop_service.dart';

void main() {
  group('PNCLE-13 Visual Closure Loop', () {
    const service = ProfessionalCreativeVisualClosureLoopService();

    test('passes when required apply-proof flags are true', () {
      final report = service.buildReport(
        applyProof: const <String, Object?>{
          'dataApplied': true,
          'localGraphApplied': true,
          'timelineVisible': true,
          'frameEvaluated': true,
          'visualProgramEmitted': true,
          'rendererApplied': true,
        },
        overlapDiagnostics: const <String>[],
        safeZoneDiagnostics: const <String>[],
        beforeFrameUri: 'memory://before.png',
        afterFrameUri: 'memory://after.png',
      );

      expect(report.ok, isTrue);
      expect(report.summary, contains('ready'));
    });

    test('fails when renderer proof flags are incomplete', () {
      final report = service.buildReport(
        applyProof: const <String, Object?>{
          'dataApplied': true,
          'localGraphApplied': true,
          'timelineVisible': true,
          'frameEvaluated': true,
          'visualProgramEmitted': false,
          'rendererApplied': false,
        },
        overlapDiagnostics: const <String>[],
        safeZoneDiagnostics: const <String>[],
        beforeFrameUri: 'memory://before.png',
        afterFrameUri: 'memory://after.png',
      );

      expect(report.ok, isFalse);
      expect(
        report.issues.any(
          (issue) => issue.code == 'PROOF_FLAG_MISSING_rendererApplied',
        ),
        isTrue,
      );
    });

    test('collects layout overlap and safe-zone warnings', () {
      final report = service.buildReport(
        applyProof: const <String, Object?>{
          'dataApplied': true,
          'localGraphApplied': true,
          'timelineVisible': true,
          'frameEvaluated': true,
          'visualProgramEmitted': true,
          'rendererApplied': true,
        },
        overlapDiagnostics: const <String>[
          'Text overlaps media at 1250ms.',
        ],
        safeZoneDiagnostics: const <String>[
          'Headline exits title-safe zone near frame 32.',
        ],
        beforeFrameUri: '',
        afterFrameUri: null,
      );

      expect(report.ok, isTrue);
      expect(
        report.issues.any((issue) => issue.code == 'LAYOUT_OVERLAP_DETECTED'),
        isTrue,
      );
      expect(
        report.issues.any((issue) => issue.code == 'SAFE_ZONE_VIOLATION'),
        isTrue,
      );
      expect(
        report.issues.any((issue) => issue.code == 'AFTER_FRAME_MISSING'),
        isTrue,
      );
    });

    test('buildAgentRepairPrompt returns actionable blocker summary', () {
      final report = service.buildReport(
        applyProof: const <String, Object?>{
          'dataApplied': true,
          'localGraphApplied': false,
          'timelineVisible': false,
          'frameEvaluated': false,
          'visualProgramEmitted': false,
          'rendererApplied': false,
        },
        overlapDiagnostics: const <String>['Elements overlap.'],
        safeZoneDiagnostics: const <String>[],
      );
      final prompt = service.buildAgentRepairPrompt(report);

      expect(prompt, contains('Visual closure failed'));
      expect(prompt, contains('Blockers:'));
      expect(prompt, contains('PROOF_FLAG_MISSING_rendererApplied'));
    });
  });
}
