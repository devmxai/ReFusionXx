import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_hardening_policy.dart';

void main() {
  group('RefusionMcpHardeningPolicy', () {
    test('validates pairing token by salted sha256 digest', () {
      const salt = 'salt::';
      const token = 'pair-123';
      final digest = sha256.convert(utf8.encode('$salt$token')).toString();
      final policy = RefusionMcpHardeningPolicy(
        requiredPairingTokenSha256Hex: digest,
        pairingTokenSalt: salt,
      );

      expect(policy.validatePairingToken(token).ok, isTrue);
      expect(policy.validatePairingToken('wrong').ok, isFalse);
    });

    test('enforces per-session rate limit window', () {
      var now = DateTime.utc(2026, 5, 11, 12, 0, 0);
      final policy = RefusionMcpHardeningPolicy(
        maxCallsPerMinutePerSession: 2,
        clock: () => now,
      );

      expect(policy.allowToolCallForSession('s1'), isTrue);
      expect(policy.allowToolCallForSession('s1'), isTrue);
      expect(policy.allowToolCallForSession('s1'), isFalse);

      now = now.add(const Duration(minutes: 1, seconds: 1));
      expect(policy.allowToolCallForSession('s1'), isTrue);
    });
  });
}
