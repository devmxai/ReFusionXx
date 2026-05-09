import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_director_blueprint_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/scene_director_intelligence.dart';
import 'package:refusion_app/features/editor/domain/services/scene_rhythm_density_validator.dart';

void main() {
  const intelligence = SceneDirectorIntelligence();

  final root = Directory.current.path;
  final fixturesRoot =
      '$root/test/fixtures/director_briefs/v5';
  final goodDir = Directory('$fixturesRoot/good');
  final badDir = Directory('$fixturesRoot/bad');

  test('all v5 good director brief templates compile successfully', () {
    final files = goodDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));
    expect(files.length, 12);

    for (final file in files) {
      final payload = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final result = intelligence.compileFromRawBrief(payload);
      final errors = result.issues
          .where((issue) => issue.severity.name == 'error')
          .map((issue) => '${issue.path}: ${issue.message}')
          .join(' | ');
      expect(result.isValid, isTrue, reason: '${file.path} -> $errors');
      expect(result.plan, isNotNull, reason: file.path);
      expect(result.blueprint, isNotNull, reason: file.path);
      expect(
        result.blueprint!.schemaVersion,
        'refusion.semantic-blueprint/v5',
        reason: file.path,
      );
      expect(result.blueprint!.components, isNotEmpty, reason: file.path);
      expect(
        result.issues.any(
          (issue) => issue.message.contains(kSceneDirectorPlannerProofTag),
        ),
        isTrue,
        reason: file.path,
      );
      expect(
        result.issues.any(
          (issue) => issue.message.contains(kSceneRhythmDensityProofTag),
        ),
        isTrue,
        reason: file.path,
      );
    }
  });

  test('all v5 bad director brief templates are rejected with explicit reason',
      () {
    final files = badDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));
    expect(files.length, 10);

    for (final file in files) {
      final payload = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final expectedReason =
          (payload['expectedIssueContains'] as String?)?.trim() ?? '';
      final result = intelligence.compileFromRawBrief(payload);
      expect(result.isValid, isFalse, reason: file.path);
      expect(
        result.issues.any(
          (issue) =>
              issue.severity.name == 'error' &&
              issue.message.toLowerCase().contains(expectedReason.toLowerCase()),
        ),
        isTrue,
        reason: '${file.path} expected reason: $expectedReason',
      );
    }
  });

  test('legacy scene-program payloads are intentionally rejected in v5 brief path',
      () {
    final legacyFiles = <String>[
      'assets/scene_programs/premium_app_promo_prompt_bar_scene.json',
      'assets/scene_programs/saas_launch_match_cut_scene.json',
      'assets/scene_programs/revival_prompt_burst_feature_cards_scene.json',
    ];

    for (final filePath in legacyFiles) {
      final raw = jsonDecode(File('$root/$filePath').readAsStringSync());
      final result = intelligence.compileFromRawBrief(raw);
      expect(result.isValid, isFalse, reason: filePath);
      expect(
        result.issues.any(
          (issue) =>
              issue.severity.name == 'error' &&
              (issue.path ?? '').startsWith('directorBrief'),
        ),
        isTrue,
        reason: filePath,
      );
    }
  });
}
