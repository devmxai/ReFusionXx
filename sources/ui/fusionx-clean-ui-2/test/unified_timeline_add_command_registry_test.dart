import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_add_command_registry.dart';

void main() {
  const registry = UnifiedTimelineAddCommandRegistry();

  test('exposes expected commands for root scope', () {
    final commands = registry.commandsForScope(UnifiedTimelineAddScope.root);

    expect(
      commands.map((command) => command.id),
      <String>[
        'newScene',
        'sceneScript',
        'videoLayer',
        'imageLayer',
        'textLayer',
        'audioLayer',
      ],
    );
  });

  test('exposes expected commands for scene scope', () {
    final commands = registry.commandsForScope(UnifiedTimelineAddScope.scene);

    expect(
      commands.map((command) => command.id),
      <String>[
        'videoLayer',
        'imageLayer',
        'textLayer',
        'shapeLayer',
        'audioLayer',
      ],
    );
  });

  test('exposes expected commands for layer scope', () {
    final commands = registry.commandsForScope(UnifiedTimelineAddScope.layer);

    expect(
      commands.map((command) => command.id),
      <String>['textLayer', 'adjustmentLayer'],
    );
  });
}
