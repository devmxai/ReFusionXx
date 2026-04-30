import '../models/timeline_mock_models.dart';

enum TransitionBoundaryFrameRole {
  outgoing,
  incoming,
}

class TransitionBoundaryFrameRequest {
  const TransitionBoundaryFrameRequest({
    required this.cacheKey,
    required this.sourceUri,
    required this.positionMs,
    required this.targetWidth,
    required this.targetHeight,
  });

  final String cacheKey;
  final String sourceUri;
  final int positionMs;
  final int targetWidth;
  final int targetHeight;
}

class TransitionBoundaryFrameRequestResolver {
  const TransitionBoundaryFrameRequestResolver();

  TransitionBoundaryFrameRequest? resolve({
    required TimelineClipData clip,
    required String sourceUri,
    required TransitionBoundaryFrameRole role,
    required int frameDurationMs,
    required int targetWidth,
    required int targetHeight,
  }) {
    final assetId = clip.assetId;
    if (assetId == null || assetId.isEmpty || sourceUri.isEmpty) {
      return null;
    }
    final safeFrameDurationMs =
        frameDurationMs <= 0 ? 33 : frameDurationMs.clamp(1, 1000);
    final sourceStartMs = clip.sourceStartTime.inMilliseconds;
    final sourceEndMs = clip.sourceEndTime.inMilliseconds;
    final positionMs = switch (role) {
      TransitionBoundaryFrameRole.incoming => sourceStartMs,
      TransitionBoundaryFrameRole.outgoing => _clampInt(
          sourceEndMs - safeFrameDurationMs,
          sourceStartMs,
          sourceEndMs,
        ),
    };
    final safePositionMs = positionMs < 0 ? 0 : positionMs;
    final roleKey = switch (role) {
      TransitionBoundaryFrameRole.outgoing => 'out',
      TransitionBoundaryFrameRole.incoming => 'in',
    };
    return TransitionBoundaryFrameRequest(
      cacheKey:
          '$assetId:${clip.id}:$roleKey:$safePositionMs:${targetWidth}x$targetHeight',
      sourceUri: sourceUri,
      positionMs: safePositionMs,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
  }

  int _clampInt(int value, int lower, int upper) {
    if (upper < lower) {
      return lower;
    }
    if (value < lower) {
      return lower;
    }
    if (value > upper) {
      return upper;
    }
    return value;
  }
}
