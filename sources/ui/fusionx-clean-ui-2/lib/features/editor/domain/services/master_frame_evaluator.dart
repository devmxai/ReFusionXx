import 'unified_creative_apply_engine.dart';

class EvaluatedLayerFrame {
  const EvaluatedLayerFrame({
    required this.layerId,
    required this.x,
    required this.y,
    required this.scaleX,
    required this.scaleY,
    required this.opacity,
    required this.rotation,
  });

  final String layerId;
  final double x;
  final double y;
  final double scaleX;
  final double scaleY;
  final double opacity;
  final double rotation;
}

class MasterFrameEvaluator {
  const MasterFrameEvaluator();

  EvaluatedLayerFrame evaluateLayerAtTime({
    required UnifiedCreativeLayerNode layer,
    required int timeMs,
  }) {
    return EvaluatedLayerFrame(
      layerId: layer.identity.layerId,
      x: _evaluateProperty(layer, 'x', timeMs, layer.x),
      y: _evaluateProperty(layer, 'y', timeMs, layer.y),
      scaleX: _evaluateProperty(layer, 'scaleX', timeMs, layer.scaleX),
      scaleY: _evaluateProperty(layer, 'scaleY', timeMs, layer.scaleY),
      opacity: _evaluateProperty(layer, 'opacity', timeMs, layer.opacity),
      rotation: _evaluateProperty(layer, 'rotation', timeMs, layer.rotation),
    );
  }
}

double _evaluateProperty(
  UnifiedCreativeLayerNode layer,
  String propertyId,
  int timeMs,
  double fallback,
) {
  UnifiedCreativeMotionChannel? channel;
  for (final candidate in layer.motionChannels) {
    if (candidate.propertyId == propertyId) {
      channel = candidate;
      break;
    }
  }
  if (channel == null || channel.keyframes.isEmpty) {
    return fallback;
  }
  final sorted = <UnifiedCreativeKeyframe>[...channel.keyframes]
    ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
  if (timeMs <= sorted.first.timeMs) {
    return sorted.first.value;
  }
  if (timeMs >= sorted.last.timeMs) {
    return sorted.last.value;
  }
  for (var i = 0; i < sorted.length - 1; i++) {
    final left = sorted[i];
    final right = sorted[i + 1];
    if (timeMs < left.timeMs || timeMs > right.timeMs) {
      continue;
    }
    final span = (right.timeMs - left.timeMs).toDouble();
    if (span <= 0) {
      return right.value;
    }
    final t = (timeMs - left.timeMs) / span;
    return left.value + (right.value - left.value) * t;
  }
  return fallback;
}
