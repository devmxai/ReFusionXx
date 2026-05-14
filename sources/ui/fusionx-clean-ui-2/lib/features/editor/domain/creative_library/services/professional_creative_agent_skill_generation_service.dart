import '../../mcp/refusion_mcp_tool_registry.dart';
import '../models/professional_creative_library_registry_models.dart';
import 'professional_creative_library_registry.dart';

enum AgentSkillValidationSeverity {
  info,
  warning,
  blocker,
}

class AgentSkillValidationIssue {
  const AgentSkillValidationIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.reference,
  });

  final String code;
  final String message;
  final AgentSkillValidationSeverity severity;
  final String? reference;
}

class ProfessionalCreativeAgentSkillSnapshot {
  const ProfessionalCreativeAgentSkillSnapshot({
    required this.supportedCapabilityIds,
    required this.unsupportedCapabilityIds,
    required this.supportedTools,
  });

  final List<String> supportedCapabilityIds;
  final List<String> unsupportedCapabilityIds;
  final List<String> supportedTools;
}

class ProfessionalCreativeAgentSkillValidationReport {
  const ProfessionalCreativeAgentSkillValidationReport({
    required this.ok,
    required this.issues,
    required this.staleSkillReferenceCount,
  });

  final bool ok;
  final List<AgentSkillValidationIssue> issues;
  final int staleSkillReferenceCount;
}

class ProfessionalCreativeAgentSkillGenerationService {
  const ProfessionalCreativeAgentSkillGenerationService({
    required this.registry,
    required this.toolRegistry,
  });

  final ProfessionalCreativeLibraryRegistry registry;
  final RefusionMcpToolRegistry toolRegistry;

  ProfessionalCreativeAgentSkillSnapshot buildSnapshot() {
    final supportedCapabilities = <String>[];
    final unsupportedCapabilities = <String>[];
    for (final item in registry.listAll()) {
      if (item.supportedEntrySurfaces.contains(SupportedEntrySurface.mcp)) {
        supportedCapabilities.add(item.id);
      } else {
        unsupportedCapabilities.add(item.id);
      }
    }
    supportedCapabilities.sort();
    unsupportedCapabilities.sort();
    final tools = toolRegistry
        .list()
        .map((tool) => tool.name)
        .toList(growable: false)
      ..sort();
    return ProfessionalCreativeAgentSkillSnapshot(
      supportedCapabilityIds: List<String>.unmodifiable(supportedCapabilities),
      unsupportedCapabilityIds:
          List<String>.unmodifiable(unsupportedCapabilities),
      supportedTools: List<String>.unmodifiable(tools),
    );
  }

  String generateCanonicalSkillMarkdown({
    String title = 'ReFusion MCP Agent Skill (Registry-Synced)',
  }) {
    final snapshot = buildSnapshot();
    final buffer = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln('## Supported Capability IDs (MCP)')
      ..writeln();
    for (final id in snapshot.supportedCapabilityIds) {
      buffer.writeln('- `$id`');
    }
    buffer
      ..writeln()
      ..writeln('## Supported MCP Tools')
      ..writeln();
    for (final toolName in snapshot.supportedTools) {
      buffer.writeln('- `$toolName`');
    }
    buffer
      ..writeln()
      ..writeln('## Validation Rule')
      ..writeln(
          '- Do not reference capability IDs or tools outside the lists above.');
    return buffer.toString().trimRight();
  }

  ProfessionalCreativeAgentSkillValidationReport validateMarkdown(
    String markdown,
  ) {
    final snapshot = buildSnapshot();
    final issues = <AgentSkillValidationIssue>[];
    final supportedCapabilities = snapshot.supportedCapabilityIds.toSet();
    final unsupportedCapabilities = snapshot.unsupportedCapabilityIds.toSet();
    final supportedTools = snapshot.supportedTools.toSet();

    final toolRefs = _extractToolRefs(markdown);
    for (final ref in toolRefs) {
      if (!supportedTools.contains(ref)) {
        issues.add(
          AgentSkillValidationIssue(
            code: 'STALE_TOOL_REFERENCE',
            message: 'Tool `$ref` is not present in MCP tool registry.',
            severity: AgentSkillValidationSeverity.blocker,
            reference: ref,
          ),
        );
      }
    }

    final capabilityRefs = _extractCapabilityRefs(markdown);
    for (final ref in capabilityRefs) {
      if (supportedCapabilities.contains(ref)) {
        continue;
      }
      if (unsupportedCapabilities.contains(ref)) {
        issues.add(
          AgentSkillValidationIssue(
            code: 'UNSUPPORTED_CAPABILITY_ADVERTISED',
            message: 'Capability `$ref` is not MCP-supported.',
            severity: AgentSkillValidationSeverity.blocker,
            reference: ref,
          ),
        );
        continue;
      }
      issues.add(
        AgentSkillValidationIssue(
          code: 'STALE_CAPABILITY_REFERENCE',
          message: 'Capability `$ref` is not present in creative registry.',
          severity: AgentSkillValidationSeverity.blocker,
          reference: ref,
        ),
      );
    }

    for (final jsonCheck in _validateJsonCodeBlocks(markdown)) {
      issues.add(jsonCheck);
    }

    final blockers = issues
        .where(
            (issue) => issue.severity == AgentSkillValidationSeverity.blocker)
        .toList(growable: false);
    final staleCount = issues
        .where((issue) =>
            issue.code == 'STALE_TOOL_REFERENCE' ||
            issue.code == 'STALE_CAPABILITY_REFERENCE')
        .length;
    return ProfessionalCreativeAgentSkillValidationReport(
      ok: blockers.isEmpty,
      issues: List<AgentSkillValidationIssue>.unmodifiable(issues),
      staleSkillReferenceCount: staleCount,
    );
  }

  Set<String> _extractToolRefs(String markdown) {
    final matches = RegExp(r'refusion(?:\.[a-z0-9_]+)+')
        .allMatches(markdown)
        .map((match) => match.group(0))
        .whereType<String>()
        .toSet();
    return matches;
  }

  Set<String> _extractCapabilityRefs(String markdown) {
    final refs = <String>{};
    final inlineCode = RegExp(r'`([^`]+)`');
    for (final match in inlineCode.allMatches(markdown)) {
      final token = match.group(1)?.trim();
      if (token == null || token.isEmpty) {
        continue;
      }
      if (token.startsWith(r'$')) {
        refs.add(token);
      }
    }
    return refs;
  }

  List<AgentSkillValidationIssue> _validateJsonCodeBlocks(String markdown) {
    final issues = <AgentSkillValidationIssue>[];
    final blockRegex = RegExp(r'```json\s*([\s\S]*?)```', multiLine: true);
    for (final match in blockRegex.allMatches(markdown)) {
      final jsonBody = match.group(1)?.trim();
      if (jsonBody == null || jsonBody.isEmpty) {
        continue;
      }
      final hasObjectLikeShape =
          jsonBody.startsWith('{') && jsonBody.endsWith('}');
      final hasArrayLikeShape =
          jsonBody.startsWith('[') && jsonBody.endsWith(']');
      if (!hasObjectLikeShape && !hasArrayLikeShape) {
        issues.add(
          const AgentSkillValidationIssue(
            code: 'JSON_EXAMPLE_NOT_CANONICAL',
            message:
                'JSON code block must contain a top-level object or array.',
            severity: AgentSkillValidationSeverity.blocker,
          ),
        );
      }
    }
    return issues;
  }
}
