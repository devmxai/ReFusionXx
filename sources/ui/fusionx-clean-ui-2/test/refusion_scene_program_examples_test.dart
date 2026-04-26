import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_import_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_motion_lowering_service.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/motion_authoring_bundle_timeline_adapter.dart';

void main() {
  const importer = ReFusionSceneProgramImportService();
  const lowerer = ReFusionSceneProgramMotionLoweringService();
  const adapter = MotionAuthoringBundleTimelineAdapter();

  final examplesDir = Directory('docs/examples/refusion_scene_program');
  final exampleFiles = examplesDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList(growable: false)
    ..sort((left, right) => left.path.compareTo(right.path));

  test('example fixtures exist', () {
    expect(exampleFiles, isNotEmpty);
  });

  for (final file in exampleFiles) {
    test('${file.path} validates, lowers, and projects to editable lanes', () {
      final source = file.readAsStringSync();
      final imported = importer.validate(
        source: source,
        fileName: file.uri.pathSegments.last,
      );

      expect(
        imported.issues,
        isEmpty,
        reason: 'Import issues in ${file.path}',
      );
      expect(imported.canApply, isTrue);

      final lowered = lowerer.lower(
        document: imported.document!,
        projectId: 'project',
        sceneId: 'scene',
        layerId: 'layer',
      );
      expect(
        lowered.issues,
        isEmpty,
        reason: 'Lowering issues in ${file.path}',
      );
      expect(lowered.canApply, isTrue);
      expect(lowered.bundle!.hasEditableMotion, isTrue);

      final projected = adapter.projectBundle(
        bundle: lowered.bundle!,
        window: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: imported.document!.duration,
        ),
      );
      expect(
        projected.issues,
        isEmpty,
        reason: 'Projection issues in ${file.path}',
      );
      expect(projected.lanes, isNotEmpty);
      expect(
        projected.lanes.every((lane) => lane.keyframeIds.isNotEmpty),
        isTrue,
      );
    });
  }
}
