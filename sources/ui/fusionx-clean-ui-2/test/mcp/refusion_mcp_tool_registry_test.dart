import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';

void main() {
  group('RefusionMcpToolRegistry', () {
    test('contains baseline tools required by PMC MVP', () {
      final registry = RefusionMcpToolRegistry();
      final names = registry.list().map((tool) => tool.name).toSet();
      expect(names.contains('refusion.get_project_state'), isTrue);
      expect(names.contains('refusion.get_timeline_summary'), isTrue);
      expect(names.contains('refusion.capture_preview_frame'), isTrue);
      expect(names.contains('refusion.get_security_profile'), isTrue);
      expect(names.contains('refusion.get_host_compatibility'), isTrue);
      expect(names.contains('refusion.validate_scene_program'), isTrue);
      expect(names.contains('refusion.author_scene_program'), isTrue);
      expect(names.contains('refusion.apply_scene_program'), isTrue);
      expect(names.contains('refusion.insert_layer'), isTrue);
      expect(names.contains('refusion.split_at_playhead'), isTrue);
      expect(names.contains('refusion.trim_layer'), isTrue);
      expect(names.contains('refusion.move_layer'), isTrue);
      expect(names.contains('refusion.delete_layer'), isTrue);
    });

    test('resolves descriptor by name', () {
      final registry = RefusionMcpToolRegistry();
      final descriptor = registry.find('refusion.apply_scene_program');
      expect(descriptor, isNotNull);
      expect(descriptor!.capability, RefusionMcpCapability.sceneWrite);
      expect(descriptor.mutating, isTrue);
    });

    test('normalizes short tool names for host compatibility', () {
      final registry = RefusionMcpToolRegistry();
      expect(
        registry.normalizeToolName('insert_layer'),
        'refusion.insert_layer',
      );
      expect(
        registry.normalizeToolName('get_project_state'),
        'refusion.get_project_state',
      );
      expect(
        registry.normalizeToolName('unknown_tool'),
        isNull,
      );
    });
  });
}
