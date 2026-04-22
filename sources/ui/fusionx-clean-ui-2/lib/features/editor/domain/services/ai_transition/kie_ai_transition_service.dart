import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../presentation/models/ai_transition_models.dart';

class KieAiTransitionService {
  static const String _apiKey = String.fromEnvironment('KIE_API_KEY');
  static const String _jobsBaseUrl = 'https://api.kie.ai';
  static const String _uploadBaseUrl = 'https://kieai.redpandaai.co';
  static const MethodChannel _runtimeConfigChannel =
      MethodChannel('com.refusion.app/runtime_config');

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
      // Keep the service usable with --dart-define fallback even if the
      // runtime config channel is unavailable.
    }
  }

  Future<KieAiTransitionGenerationResult> generateTransition({
    required AiTransitionDraftData draft,
    required Uint8List firstFrameBytes,
    required Uint8List lastFrameBytes,
    String? aspectRatioHint,
    void Function(AiTransitionJobStatus status, {String? taskId})? onStatus,
  }) async {
    await ensureConfigured();
    if (!isConfigured) {
      throw const KieAiTransitionException(
        'KIE_API_KEY is missing. Rebuild with --dart-define=KIE_API_KEY=...',
      );
    }
    final apiKey = _resolvedApiKey;

    onStatus?.call(AiTransitionJobStatus.waitingForBackend);

    final firstFrameUrl = await _uploadFrame(
      bytes: firstFrameBytes,
      fileNamePrefix: 'ai-transition-first',
      authToken: apiKey,
    );
    final lastFrameUrl = await _uploadFrame(
      bytes: lastFrameBytes,
      fileNamePrefix: 'ai-transition-last',
      authToken: apiKey,
    );

    final taskId = await _createGenerationTask(
      draft: draft,
      firstFrameUrl: firstFrameUrl,
      lastFrameUrl: lastFrameUrl,
      aspectRatioHint: aspectRatioHint,
      authToken: apiKey,
    );

    onStatus?.call(AiTransitionJobStatus.queued, taskId: taskId);

    final task = await _pollForCompletion(
      taskId: taskId,
      onStatus: onStatus,
    );
    final resultUrl = _extractResultUrl(task.resultJson);
    final localPath =
        await _downloadResultVideo(taskId: taskId, url: resultUrl);
    return KieAiTransitionGenerationResult(
      taskId: taskId,
      remoteVideoUrl: resultUrl,
      localVideoPath: localPath,
    );
  }

  Future<String> _uploadFrame({
    required Uint8List bytes,
    required String fileNamePrefix,
    required String authToken,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, Object?>{
      'base64Data': 'data:image/jpeg;base64,${base64Encode(bytes)}',
      'uploadPath': 'images/refusion-ai-transitions',
      'fileName': '$fileNamePrefix-$timestamp.jpg',
    };
    final response = await _sendJsonRequest(
      method: 'POST',
      uri: Uri.parse('$_uploadBaseUrl/api/file-base64-upload'),
      body: payload,
      authToken: authToken,
    );
    final data = _asMap(response['data']);
    final downloadUrl = data['downloadUrl']?.toString();
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw const KieAiTransitionException(
        'KIE upload did not return a usable frame URL.',
      );
    }
    return downloadUrl;
  }

  Future<String> _createGenerationTask({
    required AiTransitionDraftData draft,
    required String firstFrameUrl,
    required String lastFrameUrl,
    String? aspectRatioHint,
    required String authToken,
  }) async {
    final durationSeconds = draft.durationSeconds.clamp(
      draft.model.minDurationSeconds,
      draft.model.maxDurationSeconds,
    );
    final payload = switch (draft.model) {
      AiTransitionModel.grokImagineImageToVideo => <String, Object?>{
          'model': 'grok-imagine/image-to-video',
          'input': <String, Object?>{
            'image_urls': <String>[firstFrameUrl, lastFrameUrl],
            'prompt': _buildGrokTransitionPrompt(draft.prompt),
            'mode': 'normal',
            'duration': durationSeconds.toString(),
            'resolution': '720p',
            if (aspectRatioHint != null && aspectRatioHint.isNotEmpty)
              'aspect_ratio': aspectRatioHint,
          },
        },
      AiTransitionModel.kling3StandardSilent => <String, Object?>{
          'model': 'kling-3.0/video',
          'input': <String, Object?>{
            'prompt': draft.prompt,
            'image_urls': <String>[firstFrameUrl, lastFrameUrl],
            'sound': false,
            'duration': durationSeconds.toString(),
            'mode': 'std',
            'multi_shots': false,
          },
        },
      AiTransitionModel.wan27ImageToVideo => <String, Object?>{
          'model': 'wan/2-7-image-to-video',
          'input': <String, Object?>{
            'prompt': draft.prompt,
            'negative_prompt': 'blurry, flicker, low quality, distorted',
            'first_frame_url': firstFrameUrl,
            'last_frame_url': lastFrameUrl,
            'resolution': '720p',
            'duration': durationSeconds,
            'prompt_extend': true,
            'watermark': false,
          },
        },
    };
    final response = await _sendJsonRequest(
      method: 'POST',
      uri: Uri.parse('$_jobsBaseUrl/api/v1/jobs/createTask'),
      body: payload,
      authToken: authToken,
    );
    final data = _asMap(response['data']);
    final taskId = data['taskId']?.toString();
    if (taskId == null || taskId.isEmpty) {
      throw const KieAiTransitionException(
        'KIE createTask did not return a taskId.',
      );
    }
    return taskId;
  }

  String _buildGrokTransitionPrompt(String prompt) {
    final trimmed = prompt.trim();
    const basePrompt =
        'Create a smooth cinematic transition from image one to image two. Start faithfully from the first frame, end faithfully on the second frame, preserve subject identity and scene continuity, and make the bridge feel premium, elegant, and professional.';
    if (trimmed.isEmpty) {
      return basePrompt;
    }
    return '$basePrompt $trimmed';
  }

  Future<_KieTaskRecord> _pollForCompletion({
    required String taskId,
    void Function(AiTransitionJobStatus status, {String? taskId})? onStatus,
  }) async {
    var delaySeconds = 2;
    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < const Duration(minutes: 12)) {
      final response = await _sendJsonRequest(
        method: 'GET',
        uri: Uri.parse('$_jobsBaseUrl/api/v1/jobs/recordInfo')
            .replace(queryParameters: <String, String>{'taskId': taskId}),
        authToken: _resolvedApiKey,
      );
      final data = _asMap(response['data']);
      final record = _KieTaskRecord.fromJson(data);
      switch (record.state) {
        case 'waiting':
        case 'queuing':
          onStatus?.call(AiTransitionJobStatus.queued, taskId: taskId);
        case 'generating':
          onStatus?.call(AiTransitionJobStatus.running, taskId: taskId);
        case 'success':
          onStatus?.call(AiTransitionJobStatus.completed, taskId: taskId);
          return record;
        case 'fail':
          throw KieAiTransitionException(
            record.failMessage.isEmpty
                ? 'KIE task failed without a detailed message.'
                : record.failMessage,
          );
        default:
          onStatus?.call(AiTransitionJobStatus.running, taskId: taskId);
      }
      await Future<void>.delayed(Duration(seconds: delaySeconds));
      if (delaySeconds < 6) {
        delaySeconds += 1;
      }
    }
    throw const KieAiTransitionException(
      'KIE task polling timed out before the transition finished.',
    );
  }

  String _extractResultUrl(String? resultJson) {
    if (resultJson == null || resultJson.trim().isEmpty) {
      throw const KieAiTransitionException(
        'KIE task completed but did not include resultJson.',
      );
    }
    final decoded = jsonDecode(resultJson);
    if (decoded is Map<String, dynamic>) {
      final resultUrls = decoded['resultUrls'];
      if (resultUrls is List && resultUrls.isNotEmpty) {
        final first = resultUrls.first?.toString();
        if (first != null && first.isNotEmpty) {
          return first;
        }
      }
      for (final key in const <String>['videoUrl', 'url', 'resultUrl']) {
        final value = decoded[key]?.toString();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
    }
    throw const KieAiTransitionException(
      'Unable to extract a generated video URL from KIE resultJson.',
    );
  }

  Future<String> _downloadResultVideo({
    required String taskId,
    required String url,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw KieAiTransitionException(
          'Failed to download generated transition video (${response.statusCode}).',
        );
      }
      final directory =
          await Directory.systemTemp.createTemp('refusion-ai-transition');
      final file = File('${directory.path}/$taskId.mp4');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _sendJsonRequest({
    required String method,
    required Uri uri,
    Map<String, Object?>? body,
    required String authToken,
  }) async {
    final client = HttpClient();
    try {
      final request = await switch (method) {
        'POST' => client.postUrl(uri),
        'GET' => client.getUrl(uri),
        _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
      };
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close();
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw KieAiTransitionException(
          'KIE request failed (${response.statusCode}): $raw',
        );
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const KieAiTransitionException(
          'KIE response was not a JSON object.',
        );
      }
      final code = decoded['code'];
      if (code is int && code != 200) {
        throw KieAiTransitionException(
          decoded['msg']?.toString() ??
              'KIE returned a non-success application code.',
        );
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    throw const KieAiTransitionException('KIE response payload was malformed.');
  }
}

class KieAiTransitionGenerationResult {
  const KieAiTransitionGenerationResult({
    required this.taskId,
    required this.remoteVideoUrl,
    required this.localVideoPath,
  });

  final String taskId;
  final String remoteVideoUrl;
  final String localVideoPath;
}

class KieAiTransitionException implements Exception {
  const KieAiTransitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _KieTaskRecord {
  const _KieTaskRecord({
    required this.state,
    required this.resultJson,
    required this.failMessage,
  });

  factory _KieTaskRecord.fromJson(Map<String, dynamic> json) {
    return _KieTaskRecord(
      state: json['state']?.toString() ?? '',
      resultJson: json['resultJson']?.toString(),
      failMessage: json['failMsg']?.toString() ?? '',
    );
  }

  final String state;
  final String? resultJson;
  final String failMessage;
}
