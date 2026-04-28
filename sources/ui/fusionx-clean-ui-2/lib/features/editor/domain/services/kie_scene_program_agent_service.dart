import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'refusion_scene_agent_provider_catalog.dart';

class KieSceneProgramAgentService {
  KieSceneProgramAgentService({
    ReFusionSceneAgentProviderCatalog catalog =
        const ReFusionSceneAgentProviderCatalog(),
    MethodChannel runtimeConfigChannel =
        const MethodChannel('com.refusion.app/runtime_config'),
  })  : _catalog = catalog,
        _runtimeConfigChannel = runtimeConfigChannel;

  static const String _apiKey = String.fromEnvironment('KIE_API_KEY');

  final ReFusionSceneAgentProviderCatalog _catalog;
  final MethodChannel _runtimeConfigChannel;
  String _runtimeApiKey = '';
  bool _attemptedRuntimeKeyLoad = false;

  String get _resolvedApiKey {
    final runtimeApiKey = _runtimeApiKey.trim();
    if (runtimeApiKey.isNotEmpty) {
      return runtimeApiKey;
    }
    return _apiKey.trim();
  }

  bool get isConfigured => _resolvedApiKey.isNotEmpty;

  Future<void> ensureConfigured() async {
    if (isConfigured || _attemptedRuntimeKeyLoad || kIsWeb) {
      return;
    }
    _attemptedRuntimeKeyLoad = true;
    try {
      final nativeApiKey =
          await _runtimeConfigChannel.invokeMethod<String>('getKieApiKey');
      if (nativeApiKey != null && nativeApiKey.trim().isNotEmpty) {
        _runtimeApiKey = nativeApiKey.trim();
      }
    } catch (_) {
      // Keep --dart-define usable even if the native runtime channel is absent.
    }
  }

  Future<KieSceneProgramGenerationResult> generateSceneProgram({
    required ReFusionSceneAgentProfile profile,
    required String prompt,
    required int durationMs,
    required int canvasWidth,
    required int canvasHeight,
    required double frameRate,
  }) async {
    await ensureConfigured();
    if (!isConfigured) {
      throw const KieSceneProgramAgentException(
        'KIE_API_KEY is missing. Add `kie.api.key` to android/local.properties or rebuild with --dart-define=KIE_API_KEY=...',
      );
    }

    final preview = _catalog.buildRequestPreview(
      profile: profile,
      prompt: prompt,
      durationMs: durationMs,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      frameRate: frameRate,
    );
    final rawResponse = await _sendJsonRequest(
      uri: Uri.parse(preview.endpointUrl),
      body: preview.body,
      authToken: _resolvedApiKey,
    );
    final sceneProgramJson = extractSceneProgramJson(
      rawResponse: rawResponse,
      transport: profile.transport,
    );
    return KieSceneProgramGenerationResult(
      requestPreview: preview,
      rawResponse: rawResponse,
      sceneProgramJson: sceneProgramJson,
    );
  }

  @visibleForTesting
  String extractSceneProgramJson({
    required String rawResponse,
    required ReFusionSceneAgentTransport transport,
  }) {
    final decoded = _decodeJsonOrSse(rawResponse);
    final content = switch (transport) {
      ReFusionSceneAgentTransport.responses =>
        _extractResponsesOutputText(decoded),
      ReFusionSceneAgentTransport.claudeMessages =>
        _extractClaudeMessagesText(decoded),
    };
    final jsonText = _extractJsonObjectText(content);
    final object = jsonDecode(jsonText);
    if (object is! Map) {
      throw const KieSceneProgramAgentException(
        'Generated scene payload must be a JSON object.',
      );
    }
    final sceneProgram = object['sceneProgram'] ?? object['program'] ?? object;
    if (sceneProgram is! Map) {
      throw const KieSceneProgramAgentException(
        'Generated response did not contain a Scene Program object.',
      );
    }
    if (sceneProgram['schemaVersion'] != 'refusion.scene-program/v1') {
      throw const KieSceneProgramAgentException(
        'Generated response did not contain schemaVersion `refusion.scene-program/v1`.',
      );
    }
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(sceneProgram);
  }

