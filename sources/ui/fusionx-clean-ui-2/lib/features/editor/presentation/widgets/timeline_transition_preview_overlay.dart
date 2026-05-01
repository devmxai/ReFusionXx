import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../models/timeline_mock_models.dart';

class TimelineTransitionPreviewOverlay extends StatelessWidget {
  const TimelineTransitionPreviewOverlay({
    super.key,
    required this.transition,
    required this.progress,
    this.manualLaneProgress,
    this.manualSeamProgress,
    this.outgoingThumbnailBytes,
    this.incomingThumbnailBytes,
  });

  final TimelineTrackTransitionData transition;
  final double progress;
  final double? manualLaneProgress;
  final double? manualSeamProgress;
  final Uint8List? outgoingThumbnailBytes;
  final Uint8List? incomingThumbnailBytes;

  @override
  Widget build(BuildContext context) {
    final curvedProgress = _applyCurve(progress, transition.curve);
    final resolvedManualLaneProgress =
        (manualLaneProgress ?? progress).clamp(0.0, 1.0).toDouble();
    final seamProgress =
        manualSeamProgress ?? _seamProgressForTransition(transition);
    final manualIncomingStartScale = transition.manualLaneValueAtProgress(
          'incomingStartScale',
          resolvedManualLaneProgress,
          fallbackValue: _manualPercentFallback(
            'incomingStartScale',
            normalizedFallback: 1.0,
          ),
        ) /
        100.0;
    final manualOutgoingBoostScale = transition.manualLaneValueAtProgress(
          'outgoingBoostScale',
          resolvedManualLaneProgress,
          fallbackValue: _manualPercentFallback(
            'outgoingBoostScale',
            normalizedFallback: 1.0,
          ),
        ) /
        100.0;
    final manualEntryDelay = transition.manualLaneValueAtProgress(
          'entryDelay',
          resolvedManualLaneProgress,
          fallbackValue: _manualPercentFallback(
            'entryDelay',
            normalizedFallback: 0.0,
          ),
        ) /
        100.0;
    final manualBridgeDarkness = transition.manualLaneValueAtProgress(
          'bridgeDarkness',
          resolvedManualLaneProgress,
          fallbackValue: _manualPercentFallback(
            'bridgeDarkness',
            normalizedFallback: 0.0,
          ),
        ) /
        100.0;
    final manualBlackPeak = transition.manualLaneValueAtProgress(
          'blackPeak',
          resolvedManualLaneProgress,
          fallbackValue: _manualPercentFallback(
            'blackPeak',
            normalizedFallback: 0.0,
          ),
        ) /
        100.0;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (transition.preset == TimelineTransitionPreset.manual &&
              transition.manualEffectIds.isNotEmpty)
            _ManualTransitionLayer(
              progress: curvedProgress,
              seamProgress: seamProgress,
              effectIds: transition.manualEffectIds,
              outgoingThumbnailBytes: outgoingThumbnailBytes,
              incomingThumbnailBytes: incomingThumbnailBytes,
              incomingStartScale: manualIncomingStartScale,
              outgoingBoostScale: manualOutgoingBoostScale,
              entryDelay: manualEntryDelay,
              bridgeDarkness: manualBridgeDarkness,
              blackPeak: manualBlackPeak,
            ),
          if (transition.preset == TimelineTransitionPreset.fadeBlack)
            _FadeBlackTransitionLayer(
              opacity: _fadeBlackOpacity(
                curvedProgress,
                transition.parameterValue('blackPeak', fallback: 0.94),
              ),
            ),
          if (transition.preset == TimelineTransitionPreset.crossDissolve)
            _CrossDissolveTransitionLayer(
              progress: curvedProgress,
              seamProgress: seamProgress,
              outgoingThumbnailBytes: outgoingThumbnailBytes,
              incomingThumbnailBytes: incomingThumbnailBytes,
            ),
          if (transition.preset == TimelineTransitionPreset.zoomInCamera)
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  double _fadeBlackOpacity(double t, double peak) {
    final triangular = 1 - ((t - 0.5).abs() / 0.5);
    return (triangular.clamp(0.0, 1.0) * peak.clamp(0.0, 1.0)).toDouble();
  }

  double _manualPercentFallback(
    String key, {
    required double normalizedFallback,
  }) {
    final raw = transition.parameterValue(key, fallback: normalizedFallback);
    if (raw.abs() <= 2.0) {
      return raw * 100.0;
    }
    return raw;
  }

  double _seamProgressForTransition(TimelineTrackTransitionData transition) {
    final leading = transition.resolvedLeadingDurationTime.inMilliseconds;
    final trailing = transition.resolvedTrailingDurationTime.inMilliseconds;
    final total = leading + trailing;
    if (total <= 0) {
      return 0.5;
    }
    return (leading / total).clamp(0.0, 1.0).toDouble();
  }

  double _applyCurve(double t, TimelineTransitionCurve curve) {
    final clamped = t.clamp(0.0, 1.0);
    return switch (curve) {
      TimelineTransitionCurve.linear => clamped,
      TimelineTransitionCurve.easeIn => Curves.easeIn.transform(clamped),
      TimelineTransitionCurve.easeOut => Curves.easeOut.transform(clamped),
      TimelineTransitionCurve.easeInOut => Curves.easeInOut.transform(clamped),
    };
  }
}

class _ManualTransitionLayer extends StatelessWidget {
  const _ManualTransitionLayer({
    required this.progress,
    required this.seamProgress,
    required this.effectIds,
    required this.outgoingThumbnailBytes,
    required this.incomingThumbnailBytes,
    required this.incomingStartScale,
    required this.outgoingBoostScale,
    required this.entryDelay,
    required this.bridgeDarkness,
    required this.blackPeak,
  });

