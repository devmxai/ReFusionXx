import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/timeline_mock_models.dart';

class TimelineTransitionPreviewOverlay extends StatelessWidget {
  const TimelineTransitionPreviewOverlay({
    super.key,
    required this.transition,
    required this.progress,
    this.incomingThumbnailBytes,
  });

  final TimelineTrackTransitionData transition;
  final double progress;
  final Uint8List? incomingThumbnailBytes;

  @override
  Widget build(BuildContext context) {
    final curvedProgress = _applyCurve(progress, transition.curve);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (transition.preset == TimelineTransitionPreset.manual &&
              transition.manualEffectIds.isNotEmpty)
            _ManualTransitionLayer(
              progress: curvedProgress,
              incomingThumbnailBytes: incomingThumbnailBytes,
              incomingStartScale: transition
                  .parameterValue('incomingStartScale', fallback: 1.0),
              outgoingBoostScale: transition
                  .parameterValue('outgoingBoostScale', fallback: 1.0),
              entryDelay:
                  transition.parameterValue('entryDelay', fallback: 0.0),
              bridgeDarkness:
                  transition.parameterValue('bridgeDarkness', fallback: 0.0),
              blackPeak: transition.parameterValue('blackPeak', fallback: 0.0),
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
              incomingThumbnailBytes: incomingThumbnailBytes,
            ),
          if (transition.preset == TimelineTransitionPreset.zoomInCamera)
            _ZoomInCameraTransitionLayer(
              progress: curvedProgress,
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
        ],
      ),
    );
  }

  double _fadeBlackOpacity(double t, double peak) {
    final triangular = 1 - ((t - 0.5).abs() / 0.5);
    return (triangular.clamp(0.0, 1.0) * peak.clamp(0.0, 1.0)).toDouble();
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
    required this.incomingThumbnailBytes,
    required this.incomingStartScale,
    required this.outgoingBoostScale,
    required this.entryDelay,
    required this.bridgeDarkness,
    required this.blackPeak,
  });

  final double progress;
  final Uint8List? incomingThumbnailBytes;
  final double incomingStartScale;
  final double outgoingBoostScale;
  final double entryDelay;
  final double bridgeDarkness;
  final double blackPeak;

  @override
  Widget build(BuildContext context) {
    final fadeOpacity =
        (1 - ((progress - 0.5).abs() / 0.5)).clamp(0.0, 1.0).toDouble() *
            blackPeak.clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        _ZoomInCameraTransitionLayer(
          progress: progress,
          incomingThumbnailBytes: incomingThumbnailBytes,
          incomingStartScale: incomingStartScale,
          outgoingBoostScale: outgoingBoostScale,
          entryDelay: entryDelay,
          bridgeDarkness: bridgeDarkness,
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

class _ZoomInCameraTransitionLayer extends StatelessWidget {
  const _ZoomInCameraTransitionLayer({
    required this.progress,
    required this.incomingThumbnailBytes,
    required this.incomingStartScale,
    required this.outgoingBoostScale,
    required this.entryDelay,
    required this.bridgeDarkness,
  });

  final double progress;
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
        Transform.scale(
          scale: outgoingScale,
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
