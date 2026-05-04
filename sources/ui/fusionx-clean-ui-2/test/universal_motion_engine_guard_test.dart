import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screenFile = File(
    'lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart',
  );
  final liveScrubProgramAdapterFile = File(
    'lib/features/editor/domain/services/master_live_scrub_program_adapter.dart',
  );
  final sceneLayerScopeAdapterFile = File(
    'lib/features/editor/presentation/services/scene_layer_scope_timeline_adapter.dart',
  );

  test('master evaluation path uses universal evaluation service', () async {
    final source = await screenFile.readAsString();
    expect(
      source.contains('MasterFrameEvaluation? _masterFrameEvaluationForMode('),
      isFalse,
    );
    final methodStart =
        source.indexOf('MasterFrameEvaluation _masterFrameEvaluationForMode(');
    expect(methodStart, isNonNegative);
    final methodEnd = source.indexOf(
      'String _liveScrubRuntimeBridgeSubmissionKey({',
      methodStart,
    );
    expect(methodEnd, greaterThan(methodStart));
    final body = source.substring(methodStart, methodEnd);

    expect(body.contains('_evaluateUniversalMasterFrameForMode('), isTrue);
    expect(
        body.contains('_masterFrameEvaluationReadAdapter.evaluate('), isFalse);
  });

  test('transition runtime bridge does not drop evaluated channels', () async {
    final source = await screenFile.readAsString();
    final methodStart = source.indexOf(
      'LiveScrubVisualProgram _liveScrubVisualProgramForTransitionRuntimeBridge({',
    );
    expect(methodStart, isNonNegative);
    final methodEnd = source.indexOf(
      'LiveScrubVisualProgram? _manualTransitionLiveScrubProgram({',
      methodStart,
    );
    expect(methodEnd, greaterThan(methodStart));
    final body = source.substring(methodStart, methodEnd);

    expect(
      body.contains(
          'evaluatedChannels: const <MasterEvaluatedPropertyValue>[]'),
      isFalse,
    );
    expect(
      body.contains('channels: const <MotionPropertyChannelModel>[]'),
      isFalse,
    );
    expect(body.contains('blockers: const <String>[]'), isFalse);
    expect(body.contains('evaluatedChannels: evaluation.evaluatedChannels'),
        isTrue);
    expect(body.contains('_evaluateUniversalMasterFrameForMode('), isFalse);
  });

  test('manual transition runtime bridge preserves effect parameters',
      () async {
    final source = await screenFile.readAsString();
    final methodStart = source.indexOf(
      'LiveScrubVisualProgram? _manualTransitionLiveScrubProgram({',
    );
    expect(methodStart, isNonNegative);
    final methodEnd = source.indexOf(
      'Set<String> _activeManualTransitionSourceIdsForTime({',
      methodStart,
    );
    expect(methodEnd, greaterThan(methodStart));
    final body = source.substring(methodStart, methodEnd);

    expect(
        body.contains('effectParameters: evaluation.effectParameters'), isTrue);
  });

  test('screen state does not keep legacy master frame read adapter field',
      () async {
    final source = await screenFile.readAsString();
    expect(source.contains('late final MasterFrameEvaluationReadAdapter'),
        isFalse);
    expect(source.contains('_masterFrameEvaluationReadAdapter'), isFalse);
  });

  test('scene layer scope maps shape layers to dedicated shape track kind',
      () async {
    final source = await sceneLayerScopeAdapterFile.readAsString();
    expect(
      source.contains('MotionLayerKind.shape => TimelineTrackKind.shape'),
      isTrue,
    );
    expect(
      source
          .contains('MotionLayerKind.shape => TimelineTrackContentKind.shape'),
      isTrue,
    );
  });

  test('universal channel source detaches legacy manual source id', () async {
    final source = await screenFile.readAsString();
    expect(source.contains("id: 'manual_motion_property_channels'"), isFalse);
    expect(source.contains("id: 'universal_authored_channels'"), isTrue);
    expect(source.contains("id: 'scene_scope_projection_channels'"), isTrue);
  });

  test('scene layer scope enables track animate/fx controls including shape',
      () async {
    final source = await screenFile.readAsString();
    expect(
      source.contains('onTrackAnimateTap:\n'
          '                                                      _handleSceneLayerScopeTrackAnimateTap'),
      isTrue,
    );
    expect(
      source.contains('onTrackFxTap:\n'
          '                                                      _handleSceneLayerScopeTrackFxTap'),
      isTrue,
    );
    expect(source.contains('TimelineTrackKind.shape,'), isTrue);
  });

  test('live scrub program is projected from master visual program', () async {
    final source = await liveScrubProgramAdapterFile.readAsString();
    expect(source.contains('MasterVisualProgramAdapter'), isTrue);
    expect(source.contains('MasterRenderGraphAdapter'), isTrue);
    expect(source.contains('_projectFromMasterVisualProgram('), isTrue);
    expect(source.contains('masterRenderGraphAdapter.build('), isTrue);
  });

  test('runtime bridge submission refreshes native presentation proof',
      () async {
    final source = await screenFile.readAsString();
    expect(
      source.contains(
        'refreshRuntimeBridgePresentationProofFromNativeSnapshot()',
      ),
      isTrue,
    );
  });
}
