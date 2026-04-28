import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/refusion_motion_director_models.dart';
import '../models/refusion_scene_program_models.dart';
import 'refusion_motion_director_linter.dart';
import 'refusion_motion_director_plan_import_service.dart';
import 'refusion_motion_director_scene_program_alignment_linter.dart';
import 'refusion_motion_director_scene_program_compiler.dart';
import 'refusion_scene_agent_provider_catalog.dart';
import 'refusion_scene_program_import_service.dart';

class KieSceneProgramAgentService {
  KieSceneProgramAgentService({
    ReFusionSceneAgentProviderCatalog catalog =
        const ReFusionSceneAgentProviderCatalog(),
    ReFusionMotionDirectorPlanImportService directorPlanImportService =
        const ReFusionMotionDirectorPlanImportService(),
    ReFusionMotionDirectorLinter directorLinter =
        const ReFusionMotionDirectorLinter(),
    ReFusionMotionDirectorSceneProgramCompiler directorCompiler =
        const ReFusionMotionDirectorSceneProgramCompiler(),
    ReFusionMotionDirectorSceneProgramAlignmentLinter alignmentLinter =
        const ReFusionMotionDirectorSceneProgramAlignmentLinter(),
    ReFusionSceneProgramImportService sceneProgramImportService =
        const ReFusionSceneProgramImportService(),
    MethodChannel runtimeConfigChannel =
        const MethodChannel('com.refusion.app/runtime_config'),
  })  : _catalog = catalog,
        _directorPlanImportService = directorPlanImportService,
        _directorLinter = directorLinter,
        _directorCompiler = directorCompiler,
        _alignmentLinter = alignmentLinter,
        _sceneProgramImportService = sceneProgramImportService,
        _runtimeConfigChannel = runtimeConfigChannel;

  static const String _apiKey = String.fromEnvironment('KIE_API_KEY');

