import 'package:flutter/foundation.dart';

import 'refusion_mcp_capability.dart';

@immutable
class RefusionMcpSession {
  RefusionMcpSession({
    required this.id,
    required this.clientName,
    required this.clientVersion,
    required this.transport,
    required this.activeProjectId,
    required this.activeCompositionId,
    required this.timelineRevision,
    this.playheadMs = 0,
    this.previewMode = 'timeline',
    Set<String> selectedObjectIds = const <String>{},
    Set<RefusionMcpCapability> grantedCapabilities =
        const <RefusionMcpCapability>{},
    this.lastPreviewFrameResourceUri,
    this.lastDiagnosticsResourceUri,
    DateTime? createdAt,
    DateTime? lastSeenAt,
  })  : selectedObjectIds = Set.unmodifiable(selectedObjectIds),
        grantedCapabilities = Set.unmodifiable(grantedCapabilities),
        createdAt = createdAt ?? DateTime.now().toUtc(),
        lastSeenAt = lastSeenAt ?? DateTime.now().toUtc();

  final String id;
  final String clientName;
  final String clientVersion;
  final String transport;
  final String activeProjectId;
  final String activeCompositionId;
  final int timelineRevision;
  final int playheadMs;
  final String previewMode;
  final Set<String> selectedObjectIds;
  final Set<RefusionMcpCapability> grantedCapabilities;
  final String? lastPreviewFrameResourceUri;
  final String? lastDiagnosticsResourceUri;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  bool hasCapability(RefusionMcpCapability capability) {
    return grantedCapabilities.contains(capability);
  }

  RefusionMcpSession copyWith({
    int? timelineRevision,
    int? playheadMs,
    String? previewMode,
    Set<String>? selectedObjectIds,
    Set<RefusionMcpCapability>? grantedCapabilities,
    String? lastPreviewFrameResourceUri,
    String? lastDiagnosticsResourceUri,
    DateTime? lastSeenAt,
  }) {
    return RefusionMcpSession(
      id: id,
      clientName: clientName,
      clientVersion: clientVersion,
      transport: transport,
      activeProjectId: activeProjectId,
      activeCompositionId: activeCompositionId,
      timelineRevision: timelineRevision ?? this.timelineRevision,
      playheadMs: playheadMs ?? this.playheadMs,
      previewMode: previewMode ?? this.previewMode,
      selectedObjectIds: selectedObjectIds ?? this.selectedObjectIds,
      grantedCapabilities: grantedCapabilities ?? this.grantedCapabilities,
      lastPreviewFrameResourceUri:
          lastPreviewFrameResourceUri ?? this.lastPreviewFrameResourceUri,
      lastDiagnosticsResourceUri:
          lastDiagnosticsResourceUri ?? this.lastDiagnosticsResourceUri,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? DateTime.now().toUtc(),
    );
  }
}
