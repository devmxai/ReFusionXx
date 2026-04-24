import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class LayerScopeGraphBottomSheet extends StatefulWidget {
  const LayerScopeGraphBottomSheet({
    super.key,
    required this.easyEaseEnabled,
    required this.onEasyEaseChanged,
    required this.onDone,
  });

  final bool easyEaseEnabled;
  final ValueChanged<bool> onEasyEaseChanged;
  final VoidCallback onDone;

  @override
  State<LayerScopeGraphBottomSheet> createState() =>
      _LayerScopeGraphBottomSheetState();
}

class _LayerScopeGraphBottomSheetState
    extends State<LayerScopeGraphBottomSheet> {
  late bool _easyEaseEnabled;

  @override
  void initState() {
    super.initState();
    _easyEaseEnabled = widget.easyEaseEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.30).clamp(220.0, 280.0);
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
                    const SizedBox(height: 12),
                    _GraphActionCard(
                      icon: Icons.auto_graph_rounded,
                      label: 'Easy Ease',
                      detail: 'F9-style smooth in and out',
                      isActive: _easyEaseEnabled,
                      onTap: () {
                        final nextValue = !_easyEaseEnabled;
                        setState(() {
                          _easyEaseEnabled = nextValue;
                        });
                        widget.onEasyEaseChanged(nextValue);
                      },
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
}

class _GraphActionCard extends StatelessWidget {
  const _GraphActionCard({
    required this.icon,
    required this.label,
    required this.detail,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: isActive
              ? FxPalette.surfaceRaised.withOpacity(0.98)
              : FxPalette.surfaceRaised.withOpacity(0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? FxPalette.accent.withOpacity(0.65)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive
                    ? FxPalette.accent.withOpacity(0.16)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isActive ? FxPalette.accent : FxPalette.textPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: FxPalette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: FxPalette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isActive
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isActive ? FxPalette.accent : FxPalette.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
