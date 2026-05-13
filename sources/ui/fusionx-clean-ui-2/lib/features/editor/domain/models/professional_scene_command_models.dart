import 'package:flutter/foundation.dart';

enum ProfessionalSceneCommandSource {
  mcpAgent,
  manualUi,
  pasteScript,
  template,
  tapList,
  futureTool,
}

enum ProfessionalSceneCommandType {
  applyLegacyAnimation,
  applyTextLayer,
  applySolidLayer,
  registerMediaBinding,
  applyTimelineMutation,
}

enum ProfessionalSceneCommandTargetMode {
  layerId,
  elementId,
  clipId,
  sceneId,
  graphQuery,
}

@immutable
class ProfessionalSceneCommandTarget {
  const ProfessionalSceneCommandTarget({
    required this.mode,
    this.id,
  });

  final ProfessionalSceneCommandTargetMode mode;
  final String? id;
}

@immutable
class ProfessionalSceneCommand {
  const ProfessionalSceneCommand({
    required this.type,
    required this.source,
    required this.target,
    required this.payload,
  });

  final ProfessionalSceneCommandType type;
  final ProfessionalSceneCommandSource source;
  final ProfessionalSceneCommandTarget target;
  final Map<String, Object?> payload;
}

@immutable
class ProfessionalSceneApplyReceipt {
  const ProfessionalSceneApplyReceipt({
    required this.appliedCommandCount,
    required this.appliedCommandTypes,
    required this.receivedRemoteLayers,
    this.appliedMotionChannels,
    this.lastAppliedMotionChannelsBatch,
    this.operationApplied,
    this.createdLayerCount,
    this.updatedLayerCount,
    this.targetLayerIds = const <String>[],
  });

  final int appliedCommandCount;
  final List<String> appliedCommandTypes;
  final int receivedRemoteLayers;
  final int? appliedMotionChannels;
  final int? lastAppliedMotionChannelsBatch;
  final String? operationApplied;
  final int? createdLayerCount;
  final int? updatedLayerCount;
  final List<String> targetLayerIds;

  Map<String, Object?> toProofMap() {
    return <String, Object?>{
      'appliedCommands': appliedCommandCount,
      'appliedKinds': appliedCommandTypes,
      'remoteLayersReceived': receivedRemoteLayers,
      if (appliedMotionChannels != null)
        'appliedMotionChannels': appliedMotionChannels,
      if (lastAppliedMotionChannelsBatch != null)
        'lastAppliedMotionChannelsBatch': lastAppliedMotionChannelsBatch,
      if (operationApplied != null && operationApplied!.isNotEmpty)
        'operationApplied': operationApplied,
      if (createdLayerCount != null) 'createdLayerCount': createdLayerCount,
      if (updatedLayerCount != null) 'updatedLayerCount': updatedLayerCount,
      if (targetLayerIds.isNotEmpty) 'targetLayerIds': targetLayerIds,
    };
  }

  ProfessionalSceneApplyReceipt copyWith({
    int? appliedCommandCount,
    List<String>? appliedCommandTypes,
    int? receivedRemoteLayers,
    int? appliedMotionChannels,
    int? lastAppliedMotionChannelsBatch,
    String? operationApplied,
    int? createdLayerCount,
    int? updatedLayerCount,
    List<String>? targetLayerIds,
  }) {
    return ProfessionalSceneApplyReceipt(
      appliedCommandCount: appliedCommandCount ?? this.appliedCommandCount,
      appliedCommandTypes: appliedCommandTypes ?? this.appliedCommandTypes,
      receivedRemoteLayers: receivedRemoteLayers ?? this.receivedRemoteLayers,
      appliedMotionChannels:
          appliedMotionChannels ?? this.appliedMotionChannels,
      lastAppliedMotionChannelsBatch:
          lastAppliedMotionChannelsBatch ?? this.lastAppliedMotionChannelsBatch,
      operationApplied: operationApplied ?? this.operationApplied,
      createdLayerCount: createdLayerCount ?? this.createdLayerCount,
      updatedLayerCount: updatedLayerCount ?? this.updatedLayerCount,
      targetLayerIds: targetLayerIds ?? this.targetLayerIds,
    );
  }
}