  Object? _decodeJsonOrSse(String rawResponse) {
    final trimmed = rawResponse.trim();
    if (trimmed.isEmpty) {
      throw const KieSceneProgramAgentException(
        'KIE returned an empty scene-generation response.',
      );
    }
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      final dataLines = <String>[];
      for (final line in const LineSplitter().convert(trimmed)) {
        final normalized = line.trim();
        if (!normalized.startsWith('data:')) {
          continue;
        }
        final value = normalized.substring(5).trim();
        if (value.isEmpty || value == '[DONE]') {
          continue;
        }
        dataLines.add(value);
      }
      if (dataLines.isEmpty) {
        rethrow;
      }
      return jsonDecode(dataLines.last);
    }
  }

  String _extractResponsesOutputText(Object? decoded) {
    if (decoded is! Map) {
      throw const KieSceneProgramAgentException(
        'KIE Responses payload was not a JSON object.',
      );
    }
    final output = decoded['output'];
    if (output is List) {
      final buffer = StringBuffer();
      for (final item in output) {
        if (item is! Map) {
          continue;
        }
        final content = item['content'];
        if (content is! List) {
          continue;
        }
        for (final part in content) {
          if (part is! Map) {
            continue;
          }
          final text = part['text'] ?? part['output_text'];
          if (text != null && text.toString().trim().isNotEmpty) {
            buffer.write(text);
          }
        }
      }
      final value = buffer.toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    final outputText = decoded['output_text'];
    if (outputText != null && outputText.toString().trim().isNotEmpty) {
      return outputText.toString();
    }
    throw const KieSceneProgramAgentException(
      'KIE response did not include Scene Program text output.',
    );
  }

  String _extractClaudeMessagesText(Object? decoded) {
    if (decoded is! Map) {
      throw const KieSceneProgramAgentException(
        'KIE Claude payload was not a JSON object.',
      );
    }
    final content = decoded['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content;
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is! Map) {
          continue;
        }
        final text = part['text'] ?? part['content'];
        if (text != null && text.toString().trim().isNotEmpty) {
          buffer.write(text);
        }
      }
      final value = buffer.toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    final message = decoded['message'];
    if (message is Map) {
      final messageContent = message['content'];
      if (messageContent != null &&
          messageContent.toString().trim().isNotEmpty) {
        return messageContent.toString();
      }
    }
    throw const KieSceneProgramAgentException(
      'KIE Claude response did not include assistant content.',
    );
  }

  String _extractJsonObjectText(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final fenced = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (fenced != null) {
      final value = fenced.group(1)?.trim();
      if (value != null && value.startsWith('{') && value.endsWith('}')) {
        return value;
      }
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final candidate = trimmed.substring(start, end + 1);
      jsonDecode(candidate);
      return candidate;
    }

    throw const KieSceneProgramAgentException(
      'KIE output did not contain a valid JSON object.',
    );
  }

  Future<String> _sendJsonRequest({
    required Uri uri,
    required Map<String, Object?> body,
    required String authToken,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(
            const Duration(seconds: 120),
          );
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw KieSceneProgramAgentException(
          'KIE scene request failed (${response.statusCode}): $raw',
        );
      }
      return raw;
    } finally {
      client.close(force: true);
    }
  }
}

class KieSceneProgramGenerationResult {
  const KieSceneProgramGenerationResult({
    required this.requestPreview,
    required this.rawResponse,
    required this.sceneProgramJson,
  });

  final ReFusionSceneAgentRequestPreview requestPreview;
  final String rawResponse;
  final String sceneProgramJson;
}

class KieSceneProgramAgentException implements Exception {
  const KieSceneProgramAgentException(this.message);

  final String message;

  @override
  String toString() => message;
}
