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
  });

  final int appliedCommandCount;
  final List<String> appliedCommandTypes;
  final int receivedRemoteLayers;
  final int? appliedMotionChannels;
  final int? lastAppliedMotionChannelsBatch;

  Map<String, Object?> toProofMap() {
    return <String, Object?>{
      'appliedCommands': appliedCommandCount,
      'appliedKinds': appliedCommandTypes,
      'remoteLayersReceived': receivedRemoteLayers,
      if (appliedMotionChannels != null)
        'appliedMotionChannels': appliedMotionChannels,
      if (lastAppliedMotionChannelsBatch != null)
        'lastAppliedMotionChannelsBatch': lastAppliedMotionChannelsBatch,
    };
  }

  ProfessionalSceneApplyReceipt copyWith({
    int? appliedCommandCount,
    List<String>? appliedCommandTypes,
    int? receivedRemoteLayers,
    int? appliedMotionChannels,
    int? lastAppliedMotionChannelsBatch,
  }) {
    return ProfessionalSceneApplyReceipt(
      appliedCommandCount: appliedCommandCount ?? this.appliedCommandCount,
      appliedCommandTypes: appliedCommandTypes ?? this.appliedCommandTypes,
      receivedRemoteLayers: receivedRemoteLayers ?? this.receivedRemoteLayers,
      appliedMotionChannels:
          appliedMotionChannels ?? this.appliedMotionChannels,
      lastAppliedMotionChannelsBatch:
          lastAppliedMotionChannelsBatch ?? this.lastAppliedMotionChannelsBatch,
    );
  }
}
