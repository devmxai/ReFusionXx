import 'dart:convert';

import '../../domain/mcp/refusion_mcp_agent_control_plane.dart';
import '../../domain/mcp/refusion_mcp_capability.dart';
import '../../domain/mcp/refusion_mcp_command.dart';
import '../../domain/mcp/refusion_mcp_session.dart';
import '../../domain/mcp/refusion_mcp_tool_registry.dart';
import 'refusion_mcp_app_bridge.dart';

class RefusionMcpJsonRpcServer {
  RefusionMcpJsonRpcServer({
    required RefusionMcpAppBridge bridge,
    required RefusionMcpToolRegistry toolRegistry,
  })  : _bridge = bridge,
        _toolRegistry = toolRegistry;

  final RefusionMcpAppBridge _bridge;
  final RefusionMcpToolRegistry _toolRegistry;

  Map<String, Object?> handle(Map<String, Object?> request) {
    final id = request['id'];
    final method = request['method'];
    if (method is! String || method.trim().isEmpty) {
      return _error(
        id: id,
        code: -32600,
        message: 'Invalid JSON-RPC request: missing method.',
      );
    }
    try {
      switch (method) {
        case 'initialize':
          return _result(
            id: id,
            value: <String, Object?>{
              'protocolVersion': '2025-03-26',
              'serverInfo': <String, Object?>{
                'name': 'refusion-mcp',
                'version': '0.1.0',
              },
              'capabilities': <String, Object?>{
                'tools': <String, Object?>{},
                'resources': <String, Object?>{},
              },
            },
          );
        case 'tools/list':
          return _result(
            id: id,
            value: <String, Object?>{
              'tools': _toolRegistry.list().map(_serializeTool).toList(),
            },
          );
        case 'tools/call':
          return _handleToolsCall(id: id, params: request['params']);
        case 'resources/list':
          return _result(
            id: id,
            value: <String, Object?>{
              'resources': _bridge.listResourceUris().map((uri) {
                return <String, Object?>{
                  'uri': uri,
                  'name': uri,
                };
              }).toList(growable: false),
            },
          );
        case 'prompts/list':
          return _result(
            id: id,
            value: <String, Object?>{
              'prompts': _bridge.listPrompts().map((prompt) {
                return <String, Object?>{
                  'name': prompt.name,
                  'title': prompt.title,
                  'description': prompt.description,
                  'arguments': prompt.arguments,
                };
              }).toList(growable: false),
            },
          );
        case 'prompts/get':
          return _handlePromptGet(id: id, params: request['params']);
        case 'resources/read':
          return _handleResourceRead(id: id, params: request['params']);
        case 'refusion/session/open':
          return _handleSessionOpen(id: id, params: request['params']);
        case 'refusion/session/close':
          return _handleSessionClose(id: id, params: request['params']);
        case 'refusion/session/list':
          return _result(
            id: id,
            value: <String, Object?>{
              'sessions':
                  _bridge.listSessions().map(_serializeSession).toList(),
            },
          );
        default:
          return _error(
            id: id,
            code: -32601,
            message: 'Method not found: $method',
          );
      }
    } catch (error) {
      return _error(
        id: id,
        code: -32603,
        message: 'Internal error: $error',
      );
    }
  }

