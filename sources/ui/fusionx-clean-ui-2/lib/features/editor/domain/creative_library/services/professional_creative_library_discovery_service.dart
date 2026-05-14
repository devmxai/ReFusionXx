import '../models/professional_creative_library_discovery_models.dart';
import '../models/professional_creative_library_registry_models.dart';
import 'professional_creative_library_registry.dart';

class ProfessionalCreativeLibraryDiscoveryService {
  const ProfessionalCreativeLibraryDiscoveryService({
    required ProfessionalCreativeLibraryRegistry registry,
  }) : _registry = registry;

  final ProfessionalCreativeLibraryRegistry _registry;

  CreativeLibraryDiscoveryListResponse listComponents() {
    return _list('components', CreativeLibraryItemKind.component);
  }

  CreativeLibraryDiscoveryListResponse listEffects() {
    return _list('effects', CreativeLibraryItemKind.effect);
  }

  CreativeLibraryDiscoveryListResponse listMotionRecipes() {
    return _list('motion_recipes', CreativeLibraryItemKind.motionRecipe);
  }

  CreativeLibraryDiscoveryListResponse listTemplates() {
    return _list('templates', CreativeLibraryItemKind.template);
  }

  CreativeLibraryDiscoveryListResponse listIcons() {
    return _list('icons', CreativeLibraryItemKind.icon);
  }

  CreativeLibraryDiscoveryDescribeResponse? describeComponent(String id) {
    return _describe(id, CreativeLibraryItemKind.component);
  }

  CreativeLibraryDiscoveryDescribeResponse? describeEffect(String id) {
    return _describe(id, CreativeLibraryItemKind.effect);
  }

  CreativeLibraryDiscoveryDescribeResponse? describeMotionRecipe(String id) {
    return _describe(id, CreativeLibraryItemKind.motionRecipe);
  }

  CreativeLibraryDiscoveryDescribeResponse? describeTemplate(String id) {
    return _describe(id, CreativeLibraryItemKind.template);
  }

  CreativeLibraryDiscoveryDescribeResponse? describeIcon(String id) {
    return _describe(id, CreativeLibraryItemKind.icon);
  }

  CreativeLibraryDiscoveryListResponse _list(
    String family,
    CreativeLibraryItemKind kind,
  ) {
    final items = _registry
        .listByKind(kind)
        .map(
          (item) => CreativeLibraryDiscoveryListItem(
            id: item.id,
            title: item.title,
            kind: item.kind,
            category: item.category,
            tags: item.tags,
          ),
        )
        .toList(growable: false);

    return CreativeLibraryDiscoveryListResponse(
      family: family,
      items: items,
    );
  }

  CreativeLibraryDiscoveryDescribeResponse? _describe(
    String id,
    CreativeLibraryItemKind kind,
  ) {
    final item = _registry.describe(id);
    if (item == null || item.kind != kind) {
      return null;
    }
    return CreativeLibraryDiscoveryDescribeResponse(id: id, item: item);
  }
}
