import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_agent_skill_generation_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_command_compiler.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_command_lowerer.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_export_parity_gate.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_visual_closure_loop_service.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';

void main() {
  group('PNCLE-14 Full Acceptance Suite', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    final compiler = ProfessionalCreativeCommandCompiler(registry: registry);
    const lowerer = ProfessionalCreativeCommandLowerer();
    const parityGate = ProfessionalCreativeExportParityGate();
    final skillService = ProfessionalCreativeAgentSkillGenerationService(
      registry: registry,
      toolRegistry: RefusionMcpToolRegistry(),
    );
    const closureService = ProfessionalCreativeVisualClosureLoopService();

    test('canonical creative flow passes full acceptance gate', () {
      final schemaIssues = registry.validateSchema();
      expect(schemaIssues, isEmpty);
      expect(registry.hasParallelTruthPaths, isFalse);

      final component =
          registry.listByKind(CreativeLibraryItemKind.component).firstWhere(
                (item) => item.supportedEntrySurfaces.contains(
                  SupportedEntrySurface.mcp,
                ),
              );

      final compileResult = compiler.compileInsertComponent(
        surface: SupportedEntrySurface.mcp,
        capabilityId: component.id,
        targetId: 'node.acceptance.hero',
        params: const <String, Object?>{
          'trackKind': 'visual',
          'startMs': 0,
          'durationMs': 1800,
          'zIndex': 10,
        },
      );
      expect(compileResult.ok, isTrue);
      expect(compileResult.envelopes, isNotEmpty);

      final projection = lowerer.lower(envelopes: compileResult.envelopes);
      expect(projection.ok, isTrue);
      expect(projection.graphVisible, isTrue);
      expect(projection.timelineVisible, isTrue);

      final parity = parityGate.evaluate(
        registry: registry,
        capabilityIds: <String>{component.id},
        projection: projection,
      );
      expect(parity.ready, isTrue);
      expect(parity.issues, isEmpty);

      final skillDoc =
          File('docs/refusion_mcp_agent_control_skill.md').readAsStringSync();
      final skillReport = skillService.validateMarkdown(skillDoc);
      expect(skillReport.ok, isTrue);
      expect(skillReport.staleSkillReferenceCount, 0);

      final closure = closureService.buildReport(
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
      expect(closure.ok, isTrue);
    });
  });
}
