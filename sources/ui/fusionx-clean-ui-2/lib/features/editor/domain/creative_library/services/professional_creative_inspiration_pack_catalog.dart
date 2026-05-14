import '../models/professional_creative_library_registry_models.dart';
import 'professional_creative_library_registry.dart';

enum InspirationPackSource {
  hyperframesInspired,
  remotionInspired,
}

class InspirationPackItem {
  const InspirationPackItem({
    required this.capabilityId,
    required this.kind,
  });

  final String capabilityId;
  final CreativeLibraryItemKind kind;
}

class InspirationPackMaterialization {
  const InspirationPackMaterialization({
    required this.packId,
    required this.source,
    required this.items,
    required this.missingRequirements,
  });

  final String packId;
  final InspirationPackSource source;
  final List<InspirationPackItem> items;
  final List<String> missingRequirements;

  bool get isReady => missingRequirements.isEmpty && items.isNotEmpty;
}

class InspirationPackDefinition {
  const InspirationPackDefinition({
    required this.id,
    required this.source,
    required this.title,
    required this.requiredKinds,
    required this.intentTags,
  });

  final String id;
  final InspirationPackSource source;
  final String title;
  final Set<CreativeLibraryItemKind> requiredKinds;
  final Set<String> intentTags;
}

class ProfessionalCreativeInspirationPackCatalog {
  const ProfessionalCreativeInspirationPackCatalog();

  static const List<InspirationPackDefinition> _definitions =
      <InspirationPackDefinition>[
    InspirationPackDefinition(
      id: 'pack.hyperframes.social_overlay',
      source: InspirationPackSource.hyperframesInspired,
      title: 'Social Overlay Starter',
      requiredKinds: <CreativeLibraryItemKind>{
        CreativeLibraryItemKind.component,
        CreativeLibraryItemKind.effect,
        CreativeLibraryItemKind.motionRecipe,
      },
      intentTags: <String>{'social', 'overlay', 'promo', 'grid', 'shimmer'},
    ),
    InspirationPackDefinition(
      id: 'pack.hyperframes.kinetic_type',
      source: InspirationPackSource.hyperframesInspired,
      title: 'Kinetic Type Starter',
      requiredKinds: <CreativeLibraryItemKind>{
        CreativeLibraryItemKind.component,
        CreativeLibraryItemKind.motionRecipe,
      },
      intentTags: <String>{'text', 'type', 'kinetic', 'title'},
    ),
    InspirationPackDefinition(
      id: 'pack.remotion.sequence_motion',
      source: InspirationPackSource.remotionInspired,
      title: 'Sequence Motion Starter',
      requiredKinds: <CreativeLibraryItemKind>{
        CreativeLibraryItemKind.motionRecipe,
        CreativeLibraryItemKind.component,
      },
      intentTags: <String>{'sequence', 'transition', 'spring', 'interpolate'},
    ),
    InspirationPackDefinition(
      id: 'pack.remotion.shape_caption',
      source: InspirationPackSource.remotionInspired,
      title: 'Shape + Caption Starter',
      requiredKinds: <CreativeLibraryItemKind>{
        CreativeLibraryItemKind.component,
        CreativeLibraryItemKind.effect,
      },
      intentTags: <String>{'shape', 'caption', 'subtitle', 'lower-third'},
    ),
  ];

  List<InspirationPackDefinition> listDefinitions() => _definitions;

  InspirationPackMaterialization materialize({
    required ProfessionalCreativeLibraryRegistry registry,
    required String packId,
  }) {
    final definition = _definitions.where((pack) => pack.id == packId);
    if (definition.isEmpty) {
      return InspirationPackMaterialization(
        packId: packId,
        source: InspirationPackSource.hyperframesInspired,
        items: const <InspirationPackItem>[],
        missingRequirements: const <String>['PACK_NOT_FOUND'],
      );
    }
    final pack = definition.first;

    final items = <InspirationPackItem>[];
    final missing = <String>[];
    for (final kind in pack.requiredKinds) {
      final candidates = registry
          .listByKind(kind)
          .where(_isNativeEditable)
          .toList(growable: false);
      if (candidates.isEmpty) {
        missing.add('NO_NATIVE_EDITABLE_${kind.name.toUpperCase()}');
        continue;
      }
      final preferred = _pickPreferred(candidates, pack.intentTags);
      items.add(
        InspirationPackItem(
          capabilityId: preferred.id,
          kind: preferred.kind,
        ),
      );
    }
    return InspirationPackMaterialization(
      packId: pack.id,
      source: pack.source,
      items: List<InspirationPackItem>.unmodifiable(items),
      missingRequirements: List<String>.unmodifiable(missing),
    );
  }

  bool _isNativeEditable(CreativeLibraryItemDefinition item) {
    if (!item.rendererConformance.previewSupported ||
        !item.exportConformance.exportSupported) {
      return false;
    }
    if (item.benchmarkDecision == CapabilityBenchmarkDecision.prerenderOnly ||
        item.benchmarkDecision == CapabilityBenchmarkDecision.blocked ||
        item.benchmarkDecision == CapabilityBenchmarkDecision.reject) {
      return false;
    }
    return true;
  }

  CreativeLibraryItemDefinition _pickPreferred(
    List<CreativeLibraryItemDefinition> candidates,
    Set<String> intentTags,
  ) {
    if (candidates.length == 1) {
      return candidates.first;
    }
    final normalizedIntentTags =
        intentTags.map((tag) => tag.toLowerCase()).toSet();
    final ranked = candidates.toList(growable: false)
      ..sort((left, right) {
        final leftScore = _tagMatchScore(left.tags, normalizedIntentTags);
        final rightScore = _tagMatchScore(right.tags, normalizedIntentTags);
        if (leftScore != rightScore) {
          return rightScore.compareTo(leftScore);
        }
        return left.id.compareTo(right.id);
      });
    return ranked.first;
  }

  int _tagMatchScore(List<String> tags, Set<String> intentTags) {
    var score = 0;
    for (final tag in tags) {
      final normalized = tag.toLowerCase();
      for (final intent in intentTags) {
        if (normalized.contains(intent) || intent.contains(normalized)) {
          score += 1;
        }
      }
    }
    return score;
  }
}
