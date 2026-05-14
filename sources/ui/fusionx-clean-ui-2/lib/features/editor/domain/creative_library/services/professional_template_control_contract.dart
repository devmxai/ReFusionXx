import '../models/professional_creative_library_registry_models.dart';

enum ExposedControlType {
  text,
  color,
  number,
  boolean,
  media,
  layout,
  motion,
  unknown,
}

class ExposedControlDefinition {
  const ExposedControlDefinition({
    required this.id,
    required this.label,
    required this.type,
    required this.defaultValue,
    required this.required,
    required this.advancedOnly,
    this.minimum,
    this.maximum,
    this.allowedValues = const <Object?>[],
  });

  final String id;
  final String label;
  final ExposedControlType type;
  final Object? defaultValue;
  final bool required;
  final bool advancedOnly;
  final num? minimum;
  final num? maximum;
  final List<Object?> allowedValues;
}

class EditableSlotDefinition {
  const EditableSlotDefinition({
    required this.id,
    required this.kind,
    required this.controlIds,
  });

  final String id;
  final String kind;
  final List<String> controlIds;
}

class ControlBinding {
  const ControlBinding({
    required this.controlId,
    required this.path,
  });

  final String controlId;
  final String path;
}

class ValidationRule {
  const ValidationRule({
    required this.id,
    required this.message,
    required this.isBlocker,
  });

  final String id;
  final String message;
  final bool isBlocker;
}

class TemplateControlContractSnapshot {
  const TemplateControlContractSnapshot({
    required this.templateCapabilityId,
    required this.controls,
    required this.slots,
    required this.bindings,
    required this.validationRules,
  });

  final String templateCapabilityId;
  final List<ExposedControlDefinition> controls;
  final List<EditableSlotDefinition> slots;
  final List<ControlBinding> bindings;
  final List<ValidationRule> validationRules;
}

class TemplateControlValidationResult {
  const TemplateControlValidationResult({
    required this.ok,
    required this.rules,
  });

  final bool ok;
  final List<ValidationRule> rules;
}

class ProfessionalTemplateControlContractBuilder {
  const ProfessionalTemplateControlContractBuilder();

  TemplateControlContractSnapshot build(TemplateDefinition template) {
    final controls = <ExposedControlDefinition>[];
    final slots = <EditableSlotDefinition>[];
    final bindings = <ControlBinding>[];
    final rules = <ValidationRule>[];

    final manualControls = template.manualUiControls;
    for (final control in manualControls) {
      final schema = _asMap(template.parameterSchema[control.id]);
      final type = _resolveType(control.controlType, schema['type']);
      final advancedOnly = _isAdvancedControl(control.id);
      controls.add(
        ExposedControlDefinition(
          id: control.id,
          label: control.label,
          type: type,
          defaultValue:
              template.defaultParams[control.id] ?? control.defaultValue,
          required: schema['required'] == true,
          advancedOnly: advancedOnly,
          minimum: _asNum(schema['minimum']),
          maximum: _asNum(schema['maximum']),
          allowedValues: _asList(schema['enum']),
        ),
      );
      bindings.add(
        ControlBinding(
          controlId: control.id,
          path: 'controls.${control.id}',
        ),
      );
    }

    if (controls.isEmpty) {
      rules.add(
        const ValidationRule(
          id: 'template.controls.missing',
          message: 'Template exposes no editable controls.',
          isBlocker: true,
        ),
      );
    }

    slots.add(
      EditableSlotDefinition(
        id: 'template.root',
        kind: 'template',
        controlIds:
            controls.map((control) => control.id).toList(growable: false),
      ),
    );

    return TemplateControlContractSnapshot(
      templateCapabilityId: template.id,
      controls: List<ExposedControlDefinition>.unmodifiable(controls),
      slots: List<EditableSlotDefinition>.unmodifiable(slots),
      bindings: List<ControlBinding>.unmodifiable(bindings),
      validationRules: List<ValidationRule>.unmodifiable(rules),
    );
  }

  TemplateControlValidationResult validate(
    TemplateControlContractSnapshot snapshot, {
    required bool advancedEditModeEnabled,
  }) {
    final rules = <ValidationRule>[];
    final visibleControlIds = visibleControls(
      snapshot,
      advancedEditModeEnabled: advancedEditModeEnabled,
    ).map((control) => control.id).toSet();

    if (visibleControlIds.isEmpty) {
      rules.add(
        const ValidationRule(
          id: 'template.controls.none_visible',
          message: 'No controls are visible in current edit mode.',
          isBlocker: true,
        ),
      );
    }
    for (final binding in snapshot.bindings) {
      if (!snapshot.controls
          .any((control) => control.id == binding.controlId)) {
        rules.add(
          ValidationRule(
            id: 'template.binding.orphan.${binding.controlId}',
            message:
                'Control binding `${binding.controlId}` does not map to exposed controls.',
            isBlocker: true,
          ),
        );
      }
    }
    return TemplateControlValidationResult(
      ok: rules.where((rule) => rule.isBlocker).isEmpty,
      rules: List<ValidationRule>.unmodifiable(
        <ValidationRule>[...snapshot.validationRules, ...rules],
      ),
    );
  }

  List<ExposedControlDefinition> visibleControls(
    TemplateControlContractSnapshot snapshot, {
    required bool advancedEditModeEnabled,
  }) {
    if (advancedEditModeEnabled) {
      return snapshot.controls;
    }
    return snapshot.controls
        .where((control) => !control.advancedOnly)
        .toList(growable: false);
  }

  bool _isAdvancedControl(String controlId) {
    final normalized = controlId.toLowerCase();
    return normalized.contains('internal') ||
        normalized.contains('advanced') ||
        normalized.contains('debug') ||
        normalized.contains('expression');
  }

  ExposedControlType _resolveType(Object? primary, Object? fallback) {
    final value = (primary ?? fallback)?.toString().toLowerCase() ?? '';
    switch (value) {
      case 'text':
      case 'string':
        return ExposedControlType.text;
      case 'color':
        return ExposedControlType.color;
      case 'number':
      case 'slider':
        return ExposedControlType.number;
      case 'boolean':
      case 'bool':
      case 'toggle':
        return ExposedControlType.boolean;
      case 'media':
        return ExposedControlType.media;
      case 'layout':
        return ExposedControlType.layout;
      case 'motion':
        return ExposedControlType.motion;
      default:
        return ExposedControlType.unknown;
    }
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

  num? _asNum(Object? value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      return num.tryParse(value.trim());
    }
    return null;
  }

  List<Object?> _asList(Object? value) {
    if (value is List) {
      return value.cast<Object?>();
    }
    return const <Object?>[];
  }
}
