import 'professional_creative_library_registry_models.dart';

class CreativeLibraryDiscoveryListItem {
  const CreativeLibraryDiscoveryListItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.category,
    required this.tags,
  });

  final String id;
  final String title;
  final CreativeLibraryItemKind kind;
  final String category;
  final List<String> tags;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'kind': kind.name,
      'category': category,
      'tags': tags,
    };
  }
}

class CreativeLibraryDiscoveryListResponse {
  const CreativeLibraryDiscoveryListResponse({
    required this.family,
    required this.items,
  });

  final String family;
  final List<CreativeLibraryDiscoveryListItem> items;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'family': family,
      'total': items.length,
      'items': items.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class CreativeLibraryDiscoveryDescribeResponse {
  const CreativeLibraryDiscoveryDescribeResponse({
    required this.id,
    required this.item,
  });

  final String id;
  final CreativeLibraryItemDefinition item;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'kind': item.kind.name,
      'title': item.title,
      'description': item.description,
      'category': item.category,
      'tags': item.tags,
      'benchmarkDecision': item.benchmarkDecision.name,
      'supportedEntrySurfaces':
          item.supportedEntrySurfaces.map((surface) => surface.name).toList(),
      'rendererConformance': <String, Object?>{
        'previewSupported': item.rendererConformance.previewSupported,
        'exportSupported': item.rendererConformance.exportSupported,
        'deterministic': item.rendererConformance.deterministic,
        'rendererPath': item.rendererConformance.rendererPath,
        'exportPath': item.rendererConformance.exportPath,
      },
    };
  }
}
