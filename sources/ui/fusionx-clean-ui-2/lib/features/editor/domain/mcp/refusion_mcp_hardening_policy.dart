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
    this.maxToolPayloadBytes = 64 * 1024,
    this.maxCallsPerMinutePerSession = 120,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final String? requiredPairingToken;
  final int maxToolPayloadBytes;
  final int maxCallsPerMinutePerSession;
  final DateTime Function() _clock;
  final Map<String, List<DateTime>> _sessionCallWindows =
      <String, List<DateTime>>{};

  RefusionMcpPairingValidation validatePairingToken(String? token) {
    final required = requiredPairingToken;
    if (required == null || required.isEmpty) {
      return const RefusionMcpPairingValidation.allowed();
    }
    if (token == required) {
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
}
