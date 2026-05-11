import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

@immutable
class RefusionMcpPairingValidation {
  const RefusionMcpPairingValidation._({
    required this.ok,
    this.message,
  });

  const RefusionMcpPairingValidation.allowed()
      : this._(
          ok: true,
        );

  const RefusionMcpPairingValidation.denied(String message)
      : this._(
          ok: false,
          message: message,
        );

  final bool ok;
  final String? message;
}

class RefusionMcpHardeningPolicy {
  RefusionMcpHardeningPolicy({
    this.requiredPairingToken,
    this.requiredPairingTokenSha256Hex,
    this.pairingTokenSalt = '',
    this.maxToolPayloadBytes = 64 * 1024,
    this.maxCallsPerMinutePerSession = 120,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final String? requiredPairingToken;
  final String? requiredPairingTokenSha256Hex;
  final String pairingTokenSalt;
  final int maxToolPayloadBytes;
  final int maxCallsPerMinutePerSession;
  final DateTime Function() _clock;
  final Map<String, List<DateTime>> _sessionCallWindows =
      <String, List<DateTime>>{};

  RefusionMcpPairingValidation validatePairingToken(String? token) {
    if (requiredPairingTokenSha256Hex != null &&
        requiredPairingTokenSha256Hex!.isNotEmpty) {
      final candidate = sha256
          .convert(utf8.encode('${pairingTokenSalt}${token ?? ''}'))
          .toString();
      if (_constantTimeEquals(
        candidate,
        requiredPairingTokenSha256Hex!.toLowerCase(),
      )) {
        return const RefusionMcpPairingValidation.allowed();
      }
      return const RefusionMcpPairingValidation.denied(
        'Pairing token is invalid or missing.',
      );
    }
    final required = requiredPairingToken;
    if (required == null || required.isEmpty) {
      return const RefusionMcpPairingValidation.allowed();
    }
    if (_constantTimeEquals(token ?? '', required)) {
      return const RefusionMcpPairingValidation.allowed();
    }
    return const RefusionMcpPairingValidation.denied(
      'Pairing token is invalid or missing.',
    );
  }

  bool isPayloadWithinLimit(Map<String, Object?> payload) {
    return _estimatePayloadBytes(payload) <= maxToolPayloadBytes;
  }

  int payloadBytes(Map<String, Object?> payload) {
    return _estimatePayloadBytes(payload);
  }

  bool allowToolCallForSession(String sessionId) {
    if (maxCallsPerMinutePerSession <= 0) {
      return true;
    }
    final now = _clock();
    final windowStart = now.subtract(const Duration(minutes: 1));
    final samples = _sessionCallWindows.putIfAbsent(
      sessionId,
      () => <DateTime>[],
    );
    samples.removeWhere((entry) => entry.isBefore(windowStart));
    if (samples.length >= maxCallsPerMinutePerSession) {
      return false;
    }
    samples.add(now);
    return true;
  }

  int _estimatePayloadBytes(Map<String, Object?> payload) {
    return payload.toString().codeUnits.length;
  }

  bool _constantTimeEquals(String left, String right) {
    var mismatch = left.length ^ right.length;
    final shared = left.length < right.length ? left.length : right.length;
    for (var index = 0; index < shared; index += 1) {
      mismatch |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return mismatch == 0;
  }
}