  Map<String, Object?> _handleToolsCall({
    required Object? id,
    required Object? params,
  }) {
    if (params is! Map<String, Object?>) {
      return _error(
        id: id,
        code: -32602,
        message: 'Invalid params for tools/call.',
      );
    }
    final name = params['name'];
    if (name is! String) {
      return _error(
        id: id,
        code: -32602,
        message: 'tools/call requires name and arguments map.',
      );
    }
    final arguments = _readMap(params['arguments']);
    final normalizedToolName = _toolRegistry.normalizeToolName(name) ?? name;

    final descriptor = _toolRegistry.find(normalizedToolName);
    final modeValue = arguments['mode'] as String?;
    final mode = modeValue == null
        ? (descriptor?.mutating == true
            ? RefusionMcpCommandMode.commit
            : RefusionMcpCommandMode.dryRun)
        : (modeValue == 'commit'
            ? RefusionMcpCommandMode.commit
            : RefusionMcpCommandMode.dryRun);
    final rawTransaction = _readMap(arguments['transaction']);
    final transactionValidation = _validateCanonicalTransaction(
      transaction: rawTransaction,
      requiredForMutation: descriptor?.mutating == true,
    );
    if (!transactionValidation.ok) {
      return _error(
        id: id,
        code: -32602,
        message: transactionValidation.message ?? 'Invalid transaction.',
      );
    }
    final expectedRevision = _readInt(arguments['expectedRevision']) ??
        _readInt(rawTransaction['baseRevision']);
    final payload = _mergedPayloadWithTransaction(
      payload: _readMap(arguments['payload']),
      transaction: rawTransaction,
    );
    final requestedSessionId = (arguments['sessionId'] as String?)?.trim();
    final sessionId = (requestedSessionId == null || requestedSessionId.isEmpty)
        ? 'default'
        : requestedSessionId;
    final requestedProjectId = _readNormalizedProjectIdentity(
      arguments['projectId'] ?? rawTransaction['projectId'],
    );

    _autoBootstrapSessionIfNeeded(
      sessionId: sessionId,
      projectId: requestedProjectId,
    );

    final projectId =
        requestedProjectId ?? _activeProjectIdForSession(sessionId) ?? '';

    final response = _bridge.executeTool(
      RefusionMcpToolCallRequest(
        toolName: normalizedToolName,
        sessionId: sessionId,
        projectId: projectId,
        commandId: (arguments['commandId'] as String?) ??
            (_readString(rawTransaction['transactionId']) != null
                ? 'cmd_${_readString(rawTransaction['transactionId'])}'
                : null) ??
            'cmd_${DateTime.now().microsecondsSinceEpoch}',
        idempotencyKey: (arguments['idempotencyKey'] as String?) ??
            _readString(rawTransaction['idempotencyKey']) ??
            'mcp-${DateTime.now().microsecondsSinceEpoch}',
        mode: mode,
        expectedRevision: expectedRevision,
        payload: payload,
      ),
    );

    return _result(
      id: id,
      value: <String, Object?>{
        'isError': !response.ok,
        'content': <Map<String, Object?>>[
          <String, Object?>{
            'type': 'text',
            'text': response.ok
                ? response.summary
                : (response.error?.message ?? response.summary),
          },
        ],
        'structuredContent': <String, Object?>{
          'ok': response.ok,
          'summary': response.summary,
          'requiresConfirmation': response.requiresConfirmation,
          'message': response.error?.message,
          'code': response.error?.code.name,
          'revisionBefore': response.revisionBefore,
          'revisionAfter': response.revisionAfter,
          'transactionId': response.transactionId,
          'payload': response.payload,
          'diagnostics': response.diagnostics,
          'resourceUris': response.resourceUris,
        },
      },
    );
  }

  void _autoBootstrapSessionIfNeeded({
    required String sessionId,
    required String? projectId,
  }) {
    final hasSession =
        _bridge.listSessions().any((session) => session.id == sessionId);
    if (hasSession) {
      return;
    }
    // Do not bypass pairing-gated environments. In those contexts, sessions
    // must be opened explicitly through `refusion/session/open`.
    final hardening = _bridge.hardeningPolicy;
    final pairingRequired =
        (hardening.requiredPairingToken?.isNotEmpty ?? false) ||
            (hardening.requiredPairingTokenSha256Hex?.isNotEmpty ?? false);
    if (pairingRequired) {
      return;
    }
    if (projectId == null || projectId.isEmpty) {
      return;
    }
    final granted =
        _bridge.grantCapabilities(RefusionMcpCapability.values.toSet());
    _bridge.openSession(
      RefusionMcpSession(
        id: sessionId,
        clientName: 'auto-bootstrap',
        clientVersion: '0.1.0',
        transport: 'streamable-http',
        activeProjectId: projectId,
        activeCompositionId: '',
        timelineRevision: 0,
        grantedCapabilities: granted,
      ),
    );
  }

  Map<String, Object?> _handleResourceRead({
    required Object? id,
    required Object? params,
  }) {
    if (params is! Map<String, Object?>) {
      return _error(
        id: id,
        code: -32602,
        message: 'Invalid params for resources/read.',
      );
    }
    final uri = params['uri'];
    if (uri is! String || uri.trim().isEmpty) {
      return _error(
        id: id,
        code: -32602,
        message: 'resources/read requires uri.',
      );
    }
    final resource = _bridge.readResource(uri);
    if (!resource.ok) {
      return _result(
        id: id,
        value: <String, Object?>{
          'contents': <Map<String, Object?>>[],
          'error': <String, Object?>{
            'code': resource.code?.name,
            'message': resource.message,
          },
        },
      );
    }
    return _result(
      id: id,
      value: <String, Object?>{
        'contents': <Map<String, Object?>>[
          <String, Object?>{
            'uri': resource.uri,
            'mimeType': 'application/json',
            'text': jsonEncode(resource.payload),
          },
        ],
      },
    );
  }

