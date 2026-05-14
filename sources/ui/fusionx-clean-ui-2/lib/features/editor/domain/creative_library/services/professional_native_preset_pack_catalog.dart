import '../models/professional_creative_library_registry_models.dart';
import 'professional_creative_library_registry.dart';

class NativePresetControl {
  const NativePresetControl({
    required this.id,
    required this.label,
    required this.type,
    required this.defaultValue,
  });

  final String id;
  final String label;
  final String type;
  final Object defaultValue;
}

class NativePresetDefinition {
  const NativePresetDefinition({
    required this.id,
    required this.title,
    required this.componentCapabilityId,
    required this.effectCapabilityId,
    required this.motionCapabilityId,
    required this.controls,
  });

  final String id;
  final String title;
  final String componentCapabilityId;
  final String effectCapabilityId;
  final String motionCapabilityId;
  final List<NativePresetControl> controls;
}

class NativePresetValidationResult {
  const NativePresetValidationResult({
    required this.ok,
    required this.presetId,
    this.blockerCode,
    this.blockerReason,
  });

  final bool ok;
  final String presetId;
  final String? blockerCode;
  final String? blockerReason;
}

class ProfessionalNativePresetPackCatalog {
  const ProfessionalNativePresetPackCatalog();

  List<NativePresetDefinition> buildWithRegistry(
    ProfessionalCreativeLibraryRegistry registry,
  ) {
    final component = _firstId(registry, CreativeLibraryItemKind.component);
    final effect = _firstId(registry, CreativeLibraryItemKind.effect);
    final motion = _firstId(registry, CreativeLibraryItemKind.motionRecipe);
    if (component == null || effect == null || motion == null) {
      return const <NativePresetDefinition>[];
    }
    return <NativePresetDefinition>[
      NativePresetDefinition(
        id: 'preset.native.hero_pop',
        title: 'Hero Pop',
        componentCapabilityId: component,
        effectCapabilityId: effect,
        motionCapabilityId: motion,
        controls: const <NativePresetControl>[
          NativePresetControl(
            id: 'headline',
            label: 'Headline',
            type: 'string',
            defaultValue: 'Welcome',
          ),
          NativePresetControl(
            id: 'accentColor',
            label: 'Accent Color',
            type: 'color',
            defaultValue: '#7C3AED',
          ),
          NativePresetControl(
            id: 'durationMs',
            label: 'Duration',
            type: 'number',
            defaultValue: 900,
          ),
        ],
      ),
      NativePresetDefinition(
        id: 'preset.native.product_focus',
        title: 'Product Focus',
        componentCapabilityId: component,
        effectCapabilityId: effect,
        motionCapabilityId: motion,
        controls: const <NativePresetControl>[
          NativePresetControl(
            id: 'title',
            label: 'Title',
            type: 'string',
            defaultValue: 'New Product',
          ),
          NativePresetControl(
            id: 'cta',
            label: 'CTA',
            type: 'string',
            defaultValue: 'Learn More',
          ),
          NativePresetControl(
            id: 'intensity',
            label: 'Motion Intensity',
            type: 'number',
            defaultValue: 0.7,
          ),
        ],
      ),
    ];
  }

  NativePresetValidationResult validatePreset(
    NativePresetDefinition preset,
    ProfessionalCreativeLibraryRegistry registry,
  ) {
    final component = registry.describe(preset.componentCapabilityId);
    if (component == null ||
        component.kind != CreativeLibraryItemKind.component) {
      return NativePresetValidationResult(
        ok: false,
        presetId: preset.id,
        blockerCode: 'PRESET_COMPONENT_CAPABILITY_INVALID',
        blockerReason:
            'Preset `${preset.id}` references invalid component capability.',
      );
    }
    final effect = registry.describe(preset.effectCapabilityId);
    if (effect == null || effect.kind != CreativeLibraryItemKind.effect) {
      return NativePresetValidationResult(
        ok: false,
        presetId: preset.id,
        blockerCode: 'PRESET_EFFECT_CAPABILITY_INVALID',
        blockerReason:
            'Preset `${preset.id}` references invalid effect capability.',
      );
    }
    final motion = registry.describe(preset.motionCapabilityId);
    if (motion == null || motion.kind != CreativeLibraryItemKind.motionRecipe) {
      return NativePresetValidationResult(
        ok: false,
        presetId: preset.id,
        blockerCode: 'PRESET_MOTION_CAPABILITY_INVALID',
        blockerReason:
            'Preset `${preset.id}` references invalid motion capability.',
      );
    }
    if (preset.controls.isEmpty) {
      return NativePresetValidationResult(
        ok: false,
        presetId: preset.id,
        blockerCode: 'PRESET_EXPOSED_CONTROLS_REQUIRED',
        blockerReason: 'Preset `${preset.id}` must expose controls.',
      );
    }
    return NativePresetValidationResult(
      ok: true,
      presetId: preset.id,
    );
  }

  String? _firstId(
    ProfessionalCreativeLibraryRegistry registry,
    CreativeLibraryItemKind kind,
  ) {
    final values = registry.listByKind(kind);
    if (values.isEmpty) {
      return null;
    }
    return values.first.id;
  }
}
