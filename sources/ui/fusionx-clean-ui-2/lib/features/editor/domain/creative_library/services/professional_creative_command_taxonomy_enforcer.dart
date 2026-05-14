import '../models/professional_creative_library_registry_models.dart';

class CreativeCommandTaxonomyValidationResult {
  const CreativeCommandTaxonomyValidationResult({
    required this.ok,
    this.blockerCode,
    this.blockerReason,
  });

  final bool ok;
  final String? blockerCode;
  final String? blockerReason;
}

class ProfessionalCreativeCommandTaxonomyEnforcer {
  const ProfessionalCreativeCommandTaxonomyEnforcer();

  CreativeCommandTaxonomyValidationResult validate({
    required String commandName,
    required CommandFamilyDefinition commandFamily,
    required Map<String, Object?> payload,
  }) {
    final hasUpdateIntent = _hasAnyKey(payload, _updateIntentKeys) ||
        _hasOperation(payload, const <String>{
          'update',
          'update_layer',
          'update_component',
          'set_text_style',
          'animate_layer',
        });
    final hasMotionMetadata = _hasAnyKey(payload, _motionKeys) ||
        _hasOperation(payload, const <String>{
          'motion',
          'animate',
          'keyframe',
          'apply_motion_patch',
        });
    final hasEffectMetadata = _hasAnyKey(payload, _effectKeys);

    switch (commandFamily) {
      case CommandFamilyDefinition.insertComponent:
        if (hasUpdateIntent || hasMotionMetadata || hasEffectMetadata) {
          return CreativeCommandTaxonomyValidationResult(
            ok: false,
            blockerCode: 'INSERT_USED_FOR_UPDATE',
            blockerReason:
                '`$commandName` used insert path with update/effect/motion payload. Use update/effect/motion command family explicitly.',
          );
        }
        break;
      case CommandFamilyDefinition.updateComponent:
        if (hasMotionMetadata) {
          return const CreativeCommandTaxonomyValidationResult(
            ok: false,
            blockerCode: 'UPDATE_COMMAND_CANNOT_CONTAIN_MOTION_METADATA',
            blockerReason:
                'Update command cannot carry motion metadata. Use apply_motion_recipe/apply_keyframes.',
          );
        }
        break;
      case CommandFamilyDefinition.applyEffect:
        if (hasMotionMetadata) {
          return const CreativeCommandTaxonomyValidationResult(
            ok: false,
            blockerCode: 'MOTION_METADATA_NOT_ALLOWED_IN_EFFECT_COMMAND',
            blockerReason:
                'Effect command cannot carry motion payload. Use apply_motion_recipe or keyframe command families.',
          );
        }
        break;
      case CommandFamilyDefinition.applyMotionRecipe:
      case CommandFamilyDefinition.applyKeyframes:
      case CommandFamilyDefinition.editKeyframe:
        if (hasEffectMetadata) {
          return const CreativeCommandTaxonomyValidationResult(
            ok: false,
            blockerCode: 'EFFECT_METADATA_NOT_ALLOWED_IN_MOTION_COMMAND',
            blockerReason:
                'Motion command cannot carry effect metadata. Use apply_effect/update_effect command families.',
          );
        }
        break;
      default:
        break;
    }

    return const CreativeCommandTaxonomyValidationResult(ok: true);
  }

  static const Set<String> _updateIntentKeys = <String>{
    'layerid',
    'targetlayerid',
    'targetid',
    'stylepatch',
    'updates',
  };
  static const Set<String> _motionKeys = <String>{
    'motion',
    'animation',
    'keyframes',
    'motionchannels',
    'motionrecipe',
  };
  static const Set<String> _effectKeys = <String>{
    'effect',
    'effectid',
    'effectinstance',
    'border',
    'glow',
    'shadow',
    'mask',
    'clipath',
    'clip_path',
  };

  bool _hasOperation(Map<String, Object?> payload, Set<String> tokens) {
    final values = <Object?>[
      payload['operation'],
      payload['mode'],
      _asMap(payload['updates'])['operation'],
    ];
    for (final value in values) {
      if (value is String) {
        final normalized = value.toLowerCase();
        for (final token in tokens) {
          if (normalized.contains(token)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool _hasAnyKey(Map<String, Object?> payload, Set<String> keys) {
    final queue = <Object?>[payload];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (current is Map) {
        for (final entry in current.entries) {
          final rawKey = entry.key;
          final value = entry.value;
          if (rawKey is String) {
            if (keys.contains(rawKey.toLowerCase())) {
              return true;
            }
          }
          queue.add(value);
        }
      } else if (current is Iterable) {
        queue.addAll(current);
      }
    }
    return false;
  }

  Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      final next = <String, Object?>{};
      value.forEach((key, dynamicValue) {
        if (key is String) {
          next[key] = dynamicValue;
        }
      });
      return next;
    }
    return const <String, Object?>{};
  }
}
