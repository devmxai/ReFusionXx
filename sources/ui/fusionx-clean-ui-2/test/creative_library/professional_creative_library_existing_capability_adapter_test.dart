import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/scene_icon_registry.dart';
import 'package:refusion_app/features/editor/domain/services/scene_micro_scene_registry.dart';
import 'package:refusion_app/features/editor/domain/services/scene_motion_recipe_library.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_component_registry.dart';

void main() {
  group('PNCLE-02 Existing Capability Audit + Adapter', () {
    final adapter = ProfessionalCreativeLibraryExistingCapabilityAdapter();

    test('registry wraps existing capabilities with schema coverage', () {
      final registry = adapter.buildRegistry();
      final issues = registry.validateSchema();
      expect(issues, isEmpty);

      final motionRecipeCount = const SceneMotionRecipeLibrary().all.length;
      final componentCount =
          SceneSemanticComponentRegistry().supportedComponentIds.length;
      final iconCount = const SceneIconRegistry().semanticIcons.length +
          const SceneIconRegistry().brands.length;
      final templateCount = const SceneMicroSceneRegistry().ids.length;

      expect(
        registry.listByKind(CreativeLibraryItemKind.motionRecipe).length,
        motionRecipeCount,
      );
      expect(
        registry.listByKind(CreativeLibraryItemKind.component).length,
        componentCount,
      );
      expect(
          registry.listByKind(CreativeLibraryItemKind.icon).length, iconCount);
      expect(
        registry.listByKind(CreativeLibraryItemKind.template).length,
        templateCount,
      );

      final ids = registry.listAll().map((item) => item.id).toSet();
      expect(
        ids,
        containsAll(<String>[
          r'$effect.motionBlur',
          r'$effect.gaussianBlur',
          r'$motion.transformStack',
          r'$motion.keyframes',
          r'$text.insertUpdate',
          r'$shape.background',
          r'$media.videoImage',
        ]),
      );
    });

    test('capability_benchmark_record_coverage = 100%', () {
      final items = adapter.buildRegistry().listAll();
      final covered =
          items.where((item) => item.capabilityBenchmark.hasCompleteEvidence);
      expect(covered.length, items.length);
      expect(
        items.every((item) => item.capabilityBenchmark.hasValidScores),
        isTrue,
      );
    });

    test('legacy_path_cleanup_decision_coverage = 100%', () {
      final items = adapter.buildRegistry().listAll();
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

      final covered = items.where(
        (item) =>
            requiredCleanupPaths.every(item.legacyPathCleanup.containsKey),
      );
      expect(covered.length, items.length);
    });

    test('parallel_truth_path_count = 0', () {
      final registry = adapter.buildRegistry();
      final parallelTruthPathCount = registry.adapters
          .where((adapter) => adapter.directMutationCount > 0)
          .length;
      expect(parallelTruthPathCount, 0);
      expect(registry.hasParallelTruthPaths, isFalse);
    });

    test('existing_capability_review_coverage = 100% for audited core ids', () {
      final records = adapter.auditRecords();
      final recordById = <String, ExistingCapabilityAuditRecord>{
        for (final record in records) record.capabilityId: record,
      };

      expect(recordById[r'$effect.motionBlur'], isNotNull);
      expect(recordById[r'$effect.gaussianBlur'], isNotNull);
      expect(recordById[r'$motion.transformStack'], isNotNull);
      expect(recordById[r'$motion.keyframes'], isNotNull);
      expect(recordById[r'$text.insertUpdate'], isNotNull);
      expect(recordById[r'$shape.background'], isNotNull);
      expect(recordById[r'$media.videoImage'], isNotNull);

      expect(
        recordById[r'$effect.motionBlur']!.reviewDecision,
        ExistingCapabilityReviewDecision.upgrade,
      );
      expect(
        recordById[r'$effect.gaussianBlur']!.reviewDecision,
        ExistingCapabilityReviewDecision.wrap,
      );
    });
  });
}
