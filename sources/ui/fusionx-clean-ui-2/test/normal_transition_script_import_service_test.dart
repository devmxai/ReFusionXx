import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_normal_transition_models.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_script_import_service.dart';

void main() {
  const service = NormalTransitionScriptImportService();

  test('imports valid declarative cross dissolve JSON', () {
    const source = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "cross_dissolve",
  "name": "Cross Dissolve",
  "category": "basic",
  "rendererType": "primitive",
  "defaultDurationMs": 720,
  "requires": ["dual-texture", "opacity", "timeline-overlap"],
  "parameters": [
    {
      "name": "softness",
      "type": "number",
      "default": 0.5,
      "range": [0.0, 1.0],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "linear" },
        { "t": 1.0, "value": 0.0, "easing": "linear" }
      ]
    },
    {
      "target": "to",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "linear" },
        { "t": 1.0, "value": 1.0, "easing": "linear" }
      ]
    }
  ]
}
''';

    final result = service.validate(source: source, fileName: 'cross.json');

    expect(result.canImport, isTrue);
    expect(result.issues, isEmpty);
    expect(result.definition!.definitionId, 'cross_dissolve');
    expect(result.definition!.defaultDuration.inMilliseconds, 720);
    expect(result.definition!.capabilities, contains('dual-texture'));
    expect(result.definition!.channels, hasLength(2));
    expect(result.definition!.channels.first.target, 'from');
    expect(result.definition!.channels.last.target, 'to');
  });

  test('rejects non-json uploads before parsing', () {
    final result = service.validate(
      source: '{"id":"cross_dissolve"}',
      fileName: 'cross.txt',
    );

    expect(result.canImport, isFalse);
    expect(result.issues.single.path, 'fileName');
  });

  test('rejects executable fields and unsafe shader source', () {
    const source = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "unsafe",
  "rendererType": "primitive",
  "defaultDurationMs": 400,
  "code": "return transition;",
  "shaderSource": "void main() {}",
  "channels": []
}
''';

    final result = service.validate(source: source, fileName: 'unsafe.json');

    expect(result.canImport, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      ),
      hasLength(2),
    );
    expect(result.issues.map((issue) => issue.path), contains('code'));
    expect(result.issues.map((issue) => issue.path), contains('shaderSource'));
  });

  test('rejects channel keyframes outside normalized time range', () {
    const source = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "bad_time",
  "rendererType": "primitive",
  "defaultDurationMs": 400,
  "channels": [
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 1.0 },
        { "t": 1.2, "value": 0.0 }
      ]
    }
  ]
}
''';

    final result = service.validate(source: source, fileName: 'bad.json');

    expect(result.canImport, isFalse);
    expect(
      result.issues.any((issue) => issue.path == 'channels[0].keyframes[1].t'),
      isTrue,
    );
  });
}
