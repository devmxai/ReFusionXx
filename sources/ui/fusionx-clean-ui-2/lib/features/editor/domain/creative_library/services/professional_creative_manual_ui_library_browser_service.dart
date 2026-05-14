import '../models/professional_creative_library_discovery_models.dart';
import 'professional_creative_library_discovery_service.dart';

class CreativeManualUiLibraryBrowserSnapshot {
  const CreativeManualUiLibraryBrowserSnapshot({
    required this.components,
    required this.effects,
    required this.motionRecipes,
    required this.templates,
    required this.icons,
  });

  final CreativeLibraryDiscoveryListResponse components;
  final CreativeLibraryDiscoveryListResponse effects;
  final CreativeLibraryDiscoveryListResponse motionRecipes;
  final CreativeLibraryDiscoveryListResponse templates;
  final CreativeLibraryDiscoveryListResponse icons;
}

class CreativeManualUiMcpParityResult {
  const CreativeManualUiMcpParityResult({
    required this.ok,
    required this.matchRatio,
    required this.missingFamilies,
  });

  final bool ok;
  final double matchRatio;
  final List<String> missingFamilies;
}

class ProfessionalCreativeManualUiLibraryBrowserService {
  const ProfessionalCreativeManualUiLibraryBrowserService({
    required ProfessionalCreativeLibraryDiscoveryService discovery,
  }) : _discovery = discovery;

  final ProfessionalCreativeLibraryDiscoveryService _discovery;

  CreativeManualUiLibraryBrowserSnapshot browse() {
    return CreativeManualUiLibraryBrowserSnapshot(
      components: _discovery.listComponents(),
      effects: _discovery.listEffects(),
      motionRecipes: _discovery.listMotionRecipes(),
      templates: _discovery.listTemplates(),
      icons: _discovery.listIcons(),
    );
  }

  CreativeManualUiMcpParityResult validateParity({
    required CreativeManualUiLibraryBrowserSnapshot manualUiSnapshot,
    required CreativeManualUiLibraryBrowserSnapshot mcpSnapshot,
  }) {
    final missingFamilies = <String>[];
    var matched = 0;
    const total = 5;

    bool checkFamily(
      String family,
      CreativeLibraryDiscoveryListResponse left,
      CreativeLibraryDiscoveryListResponse right,
    ) {
      final leftIds = left.items.map((item) => item.id).toSet();
      final rightIds = right.items.map((item) => item.id).toSet();
      final same =
          leftIds.length == rightIds.length && leftIds.containsAll(rightIds);
      if (same) {
        matched += 1;
      } else {
        missingFamilies.add(family);
      }
      return same;
    }

    checkFamily(
        'components', manualUiSnapshot.components, mcpSnapshot.components);
    checkFamily('effects', manualUiSnapshot.effects, mcpSnapshot.effects);
    checkFamily(
        'motion', manualUiSnapshot.motionRecipes, mcpSnapshot.motionRecipes);
    checkFamily('templates', manualUiSnapshot.templates, mcpSnapshot.templates);
    checkFamily('icons', manualUiSnapshot.icons, mcpSnapshot.icons);

    return CreativeManualUiMcpParityResult(
      ok: missingFamilies.isEmpty,
      matchRatio: matched / total,
      missingFamilies: List<String>.unmodifiable(missingFamilies),
    );
  }
}