  Map<String, Object?> _handlePromptGet({
    required Object? id,
    required Object? params,
  }) {
    if (params is! Map<String, Object?>) {
      return _error(
        id: id,
        code: -32602,
        message: 'Invalid params for prompts/get.',
      );
    }
    final name = params['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return _error(
        id: id,
        code: -32602,
        message: 'prompts/get requires name.',
      );
    }
    final prompt = _bridge.getPrompt(name.trim());
    if (!prompt.ok || prompt.descriptor == null) {
      return _result(
        id: id,
        value: <String, Object?>{
          'messages': const <Map<String, Object?>>[],
          'error': <String, Object?>{
            'message': prompt.message ?? 'Prompt was not found.',
          },
        },
      );
    }
    final descriptor = prompt.descriptor!;
    return _result(
      id: id,
      value: <String, Object?>{
        'description': descriptor.description,
        'messages': <Map<String, Object?>>[
          <String, Object?>{
            'role': 'user',
            'content': <Map<String, Object?>>[
              <String, Object?>{
                'type': 'text',
                'text': descriptor.description,
              },
            ],
          },
        ],
        'arguments': descriptor.arguments,
      },
    );
  }

  Map<String, Object?> _handleSessionOpen({
    required Object? id,
    required Object? params,
  }) {
    if (params is! Map<String, Object?>) {
      return _error(
        id: id,
        code: -32602,
        message: 'Invalid params for refusion/session/open.',
      );
    }
    final sessionMap = _readMap(params['session']);
    final pairingValidation = _bridge.hardeningPolicy.validatePairingToken(
      params['pairingToken'] as String?,
    );
    if (!pairingValidation.ok) {
      return _error(
        id: id,
        code: -32001,
        message: pairingValidation.message ?? 'Session pairing failed.',
      );
    }
    final sessionId = sessionMap['id'] as String?;
    if (sessionId == null || sessionId.trim().isEmpty) {
      return _error(
        id: id,
        code: -32602,
        message: 'session.id is required.',
      );
    }
    final capabilityValues =
        (sessionMap['capabilities'] as List?)?.whereType<String>() ??
            const <String>[];
    final requestedCapabilities = capabilityValues
        .map(RefusionMcpCapability.parse)
        .whereType<RefusionMcpCapability>()
        .toSet();
    final capabilities = _bridge.grantCapabilities(requestedCapabilities);
    final activeProjectId =
        _readNormalizedProjectIdentity(sessionMap['activeProjectId']);
    if (activeProjectId == null) {
      return _error(
        id: id,
        code: -32602,
        message:
            'session.activeProjectId is required and cannot be a placeholder identity.',
      );
    }
    final activeCompositionId =
        _readNormalizedCompositionIdentity(sessionMap['activeCompositionId']);
    if (activeCompositionId == null) {
      return _error(
        id: id,
        code: -32602,
        message:
            'session.activeCompositionId is required and cannot be a placeholder identity.',
      );
    }

    _bridge.openSession(
      RefusionMcpSession(
        id: sessionId,
        clientName: (sessionMap['clientName'] as String?) ?? 'unknown',
        clientVersion: (sessionMap['clientVersion'] as String?) ?? '0.0.0',
        transport: (sessionMap['transport'] as String?) ?? 'stdio',
        activeProjectId: activeProjectId,
        activeCompositionId: activeCompositionId,
        timelineRevision: _readInt(sessionMap['timelineRevision']) ?? 0,
        grantedCapabilities: capabilities,
      ),
    );
    return _result(
      id: id,
      value: <String, Object?>{
        'sessionId': sessionId,
        'grantedCapabilities':
            capabilities.map((capability) => capability.value).toList(),
      },
    );
  }

  Map<String, Object?> _handleSessionClose({
    required Object? id,
    required Object? params,
  }) {
    if (params is! Map<String, Object?>) {
      return _error(
        id: id,
        code: -32602,
        message: 'Invalid params for refusion/session/close.',
      );
    }
    final sessionId = params['sessionId'] as String?;
    if (sessionId == null || sessionId.trim().isEmpty) {
      return _error(
        id: id,
        code: -32602,
        message: 'sessionId is required.',
      );
    }
    return _result(
      id: id,
      value: <String, Object?>{
        'closed': _bridge.closeSession(sessionId),
      },
    );
  }

  Map<String, Object?> _serializeTool(RefusionMcpToolDescriptor tool) {
    final inputSchemaProperties = <String, Object?>{
      'sessionId': <String, Object?>{'type': 'string'},
      'projectId': <String, Object?>{'type': 'string'},
      'commandId': <String, Object?>{'type': 'string'},
      'idempotencyKey': <String, Object?>{'type': 'string'},
      'mode': <String, Object?>{
        'type': 'string',
        'enum': <String>['dryRun', 'commit'],
      },
      'expectedRevision': <String, Object?>{'type': 'integer'},
      'payload': <String, Object?>{'type': 'object'},
      'transaction': <String, Object?>{
        'type': 'object',
        'description':
            'CanonicalCreativeTransactionV1-compatible envelope (schemaVersion/baseRevision/idempotencyKey/projectId/compositionId/operations).',
      },
    };
    final required = <String>[
      'sessionId',
      'projectId',
      'commandId',
      'idempotencyKey',
      'payload',
    ];
    if (tool.mutating) {
      required.add('expectedRevision');
    }
    return <String, Object?>{
      'name': tool.name,
      'title': tool.title,
      'description': tool.description,
      'inputSchema': <String, Object?>{
        'type': 'object',
        'properties': inputSchemaProperties,
        'required': required,
      },
      'annotations': <String, Object?>{
        'mutating': tool.mutating,
        'capability': tool.capability.value,
      },
    };
  }

  Map<String, Object?> _serializeSession(RefusionMcpSession session) {
    return <String, Object?>{
      'id': session.id,
      'clientName': session.clientName,
      'clientVersion': session.clientVersion,
      'transport': session.transport,
      'activeProjectId': session.activeProjectId,
      'activeCompositionId': session.activeCompositionId,
      'timelineRevision': session.timelineRevision,
      'capabilities':
          session.grantedCapabilities.map((value) => value.value).toList(),
    };
  }

  Map<String, Object?> _result({
    required Object? id,
    required Map<String, Object?> value,
  }) {
    return <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'result': value,
    };
  }

  Map<String, Object?> _error({
    required Object? id,
    required int code,
    required String message,
  }) {
    return <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'error': <String, Object?>{
        'code': code,
        'message': message,
      },
    };
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return null;
  }

  String? _activeProjectIdForSession(String sessionId) {
    for (final session in _bridge.listSessions()) {
      if (session.id != sessionId) {
        continue;
      }
      return _normalizedProjectIdentity(session.activeProjectId);
    }
    return null;
  }

  String? _readNormalizedProjectIdentity(Object? value) {
    if (value is! String) {
      return null;
    }
    return _normalizedProjectIdentity(value);
  }

  String? _readNormalizedCompositionIdentity(Object? value) {
    if (value is! String) {
      return null;
    }
    return _normalizedCompositionIdentity(value);
  }

  String? _normalizedProjectIdentity(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final lower = normalized.toLowerCase();
    if (const <String>{
      'active',
      'default',
      'motion-project',
      'project',
    }.contains(lower)) {
      return null;
    }
    return normalized;
  }

  String? _normalizedCompositionIdentity(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final lower = normalized.toLowerCase();
    if (const <String>{
      'active-composition',
      'active',
      'scene-main',
      'comp_1',
      'main',
      'default',
    }.contains(lower)) {
      return null;
    }
    return normalized;
  }

  Map<String, Object?> _readMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is String) {
          result[key] = entry.value;
        }
      }
      return result;
    }
    return const <String, Object?>{};
  }

  String? _readString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  _TransactionValidation _validateCanonicalTransaction({
    required Map<String, Object?> transaction,
    required bool requiredForMutation,
  }) {
    if (transaction.isEmpty) {
      return requiredForMutation
          ? const _TransactionValidation(
              ok: true,
              message: null,
            )
          : const _TransactionValidation(ok: true, message: null);
    }
    final schemaVersion = _readInt(transaction['schemaVersion']);
    final baseRevision = _readInt(transaction['baseRevision']);
    final idempotencyKey = _readString(transaction['idempotencyKey']);
    final projectId = _readString(transaction['projectId']);
    final compositionId = _readString(transaction['compositionId']);
    final operations = transaction['operations'];
    final issues = <String>[];
    if (schemaVersion == null || schemaVersion <= 0) {
      issues.add('transaction.schemaVersion must be a positive integer');
    }
    if (baseRevision == null || baseRevision < 0) {
      issues.add('transaction.baseRevision must be >= 0');
    }
    if (idempotencyKey == null) {
      issues.add('transaction.idempotencyKey is required');
    }
    if (projectId == null) {
      issues.add('transaction.projectId is required');
    }
    if (compositionId == null) {
      issues.add('transaction.compositionId is required');
    }
    if (operations is! List || operations.isEmpty) {
      issues.add('transaction.operations must be a non-empty array');
    }
    if (issues.isNotEmpty) {
      return _TransactionValidation(
        ok: false,
        message:
            'Canonical transaction validation failed: ${issues.join('; ')}.',
      );
    }
    return const _TransactionValidation(ok: true, message: null);
  }

  Map<String, Object?> _mergedPayloadWithTransaction({
    required Map<String, Object?> payload,
    required Map<String, Object?> transaction,
  }) {
    if (transaction.isEmpty) {
      return payload;
    }
    return <String, Object?>{
      ...payload,
      'transaction': transaction,
      if (payload['baseRevision'] == null && transaction['baseRevision'] is int)
        'baseRevision': transaction['baseRevision'],
      if (payload['schemaVersion'] == null &&
          transaction['schemaVersion'] is int)
        'schemaVersion': transaction['schemaVersion'],
    };
  }
}

class _TransactionValidation {
  const _TransactionValidation({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String? message;
}
