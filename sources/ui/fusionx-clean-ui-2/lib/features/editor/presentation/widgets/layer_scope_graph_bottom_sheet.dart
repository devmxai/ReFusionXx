import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_motion_animation_models.dart';

enum LayerScopeGraphMode {
  value,
  speed,
}

enum LayerScopeGraphSpeedPreset {
  linear,
  easyEase,
  easeIn,
  easeOut,
  slowFastSlow,
  fastSlow,
  slowFast,
  whip,
  custom,
}

typedef GraphVelocityChanged = void Function(
  MotionKeyframeVelocity velocity, {
  required String editType,
});

class LayerScopeGraphBottomSheet extends StatefulWidget {
  const LayerScopeGraphBottomSheet({
    super.key,
    required this.easyEaseEnabled,
    required this.onEasyEaseChanged,
    this.initialMode = LayerScopeGraphMode.speed,
    this.selectedPreset = LayerScopeGraphSpeedPreset.easyEase,
    this.initialVelocity,
    this.onModeChanged,
    this.onPresetSelected,
    this.onVelocityChanged,
    required this.onDone,
  });

  final bool easyEaseEnabled;
  final ValueChanged<bool> onEasyEaseChanged;
  final LayerScopeGraphMode initialMode;
  final LayerScopeGraphSpeedPreset selectedPreset;
  final MotionKeyframeVelocity? initialVelocity;
  final ValueChanged<LayerScopeGraphMode>? onModeChanged;
  final ValueChanged<LayerScopeGraphSpeedPreset>? onPresetSelected;
  final GraphVelocityChanged? onVelocityChanged;
  final VoidCallback onDone;

  @override
  State<LayerScopeGraphBottomSheet> createState() =>
      _LayerScopeGraphBottomSheetState();
}

