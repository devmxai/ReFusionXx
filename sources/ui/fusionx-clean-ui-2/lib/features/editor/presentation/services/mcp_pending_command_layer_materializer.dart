class McpPendingCommandLayerMaterializer {
  const McpPendingCommandLayerMaterializer();

  List<Map<String, Object?>> materialize(
    List<Map<String, Object?>> pendingCommands,
  ) {
    final remoteLayers = <Map<String, Object?>>[];
    final seenLayerIds = <String>{};
    for (final command in pendingCommands) {
      final remoteLayer = _remoteLayerForCommand(command);
      if (remoteLayer == null) {
        continue;
      }
      final layerId = _text(remoteLayer['id']);
      if (layerId == null || !seenLayerIds.add(layerId)) {
        continue;
      }
      remoteLayers.add(remoteLayer);
    }
    return List<Map<String, Object?>>.unmodifiable(remoteLayers);
  }

  Map<String, Object?>? _remoteLayerForCommand(
    Map<String, Object?> command,
  ) {
    final status = (_text(command['status']) ?? '').toLowerCase();
    if (status.isNotEmpty &&
        status != 'pending' &&
        status != 'running' &&
        status != 'received') {
      return null;
    }
    final commandType = (_text(command['command_type']) ??
            _text(command['commandType']) ??
            _text(command['type']) ??
            '')
        .toLowerCase();
    if (!_isLayerInsertCommand(commandType)) {
      return null;
    }

    final commandPayload = _map(command['payload']);
    final nestedPayload = _map(commandPayload['payload']);
    final layerId = _firstText(<Object?>[
      commandPayload['layerId'],
      commandPayload['targetLayerId'],
      nestedPayload['layerId'],
      nestedPayload['targetLayerId'],
    ]);
    if (layerId == null) {
      return null;
    }
    final layerKind = _normalizeLayerKind(
      _firstText(<Object?>[
        commandPayload['layerKind'],
        commandPayload['layer_kind'],
        nestedPayload['layerKind'],
        nestedPayload['layer_kind'],
        nestedPayload['kind'],
        nestedPayload['type'],
      ]),
    );
    final name = _firstText(<Object?>[
          commandPayload['name'],
          nestedPayload['name'],
        ]) ??
        _defaultNameForKind(layerKind);
    final startMs = _number(<Object?>[
      commandPayload['startMs'],
      commandPayload['start_ms'],
      nestedPayload['startMs'],
      nestedPayload['start_ms'],
    ], 0);
    final durationMs = _number(<Object?>[
      commandPayload['durationMs'],
      commandPayload['duration_ms'],
      nestedPayload['durationMs'],
      nestedPayload['duration_ms'],
    ], 8000);
    final zIndex = _number(<Object?>[
      commandPayload['zIndex'],
      commandPayload['z_index'],
      nestedPayload['zIndex'],
      nestedPayload['z_index'],
    ], layerKind == 'solid' ? -1000 : 0);

    final payload = <String, Object?>{
      ...nestedPayload,
      'operation': _firstText(<Object?>[
            nestedPayload['operation'],
            commandPayload['operation'],
          ]) ??
          'insert_layer',
      'layerId': layerId,
      'remoteLayerId': layerId,
      'layerKind': layerKind,
      'kind': layerKind,
      'name': name,
      'startMs': startMs,
      'durationMs': durationMs,
      'zIndex': zIndex,
      'mcpCommandId': _text(command['id']),
    };

    if (layerKind == 'solid') {
      final color = _firstText(<Object?>[
            nestedPayload['color'],
            nestedPayload['backgroundColor'],
            commandPayload['color'],
          ]) ??
          '#FFFFFF';
      payload
        ..['type'] = 'solid'
        ..['shape'] = 'rect'
        ..['color'] = color
        ..['backgroundColor'] = color
        ..['semanticRole'] = 'background.canvas'
        ..['backgroundRole'] = 'canvas';
    }

    return <String, Object?>{
      'id': layerId,
      'layer_kind': layerKind,
      'layerKind': layerKind,
      'name': name,
      'start_ms': startMs,
      'duration_ms': durationMs,
      'z_index': zIndex,
      'payload': Map<String, Object?>.unmodifiable(payload),
    };
  }

  bool _isLayerInsertCommand(String commandType) {
    return commandType == 'refusion.insert_layer' ||
        commandType.endsWith('.insert_layer') ||
        commandType == 'insert_layer';
  }

  String _normalizeLayerKind(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return switch (normalized) {
      'text' ||
      'shape' ||
      'solid' ||
      'media' ||
      'image' ||
      'video' ||
      'audio' =>
        normalized,
      'background' => 'solid',
      _ => 'shape',
    };
  }

  String _defaultNameForKind(String layerKind) {
    return switch (layerKind) {
      'solid' => 'Background',
      'text' => 'Text',
      _ => 'Layer',
    };
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      final mapped = <String, Object?>{};
      value.forEach((key, dynamicValue) {
        if (key is String) {
          mapped[key] = dynamicValue;
        }
      });
      return mapped;
    }
    return const <String, Object?>{};
  }

  String? _firstText(List<Object?> values) {
    for (final value in values) {
      final normalized = _text(value);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  String? _text(Object? value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  int _number(List<Object?> values, int fallback) {
    for (final value in values) {
      if (value is num && value.isFinite) {
        return value.round();
      }
    }
    return fallback;
  }
}
