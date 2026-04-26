import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
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
    final manualWhiteFlash = transition.manualLaneValueAtProgress(
          'whiteFlash',
          resolvedManualLaneProgress,
          fallbackValue: _manualPercentFallback(
            'whiteFlash',
            normalizedFallback: 0.0,
          ),
        ) /
        100.0;
    final manualOutgoingOffsetX = transition.manualLaneValueAtProgress(
          'outgoingOffsetX',
          resolvedManualLaneProgress,
          fallbackValue: transition.parameterValue(
            'outgoingOffsetX',
            fallback: 0.0,
          ),
        ) /
        100.0;
    final manualIncomingOffsetX = transition.manualLaneValueAtProgress(
          'incomingOffsetX',
          resolvedManualLaneProgress,
          fallbackValue: transition.parameterValue(
            'incomingOffsetX',
            fallback: 0.0,
          ),
        ) /
        100.0;
    final manualOutgoingOffsetY = transition.manualLaneValueAtProgress(
          'outgoingOffsetY',
          resolvedManualLaneProgress,
          fallbackValue: transition.parameterValue(
            'outgoingOffsetY',
            fallback: 0.0,
          ),
        ) /
        100.0;
    final manualIncomingOffsetY = transition.manualLaneValueAtProgress(
          'incomingOffsetY',
          resolvedManualLaneProgress,
          fallbackValue: transition.parameterValue(
            'incomingOffsetY',
            fallback: 0.0,
          ),
        ) /
        100.0;
    final manualOutgoingOpacity = transition.manualLaneValueAtProgress(
          'outgoingOpacity',
          resolvedManualLaneProgress,
          fallbackValue: _manualPercentFallback(
            'outgoingOpacity',
            normalizedFallback: 1.0,
          ),
        ) /
        100.0;
    final manualIncomingOpacity = transition.manualLaneValueAtProgress(
          'incomingOpacity',
          resolvedManualLaneProgress,
          fallbackValue: _manualPercentFallback(
            'incomingOpacity',
            normalizedFallback: 0.0,
          ),
        ) /
        100.0;
    final manualOutgoingRotation = transition.manualLaneValueAtProgress(
      'outgoingRotation',
      resolvedManualLaneProgress,
      fallbackValue: transition.parameterValue('outgoingRotation'),
    );
    final manualIncomingRotation = transition.manualLaneValueAtProgress(
      'incomingRotation',
      resolvedManualLaneProgress,
      fallbackValue: transition.parameterValue('incomingRotation'),
    );
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
              whiteFlash: manualWhiteFlash,
              outgoingOffsetX: manualOutgoingOffsetX,
              incomingOffsetX: manualIncomingOffsetX,
              outgoingOffsetY: manualOutgoingOffsetY,
              incomingOffsetY: manualIncomingOffsetY,
              outgoingOpacity: manualOutgoingOpacity,
              incomingOpacity: manualIncomingOpacity,
              outgoingRotation: manualOutgoingRotation,
              incomingRotation: manualIncomingRotation,
            ),
          if (transition.preset == TimelineTransitionPreset.fadeBlack)
            _FadeBlackTransitionLayer(
              opacity: _fadeBlackOpacity(
                curvedProgress,
                transition.parameterValue('blackPeak', fallback: 0.94),
              ),
            ),
          if (transition.preset == TimelineTransitionPreset.whiteFlash)
            _WhiteFlashTransitionLayer(
              opacity: _fadeBlackOpacity(
                curvedProgress,
                transition.parameterValue('flashPeak', fallback: 0.88),
              ),
            ),
          if (transition.preset == TimelineTransitionPreset.crossDissolve)
            _CrossDissolveTransitionLayer(
              progress: curvedProgress,
              incomingThumbnailBytes: incomingThumbnailBytes,
            ),
          if (transition.preset == TimelineTransitionPreset.blurDissolve)
            _BlurDissolveTransitionLayer(
              progress: curvedProgress,
              outgoingThumbnailBytes: outgoingThumbnailBytes,
              incomingThumbnailBytes: incomingThumbnailBytes,
              maxBlur: transition.parameterValue('maxBlur', fallback: 10.0),
            ),
          if (transition.preset == TimelineTransitionPreset.pushLeft ||
              transition.preset == TimelineTransitionPreset.pushRight)
            _PushTransitionLayer(
              progress: curvedProgress,
              outgoingThumbnailBytes: outgoingThumbnailBytes,
              incomingThumbnailBytes: incomingThumbnailBytes,
              distance: transition.parameterValue('distance', fallback: 1.0),
              direction: transition.preset == TimelineTransitionPreset.pushLeft
                  ? _PushDirection.left
                  : _PushDirection.right,
              maxBlur: 0,
              flashPeak: 0,
            ),
          if (transition.preset == TimelineTransitionPreset.whipPanLeft ||
              transition.preset == TimelineTransitionPreset.whipPanRight)
            _PushTransitionLayer(
              progress: curvedProgress,
              outgoingThumbnailBytes: outgoingThumbnailBytes,
              incomingThumbnailBytes: incomingThumbnailBytes,
              distance: transition.parameterValue('distance', fallback: 1.15),
              direction:
                  transition.preset == TimelineTransitionPreset.whipPanLeft
                      ? _PushDirection.left
                      : _PushDirection.right,
              maxBlur: transition.parameterValue('maxBlur', fallback: 16.0),
              flashPeak: transition.parameterValue('flashPeak', fallback: 0.22),
            ),
          if (transition.preset == TimelineTransitionPreset.slideBlurLeft ||
              transition.preset == TimelineTransitionPreset.slideBlurRight)
            _PushTransitionLayer(
              progress: curvedProgress,
              outgoingThumbnailBytes: outgoingThumbnailBytes,
              incomingThumbnailBytes: incomingThumbnailBytes,
              distance: transition.parameterValue('distance', fallback: 1.0),
              direction:
                  transition.preset == TimelineTransitionPreset.slideBlurLeft
                      ? _PushDirection.left
                      : _PushDirection.right,
              maxBlur: transition.parameterValue('maxBlur', fallback: 8.0),
              flashPeak: 0,
            ),
          if (transition.preset == TimelineTransitionPreset.zoomInCamera)
            _ZoomInCameraTransitionLayer(
              progress: curvedProgress,
              outgoingThumbnailBytes: outgoingThumbnailBytes,
              incomingThumbnailBytes: incomingThumbnailBytes,
              incomingStartScale: transition
                  .parameterValue('incomingStartScale', fallback: 1.18),
              outgoingBoostScale: transition
                  .parameterValue('outgoingBoostScale', fallback: 1.05),
              entryDelay:
                  transition.parameterValue('entryDelay', fallback: 0.18),
              bridgeDarkness:
                  transition.parameterValue('bridgeDarkness', fallback: 0.22),
            ),
          if (transition.preset == TimelineTransitionPreset.zoomOutCamera)
            _ZoomOutCameraTransitionLayer(
              progress: curvedProgress,
              outgoingThumbnailBytes: outgoingThumbnailBytes,
              incomingThumbnailBytes: incomingThumbnailBytes,
              outgoingStartScale: transition
                  .parameterValue('outgoingStartScale', fallback: 1.14),
              incomingStartScale: transition
                  .parameterValue('incomingStartScale', fallback: 1.04),
              bridgeDarkness:
                  transition.parameterValue('bridgeDarkness', fallback: 0.18),
            ),
          if (transition.preset == TimelineTransitionPreset.flashZoom)
            _FlashZoomTransitionLayer(
              progress: curvedProgress,
              outgoingThumbnailBytes: outgoingThumbnailBytes,
              incomingThumbnailBytes: incomingThumbnailBytes,
              incomingStartScale: transition
                  .parameterValue('incomingStartScale', fallback: 1.24),
              outgoingBoostScale: transition
                  .parameterValue('outgoingBoostScale', fallback: 1.12),
              flashPeak: transition.parameterValue('flashPeak', fallback: 0.72),
              bridgeDarkness:
                  transition.parameterValue('bridgeDarkness', fallback: 0.16),
            ),
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
    required this.whiteFlash,
    required this.outgoingOffsetX,
    required this.incomingOffsetX,
    required this.outgoingOffsetY,
    required this.incomingOffsetY,
    required this.outgoingOpacity,
    required this.incomingOpacity,
    required this.outgoingRotation,
    required this.incomingRotation,
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
  final double whiteFlash;
  final double outgoingOffsetX;
  final double incomingOffsetX;
  final double outgoingOffsetY;
  final double incomingOffsetY;
  final double outgoingOpacity;
  final double incomingOpacity;
  final double outgoingRotation;
  final double incomingRotation;

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
    final hasWhiteFlash = effectSet.contains('whiteFlash');
    final hasOutgoingOffset = effectSet.contains('outgoingOffsetX');
    final hasIncomingOffset = effectSet.contains('incomingOffsetX');
    final hasOutgoingOffsetY = effectSet.contains('outgoingOffsetY');
    final hasIncomingOffsetY = effectSet.contains('incomingOffsetY');
    final hasOutgoingOpacity = effectSet.contains('outgoingOpacity');
    final hasIncomingOpacity = effectSet.contains('incomingOpacity');
    final hasOutgoingRotation = effectSet.contains('outgoingRotation');
    final hasIncomingRotation = effectSet.contains('incomingRotation');
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
    final outgoingFractionalX = hasOutgoingOffset ? outgoingOffsetX : 0.0;
    final incomingFractionalX = hasIncomingOffset ? incomingOffsetX : 0.0;
    final outgoingFractionalY = hasOutgoingOffsetY ? outgoingOffsetY : 0.0;
    final incomingFractionalY = hasIncomingOffsetY ? incomingOffsetY : 0.0;
    final resolvedOutgoingOpacity =
        hasOutgoingOpacity ? outgoingOpacity.clamp(0.0, 1.0).toDouble() : 1.0;
    final resolvedIncomingOpacity =
        hasIncomingOpacity ? incomingOpacity.clamp(0.0, 1.0).toDouble() : null;
    final outgoingRotationRadians =
        hasOutgoingRotation ? outgoingRotation * math.pi / 180.0 : 0.0;
    final incomingRotationRadians =
        hasIncomingRotation ? incomingRotation * math.pi / 180.0 : 0.0;
    final bridgeOpacity = hasBridgeDarkness
        ? (centeredPulse * bridgeDarkness.clamp(0.0, 1.0)).toDouble()
        : 0.0;
    final fadeOpacity =
        hasBlackMix ? blackPeak.clamp(0.0, 1.0).toDouble() : 0.0;
    final flashOpacity =
        hasWhiteFlash ? whiteFlash.clamp(0.0, 1.0).toDouble() : 0.0;
    final autoIncomingOpacity = (hasIncomingScale ||
            hasIncomingOffset ||
            hasIncomingOffsetY ||
            hasIncomingRotation)
        ? Curves.easeOut.transform(incomingPhase)
        : 0.0;
    final effectiveIncomingOpacity =
        resolvedIncomingOpacity ?? autoIncomingOpacity;
    final incomingScale =
        lerpDouble(incomingStartScale, 1.0, incomingPhase) ?? 1.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        if ((hasOutgoingScale ||
                hasOutgoingOffset ||
                hasOutgoingOffsetY ||
                hasOutgoingOpacity ||
                hasOutgoingRotation) &&
            outgoingThumbnailBytes != null)
          Opacity(
            opacity: resolvedOutgoingOpacity,
            child: FractionalTranslation(
              translation: Offset(outgoingFractionalX, outgoingFractionalY),
              child: Transform.rotate(
                angle: outgoingRotationRadians,
                child: Transform.scale(
                  scale: outgoingScale,
                  child: Image.memory(
                    outgoingThumbnailBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
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
        if ((hasIncomingScale ||
                hasIncomingOffset ||
                hasIncomingOffsetY ||
                hasIncomingOpacity ||
                hasIncomingRotation) &&
            incomingThumbnailBytes != null &&
            effectiveIncomingOpacity > 0.001)
          Opacity(
            opacity: effectiveIncomingOpacity.clamp(0.0, 1.0).toDouble(),
            child: FractionalTranslation(
              translation: Offset(incomingFractionalX, incomingFractionalY),
              child: Transform.rotate(
                angle: incomingRotationRadians,
                child: Transform.scale(
                  scale: incomingScale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.18 + (effectiveIncomingOpacity * 0.2),
                          ),
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
            ),
          ),
        if (fadeOpacity > 0.001)
          ColoredBox(
            color: Colors.black.withOpacity(fadeOpacity),
          ),
        if (flashOpacity > 0.001)
          ColoredBox(
            color: Colors.white.withOpacity(flashOpacity),
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
    required this.incomingThumbnailBytes,
  });

  final double progress;
  final Uint8List? incomingThumbnailBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = incomingThumbnailBytes;
    if (bytes == null || bytes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Opacity(
      opacity: progress.clamp(0.0, 1.0).toDouble(),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}

class _WhiteFlashTransitionLayer extends StatelessWidget {
  const _WhiteFlashTransitionLayer({
    required this.opacity,
  });

  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.001) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: Colors.white.withOpacity(opacity.clamp(0.0, 1.0).toDouble()),
    );
  }
}

class _BlurDissolveTransitionLayer extends StatelessWidget {
  const _BlurDissolveTransitionLayer({
    required this.progress,
    required this.outgoingThumbnailBytes,
    required this.incomingThumbnailBytes,
    required this.maxBlur,
  });

  final double progress;
  final Uint8List? outgoingThumbnailBytes;
  final Uint8List? incomingThumbnailBytes;
  final double maxBlur;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final blurPeak =
        (1 - ((clampedProgress - 0.5).abs() / 0.5)).clamp(0.0, 1.0).toDouble();
    final sigma = maxBlur.clamp(0.0, 24.0).toDouble() * blurPeak;
    final incomingOpacity = Curves.easeInOut.transform(clampedProgress);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (outgoingThumbnailBytes != null)
          Opacity(
            opacity: (1 - incomingOpacity).clamp(0.0, 1.0).toDouble(),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: Image.memory(
                outgoingThumbnailBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        if (incomingThumbnailBytes != null)
          Opacity(
            opacity: incomingOpacity.clamp(0.0, 1.0).toDouble(),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: sigma * (1 - incomingOpacity),
                sigmaY: sigma * (1 - incomingOpacity),
              ),
              child: Image.memory(
                incomingThumbnailBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
      ],
    );
  }
}

enum _PushDirection {
  left,
  right,
}

class _PushTransitionLayer extends StatelessWidget {
  const _PushTransitionLayer({
    required this.progress,
    required this.outgoingThumbnailBytes,
    required this.incomingThumbnailBytes,
    required this.distance,
    required this.direction,
    required this.maxBlur,
    required this.flashPeak,
  });

  final double progress;
  final Uint8List? outgoingThumbnailBytes;
  final Uint8List? incomingThumbnailBytes;
  final double distance;
  final _PushDirection direction;
  final double maxBlur;
  final double flashPeak;

  @override
  Widget build(BuildContext context) {
    final sign = direction == _PushDirection.left ? -1.0 : 1.0;
    final resolvedDistance = distance.clamp(0.25, 1.25).toDouble();
    final t = Curves.easeInOut.transform(progress.clamp(0.0, 1.0).toDouble());
    final blurPeak =
        math.sin(progress.clamp(0.0, 1.0).toDouble() * math.pi).abs();
    final sigmaX = maxBlur.clamp(0.0, 32.0).toDouble() * blurPeak;
    final flashOpacity = flashPeak.clamp(0.0, 1.0).toDouble() * blurPeak;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (outgoingThumbnailBytes != null)
          FractionalTranslation(
            translation: Offset(sign * resolvedDistance * t, 0),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: 0),
              child: Image.memory(
                outgoingThumbnailBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        if (incomingThumbnailBytes != null)
          FractionalTranslation(
            translation: Offset(-sign * resolvedDistance * (1 - t), 0),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: 0),
              child: Image.memory(
                incomingThumbnailBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        if (flashOpacity > 0.001)
          ColoredBox(color: Colors.white.withOpacity(flashOpacity)),
      ],
    );
  }
}

class _ZoomOutCameraTransitionLayer extends StatelessWidget {
  const _ZoomOutCameraTransitionLayer({
    required this.progress,
    required this.outgoingThumbnailBytes,
    required this.incomingThumbnailBytes,
    required this.outgoingStartScale,
    required this.incomingStartScale,
    required this.bridgeDarkness,
  });

  final double progress;
  final Uint8List? outgoingThumbnailBytes;
  final Uint8List? incomingThumbnailBytes;
  final double outgoingStartScale;
  final double incomingStartScale;
  final double bridgeDarkness;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(progress.clamp(0.0, 1.0).toDouble());
    final outgoingScale = lerpDouble(outgoingStartScale, 1.0, t) ?? 1.0;
    final incomingScale = lerpDouble(incomingStartScale, 1.0, t) ?? 1.0;
    final incomingOpacity = Curves.easeInOut.transform(t);
    final bridgeOpacity =
        math.sin(t * math.pi).abs() * bridgeDarkness.clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (outgoingThumbnailBytes != null)
          Transform.scale(
            scale: outgoingScale,
            child: Image.memory(
              outgoingThumbnailBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        if (incomingThumbnailBytes != null)
          Opacity(
            opacity: incomingOpacity.clamp(0.0, 1.0).toDouble(),
            child: Transform.scale(
              scale: incomingScale,
              child: Image.memory(
                incomingThumbnailBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        if (bridgeOpacity > 0.001)
          ColoredBox(color: Colors.black.withOpacity(bridgeOpacity)),
      ],
    );
  }
}

class _FlashZoomTransitionLayer extends StatelessWidget {
  const _FlashZoomTransitionLayer({
    required this.progress,
    required this.outgoingThumbnailBytes,
    required this.incomingThumbnailBytes,
    required this.incomingStartScale,
    required this.outgoingBoostScale,
    required this.flashPeak,
    required this.bridgeDarkness,
  });

  final double progress;
  final Uint8List? outgoingThumbnailBytes;
  final Uint8List? incomingThumbnailBytes;
  final double incomingStartScale;
  final double outgoingBoostScale;
  final double flashPeak;
  final double bridgeDarkness;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    final eased = Curves.easeOutCubic.transform(t);
    final pulse = math.sin(t * math.pi).abs();
    final incomingScale = lerpDouble(incomingStartScale, 1.0, eased) ?? 1.0;
    final outgoingScale = lerpDouble(1.0, outgoingBoostScale, eased) ?? 1.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (outgoingThumbnailBytes != null)
          Transform.scale(
            scale: outgoingScale,
            child: Image.memory(
              outgoingThumbnailBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        if (incomingThumbnailBytes != null)
          Opacity(
            opacity: Curves.easeIn.transform(eased).clamp(0.0, 1.0).toDouble(),
            child: Transform.scale(
              scale: incomingScale,
              child: Image.memory(
                incomingThumbnailBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        if (bridgeDarkness > 0)
          ColoredBox(
            color: Colors.black.withOpacity(
              (bridgeDarkness.clamp(0.0, 1.0) * pulse).toDouble(),
            ),
          ),
        if (flashPeak > 0)
          ColoredBox(
            color: Colors.white.withOpacity(
              (flashPeak.clamp(0.0, 1.0) * pulse).toDouble(),
            ),
          ),
      ],
    );
  }
}

class _ZoomInCameraTransitionLayer extends StatelessWidget {
  const _ZoomInCameraTransitionLayer({
    required this.progress,
    required this.outgoingThumbnailBytes,
    required this.incomingThumbnailBytes,
    required this.incomingStartScale,
    required this.outgoingBoostScale,
    required this.entryDelay,
    required this.bridgeDarkness,
  });

  final double progress;
  final Uint8List? outgoingThumbnailBytes;
  final Uint8List? incomingThumbnailBytes;
  final double incomingStartScale;
  final double outgoingBoostScale;
  final double entryDelay;
  final double bridgeDarkness;

  @override
  Widget build(BuildContext context) {
    final entryStart = entryDelay.clamp(0.0, 0.8);
    final incomingProgress = progress <= entryStart
        ? 0.0
        : ((progress - entryStart) / math.max(0.001, 1 - entryStart))
            .clamp(0.0, 1.0);
    final outgoingMaskOpacity = (math.sin(progress * math.pi) * bridgeDarkness)
        .clamp(0.0, 1.0)
        .toDouble();
    final outgoingScale = lerpDouble(1.0, outgoingBoostScale, progress) ?? 1.0;
    final incomingScale =
        lerpDouble(incomingStartScale, 1.0, incomingProgress) ?? 1.0;
    final incomingOpacity =
        Curves.easeOut.transform(incomingProgress).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (outgoingThumbnailBytes != null)
          Transform.scale(
            scale: outgoingScale,
            child: Image.memory(
              outgoingThumbnailBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.92,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(outgoingMaskOpacity * 0.46),
                  Colors.black.withOpacity(outgoingMaskOpacity),
                ],
                stops: const [0.0, 0.72, 1.0],
              ),
            ),
          ),
        ),
        if (incomingThumbnailBytes != null)
          Opacity(
            opacity: incomingOpacity,
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
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(progress * 0.035),
                  Colors.transparent,
                  Colors.black.withOpacity(outgoingMaskOpacity * 0.52),
                ],
              ),
            ),
          ),
        ),
        if (incomingThumbnailBytes == null)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.34),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: const Text(
                'Preview warming',
                style: TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
