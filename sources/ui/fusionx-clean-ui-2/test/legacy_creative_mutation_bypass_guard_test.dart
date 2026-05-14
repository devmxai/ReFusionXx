import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/legacy_creative_mutation_bypass_guard.dart';

void main() {
  group('PIVWSCT-12 legacy cleanup and bypass guards', () {
    test('guard allows canonical transaction path', () {
      const guard = LegacyCreativeMutationBypassGuard();
      expect(
        () => guard.assertAllowedPath(
          pathId: 'manual_ui.transaction_adapter',
          throughCanonicalTransactionEngine: true,
        ),
        returnsNormally,
      );
    });

    test('guard blocks direct legacy bypass write path', () {
      const guard = LegacyCreativeMutationBypassGuard();
      expect(
        () => guard.assertAllowedPath(
          pathId: 'legacy.mcp.direct_apply',
          throughCanonicalTransactionEngine: false,
        ),
        throwsA(isA<LegacyMutationBypassViolation>()),
      );
    });

    test('guard blocks registry-marked legacy path', () {
      final registry = LegacyPathCleanupRegistry(
        records: <LegacyPathCleanupRecord>[
          LegacyPathCleanupRecord(
            pathId: 'legacy.screen.shape_apply',
            decision: LegacyPathCleanupDecision.block,
            reason: 'migrated to unified transaction engine',
          ),
        ],
      );
      final guard = LegacyCreativeMutationBypassGuard(registry: registry);
      expect(
        () => guard.assertAllowedPath(
          pathId: 'legacy.screen.shape_apply',
          throughCanonicalTransactionEngine: true,
        ),
        throwsA(isA<LegacyMutationBypassViolation>()),
      );
    });

    test('pattern scanner reports legacy risk patterns', () {
      const scanner = LegacyMutationPatternScanner();
      const source = '''
        void applyLegacy() {
          insertLayer();
          setState(() {});
          final appApplied = true;
          final msg = "selected fallback";
        }
      ''';
      final result = scanner.scan(source);
      expect(result.counts['insert_used_as_update'], greaterThan(0));
      expect(result.counts['metadata_only_success'], greaterThan(0));
      expect(result.counts['selected_fallback'], greaterThan(0));
      expect(result.counts['direct_canvas_mutation'], greaterThan(0));
    });
  });
}
