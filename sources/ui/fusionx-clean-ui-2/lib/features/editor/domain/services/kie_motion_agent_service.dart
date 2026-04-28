import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'refusion_motion_agent_provider_catalog.dart';
import 'scene_mention_prompt_context.dart';

class KieMotionAgentService {
  KieMotionAgentService({
    ReFusionMotionAgentProviderCatalog catalog =
        const ReFusionMotionAgentProviderCatalog(),
    MethodChannel runtimeConfigChannel =
        const MethodChannel('com.refusion.app/runtime_config'),
  })  : _catalog = catalog,
        _runtimeConfigChannel = runtimeConfigChannel;

  static const String _apiKey = String.fromEnvironment('KIE_API_KEY');

  final ReFusionMotionAgentProviderCatalog _catalog;
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

  Future<KieMotionAgentGenerationResult> generateMotionPatch({
    required ReFusionMotionAgentProfile profile,
    required SceneMentionPromptContext context,
    required int scopeDurationMs,
  }) async {
    await ensureConfigured();
    if (!isConfigured) {
      throw const KieMotionAgentException(
        'KIE_API_KEY is missing. Add `kie.api.key` to android/local.properties or rebuild with --dart-define=KIE_API_KEY=...',
      );
    }

    final preview = _catalog.buildRequestPreview(
      profile: profile,
      context: context,
      scopeDurationMs: scopeDurationMs,
    );
    final rawResponse = await _sendJsonRequest(
      uri: Uri.parse(preview.endpointUrl),
      body: preview.body,
      authToken: _resolvedApiKey,
    );
    final patchJson = extractMotionPatchJson(
      rawResponse: rawResponse,
      transport: profile.transport,
    );
    return KieMotionAgentGenerationResult(
      requestPreview: preview,
      rawResponse: rawResponse,
      motionPatchJson: patchJson,
    );
  }

  @visibleForTesting
  String extractMotionPatchJson({
    required String rawResponse,
    required ReFusionMotionAgentTransport transport,
  }) {
    final decoded = _decodeJsonOrSse(rawResponse);
    final content = switch (transport) {
      ReFusionMotionAgentTransport.responses =>
        _extractResponsesOutputText(decoded),
      ReFusionMotionAgentTransport.chatCompletions =>
        _extractChatCompletionText(decoded),
    };
    return _extractJsonObjectText(content);
  }

  Object? _decodeJsonOrSse(String rawResponse) {
    final trimmed = rawResponse.trim();
    if (trimmed.isEmpty) {
      throw const KieMotionAgentException('KIE returned an empty response.');
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
      throw const KieMotionAgentException(
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
    throw const KieMotionAgentException(
      'KIE response did not include a Motion Patch text output.',
    );
  }

  String _extractChatCompletionText(Object? decoded) {
    if (decoded is! Map) {
      throw const KieMotionAgentException(
        'KIE chat-completions payload was not a JSON object.',
      );
    }
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) {
          final content = message['content'];
          if (content != null && content.toString().trim().isNotEmpty) {
            return content.toString();
          }
        }
        final text = first['text'];
        if (text != null && text.toString().trim().isNotEmpty) {
          return text.toString();
        }
      }
    }
    throw const KieMotionAgentException(
      'KIE chat response did not include assistant content.',
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

    throw const KieMotionAgentException(
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
            const Duration(seconds: 90),
          );
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw KieMotionAgentException(
          'KIE request failed (${response.statusCode}): $raw',
        );
      }
      return raw;
    } finally {
      client.close(force: true);
    }
  }
}

class KieMotionAgentGenerationResult {
  const KieMotionAgentGenerationResult({
    required this.requestPreview,
    required this.rawResponse,
    required this.motionPatchJson,
  });

  final ReFusionMotionAgentRequestPreview requestPreview;
  final String rawResponse;
  final String motionPatchJson;
}

class KieMotionAgentException implements Exception {
  const KieMotionAgentException(this.message);

  final String message;

  @override
  String toString() => message;
}
