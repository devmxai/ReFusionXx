import 'package:flutter/material.dart';

import '../../domain/services/professional_speed_graph_preset_catalog.dart';
import 'professional_speed_graph_preset_card.dart';

class ProfessionalSpeedGraphPresetGrid extends StatelessWidget {
  const ProfessionalSpeedGraphPresetGrid({
    super.key,
    required this.presets,
    required this.selectedPresetId,
    required this.onPresetTap,
    this.onPresetDoubleTap,
    this.onPresetLongPress,
  });

  final List<ProfessionalSpeedGraphPreset> presets;
  final String selectedPresetId;
  final ValueChanged<ProfessionalSpeedGraphPreset> onPresetTap;
  final ValueChanged<ProfessionalSpeedGraphPreset>? onPresetDoubleTap;
  final ValueChanged<ProfessionalSpeedGraphPreset>? onPresetLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.66,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        return ProfessionalSpeedGraphPresetCard(
          preset: preset,
          selected: preset.id == selectedPresetId,
          onTap: () => onPresetTap(preset),
          onDoubleTap: onPresetDoubleTap == null
              ? null
              : () => onPresetDoubleTap!.call(preset),
          onLongPress: onPresetLongPress == null
              ? null
              : () => onPresetLongPress!.call(preset),
        );
      },
    );
  }
}
