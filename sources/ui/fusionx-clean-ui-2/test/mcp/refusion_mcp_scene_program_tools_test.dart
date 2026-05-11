import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_scene_program_tools.dart';

void main() {
  group('RefusionMcpSceneProgramTools', () {
    test('validates known fixture scene program', () {
      final tools = RefusionMcpSceneProgramTools();
      final source = File(
        '/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/test/fixtures/refusion_scene_programs/first_generated_scene.json',
      ).readAsStringSync();
      final validation = tools.validateSceneProgram(source: source);
      expect(validation.isValid, isTrue);
      expect(validation.program, isNotNull);
    });

    test('returns invalid for malformed scene program json', () {
      final tools = RefusionMcpSceneProgramTools();
      final validation = tools.validateSceneProgram(
        source: '{"schemaVersion": "refusion.scene-program/v1"',
      );
      expect(validation.isValid, isFalse);
      expect(validation.issues, isNotEmpty);
    });

    test('compiles minimal director plan into scene program', () {
      final tools = RefusionMcpSceneProgramTools();
      final directorPlan = '''
{
  "schemaVersion": "refusion.motion-director/v1",
  "name": "MCP Director Test",
  "durationMs": 2400,
  "frameRate": 30,
  "canvasWidth": 1080,
  "canvasHeight": 1920,
  "beats": [
    {
      "id": "beat-1",
      "label": "Intro",
      "startMs": 0,
      "endMs": 2400,
      "intent": "title reveal",
      "componentRefs": ["component-1"]
    }
  ],
  "components": [
    {
      "id": "component-1",
      "role": "title text",
      "label": "Hero Title",
      "properties": {
        "text": "Smart Test App"
      }
    }
  ],
  "primitives": []
}
''';
      final compile = tools.compileDirectorPlan(source: directorPlan);
      expect(compile.plan, isNotNull);
      expect(compile.program, isNotNull);
      expect(compile.isValid, isTrue);
    });

    test('rejects invalid director plan json', () {
      final tools = RefusionMcpSceneProgramTools();
      final compile = tools.compileDirectorPlan(source: '{invalid}');
      expect(compile.isValid, isFalse);
      expect(compile.issues, isNotEmpty);
    });
  });
}
