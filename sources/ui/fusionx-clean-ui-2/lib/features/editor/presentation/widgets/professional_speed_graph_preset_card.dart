import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/services/professional_speed_graph_preset_catalog.dart';

class ProfessionalSpeedGraphPresetCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised.withOpacity(selected ? 0.95 : 0.74),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? FxPalette.accent.withOpacity(0.8)
                : Colors.white.withOpacity(0.09),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
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
                painter: _PresetThumbnailPainter(preset: preset),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              preset.displayName,
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
              preset.arabicDisplayName,
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

class _PresetThumbnailPainter extends CustomPainter {
  const _PresetThumbnailPainter({required this.preset});

  final ProfessionalSpeedGraphPreset preset;

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

    final p0 = Offset(2, size.height - 2);
    final p1 = Offset(
        size.width * preset.bezier.x1, size.height * (1 - preset.bezier.y1));
    final p2 = Offset(
        size.width * preset.bezier.x2, size.height * (1 - preset.bezier.y2));
    final p3 = Offset(size.width - 2, 2);

    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

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
  }

  @override
  bool shouldRepaint(covariant _PresetThumbnailPainter oldDelegate) {
    return oldDelegate.preset.id != preset.id ||
        oldDelegate.preset.bezier != preset.bezier;
  }
}
