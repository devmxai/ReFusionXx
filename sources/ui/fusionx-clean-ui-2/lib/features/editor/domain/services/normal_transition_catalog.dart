import 'package:flutter/foundation.dart';

import '../models/professional_normal_transition_models.dart';
import '../models/professional_normal_transition_presets.dart';
import 'normal_transition_script_import_service.dart';

@immutable
class NormalTransitionCatalogLoadResult {
  const NormalTransitionCatalogLoadResult({
    required this.definitions,
    required this.issues,
  });

  final List<NormalTransitionDefinition> definitions;
  final List<NormalTransitionIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );

  NormalTransitionDefinition? definitionById(String id) {
    for (final definition in definitions) {
      if (definition.definitionId == id) {
        return definition;
      }
    }
    return null;
  }
}

class NormalTransitionCatalog {
  const NormalTransitionCatalog({
    this.importService = const NormalTransitionScriptImportService(),
    this.sourcesById = kBuiltInNormalTransitionDefinitionJsonById,
  });

  final NormalTransitionScriptImportService importService;
  final Map<String, String> sourcesById;

  NormalTransitionCatalogLoadResult loadBuiltIns() {
    final definitions = <NormalTransitionDefinition>[];
    final issues = <NormalTransitionIssue>[];
    final seenIds = <String>{};
    for (final entry in sourcesById.entries) {
      final result = importService.validate(
        source: entry.value,
        fileName: '${entry.key}.json',
      );
      for (final issue in result.issues) {
        issues.add(
          NormalTransitionIssue(
            severity: issue.severity,
            message: issue.message,
            path: issue.path == null ? entry.key : '${entry.key}.${issue.path}',
          ),
        );
      }
      final definition = result.definition;
      if (definition == null) {
        continue;
      }
      if (definition.definitionId != entry.key) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Definition id `${definition.definitionId}` must match catalog key `${entry.key}`.',
            path: entry.key,
          ),
        );
        continue;
      }
      if (!seenIds.add(definition.definitionId)) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Duplicate transition definition `${definition.definitionId}`.',
            path: entry.key,
          ),
        );
        continue;
      }
      definitions.add(definition);
    }
    definitions.sort(
      (left, right) => left.definitionId.compareTo(right.definitionId),
    );
    return NormalTransitionCatalogLoadResult(
      definitions: List.unmodifiable(definitions),
      issues: List.unmodifiable(issues),
    );
  }
}
