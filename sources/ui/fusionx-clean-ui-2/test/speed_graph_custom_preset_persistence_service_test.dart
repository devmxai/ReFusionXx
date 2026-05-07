import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/services/speed_graph_custom_preset_persistence_service.dart';

void main() {
  late SpeedGraphCustomPresetPersistenceService service;

  setUp(() {
    service = SpeedGraphCustomPresetPersistenceService(
      storageDriver: InMemorySpeedGraphCustomPresetStorageDriver(),
    );
    service.clearForTest();
  });

  const easeCurve = MotionInterpolationSpec.cubicBezier(
    bezier: MotionBezierControlPoints(
      x1: 0.2,
      y1: 0.0,
      x2: 0.8,
      y2: 1.0,
    ),
  );

  test('save stores Bezier truth and preserves curve hash on load', () {
    final saved = service.saveInterpolation(
      interpolation: easeCurve,
      label: 'Cinematic',
    );
    expect(saved, isNotNull);
    expect(saved!.curveHash, isNotEmpty);

    final loaded = service.loadInterpolationByPresetId(saved.presetId);
    expect(loaded, isNotNull);
    expect(loaded!.kind, MotionInterpolationKind.cubicBezier);
    expect(loaded.bezier, equals(easeCurve.bezier));
  });

  test('duplicate save deduplicates by curve hash', () {
    final first = service.saveInterpolation(interpolation: easeCurve)!;
    final second = service.saveInterpolation(
      interpolation: easeCurve,
      label: 'Duplicate',
    )!;
    expect(first.curveHash, equals(second.curveHash));
    expect(service.listPresets(), hasLength(1));
  });

  test('export and import preserve curve hash truth', () {
    final saved = service.saveInterpolation(interpolation: easeCurve)!;
    final exported = service.exportPresetMaps();
    final restored = SpeedGraphCustomPresetPersistenceService(
      storageDriver: InMemorySpeedGraphCustomPresetStorageDriver(),
    );
    restored.clearForTest();
    restored.importPresetMaps(exported);
    expect(restored.listPresets(), hasLength(1));
    final loaded = restored.loadInterpolationByPresetId(
      restored.listPresets().first.presetId,
    );
    expect(loaded?.bezier?.x1, closeTo(saved.bezier.x1, 1e-9));
    expect(loaded?.bezier?.y1, closeTo(saved.bezier.y1, 1e-9));
    expect(loaded?.bezier?.x2, closeTo(saved.bezier.x2, 1e-9));
    expect(loaded?.bezier?.y2, closeTo(saved.bezier.y2, 1e-9));
    expect(restored.listPresets().first.curveHash, equals(saved.curveHash));
  });

  test('non-bezier interpolation is rejected for custom persistence', () {
    final rejected = service.saveInterpolation(
      interpolation: const MotionInterpolationSpec.linear(),
    );
    expect(rejected, isNull);
    expect(service.listPresets(), isEmpty);
  });
}
