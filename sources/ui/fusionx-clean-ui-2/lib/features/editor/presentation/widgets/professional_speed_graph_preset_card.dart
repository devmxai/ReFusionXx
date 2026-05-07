import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_interpolation_evaluator.dart';
import '../../domain/services/motion_interpolation_truth_compiler.dart';
import '../../domain/services/professional_speed_graph_preset_catalog.dart';

class ProfessionalSpeedGraphPresetCard extends StatefulWidget {
  const ProfessionalSpeedGraphPresetCard({
    super.key,
    required this.preset,
    required this.selected,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  final ProfessionalSpeedGraphPreset preset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  @override
  State<ProfessionalSpeedGraphPresetCard> createState() =>
      _ProfessionalSpeedGraphPresetCardState();
}

class _ProfessionalSpeedGraphPresetCardState
    extends State<ProfessionalSpeedGraphPresetCard>
    with SingleTickerProviderStateMixin {
  static const MotionInterpolationTruthCompiler _truthCompiler =
      MotionInterpolationTruthCompiler();
  late final AnimationController _previewController;
  late MotionInterpolationSpec _interpolation;
  late String _curveHash;

  @override
  void initState() {
    super.initState();
    _previewController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    _resolveInterpolation();
  }

  @override
  void didUpdateWidget(covariant ProfessionalSpeedGraphPresetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset.id != widget.preset.id ||
        oldWidget.preset.bezier != widget.preset.bezier) {
      _resolveInterpolation();
    }
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  void _resolveInterpolation() {
    if (widget.preset.linear) {
      _interpolation = const MotionInterpolationSpec.linear();
    } else {
      _interpolation = MotionInterpolationSpec.cubicBezier(
        bezier: widget.preset.bezier,
      );
    }
    final compiled = _truthCompiler.compileFromInterpolation(
      interpolation: _interpolation,
      inputMode: MotionInterpolationCompileInputMode.existingSpec,
    );
    _curveHash = compiled.curveHash;
  }

  List<double> _sampledCurve() {
    return ProfessionalSpeedGraphThumbnailSampler.sampleCurve(
      curveHash: _curveHash,
      interpolation: _interpolation,
      sampleCount: 40,
    );
  }

  @override
  Widget build(BuildContext context) {
    final samples = _sampledCurve();
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: () {
        _previewController
          ..stop()
          ..value = 0
          ..forward();
        widget.onLongPress?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised
              .withOpacity(widget.selected ? 0.95 : 0.74),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.selected
                ? FxPalette.accent.withOpacity(0.8)
                : Colors.white.withOpacity(0.09),
            width: widget.selected ? 1.4 : 1,
          ),
          boxShadow: widget.selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: FxPalette.accent.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 0.4,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              width: double.infinity,
              child: CustomPaint(
                painter: _PresetThumbnailPainter(
                  preset: widget.preset,
                  samples: samples,
                  previewProgress: _previewController.value,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.preset.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.preset.arabicDisplayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: FxPalette.textFaint.withOpacity(0.94),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfessionalSpeedGraphThumbnailSampler {
  const ProfessionalSpeedGraphThumbnailSampler._();

  static final Map<String, List<double>> _cache = <String, List<double>>{};

  static List<double> sampleCurve({
    required String curveHash,
    required MotionInterpolationSpec interpolation,
    required int sampleCount,
  }) {
    final key = '$curveHash#$sampleCount';
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    final samples = <double>[];
    for (var index = 0; index <= sampleCount; index++) {
      final t = sampleCount <= 0 ? 0.0 : index / sampleCount;
      samples.add(evaluateMotionCurveProgress(interpolation, t));
    }
    final frozen = List<double>.unmodifiable(samples);
    _cache[key] = frozen;
    return frozen;
  }

  static int get cacheSize => _cache.length;
}

class _PresetThumbnailPainter extends CustomPainter {
  const _PresetThumbnailPainter({
    required this.preset,
    required this.samples,
    required this.previewProgress,
  });

  final ProfessionalSpeedGraphPreset preset;
  final List<double> samples;
  final double previewProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()..color = const Color(0xFF0E0E10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      background,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A2E)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 5; i++) {
      final x = size.width * (i / 5);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final path = Path();
    for (var index = 0; index < samples.length; index++) {
      final t = samples.length <= 1 ? 0.0 : index / (samples.length - 1);
      final x = 2 + ((size.width - 4) * t);
      final y = size.height - 2 - ((size.height - 4) * samples[index]);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final p0 = Offset(2, size.height - 2);
    final p1 = Offset(
      size.width * preset.bezier.x1,
      size.height * (1 - preset.bezier.y1),
    );
    final p2 = Offset(
      size.width * preset.bezier.x2,
      size.height * (1 - preset.bezier.y2),
    );
    final p3 = Offset(size.width - 2, 2);

    final handlePaint = Paint()
      ..color = const Color(0xFF24E574).withOpacity(0.75)
      ..strokeWidth = 1.2;
    canvas.drawLine(p0, p1, handlePaint);
    canvas.drawLine(p3, p2, handlePaint);
    canvas.drawCircle(p1, 2.1, Paint()..color = const Color(0xFF24E574));
    canvas.drawCircle(p2, 2.1, Paint()..color = const Color(0xFF24E574));

    final curvePaint = Paint()
      ..color = const Color(0xFF4DA3FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, curvePaint);

    if (previewProgress > 0) {
      final t = previewProgress.clamp(0.0, 1.0);
      final samplePos = ((samples.length - 1) * t).round().clamp(
            0,
            samples.length - 1,
          );
      final yProgress = samples[samplePos];
      final dot = Offset(
        2 + ((size.width - 4) * t),
        size.height - 2 - ((size.height - 4) * yProgress),
      );
      canvas.drawCircle(
        dot,
        3.2,
        Paint()..color = const Color(0xFF24E574),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PresetThumbnailPainter oldDelegate) {
    return oldDelegate.preset.id != preset.id ||
        oldDelegate.preset.bezier != preset.bezier ||
        oldDelegate.previewProgress != previewProgress ||
        oldDelegate.samples.length != samples.length;
  }
}
