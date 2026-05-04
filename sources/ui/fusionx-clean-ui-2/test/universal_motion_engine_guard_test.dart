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
  final liveScrubDescriptorProjectionFile = File(
    'lib/features/editor/domain/services/master_live_scrub_descriptor_projection.dart',
  );
  final liveScrubProgramModelsFile = File(
    'lib/features/editor/domain/models/master_live_scrub_visual_program_models.dart',
  );
  final masterRenderGraphAdapterFile = File(
    'lib/features/editor/domain/services/master_render_graph_adapter.dart',
  );
  final liveScrubDescriptorModelsFile = File(
    'lib/features/editor/domain/models/master_live_scrub_descriptor_models.dart',
  );
  final stage5TransportControllerFile = File(
    'lib/core/engine/stage5_native_transport_controller.dart',
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

  test('screen enables unified transition scope bridge in production',
      () async {
    final source = await screenFile.readAsString();
    expect(
      source.contains('_unifiedTransitionScopeBridgeEnabled'),
      isFalse,
    );
    expect(
      source.contains('enableUnifiedTransitionScope: true'),
      isTrue,
    );
    expect(
      source.contains(
        'TransitionUnifiedScopeBridgeFallbackReason.featureDisabled',
      ),
      isFalse,
    );
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
    expect(source.contains('MasterRendererModeAdapter'), isTrue);
    expect(source.contains('_projectFromMasterVisualProgram('), isTrue);
    expect(source.contains('masterRenderGraphAdapter.build('), isTrue);
    expect(source.contains('masterRendererModeAdapter.project('), isTrue);
  });

  test('runtime bridge submission gates on reconciled native proof', () async {
    final source = await screenFile.readAsString();
    expect(
      source.contains('submitLiveScrubRuntimeBridgeSnapshot('),
      isTrue,
    );
    expect(
      source.contains('final proof = submission.proof;'),
      isTrue,
    );
    expect(
      source.contains('if (submission.isRenderableMatch) {'),
      isTrue,
    );
  });

  test('descriptor projection proof uses renderer mode adapter contract',
      () async {
    final source = await liveScrubDescriptorProjectionFile.readAsString();
    expect(source.contains('MasterRendererModeAdapter'), isTrue);
    expect(source.contains('MasterRendererContracts'), isTrue);
    expect(source.contains('_rendererModeFromMasterRenderMode('), isTrue);
    expect(source.contains('masterRendererModeAdapter.buildProof('), isTrue);
    expect(
      source.contains('MasterRendererContracts.descriptorRequestIdForMode('),
      isTrue,
    );
    expect(
      source.contains('MasterRendererContracts.runtimeBridgeSurfaceIdForMode('),
      isTrue,
    );
    expect(source.contains("'projection_blocked'"), isFalse);
    expect(source.contains("'awaiting_native_ack'"), isFalse);
    expect(source.contains('_extractDiagnosticValue('), isFalse);
    expect(source.contains('RendererPresentationProof('), isFalse);
    expect(source.contains("'stage5-scrub-surface'"), isFalse);
  });

  test('live scrub program adapter uses renderer contract ids', () async {
    final source = await liveScrubProgramAdapterFile.readAsString();
    expect(source.contains('MasterRendererContracts'), isTrue);
    expect(
      source.contains('MasterRendererContracts.liveScrubProgramRequestId('),
      isTrue,
    );
    expect(
      source
          .contains('MasterRendererContracts.liveScrubRuntimeBridgeSurfaceId'),
      isTrue,
    );
    expect(source.contains("'stage5-runtime-bridge'"), isFalse);
    expect(source.contains('master_source_revision:'), isFalse);
  });

  test('transition runtime bridge preserves program revisions', () async {
    final source = await screenFile.readAsString();
    final transitionMethodStart = source.indexOf(
      'LiveScrubVisualProgram _liveScrubVisualProgramForTransitionRuntimeBridge({',
    );
    expect(transitionMethodStart, isNonNegative);
    final transitionMethodEnd = source.indexOf(
      'LiveScrubVisualProgram? _manualTransitionLiveScrubProgram({',
      transitionMethodStart,
    );
    expect(transitionMethodEnd, greaterThan(transitionMethodStart));
    final transitionBody =
        source.substring(transitionMethodStart, transitionMethodEnd);
    expect(
      transitionBody.contains('sourceRevision: program.sourceRevision'),
      isTrue,
    );
    expect(
      transitionBody
          .contains('renderGraphRevision: program.renderGraphRevision'),
      isTrue,
    );

    final manualMethodStart = source.indexOf(
      'LiveScrubVisualProgram? _manualTransitionLiveScrubProgram({',
    );
    expect(manualMethodStart, isNonNegative);
    final manualMethodEnd = source.indexOf(
      'Set<String> _activeManualTransitionSourceIdsForTime({',
      manualMethodStart,
    );
    expect(manualMethodEnd, greaterThan(manualMethodStart));
    final manualBody = source.substring(manualMethodStart, manualMethodEnd);
    expect(
      manualBody.contains('sourceRevision: baseProgram.sourceRevision'),
      isTrue,
    );
    expect(
      manualBody
          .contains('renderGraphRevision: baseProgram.renderGraphRevision'),
      isTrue,
    );
  });

  test('live scrub program requires explicit revision contract', () async {
    final source = await liveScrubProgramModelsFile.readAsString();
    expect(source.contains('required this.sourceRevision'), isTrue);
    expect(source.contains('required this.renderGraphRevision'), isTrue);
    expect(source.contains("this.sourceRevision = 'unknown'"), isFalse);
    expect(source.contains("this.renderGraphRevision = 'unknown'"), isFalse);
  });

  test('descriptor projection result requires explicit proof', () async {
    final source = await liveScrubDescriptorModelsFile.readAsString();
    expect(source.contains('required this.rendererPresentationProof'), isTrue);
    expect(source.contains('this.rendererPresentationProof = const'), isFalse);
  });

  test('renderer proof constructor has no silent defaults', () async {
    final source = await liveScrubDescriptorModelsFile.readAsString();
    final ctorStart = source.indexOf('const RendererPresentationProof({');
    expect(ctorStart, isNonNegative);
    final ctorEnd = source.indexOf(
      'const RendererPresentationProof.uninitialized({',
      ctorStart,
    );
    expect(ctorEnd, greaterThan(ctorStart));
    final ctorBody = source.substring(ctorStart, ctorEnd);
    expect(ctorBody.contains('required this.requestedRootTimeMs'), isTrue);
    expect(ctorBody.contains('required this.requestedFrameIndex'), isTrue);
    expect(ctorBody.contains('required this.requestId'), isTrue);
    expect(ctorBody.contains('required this.sourceRevision'), isTrue);
    expect(ctorBody.contains('required this.renderGraphRevision'), isTrue);
    expect(ctorBody.contains('required this.rendererMode'), isTrue);
    expect(ctorBody.contains('this.requestedRootTimeMs = 0'), isFalse);
    expect(ctorBody.contains('this.requestId = \'uninitialized\''), isFalse);
    expect(ctorBody.contains('this.rendererMode = \'unknown\''), isFalse);
  });

  test('stage5 controller starts from explicit uninitialized proof', () async {
    final source = await stage5TransportControllerFile.readAsString();
    expect(source.contains('RendererPresentationProof.uninitialized('), isTrue);
    expect(source.contains('const RendererPresentationProof();'), isFalse);
  });

  test('master render graph does not emit legacy revision diagnostics',
      () async {
    final source = await masterRenderGraphAdapterFile.readAsString();
    expect(source.contains('master_render_graph_revision:'), isFalse);
  });
}