  final ReFusionSceneAgentProviderCatalog _catalog;
  final ReFusionMotionDirectorPlanImportService _directorPlanImportService;
  final ReFusionMotionDirectorLinter _directorLinter;
  final ReFusionMotionDirectorSceneProgramCompiler _directorCompiler;
  final ReFusionMotionDirectorSceneProgramAlignmentLinter _alignmentLinter;
  final ReFusionSceneProgramImportService _sceneProgramImportService;
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
    final extracted = extractSceneProgramPayload(
      rawResponse: rawResponse,
      transport: profile.transport,
    );
    return KieSceneProgramGenerationResult(
      requestPreview: preview,
      rawResponse: rawResponse,
      sceneProgramJson: extracted.sceneProgramJson,
      directorPlan: extracted.directorPlan,
      directorIssues: extracted.directorIssues,
    );
  }

  @visibleForTesting
  String extractSceneProgramJson({
    required String rawResponse,
    required ReFusionSceneAgentTransport transport,
  }) {
    return extractSceneProgramPayload(
      rawResponse: rawResponse,
      transport: transport,
    ).sceneProgramJson;
  }

  @visibleForTesting
  KieSceneProgramExtractionResult extractSceneProgramPayload({
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
    final directorExtraction = _extractAndLintDirectorPlan(object);
    final sceneProgram = object['sceneProgram'] ??
        object['program'] ??
        (object['schemaVersion'] == 'refusion.scene-program/v1'
            ? object
            : null);
    if (sceneProgram == null && directorExtraction.plan != null) {
      final compiled = _compileDirectorPlanToSceneProgram(
        directorExtraction.plan!,
        directorExtraction.issues,
      );
      return KieSceneProgramExtractionResult(
        sceneProgramJson: _encodeSceneProgram(compiled),
        directorPlan: directorExtraction.plan,
        directorIssues: directorExtraction.issues,
      );
    }
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
    final sceneProgramJson = encoder.convert(sceneProgram);
    if (directorExtraction.plan != null) {
      _lintSceneProgramAlignment(
        plan: directorExtraction.plan!,
        sceneProgramJson: sceneProgramJson,
        directorIssues: directorExtraction.issues,
      );
    }
    return KieSceneProgramExtractionResult(
      sceneProgramJson: sceneProgramJson,
      directorPlan: directorExtraction.plan,
      directorIssues: directorExtraction.issues,
    );
  }

  ReFusionSceneProgram _compileDirectorPlanToSceneProgram(
    ReFusionMotionDirectorPlan plan,
    List<ReFusionMotionDirectorIssue> directorIssues,
  ) {
    final compileResult = _directorCompiler.compile(plan);
    directorIssues.addAll(compileResult.issues);
    final hasErrors = directorIssues.any(
      (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
    );
    if (hasErrors || compileResult.program == null) {
      throw KieSceneProgramAgentException(
        'Generated directorPlan could not compile into Scene Program: ${_directorIssueSummary(directorIssues)}',
      );
    }
    return compileResult.program!;
  }

  void _lintSceneProgramAlignment({
    required ReFusionMotionDirectorPlan plan,
    required String sceneProgramJson,
    required List<ReFusionMotionDirectorIssue> directorIssues,
  }) {
    final importResult =
        _sceneProgramImportService.validate(source: sceneProgramJson);
    final importErrors = importResult.issues.where(
      (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
    );
    if (importErrors.isNotEmpty || importResult.program == null) {
      final summary = importErrors
          .take(3)
          .map((issue) => issue.path == null
              ? issue.message
              : '${issue.path}: ${issue.message}')
          .join(' ');
      throw KieSceneProgramAgentException(
        'Generated sceneProgram failed validation before Director alignment: $summary',
      );
    }
    final alignmentResult = _alignmentLinter.lint(
      plan: plan,
      program: importResult.program!,
    );
    directorIssues.addAll(alignmentResult.issues);
    final hasAlignmentErrors = alignmentResult.issues.any(
      (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
    );
    if (hasAlignmentErrors) {
      throw KieSceneProgramAgentException(
        'Generated sceneProgram does not match directorPlan: ${_directorIssueSummary(alignmentResult.issues)}',
      );
    }
  }

  String _encodeSceneProgram(ReFusionSceneProgram program) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_sceneProgramToJson(program));
  }

  Map<String, Object?> _sceneProgramToJson(ReFusionSceneProgram program) {
    return <String, Object?>{
      'schemaVersion': program.schemaVersion,
      'name': program.name,
      'durationMs': program.durationMs,
      'frameRate': program.frameRate,
      'layers': program.layers.map(_sceneLayerToJson).toList(growable: false),
    };
  }

  Map<String, Object?> _sceneLayerToJson(ReFusionSceneProgramLayer layer) {
    return <String, Object?>{
      'id': layer.id,
      'kind': layer.kind,
      if (layer.name != null) 'name': layer.name,
      'startMs': layer.startMs,
      'durationMs': layer.durationMs,
      if (layer.elements.isNotEmpty)
        'elements':
            layer.elements.map(_sceneElementToJson).toList(growable: false),
      if (layer.channels.isNotEmpty)
        'channels':
            layer.channels.map(_sceneChannelToJson).toList(growable: false),
    };
  }

  Map<String, Object?> _sceneElementToJson(
      ReFusionSceneProgramElement element) {
    return <String, Object?>{
      'id': element.id,
      'kind': element.kind,
      if (element.name != null) 'name': element.name,
      if (element.text != null) 'text': element.text,
      if (element.properties.isNotEmpty) 'properties': element.properties,
      if (element.channels.isNotEmpty)
        'channels':
            element.channels.map(_sceneChannelToJson).toList(growable: false),
    };
  }

  Map<String, Object?> _sceneChannelToJson(
      ReFusionSceneProgramChannel channel) {
    return <String, Object?>{
      'target': channel.target,
      'property': channel.property,
      'keyframes':
          channel.keyframes.map(_sceneKeyframeToJson).toList(growable: false),
    };
  }

  Map<String, Object?> _sceneKeyframeToJson(
    ReFusionSceneProgramKeyframe keyframe,
  ) {
    return <String, Object?>{
      'timeMs': keyframe.timeMs,
      'value': keyframe.value,
      'easing': keyframe.easing,
    };
  }

  _DirectorExtraction _extractAndLintDirectorPlan(
      Map<dynamic, dynamic> object) {
    final rawDirectorPlan = object['directorPlan'] ?? object['motionDirector'];
    if (rawDirectorPlan == null) {
      return const _DirectorExtraction(
        issues: <ReFusionMotionDirectorIssue>[
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'Generated scene did not include `directorPlan`; accepted for compatibility but lower confidence.',
            path: 'directorPlan',
          ),
        ],
      );
    }
    final importResult =
        _directorPlanImportService.importFromJson(rawDirectorPlan);
    final issues = <ReFusionMotionDirectorIssue>[
      ...importResult.issues,
    ];
    final plan = importResult.plan;
    final hasImportErrors = issues.any(
      (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
    );
    if (hasImportErrors || plan == null) {
      throw KieSceneProgramAgentException(
        'Generated directorPlan failed validation: ${_directorIssueSummary(issues)}',
      );
    }
    final lintResult = _directorLinter.lint(plan);
    issues.addAll(lintResult.issues);
    final hasErrors = issues.any(
      (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
    );
    if (hasErrors) {
      throw KieSceneProgramAgentException(
        'Generated directorPlan failed validation: ${_directorIssueSummary(issues)}',
      );
    }
    return _DirectorExtraction(plan: plan, issues: issues);
  }

  String _directorIssueSummary(List<ReFusionMotionDirectorIssue> issues) {
    return issues
        .where(
          (issue) =>
              issue.severity == ReFusionMotionDirectorIssueSeverity.error,
        )
        .take(3)
        .map((issue) => issue.path == null
            ? issue.message
            : '${issue.path}: ${issue.message}')
        .join(' ');
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
            const Duration(seconds: 240),
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
    this.directorPlan,
    this.directorIssues = const <ReFusionMotionDirectorIssue>[],
  });

  final ReFusionSceneAgentRequestPreview requestPreview;
  final String rawResponse;
  final String sceneProgramJson;
  final ReFusionMotionDirectorPlan? directorPlan;
  final List<ReFusionMotionDirectorIssue> directorIssues;
}

class KieSceneProgramExtractionResult {
  const KieSceneProgramExtractionResult({
    required this.sceneProgramJson,
    this.directorPlan,
    this.directorIssues = const <ReFusionMotionDirectorIssue>[],
  });

  final String sceneProgramJson;
  final ReFusionMotionDirectorPlan? directorPlan;
  final List<ReFusionMotionDirectorIssue> directorIssues;
}

class KieSceneProgramAgentException implements Exception {
  const KieSceneProgramAgentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _DirectorExtraction {
  const _DirectorExtraction({
    this.plan,
    this.issues = const <ReFusionMotionDirectorIssue>[],
  });

  final ReFusionMotionDirectorPlan? plan;
  final List<ReFusionMotionDirectorIssue> issues;
}
