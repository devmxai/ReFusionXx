import '../models/creative_transaction_contract_models.dart';

class LegacyMutationBypassViolation implements Exception {
  const LegacyMutationBypassViolation(this.message);

  final String message;

  @override
  String toString() => 'LegacyMutationBypassViolation: $message';
}

class LegacyPathCleanupRegistry {
  const LegacyPathCleanupRegistry({
    this.records = const <LegacyPathCleanupRecord>[],
  });

  final List<LegacyPathCleanupRecord> records;

  LegacyPathCleanupRegistry append(LegacyPathCleanupRecord record) {
    return LegacyPathCleanupRegistry(records: <LegacyPathCleanupRecord>[...records, record]);
  }

  bool isMarkedBlocked(String pathId) {
    return records.any(
      (record) =>
          record.pathId == pathId &&
          record.decision == LegacyPathCleanupDecision.block,
    );
  }
}

class LegacyCreativeMutationBypassGuard {
  const LegacyCreativeMutationBypassGuard({
    this.registry = const LegacyPathCleanupRegistry(),
  });

  final LegacyPathCleanupRegistry registry;

  void assertAllowedPath({
    required String pathId,
    required bool throughCanonicalTransactionEngine,
    String action = 'write',
  }) {
    final normalized = pathId.trim();
    if (normalized.isEmpty) {
      throw const LegacyMutationBypassViolation('pathId is required.');
    }
    if (registry.isMarkedBlocked(normalized)) {
      throw LegacyMutationBypassViolation(
        'blocked_legacy_path:$normalized',
      );
    }
    if (!throughCanonicalTransactionEngine) {
      throw LegacyMutationBypassViolation(
        'legacy_bypass_detected:$normalized action=$action',
      );
    }
  }
}

class LegacyMutationPatternScanner {
  const LegacyMutationPatternScanner();

  LegacyMutationPatternScanResult scan(String sourceText) {
    final patterns = <String, RegExp>{
      'insert_used_as_update': RegExp(r'insert[_A-Za-z0-9]*\s*\('),
      'metadata_only_success': RegExp(r'appApplied\s*[:=]\s*true'),
      'selected_fallback': RegExp(r'selected.*fallback', caseSensitive: false),
      'direct_canvas_mutation': RegExp(r'setState\s*\('),
    };
    final counts = <String, int>{};
    patterns.forEach((key, regex) {
      counts[key] = regex.allMatches(sourceText).length;
    });
    return LegacyMutationPatternScanResult(counts: counts);
  }
}

class LegacyMutationPatternScanResult {
  const LegacyMutationPatternScanResult({
    required this.counts,
  });

  final Map<String, int> counts;

  int get total => counts.values.fold<int>(0, (sum, next) => sum + next);
}
