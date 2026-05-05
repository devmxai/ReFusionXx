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
  final masterVisualProgramModelsFile = File(
    'lib/features/editor/domain/models/master_visual_program_models.dart',
  );
  final masterVisualProgramAdapterFile = File(
    'lib/features/editor/domain/services/master_visual_program_adapter.dart',
  );
  final liveScrubDescriptorModelsFile = File(
    'lib/features/editor/domain/models/master_live_scrub_descriptor_models.dart',
  );
  final stage5TransportControllerFile = File(
    'lib/core/engine/stage5_native_transport_controller.dart',
  );
  final compositionMediaPlaybackProjectionAdapterFile = File(
    'lib/features/editor/presentation/services/composition_media_playback_projection_adapter.dart',
  );
  final nativeTimelineScrubSurfaceFile = File(
    'lib/features/editor/presentation/widgets/native_timeline_scrub_surface.dart',
  );
  final phase7ProductionPathParityTestFile = File(
    'test/phase7_production_path_parity_test.dart',
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

  test('screen does not rebuild master frame evaluation manually', () async {
    final source = await screenFile.readAsString();
    expect(source.contains('MasterFrameEvaluation('), isFalse);
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
    expect(body.contains('frame: MasterFrameEvaluation('), isFalse);
    expect(body.contains('frame: evaluation.copyWith('), isTrue);
    expect(body.contains('blockers: const <String>[]'), isFalse);
    expect(body.contains('evaluatedChannels: evaluation.evaluatedChannels'),
        isFalse);
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

    expect(body.contains('frame: MasterFrameEvaluation('), isFalse);
    expect(body.contains('frame: evaluation.copyWith('), isTrue);
  });

  test('manual transition FX catalog exposes Gaussian and Motion Blur',
      () async {
    final source = await screenFile.readAsString();
    final videoFxStart = source.indexOf(
      'static const List<AnimateBrowserItem> _scopedVideoFxItems',
    );
    expect(videoFxStart, isNonNegative);
    final videoFxEnd = source.indexOf(
      'static const List<AnimateBrowserItem> _manualTransitionAnimateItems',
      videoFxStart,
    );
    expect(videoFxEnd, greaterThan(videoFxStart));
    final videoFxBody = source.substring(videoFxStart, videoFxEnd);

    expect(videoFxBody.contains("id: 'gaussian_blur'"), isTrue);
    expect(videoFxBody.contains("id: 'motion_blur'"), isTrue);
    expect(
      source.contains(
        'static const List<AnimateBrowserItem> _manualTransitionFxItems =\n'
        '      _scopedVideoFxItems;',
      ),
      isTrue,
    );
  });

  test('stage5 visual runtime bridge sends effect renderer values', () async {
    final source = await screenFile.readAsString();
    expect(source.contains('Stage5VisualRuntimeEffectBinding('), isTrue);
    expect(source.contains('rendererValue: effect.rendererValue'), isTrue);
    expect(source.contains('rendererUnit: effect.rendererUnit.name'), isTrue);
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
    expect(
      source.contains(
          'MotionLayerKind.camera || MotionLayerKind.effectControl =>\n'
          '        TimelineTrackKind.text'),
      isFalse,
    );
    expect(
      source.contains(
        'Unsupported layer kind for Scene Layer Scope track kind',
      ),
      isTrue,
    );
    expect(
      source.contains(
        'Unsupported layer kind for Scene Layer Scope content kind',
      ),
      isTrue,
    );
  });

  test('media playback projection has no text/control fallback for layer kind',
      () async {
    final source =
        await compositionMediaPlaybackProjectionAdapterFile.readAsString();
    expect(source.contains('_ => TimelineTrackKind.text'), isFalse);
    expect(source.contains('_ => TimelineVisualKind.control'), isFalse);
    expect(
      source.contains(
        'Unsupported layer kind for media playback track kind',
      ),
      isTrue,
    );
    expect(
      source.contains(
        'Unsupported layer kind for media playback visual kind',
      ),
      isTrue,
    );
  });

  test('universal channel source detaches legacy manual source id', () async {
    final source = await screenFile.readAsString();
    expect(source.contains("id: 'manual_motion_property_channels'"), isFalse);
    expect(source.contains("id: 'universal_authored_channels'"), isTrue);
    expect(source.contains("id: 'scene_scope_projection_channels'"), isTrue);
    expect(source.contains('_manualMotionPropertyChannels'), isFalse);
    expect(source.contains('_universalMotionPropertyChannels'), isTrue);
  });

  test('screen enables unified transition scope bridge in production',
      () async {
    final source = await screenFile.readAsString();
    expect(
      source.contains('_unifiedTransitionScopeBridgeEnabled'),
      isFalse,
    );
    expect(
      source.contains('_transitionUnifiedScopeBridgeEntryAdapter =\n'
          '        TransitionUnifiedScopeBridgeEntryAdapter();'),
      isTrue,
    );
    expect(
      source.contains(
        'TransitionUnifiedScopeBridgeBlockReason.featureDisabled',
      ),
      isFalse,
    );
    expect(source.contains('TransitionUnifiedScopeEntryConfig'), isFalse);
  });

  test('screen detaches legacy manual transform transition hooks', () async {
    final source = await screenFile.readAsString();
    expect(source.contains("'manualTransform'"), isFalse);
    expect(source.contains('_manualTransitionNativeParameters('), isFalse);
    expect(source.contains('_isLegacyTriangularBlackMixLane('), isFalse);
    expect(
      source.contains('TimelineTransitionPreset.manual => null'),
      isTrue,
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

  test('normal transitions do not fall back to legacy inspector flow',
      () async {
    final source = await screenFile.readAsString();
    expect(
      source.contains(
        'if (_normalTransitionAuthoringAdapter\n'
        '          .isNormalPreset(existingTransition.preset)) {',
      ),
      isTrue,
    );
    expect(
      source.contains(
          'if (_normalTransitionAuthoringAdapter.isNormalPreset(preset)) {'),
      isTrue,
    );
    expect(
      source.contains(
        'Unified Transition Scope blocked for this boundary. Resolve reported issues before reopening.',
      ),
      isTrue,
    );
  });

  test('transition unified scope gate uses opened/blocked result factories',
      () async {
    final gateSource = await File(
      'lib/features/editor/presentation/services/transition_unified_scope_entry_gate.dart',
    ).readAsString();
    expect(gateSource.contains('legacyTransitionScope'), isFalse);
    expect(gateSource.contains('TransitionUnifiedScopeEntryDecision'), isFalse);
    expect(gateSource.contains('TransitionUnifiedScopeEntryResult.opened('),
        isTrue);
    expect(gateSource.contains('TransitionUnifiedScopeEntryResult.blocked('),
        isTrue);
  });

  test('unified transition contracts do not use fallbackReason naming',
      () async {
    final gateSource = await File(
      'lib/features/editor/presentation/services/transition_unified_scope_entry_gate.dart',
    ).readAsString();
    final bridgeSource = await File(
      'lib/features/editor/presentation/services/transition_unified_scope_bridge_entry_adapter.dart',
    ).readAsString();
    expect(gateSource.contains('fallbackReason'), isFalse);
    expect(bridgeSource.contains('fallbackReason'), isFalse);
    expect(gateSource.contains('blockReason'), isTrue);
    expect(bridgeSource.contains('blockReason'), isTrue);
    expect(gateSource.contains('bool get isBlocked => !opensUnifiedScope;'),
        isTrue);
    expect(bridgeSource.contains('bool get isBlocked => !opensUnifiedScope;'),
        isTrue);
  });

  test('live scrub program is projected from master visual program', () async {
    final source = await liveScrubProgramAdapterFile.readAsString();
    expect(source.contains('MasterVisualProgramAdapter'), isTrue);
    expect(source.contains('MasterRenderGraphAdapter'), isTrue);
    expect(source.contains('MasterRendererFrameAdapters'), isTrue);
    expect(source.contains('_projectFromMasterVisualProgram('), isTrue);
    expect(source.contains('masterRenderGraphAdapter.build('), isTrue);
    expect(source.contains('masterRendererFrameAdapters.projectLiveScrub('),
        isTrue);
  });

  test('master visual program carries crop text and shape contracts', () async {
    final modelsSource = await masterVisualProgramModelsFile.readAsString();
    final adapterSource = await masterVisualProgramAdapterFile.readAsString();
    final renderGraphAdapterSource =
        await masterRenderGraphAdapterFile.readAsString();

    expect(modelsSource.contains('class MasterVisualCrop'), isTrue);
    expect(modelsSource.contains('class MasterVisualMask'), isTrue);
    expect(modelsSource.contains('class MasterVisualColorStyle'), isTrue);
    expect(modelsSource.contains('class MasterVisualTextStyle'), isTrue);
    expect(modelsSource.contains('class MasterVisualShapeStyle'), isTrue);
    expect(modelsSource.contains('final MasterVisualCrop crop;'), isTrue);
    expect(modelsSource.contains('final MasterVisualMask mask;'), isTrue);
    expect(
        modelsSource.contains('final MasterVisualColorStyle colors;'), isTrue);
    expect(modelsSource.contains('final int drawOrder;'), isTrue);
    expect(modelsSource.contains('final MasterVisualTextStyle textStyle;'),
        isTrue);
    expect(modelsSource.contains('final MasterVisualShapeStyle shapeStyle;'),
        isTrue);
    expect(adapterSource.contains("case 'cropRect':"), isTrue);
    expect(adapterSource.contains("case 'maskRevealProgress':"), isTrue);
    expect(adapterSource.contains("case 'shadowColor':"), isTrue);
    expect(adapterSource.contains("case 'visualColor':"), isTrue);
    expect(adapterSource.contains("case 'textFontSize':"), isTrue);
    expect(adapterSource.contains("case 'shapeWidth':"), isTrue);
    expect(adapterSource.contains("case 'trimStart':"), isTrue);
    expect(
        adapterSource.contains("case 'trimStart':\n"
            "          case 'trimEnd':"),
        isFalse);
    expect(
        renderGraphAdapterSource.contains('MasterRenderGraphNodeFamily.crop'),
        isTrue);
    expect(
        renderGraphAdapterSource.contains('MasterRenderGraphNodeFamily.mask'),
        isTrue);
    expect(
        renderGraphAdapterSource.contains('MasterRenderGraphNodeFamily.style'),
        isTrue);
    expect(renderGraphAdapterSource.contains("'drawOrder': surface.drawOrder"),
        isTrue);
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

  test('native timeline scrub payload uses master root time contract',
      () async {
    final source = await nativeTimelineScrubSurfaceFile.readAsString();
    expect(
        source.contains(
            "'masterRootTimeMs': effectiveCurrentTime.inMilliseconds +"),
        isTrue);
    expect(
      source.contains("widget.timelineOffsetTime.inMilliseconds"),
      isTrue,
    );
    expect(source.contains("'currentPositionMs':"), isFalse);
  });

  test('phase7 production-path parity test uses universal evaluation service',
      () async {
    final source = await phase7ProductionPathParityTestFile.readAsString();
    expect(source.contains('UniversalMasterFrameEvaluationService('), isTrue);
    expect(
      source.contains('UniversalMasterFrameEvaluationRequest('),
      isTrue,
    );
    expect(source.contains('MasterFrameEvaluation('), isFalse);
    expect(source.contains('MasterVisualProgramAdapter'), isTrue);
    expect(source.contains('MasterRenderGraphAdapter'), isTrue);
    expect(source.contains('MasterRendererFrameAdapters'), isTrue);
  });
}
