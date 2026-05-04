import 'master_time_models.dart';
import 'master_renderer_adapter_models.dart';

class MasterRendererContracts {
  const MasterRendererContracts._();

  static const String liveScrubRuntimeBridgeSurfaceId = 'stage5-runtime-bridge';
  static const String liveScrubDescriptorSurfaceId = 'stage5-scrub-surface';

  static String liveScrubProgramRequestId(MasterTimeSnapshot time) {
    return 'mlsp:${time.commitFrameNumber}:${time.frameIndex}:${time.renderMode.name}';
  }

  static String liveScrubDescriptorRequestId(MasterTimeSnapshot time) {
    return 'liveScrub:${time.commitFrameNumber}:${time.frameIndex}:${time.rootTime.inMilliseconds}';
  }

  static String runtimeBridgeSurfaceIdForMode(MasterRendererAdapterMode mode) {
    return switch (mode) {
      MasterRendererAdapterMode.preview => 'stage5-preview-surface',
      MasterRendererAdapterMode.liveScrub => liveScrubDescriptorSurfaceId,
      MasterRendererAdapterMode.playback => 'stage5-playback-surface',
      MasterRendererAdapterMode.export => 'stage5-export-surface',
    };
  }

  static String descriptorRequestIdForMode({
    required MasterRendererAdapterMode mode,
    required MasterTimeSnapshot time,
  }) {
    final prefix = switch (mode) {
      MasterRendererAdapterMode.preview => 'preview',
      MasterRendererAdapterMode.liveScrub => 'liveScrub',
      MasterRendererAdapterMode.playback => 'playback',
      MasterRendererAdapterMode.export => 'export',
    };
    return '$prefix:${time.commitFrameNumber}:${time.frameIndex}:${time.rootTime.inMilliseconds}';
  }
}
