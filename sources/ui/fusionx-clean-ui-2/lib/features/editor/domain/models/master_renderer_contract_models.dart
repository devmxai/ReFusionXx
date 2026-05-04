import 'master_time_models.dart';

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
}