  final double progress;
  final double seamProgress;
  final List<String> effectIds;
  final Uint8List? outgoingThumbnailBytes;
  final Uint8List? incomingThumbnailBytes;
  final double incomingStartScale;
  final double outgoingBoostScale;
  final double entryDelay;
  final double bridgeDarkness;
  final double blackPeak;

  @override
  Widget build(BuildContext context) {
    final effectSet = effectIds.toSet();
    final seam = seamProgress.clamp(0.0, 1.0);
    final pulseWidth = math.max(
      0.001,
      math.min(math.max(seam, 0.001), math.max(1 - seam, 0.001)),
    );
    final centeredPulse =
        (1 - ((progress - seam).abs() / pulseWidth)).clamp(0.0, 1.0).toDouble();
    final hasOutgoingScale = effectSet.contains('outgoingBoostScale');
    final hasIncomingScale = effectSet.contains('incomingStartScale');
    final hasBridgeDarkness = effectSet.contains('bridgeDarkness');
    final hasBlackMix = effectSet.contains('blackPeak');
    final outgoingPhase = progress <= seam
        ? (progress / math.max(seam, 0.001)).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final incomingDelayProgress =
        (seam + ((1 - seam) * entryDelay.clamp(0.0, 1.0)))
            .clamp(seam, 1.0)
            .toDouble();
    final incomingPhase = progress <= incomingDelayProgress
        ? 0.0
        : ((progress - incomingDelayProgress) /
                math.max(0.001, 1 - incomingDelayProgress))
            .clamp(0.0, 1.0)
            .toDouble();
    final outgoingScale = hasOutgoingScale
        ? (lerpDouble(1.0, outgoingBoostScale, outgoingPhase) ?? 1.0)
        : 1.0;
    final bridgeOpacity = hasBridgeDarkness
        ? (centeredPulse * bridgeDarkness.clamp(0.0, 1.0)).toDouble()
        : 0.0;
    final fadeOpacity =
        hasBlackMix ? blackPeak.clamp(0.0, 1.0).toDouble() : 0.0;
    final incomingOpacity =
        hasIncomingScale ? Curves.easeOut.transform(incomingPhase) : 0.0;
    final incomingScale =
        lerpDouble(incomingStartScale, 1.0, incomingPhase) ?? 1.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasOutgoingScale && outgoingThumbnailBytes != null)
          Transform.scale(
            scale: outgoingScale,
            child: Image.memory(
              outgoingThumbnailBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        if (bridgeOpacity > 0.001)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.92,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(bridgeOpacity * 0.46),
                    Colors.black.withOpacity(bridgeOpacity),
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
              ),
            ),
          ),
        if (hasIncomingScale &&
            incomingThumbnailBytes != null &&
            incomingOpacity > 0.001)
          Opacity(
            opacity: incomingOpacity.clamp(0.0, 1.0).toDouble(),
            child: Transform.scale(
              scale: incomingScale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.18 + (incomingOpacity * 0.2)),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    incomingThumbnailBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        if (fadeOpacity > 0.001)
          ColoredBox(
            color: Colors.black.withOpacity(fadeOpacity),
          ),
      ],
    );
  }
}

class _FadeBlackTransitionLayer extends StatelessWidget {
  const _FadeBlackTransitionLayer({
    required this.opacity,
  });

  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.001) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: Colors.black.withOpacity(opacity),
    );
  }
}

class _CrossDissolveTransitionLayer extends StatelessWidget {
  const _CrossDissolveTransitionLayer({
    required this.progress,
    required this.seamProgress,
    required this.outgoingThumbnailBytes,
    required this.incomingThumbnailBytes,
  });

  final double progress;
  final double seamProgress;
  final Uint8List? outgoingThumbnailBytes;
  final Uint8List? incomingThumbnailBytes;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final seam = seamProgress.clamp(0.001, 0.999).toDouble();
    final isBeforeSeam = clampedProgress <= seam;
    final bytes =
        isBeforeSeam ? incomingThumbnailBytes : outgoingThumbnailBytes;
    if (bytes == null || bytes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Opacity(
      opacity: isBeforeSeam ? clampedProgress : 1.0 - clampedProgress,
      child: Image.memory(
        key: ValueKey(
          isBeforeSeam
              ? 'cross-dissolve-incoming-boundary'
              : 'cross-dissolve-outgoing-boundary',
        ),
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
