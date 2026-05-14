import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_agent_skill_generation_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';

void main() {
  group('PNCLE-12 Agent Skill Generation', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    final service = ProfessionalCreativeAgentSkillGenerationService(
      registry: registry,
      toolRegistry: RefusionMcpToolRegistry(),
    );

    test('builds MCP snapshot from canonical registries', () {
      final snapshot = service.buildSnapshot();

      expect(snapshot.supportedCapabilityIds, isNotEmpty);
      expect(snapshot.supportedTools, isNotEmpty);
      expect(
        snapshot.supportedTools.contains('refusion.insert_layer'),
        isTrue,
      );
      expect(
        snapshot.supportedCapabilityIds.toSet().intersection(
              snapshot.unsupportedCapabilityIds.toSet(),
            ),
        isEmpty,
      );
      expect(
        snapshot.recommendedCapabilityIds.toSet().intersection(
              snapshot.cautionCapabilityIds.toSet(),
            ),
        isEmpty,
      );
    });

    test('validates current skill doc with stale_skill_reference_count = 0',
        () {
      final markdown = File(
        'docs/refusion_mcp_agent_control_skill.md',
      ).readAsStringSync();
      final report = service.validateMarkdown(markdown);

      expect(report.ok, isTrue);
      expect(report.staleSkillReferenceCount, 0);
      expect(
        report.issues.where(
          (issue) => issue.severity == AgentSkillValidationSeverity.blocker,
        ),
        isEmpty,
      );
    });

    test('fails closed for stale tool/capability and invalid json example', () {
      const markdown = '''
Use `refusion.tool_that_does_not_exist`.
Use capability `\$template.unknown`.

```json
"not an object"
```
''';
      final report = service.validateMarkdown(markdown);

      expect(report.ok, isFalse);
      expect(
        report.issues.any((issue) => issue.code == 'STALE_TOOL_REFERENCE'),
        isTrue,
      );
      expect(
        report.issues
            .any((issue) => issue.code == 'STALE_CAPABILITY_REFERENCE'),
        isTrue,
      );
      expect(
        report.issues
            .any((issue) => issue.code == 'JSON_EXAMPLE_NOT_CANONICAL'),
        isTrue,
      );
    });

    test('flags MCP-unsupported capability when advertised', () {
      final snapshot = service.buildSnapshot();
      if (snapshot.unsupportedCapabilityIds.isEmpty) {
        // Defensive guard: if all capabilities are MCP-supported, nothing to assert.
        expect(snapshot.unsupportedCapabilityIds, isEmpty);
        return;
      }

      final capabilityId = snapshot.unsupportedCapabilityIds.first;
      final report = service.validateMarkdown(
        'Do not advertise `$capabilityId` for MCP skill docs.',
      );

      expect(report.ok, isFalse);
      expect(
        report.issues.any(
          (issue) => issue.code == 'UNSUPPORTED_CAPABILITY_ADVERTISED',
        ),
        isTrue,
      );
    });

    test('generates canonical markdown with only registry-backed references',
        () {
      final markdown = service.generateCanonicalSkillMarkdown();
      final report = service.validateMarkdown(markdown);

      expect(
        report.ok,
        isTrue,
        reason: report.issues
            .map((issue) => '${issue.code}:${issue.reference ?? ''}')
            .join('\n'),
      );
      expect(report.staleSkillReferenceCount, 0);
    });

    test('warns when markdown advertises caution capability', () {
      final snapshot = service.buildSnapshot();
      if (snapshot.cautionCapabilityIds.isEmpty) {
        expect(snapshot.cautionCapabilityIds, isEmpty);
        return;
      }
      final capabilityId = snapshot.cautionCapabilityIds.first;
      final report = service.validateMarkdown(
        'Prefer using `$capabilityId` in every baseline prompt.',
      );
      expect(report.ok, isTrue);
      expect(
        report.issues.any(
          (issue) => issue.code == 'CAPABILITY_REQUIRES_UPGRADE',
        ),
        isTrue,
      );
    });
  });
}
