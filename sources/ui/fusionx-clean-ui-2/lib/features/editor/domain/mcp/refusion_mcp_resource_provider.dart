import 'package:meta/meta.dart';

enum RefusionMcpResourceCode {
  unknownResource,
  unavailableResource,
  resourceTooLarge,
}

@immutable
class RefusionMcpResourceResult {
  RefusionMcpResourceResult({
    required this.ok,
    required this.uri,
    Map<String, Object?> payload = const <String, Object?>{},
    this.code,
    this.message,
  }) : payload = Map.unmodifiable(payload);

  final bool ok;
  final String uri;
  final RefusionMcpResourceCode? code;
  final String? message;
  final Map<String, Object?> payload;

  factory RefusionMcpResourceResult.failure({
    required String uri,
    required RefusionMcpResourceCode code,
    required String message,
  }) {
    return RefusionMcpResourceResult(
      ok: false,
      uri: uri,
      code: code,
      message: message,
    );
  }
}

typedef RefusionMcpResourceReader = Map<String, Object?>? Function();

class RefusionMcpResourceProvider {
  RefusionMcpResourceProvider({
    Map<String, RefusionMcpResourceReader> readers =
        const <String, RefusionMcpResourceReader>{},
    this.maxPayloadBytes = 256 * 1024,
  }) : _readers = Map<String, RefusionMcpResourceReader>.from(readers);

  final Map<String, RefusionMcpResourceReader> _readers;
  final int maxPayloadBytes;

  void registerReader({
    required String uri,
    required RefusionMcpResourceReader reader,
  }) {
    _readers[uri] = reader;
  }

  RefusionMcpResourceResult read(String uri) {
    final reader = _readers[uri];
    if (reader == null) {
      return RefusionMcpResourceResult.failure(
        uri: uri,
        code: RefusionMcpResourceCode.unknownResource,
        message: 'Unknown resource `$uri`.',
      );
    }
    final payload = reader();
    if (payload == null) {
      return RefusionMcpResourceResult.failure(
        uri: uri,
        code: RefusionMcpResourceCode.unavailableResource,
        message: 'Resource `$uri` is currently unavailable.',
      );
    }
    if (_estimatePayloadBytes(payload) > maxPayloadBytes) {
      return RefusionMcpResourceResult.failure(
        uri: uri,
        code: RefusionMcpResourceCode.resourceTooLarge,
        message:
            'Resource `$uri` exceeds max payload size (${maxPayloadBytes} bytes).',
      );
    }
    return RefusionMcpResourceResult(
      ok: true,
      uri: uri,
      payload: payload,
    );
  }

  List<String> listUris() {
    return _readers.keys.toList(growable: false)..sort();
  }

  int _estimatePayloadBytes(Map<String, Object?> payload) {
    return payload.toString().codeUnits.length;
  }
}
