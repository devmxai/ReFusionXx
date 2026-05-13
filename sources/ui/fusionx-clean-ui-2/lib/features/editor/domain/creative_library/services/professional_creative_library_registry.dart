import '../models/professional_creative_library_registry_models.dart';

class ProfessionalCreativeLibraryRegistry {
  ProfessionalCreativeLibraryRegistry({
    List<CreativeLibraryItemDefinition> items =
        const <CreativeLibraryItemDefinition>[],
    List<EntrySurfaceAdapterDefinition> adapters =
        const <EntrySurfaceAdapterDefinition>[],
  })  : _items = Map<String, CreativeLibraryItemDefinition>.fromEntries(
          items.map(
            (item) => MapEntry<String, CreativeLibraryItemDefinition>(
              item.id,
              item,
            ),
          ),
        ),
        _adapters = List<EntrySurfaceAdapterDefinition>.unmodifiable(adapters);

  final Map<String, CreativeLibraryItemDefinition> _items;
  final List<EntrySurfaceAdapterDefinition> _adapters;

  List<CreativeLibraryItemDefinition> listAll() {
    final values = _items.values.toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));
    return values;
  }

  List<CreativeLibraryItemDefinition> listByKind(CreativeLibraryItemKind kind) {
    return listAll().where((item) => item.kind == kind).toList(growable: false);
  }

  CreativeLibraryItemDefinition? describe(String id) {
    return _items[id];
  }

  List<EntrySurfaceAdapterDefinition> get adapters => _adapters;

  List<CreativeLibrarySchemaIssue> validateSchema() {
    final issues = <CreativeLibrarySchemaIssue>[];
    for (final item in listAll()) {
      _validateItem(item, issues);
    }
    for (final adapter in _adapters) {
      if (!adapter.emitsEnvelope) {
        issues.add(
          CreativeLibrarySchemaIssue(
            itemId: adapter.id,
            message:
                'Entry surface adapter must emit ProfessionalSceneCommandEnvelope.',
          ),
        );
      }
      if (adapter.directMutationCount != 0) {
        issues.add(
          CreativeLibrarySchemaIssue(
            itemId: adapter.id,
            message:
                'Entry surface adapter directMutationCount must be 0 for canonical flow.',
          ),
        );
      }
    }
    return List<CreativeLibrarySchemaIssue>.unmodifiable(issues);
  }

  Map<String, int> capabilityCountsByKind() {
    final counts = <String, int>{};
    for (final kind in CreativeLibraryItemKind.values) {
      counts[kind.name] = listByKind(kind).length;
    }
    return counts;
  }

  bool get hasParallelTruthPaths {
    return _adapters.any((adapter) => adapter.directMutationCount > 0);
  }

  void _validateItem(
    CreativeLibraryItemDefinition item,
    List<CreativeLibrarySchemaIssue> issues,
  ) {
    if (item.id.trim().isEmpty) {
      issues.add(
        CreativeLibrarySchemaIssue(
          itemId: item.id,
          message: 'id must not be empty.',
        ),
      );
    }
    if (item.version.trim().isEmpty) {
      issues.add(
        CreativeLibrarySchemaIssue(
          itemId: item.id,
          message: 'version must not be empty.',
        ),
      );
    }
    if (item.supportedEntrySurfaces.isEmpty) {
      issues.add(
        CreativeLibrarySchemaIssue(
          itemId: item.id,
          message: 'supportedEntrySurfaces must not be empty.',
        ),
      );
    }

    const requiredCleanupPaths = <String>{
      'manualUiPath',
      'mcpPath',
      'pasteScriptPath',
      'templatePath',
      'tapListPath',
      'legacyLocalMutationPath',
      'rendererOnlyPath',
      'databaseOnlyPath',
      'metadataOnlyPath',
      'exportOnlyPath',
    };
    for (final path in requiredCleanupPaths) {
      if (!item.legacyPathCleanup.containsKey(path)) {
        issues.add(
          CreativeLibrarySchemaIssue(
            itemId: item.id,
            message: 'legacyPathCleanup missing decision for `$path`.',
          ),
        );
      }
    }

    if (!item.capabilityBenchmark.hasValidScores) {
      issues.add(
        CreativeLibrarySchemaIssue(
          itemId: item.id,
          message: 'capabilityBenchmark scores must be within [1..5].',
        ),
      );
    }
    if (!item.capabilityBenchmark.hasCompleteEvidence) {
      issues.add(
        CreativeLibrarySchemaIssue(
          itemId: item.id,
          message:
              'capabilityBenchmark must include codeReferences, benchmarkScenes, and measurementResults.',
        ),
      );
    }
    if (item.rendererConformance.rendererPath.trim().isEmpty ||
        item.rendererConformance.exportPath.trim().isEmpty) {
      issues.add(
        CreativeLibrarySchemaIssue(
          itemId: item.id,
          message: 'rendererConformance paths must not be empty.',
        ),
      );
    }
    if (item.exportConformance.rendererPath.trim().isEmpty ||
        item.exportConformance.exportPath.trim().isEmpty) {
      issues.add(
        CreativeLibrarySchemaIssue(
          itemId: item.id,
          message: 'exportConformance paths must not be empty.',
        ),
      );
    }
  }
}
