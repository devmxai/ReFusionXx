enum AiTransitionProvider {
  kie,
}

enum AiTransitionModel {
  grokImagineImageToVideo,
  kling3StandardSilent,
  wan27ImageToVideo,
}

enum AiTransitionJobStatus {
  draft,
  waitingForBackend,
  queued,
  running,
  completed,
  failed,
}

extension AiTransitionModelPresentation on AiTransitionModel {
  String get label {
    return switch (this) {
      AiTransitionModel.grokImagineImageToVideo => 'Grok Imagine I2V',
      AiTransitionModel.kling3StandardSilent => 'Kling 3 Std',
      AiTransitionModel.wan27ImageToVideo => 'WAN 2.7 I2V',
    };
  }

  String get summary {
    return switch (this) {
      AiTransitionModel.grokImagineImageToVideo =>
        'Two-frame cinematic bridge. Grok Imagine video is the default path.',
      AiTransitionModel.kling3StandardSilent =>
        'Start/end frame transition. Standard mode, sound off.',
      AiTransitionModel.wan27ImageToVideo =>
        'Image-to-video transition using first and last frames.',
    };
  }

  int get minDurationSeconds {
    return switch (this) {
      AiTransitionModel.grokImagineImageToVideo => 6,
      AiTransitionModel.kling3StandardSilent => 4,
      AiTransitionModel.wan27ImageToVideo => 3,
    };
  }

  int get maxDurationSeconds {
    return switch (this) {
      AiTransitionModel.grokImagineImageToVideo => 10,
      AiTransitionModel.kling3StandardSilent => 10,
      AiTransitionModel.wan27ImageToVideo => 8,
    };
  }

  int get defaultDurationSeconds {
    return minDurationSeconds;
  }

  String get providerModelId {
    return switch (this) {
      AiTransitionModel.grokImagineImageToVideo =>
        'grok-imagine/image-to-video',
      AiTransitionModel.kling3StandardSilent => 'kling-3.0/std/silent',
      AiTransitionModel.wan27ImageToVideo => 'wan-2.7/image-to-video',
    };
  }
}

extension AiTransitionJobStatusPresentation on AiTransitionJobStatus {
  String get label {
    return switch (this) {
      AiTransitionJobStatus.draft => 'Draft',
      AiTransitionJobStatus.waitingForBackend => 'Preparing',
      AiTransitionJobStatus.queued => 'Queued',
      AiTransitionJobStatus.running => 'Running',
      AiTransitionJobStatus.completed => 'Ready',
      AiTransitionJobStatus.failed => 'Failed',
    };
  }
}

class AiTransitionDraftData {
  const AiTransitionDraftData({
    required this.model,
    required this.prompt,
    required this.durationSeconds,
    this.provider = AiTransitionProvider.kie,
    this.status = AiTransitionJobStatus.draft,
    this.soundEnabled = false,
    this.requestId,
    this.generatedVideoUri,
    this.generatedAssetId,
    this.errorMessage,
    this.createdAtMs,
    this.leftSourceAssetId,
    this.rightSourceAssetId,
    this.leftBoundaryFramePositionMs,
    this.rightBoundaryFramePositionMs,
    this.aspectRatioHint,
  });

  final AiTransitionProvider provider;
  final AiTransitionModel model;
  final String prompt;
  final int durationSeconds;
  final AiTransitionJobStatus status;
  final bool soundEnabled;
  final String? requestId;
  final String? generatedVideoUri;
  final String? generatedAssetId;
  final String? errorMessage;
  final int? createdAtMs;
  final String? leftSourceAssetId;
  final String? rightSourceAssetId;
  final int? leftBoundaryFramePositionMs;
  final int? rightBoundaryFramePositionMs;
  final String? aspectRatioHint;

  AiTransitionDraftData copyWith({
    AiTransitionProvider? provider,
    AiTransitionModel? model,
    String? prompt,
    int? durationSeconds,
    AiTransitionJobStatus? status,
    bool? soundEnabled,
    String? requestId,
    String? generatedVideoUri,
    String? generatedAssetId,
    String? errorMessage,
    int? createdAtMs,
    String? leftSourceAssetId,
    String? rightSourceAssetId,
    int? leftBoundaryFramePositionMs,
    int? rightBoundaryFramePositionMs,
    String? aspectRatioHint,
    bool clearRequestId = false,
    bool clearGeneratedVideoUri = false,
    bool clearGeneratedAssetId = false,
    bool clearErrorMessage = false,
    bool clearLeftSourceAssetId = false,
    bool clearRightSourceAssetId = false,
    bool clearLeftBoundaryFramePositionMs = false,
    bool clearRightBoundaryFramePositionMs = false,
    bool clearAspectRatioHint = false,
  }) {
    return AiTransitionDraftData(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      prompt: prompt ?? this.prompt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      requestId: clearRequestId ? null : requestId ?? this.requestId,
      generatedVideoUri: clearGeneratedVideoUri
          ? null
          : generatedVideoUri ?? this.generatedVideoUri,
      generatedAssetId: clearGeneratedAssetId
          ? null
          : generatedAssetId ?? this.generatedAssetId,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      leftSourceAssetId: clearLeftSourceAssetId
          ? null
          : leftSourceAssetId ?? this.leftSourceAssetId,
      rightSourceAssetId: clearRightSourceAssetId
          ? null
          : rightSourceAssetId ?? this.rightSourceAssetId,
      leftBoundaryFramePositionMs: clearLeftBoundaryFramePositionMs
          ? null
          : leftBoundaryFramePositionMs ?? this.leftBoundaryFramePositionMs,
      rightBoundaryFramePositionMs: clearRightBoundaryFramePositionMs
          ? null
          : rightBoundaryFramePositionMs ?? this.rightBoundaryFramePositionMs,
      aspectRatioHint:
          clearAspectRatioHint ? null : aspectRatioHint ?? this.aspectRatioHint,
    );
  }
}