class _LayerScopeGraphBottomSheetState
    extends State<LayerScopeGraphBottomSheet> {
  late bool _easyEaseEnabled;
  late LayerScopeGraphMode _mode;
  late LayerScopeGraphSpeedPreset _selectedPreset;
  late MotionKeyframeVelocity _velocity;
  _GraphHandleDragTarget? _activeHandle;

  @override
  void initState() {
    super.initState();
    _easyEaseEnabled = widget.easyEaseEnabled;
    _mode = widget.initialMode;
    _selectedPreset = widget.selectedPreset;
    _velocity = widget.initialVelocity ??
        _velocityForPreset(widget.selectedPreset).copyWith(
          incomingHandleLocked: true,
          outgoingHandleLocked: true,
          continuous: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.62).clamp(420.0, 560.0);
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: sheetHeight,
            decoration: BoxDecoration(
              color: FxPalette.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              border: Border.all(color: FxPalette.divider, width: 1),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  10,
                  14,
                  (safeBottom > 0 ? safeBottom : 12) + 8,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 36),
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: FxPalette.textFaint,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onDone,
                          icon: const Icon(
                            Icons.check_rounded,
                            color: FxPalette.textPrimary,
                            size: 20,
                          ),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _GraphModeSelector(
                      mode: _mode,
                      onChanged: (nextMode) {
                        setState(() {
                          _mode = nextMode;
                        });
                        widget.onModeChanged?.call(nextMode);
                      },
                    ),
                    const SizedBox(height: 10),
                    _GraphToolbar(
                      velocity: _velocity,
                      onContinuousChanged: (value) {
                        final next = _velocity.copyWith(
                          continuous: value,
                          incomingHandleLocked: value,
                          outgoingHandleLocked: value,
                          presetId: 'customSpeedGraph',
                        );
                        setState(() {
                          _selectedPreset = LayerScopeGraphSpeedPreset.custom;
                          _velocity = next;
                        });
                        widget.onVelocityChanged?.call(
                          next,
                          editType: 'toggleContinuous',
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasRect = Rect.fromLTWH(
                            0,
                            0,
                            constraints.maxWidth,
                            math.max(160, constraints.maxHeight - 72),
                          );
                          final incoming = _incomingHandlePosition(canvasRect);
                          final outgoing = _outgoingHandlePosition(canvasRect);
                          return Column(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (details) {
                                    _activeHandle = _resolveHandle(
                                      details.localPosition,
                                      incoming: incoming,
                                      outgoing: outgoing,
                                    );
                                  },
                                  onPanUpdate: (details) {
                                    if (_activeHandle == null) {
                                      return;
                                    }
                                    final editType = _activeHandle ==
                                            _GraphHandleDragTarget.incoming
                                        ? 'dragIncoming'
                                        : _activeHandle ==
                                                _GraphHandleDragTarget.outgoing
                                            ? 'dragOutgoing'
                                            : 'dragBoth';
                                    final next = _velocityFromDrag(
                                      details.localPosition,
                                      canvasRect,
                                      target: _activeHandle!,
                                    );
                                    setState(() {
                                      _selectedPreset =
                                          LayerScopeGraphSpeedPreset.custom;
                                      _velocity = next.copyWith(
                                        presetId: 'customSpeedGraph',
                                      );
                                    });
                                    widget.onVelocityChanged?.call(
                                      _velocity,
                                      editType: editType,
                                    );
                                  },
                                  onPanEnd: (_) => _activeHandle = null,
                                  child: CustomPaint(
                                    painter: _SpeedGraphPainter(
                                      mode: _mode,
                                      velocity: _velocity,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _VelocityReadout(velocity: _velocity),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 92,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final preset in LayerScopeGraphSpeedPreset.values)
                              _PresetChip(
                                preset: preset,
                                isSelected: _selectedPreset == preset,
                                onTap: () {
                                  final nextVelocity = _velocityForPreset(preset);
                                  setState(() {
                                    _selectedPreset = preset;
                                    _velocity = nextVelocity;
                                    _easyEaseEnabled =
                                        preset != LayerScopeGraphSpeedPreset.linear;
                                  });
                                  widget.onEasyEaseChanged(_easyEaseEnabled);
                                  widget.onPresetSelected?.call(preset);
                                  widget.onVelocityChanged?.call(
                                    nextVelocity,
                                    editType: 'preset',
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _incomingHandlePosition(Rect canvasRect) {
    final influence = (_velocity.incomingInfluence ?? 33.333).clamp(0.0, 100.0);
    final speed = (_velocity.incomingSpeed ?? 0.0).abs().clamp(0.0, 200.0);
    final x = canvasRect.left + canvasRect.width * (0.5 - (influence / 200.0));
    final y = canvasRect.bottom - canvasRect.height * (speed / 220.0);
    return Offset(x, y);
  }

  Offset _outgoingHandlePosition(Rect canvasRect) {
    final influence = (_velocity.outgoingInfluence ?? 33.333).clamp(0.0, 100.0);
    final speed = (_velocity.outgoingSpeed ?? 0.0).abs().clamp(0.0, 200.0);
    final x = canvasRect.left + canvasRect.width * (0.5 + (influence / 200.0));
    final y = canvasRect.bottom - canvasRect.height * (speed / 220.0);
    return Offset(x, y);
  }

  _GraphHandleDragTarget _resolveHandle(
    Offset position, {
    required Offset incoming,
    required Offset outgoing,
  }) {
    final incomingDistance = (position - incoming).distance;
    final outgoingDistance = (position - outgoing).distance;
    if (_velocity.continuous) {
      return _GraphHandleDragTarget.both;
    }
    return incomingDistance <= outgoingDistance
        ? _GraphHandleDragTarget.incoming
        : _GraphHandleDragTarget.outgoing;
  }

  MotionKeyframeVelocity _velocityFromDrag(
    Offset position,
    Rect canvasRect, {
    required _GraphHandleDragTarget target,
  }) {
    final clampedX =
        ((position.dx - canvasRect.left) / canvasRect.width).clamp(0.0, 1.0);
    final clampedY =
        ((position.dy - canvasRect.top) / canvasRect.height).clamp(0.0, 1.0);
    final influenceFromCenter = ((clampedX - 0.5).abs() * 200.0).clamp(0.0, 100.0);
    final speed = ((1.0 - clampedY) * 220.0).clamp(0.0, 220.0);
    if (target == _GraphHandleDragTarget.both) {
      return _velocity.copyWith(
        incomingInfluence: influenceFromCenter,
        outgoingInfluence: influenceFromCenter,
        incomingSpeed: speed,
        outgoingSpeed: speed,
      );
    }
    if (target == _GraphHandleDragTarget.incoming) {
      return _velocity.copyWith(
        incomingInfluence: influenceFromCenter,
        incomingSpeed: speed,
      );
    }
    return _velocity.copyWith(
      outgoingInfluence: influenceFromCenter,
      outgoingSpeed: speed,
    );
  }

  MotionKeyframeVelocity _velocityForPreset(LayerScopeGraphSpeedPreset preset) {
    switch (preset) {
      case LayerScopeGraphSpeedPreset.linear:
        return const MotionKeyframeVelocity(
          incomingSpeed: 0.0,
          outgoingSpeed: 0.0,
          incomingInfluence: 0.0,
          outgoingInfluence: 0.0,
          incomingHandleLocked: true,
          outgoingHandleLocked: true,
          continuous: true,
          presetId: 'linear',
        );
      case LayerScopeGraphSpeedPreset.easyEase:
        return const MotionKeyframeVelocity(
          incomingSpeed: 0.0,
          outgoingSpeed: 0.0,
          incomingInfluence: 33.333,
          outgoingInfluence: 33.333,
          incomingHandleLocked: true,
          outgoingHandleLocked: true,
          continuous: true,
          presetId: 'easyEase',
        );
      case LayerScopeGraphSpeedPreset.easeIn:
        return const MotionKeyframeVelocity(
          incomingSpeed: 0.0,
          incomingInfluence: 33.333,
          incomingHandleLocked: true,
          outgoingHandleLocked: false,
          continuous: false,
          presetId: 'easyEaseIn',
        );
      case LayerScopeGraphSpeedPreset.easeOut:
        return const MotionKeyframeVelocity(
          outgoingSpeed: 0.0,
          outgoingInfluence: 33.333,
          incomingHandleLocked: false,
          outgoingHandleLocked: true,
          continuous: false,
          presetId: 'easyEaseOut',
        );
      case LayerScopeGraphSpeedPreset.slowFastSlow:
        return const MotionKeyframeVelocity(
          incomingSpeed: 0.0,
          outgoingSpeed: 0.0,
          incomingInfluence: 85.0,
          outgoingInfluence: 85.0,
          incomingHandleLocked: true,
          outgoingHandleLocked: true,
          continuous: true,
          presetId: 'slowFastSlow',
        );
      case LayerScopeGraphSpeedPreset.fastSlow:
        return const MotionKeyframeVelocity(
          incomingSpeed: 70.0,
          outgoingSpeed: 20.0,
          incomingInfluence: 15.0,
          outgoingInfluence: 75.0,
          continuous: false,
          presetId: 'fastSlow',
        );
      case LayerScopeGraphSpeedPreset.slowFast:
        return const MotionKeyframeVelocity(
          incomingSpeed: 20.0,
          outgoingSpeed: 70.0,
          incomingInfluence: 75.0,
          outgoingInfluence: 15.0,
          continuous: false,
          presetId: 'slowFast',
        );
      case LayerScopeGraphSpeedPreset.whip:
        return const MotionKeyframeVelocity(
          incomingSpeed: 30.0,
          outgoingSpeed: 120.0,
          incomingInfluence: 10.0,
          outgoingInfluence: 95.0,
          continuous: false,
          presetId: 'whipSnap',
        );
      case LayerScopeGraphSpeedPreset.custom:
        return _velocity.copyWith(presetId: 'customSpeedGraph');
    }
  }
}

class _GraphModeSelector extends StatelessWidget {
  const _GraphModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final LayerScopeGraphMode mode;
  final ValueChanged<LayerScopeGraphMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModePill(
            label: 'Value Graph',
            isSelected: mode == LayerScopeGraphMode.value,
            onTap: () => onChanged(LayerScopeGraphMode.value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModePill(
            label: 'Speed Graph',
            isSelected: mode == LayerScopeGraphMode.speed,
            onTap: () => onChanged(LayerScopeGraphMode.speed),
          ),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? FxPalette.accent.withOpacity(0.16)
              : FxPalette.surfaceRaised.withOpacity(0.72),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? FxPalette.accent.withOpacity(0.65)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? FxPalette.accent : FxPalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GraphToolbar extends StatelessWidget {
  const _GraphToolbar({
    required this.velocity,
    required this.onContinuousChanged,
  });

  final MotionKeyframeVelocity velocity;
  final ValueChanged<bool> onContinuousChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Continuous',
          style: TextStyle(
            color: FxPalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: velocity.continuous,
          onChanged: onContinuousChanged,
          activeColor: FxPalette.accent,
        ),
        const Spacer(),
        const Text(
          'Selected Keyframe',
          style: TextStyle(
            color: FxPalette.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SpeedGraphPainter extends CustomPainter {
  const _SpeedGraphPainter({
    required this.mode,
    required this.velocity,
  });

  final LayerScopeGraphMode mode;
  final MotionKeyframeVelocity velocity;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white.withOpacity(0.03);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(14),
      ),
      bg,
    );

    final grid = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 1; i < 6; i++) {
      final x = size.width * (i / 6);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    final centerX = size.width * 0.5;
    final selectedPaint = Paint()
      ..color = FxPalette.accent.withOpacity(0.6)
      ..strokeWidth = 1.8;
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), selectedPaint);

    final playheadPaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..strokeWidth = 1.2;
    final playheadX = size.width * 0.57;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );

    final incomingInfluence = (velocity.incomingInfluence ?? 33.333).clamp(0.0, 100.0);
    final outgoingInfluence = (velocity.outgoingInfluence ?? 33.333).clamp(0.0, 100.0);
    final incomingSpeed = (velocity.incomingSpeed ?? 0.0).abs().clamp(0.0, 220.0);
    final outgoingSpeed = (velocity.outgoingSpeed ?? 0.0).abs().clamp(0.0, 220.0);
    final incomingX = size.width * (0.5 - incomingInfluence / 200.0);
    final outgoingX = size.width * (0.5 + outgoingInfluence / 200.0);
    final incomingY = size.height * (1.0 - incomingSpeed / 220.0);
    final outgoingY = size.height * (1.0 - outgoingSpeed / 220.0);

    final path = Path()
      ..moveTo(incomingX, incomingY)
      ..quadraticBezierTo(centerX, size.height * 0.5, outgoingX, outgoingY);
    final curvePaint = Paint()
      ..color = mode == LayerScopeGraphMode.speed
          ? FxPalette.accent
          : Colors.orangeAccent.withOpacity(0.95)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, curvePaint);

    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(centerX, size.height * 0.5), Offset(incomingX, incomingY), guidePaint);
    canvas.drawLine(Offset(centerX, size.height * 0.5), Offset(outgoingX, outgoingY), guidePaint);

    final inHandlePaint = Paint()..color = Colors.cyanAccent;
    final outHandlePaint = Paint()..color = Colors.pinkAccent;
    canvas.drawCircle(Offset(incomingX, incomingY), 7, inHandlePaint);
    canvas.drawCircle(Offset(outgoingX, outgoingY), 7, outHandlePaint);
    canvas.drawCircle(
      Offset(centerX, size.height * 0.5),
      5.5,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedGraphPainter oldDelegate) {
    return oldDelegate.mode != mode || oldDelegate.velocity != velocity;
  }
}

class _VelocityReadout extends StatelessWidget {
  const _VelocityReadout({
    required this.velocity,
  });

  final MotionKeyframeVelocity velocity;

  @override
  Widget build(BuildContext context) {
    String fmt(double? value) =>
        value == null ? '0.0' : value.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.74),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'In ${fmt(velocity.incomingSpeed)} | ${fmt(velocity.incomingInfluence)}%',
              style: const TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Out ${fmt(velocity.outgoingSpeed)} | ${fmt(velocity.outgoingInfluence)}%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final LayerScopeGraphSpeedPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? FxPalette.accent.withOpacity(0.16)
              : FxPalette.surfaceRaised.withOpacity(0.72),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? FxPalette.accent.withOpacity(0.65)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          _labelForPreset(preset),
          style: TextStyle(
            color: isSelected ? FxPalette.accent : FxPalette.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static String _labelForPreset(LayerScopeGraphSpeedPreset preset) {
    switch (preset) {
      case LayerScopeGraphSpeedPreset.linear:
        return 'Linear';
      case LayerScopeGraphSpeedPreset.easyEase:
        return 'Easy Ease';
      case LayerScopeGraphSpeedPreset.easeIn:
        return 'Ease In';
      case LayerScopeGraphSpeedPreset.easeOut:
        return 'Ease Out';
      case LayerScopeGraphSpeedPreset.slowFastSlow:
        return 'Slow-Fast-Slow';
      case LayerScopeGraphSpeedPreset.fastSlow:
        return 'Fast-Slow';
      case LayerScopeGraphSpeedPreset.slowFast:
        return 'Slow-Fast';
      case LayerScopeGraphSpeedPreset.whip:
        return 'Whip';
      case LayerScopeGraphSpeedPreset.custom:
        return 'Custom';
    }
  }
}

enum _GraphHandleDragTarget {
  incoming,
  outgoing,
  both,
}
