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
  final stage5NativeScrubEngineFile = File(
    'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt',
  );
  final stage5PreviewPlatformViewFile = File(
    'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformView.kt',
  );
  final stage5ScrubOverlayTextureViewFile = File(
    'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt',
  );
  final exportCompositionModelsFile = File(
    'lib/features/editor/domain/models/export_composition_models.dart',
  );
  final stage6ExportManagerFile = File(
    'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt',
  );
  final trueFrameExecutionGraphAdapterFile = File(
    'lib/features/editor/domain/services/trueframe_execution_graph_adapter.dart',
  );
  final trueFrameCoreRuntimeEvaluatorFile = File(
    'lib/features/editor/domain/services/trueframe_core_runtime_evaluator.dart',
  );
  final trueFrameRenderBackendFile = File(
    'lib/features/editor/domain/services/trueframe_render_backend.dart',
  );
  final professionalTransitionSurfaceFile = File(
    'lib/features/editor/presentation/widgets/professional_video_transition_surface.dart',
  );
  final professionalTransitionCompositorFile = File(
    'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/ProfessionalVideoTransitionCompositorManager.kt',
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
    expect(source.contains('Stage5VisualRuntimeMotionBlurPolicy('), isTrue);
    expect(source.contains('amount: surface.motionBlur.amount'), isTrue);
    expect(
      source.contains(
        'shutterAngleDegrees: surface.motionBlur.shutterAngleDegrees',
      ),
      isTrue,
    );
    expect(
        source.contains('_stage5TemporalMotionBlurSamplesForSurface('), isTrue);
    expect(
      source.contains(
        'motionBlurSamples: _stage5TemporalMotionBlurSamplesForSurface(',
      ),
      isTrue,
    );
    expect(
      source.contains(
        'motionBlurSamples: const <Stage5VisualRuntimeMotionBlurSample>[]',
      ),
      isFalse,
    );
  });

  test('stage5 does not use snapshot overlay for temporal Motion Blur',
      () async {
    final nativeEngine = await stage5NativeScrubEngineFile.readAsString();
    final preview = await stage5PreviewPlatformViewFile.readAsString();
    final scrubOverlay = await stage5ScrubOverlayTextureViewFile.readAsString();

    expect(nativeEngine.contains('motionBlurSigmaPx'), isFalse);
    expect(nativeEngine.contains('previousMotionBlurSamples'), isFalse);
    expect(nativeEngine.contains('Stage5TemporalMotionBlurRenderer'), isFalse);
    expect(
        nativeEngine.contains('temporalMotionBlurRenderer.render('), isFalse);
    expect(nativeEngine.contains('lockCanvas(null)'), isFalse);
    expect(nativeEngine.contains('getFrameAtTime'), isFalse);
    expect(preview.contains('runtimeMotionBlurSigmaPx'), isFalse);
    expect(preview.contains('runtimeMotionBlurSamples'), isFalse);
    expect(
      preview.contains('maxOf(\n                runtimeGaussianBlurSigmaPx'),
      isFalse,
    );
    expect(
      preview.contains(
        'transformMatrix3x3 = if (motionBlurActive) null else transformMatrix3x3',
      ),
      isFalse,
    );
    expect(preview.contains('Stage5MotionBlurCompositeView'), isFalse);
    expect(preview.contains('refreshMotionBlurComposite'), isFalse);
    expect(preview.contains('snapshotBitmap'), isFalse);
    expect(scrubOverlay.contains('getBitmap('), isFalse);
    expect(scrubOverlay.contains('snapshotBitmap'), isFalse);
    expect(scrubOverlay.contains('setMotionCompositeSuppressed'), isFalse);
  });

  test(
      'manual temporal motion blur plans include explicit sample contributions',
      () async {
    final source = await screenFile.readAsString();
    expect(source.contains('sampleContributions'), isTrue);
    expect(source.contains("'sourceRole':"), isFalse);
    expect(
        source.contains('_sourcePositionMsForWindowAndTimelineTime('), isTrue);
    expect(
        source.contains('_manualTransitionProgressForTimelineTimeMs('), isTrue);
  });

  test('manual temporal motion blur plans read trueframe core sampling plan',
      () async {
    final source = await screenFile.readAsString();
    expect(
      source.contains('_coreMotionBlurSamplingPlanForManualTransition('),
      isTrue,
    );
    expect(
      source.contains('_trueFrameCoreRuntimeEvaluator.buildSamplingPlan('),
      isTrue,
    );
    expect(
      source.contains('trueframe_core_motion_blur_plan_mode:'),
      isTrue,
    );
    expect(source.contains('_stage5MotionBlurSampleOffsetsMs('), isFalse);
    expect(
        source.contains(
            'coreSamplingPlan == null\n        ? _stage5MotionBlurSampleOffsetsMs(policy)'),
        isFalse);
  });

  test('stage6 export requires trueframe execution contract for transitions',
      () async {
    final exportModels = await exportCompositionModelsFile.readAsString();
    final stage6Source = await stage6ExportManagerFile.readAsString();
    expect(exportModels.contains('class ExportTrueFrameExecutionContract'),
        isTrue);
    expect(
      exportModels.contains("'trueFrameExecutionContract':"),
      isTrue,
    );
    expect(
      stage6Source.contains(
        'readTrueFrameExecutionContract(compositionMap["trueFrameExecutionContract"])',
      ),
      isTrue,
    );
    expect(
      stage6Source.contains(
        'TRUEFRAME export execution contract is missing for motion transition export.',
      ),
      isTrue,
    );
  });

  test('trueframe phase I projection expands layer families in core graph',
      () async {
    final source = await trueFrameExecutionGraphAdapterFile.readAsString();
    expect(source.contains('_phaseIExpandedNodes('), isTrue);
    expect(source.contains('phase_i_layer_slice'), isTrue);
    expect(source.contains('TrueFrameExecutionNodeFamily.videoLayer'), isTrue);
    expect(source.contains('TrueFrameExecutionNodeFamily.imageLayer'), isTrue);
    expect(source.contains('TrueFrameExecutionNodeFamily.textLayer'), isTrue);
    expect(source.contains('TrueFrameExecutionNodeFamily.shapeLayer'), isTrue);
  });

  test('trueframe phase I projection removes legacy target-name fallback',
      () async {
    final source = await trueFrameExecutionGraphAdapterFile.readAsString();
    expect(source.contains('target.contains(\'group\')'), isFalse);
    expect(source.contains('target.contains(\'scene-clip\')'), isFalse);
    expect(source.contains('target.contains(\'scene_clip\')'), isFalse);
    expect(source.contains('target.contains(\'adjustment\')'), isFalse);
    expect(source.contains('target.contains(\'effectcontrol\')'), isFalse);
    expect(source.contains('trueframe_phase_i_family_legacy_target_fallback'),
        isFalse);
  });

  test('trueframe runtime evaluator carries resolved layer families', () async {
    final source = await trueFrameCoreRuntimeEvaluatorFile.readAsString();
    expect(source.contains('_phaseILayerFamilies'), isTrue);
    expect(source.contains('resolvedLayerFamilies'), isTrue);
    expect(source.contains('trueframe_node_layer_families:'), isTrue);
  });

  test('screen routes professional preview via trueframe node-family contract',
      () async {
    final source = await screenFile.readAsString();
    expect(
        source.contains('_trueFrameLayerFamiliesForActiveTransition('), isTrue);
    expect(
        source.contains('_trueFrameRenderBackend.routeNodeFamilies('), isTrue);
    expect(source.contains('_trueFrameRenderBackend.routeManualTransition('),
        isFalse);
    expect(
        source.contains('TrueFrameRenderOwner.professionalCompositor'), isTrue);
  });

  test('trueframe backend does not expose transition-only route api', () async {
    final source = await trueFrameRenderBackendFile.readAsString();
    expect(source.contains('routeManualTransition('), isFalse);
    expect(source.contains('routeNodeFamilies('), isTrue);
  });

  test('manual transition Motion Blur remains one timeline effect', () async {
    final source = await screenFile.readAsString();
    expect(source.contains('_manualMotionBlurLaneIds'), isFalse);
    final laneLibraryStart = source.indexOf(
      'static const Map<String, _TransitionFocusLaneSpec> _transitionLaneLibrary',
    );
    expect(laneLibraryStart, isNonNegative);
    final laneLibraryEnd = source.indexOf(
      'static const Set<String> _legacyManualMotionBlurSettingLaneIds',
      laneLibraryStart,
    );
    expect(laneLibraryEnd, greaterThan(laneLibraryStart));
    final laneLibraryBody = source.substring(laneLibraryStart, laneLibraryEnd);
    expect(laneLibraryBody.contains("'motion_blur': _TransitionFocusLaneSpec"),
        isTrue);
    for (final settingLaneId in <String>[
      'motion_blur_amount',
      'motion_blur_shutter_angle',
      'motion_blur_shutter_phase',
      'motion_blur_samples',
      'motion_blur_adaptive_samples',
      'motion_blur_max_trail',
    ]) {
      expect(
        laneLibraryBody.contains("'$settingLaneId': _TransitionFocusLaneSpec"),
        isFalse,
      );
    }
  });

  test('manual transition exposes channel-scoped motion blur modifiers',
      () async {
    final source = await screenFile.readAsString();
    expect(source.contains('_manualTransitionMotionModifierItems'), isTrue);
    expect(source.contains("'transform.motion_blur': _TransitionFocusLaneSpec"),
        isTrue);
    expect(source.contains("'position.motion_blur': _TransitionFocusLaneSpec"),
        isTrue);
    expect(source.contains("'scale.motion_blur': _TransitionFocusLaneSpec"),
        isTrue);
    expect(source.contains("'rotation.motion_blur': _TransitionFocusLaneSpec"),
        isTrue);
    expect(source.contains('onAnimationLaneModifierAdd'), isTrue);
    expect(source.contains('animationModifierSourceLaneIds'), isTrue);
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
    expect(source.contains("'manualTransformMotionBlur'"), isTrue);
    expect(source.contains("'manualTransform'"), isFalse);
    expect(source.contains('_manualTransitionNativeParameters('), isFalse);
    expect(source.contains('_isLegacyTriangularBlackMixLane('), isFalse);
    expect(
      source.contains(
        "TimelineTransitionPreset.manual => 'manualTransformMotionBlur'",
      ),
      isTrue,
    );
  });

  test('manual temporal blur suppresses Stage5 only after first surface frame',
      () async {
    final source = await screenFile.readAsString();
    final surfaceSource =
        await professionalTransitionSurfaceFile.readAsString();
    final nativePreviewStart =
        source.indexOf('Widget _buildNativePreviewSurface({');
    expect(nativePreviewStart, isNonNegative);
    final nativePreviewEnd =
        source.indexOf('Widget? _buildPreviewOverlay({', nativePreviewStart);
    expect(nativePreviewEnd, greaterThan(nativePreviewStart));
    final nativePreviewBody =
        source.substring(nativePreviewStart, nativePreviewEnd);
    expect(
      nativePreviewBody.contains(
        '_manualTransitionTemporalMotionBlurPlanIsActive(',
      ),
      isTrue,
    );
    expect(
      nativePreviewBody.contains(
        '_professionalTransitionSurfaceHasPresented(',
      ),
      isTrue,
    );

    final previewOverlayStart =
        source.indexOf('Widget? _buildPreviewOverlay({');
    expect(previewOverlayStart, isNonNegative);
    final previewOverlayEnd = source.indexOf(
      '@override\n  Widget build(BuildContext context)',
      previewOverlayStart,
    );
    expect(previewOverlayEnd, greaterThan(previewOverlayStart));
    final previewOverlayBody =
        source.substring(previewOverlayStart, previewOverlayEnd);
    expect(
      previewOverlayBody.contains(
        '_handleProfessionalTransitionSurfacePresentationChanged(',
      ),
      isTrue,
    );
    expect(
      surfaceSource.contains(
        'professionalTransitionSurfaceOpacityForPresentedState(',
      ),
      isTrue,
    );
    expect(
      surfaceSource.contains('opacity: _hasPresentedFrame ? 1.0 : 0.0'),
      isFalse,
    );
  });

  test('professional compositor owns visible temporal blur trails', () async {
    final source = await professionalTransitionCompositorFile.readAsString();
    expect(
      source.contains('writerTrailContributionCount'),
      isTrue,
    );
    expect(
      source.contains('val normalizedWeight = (sampleWeight / totalWeight)'),
      isTrue,
    );
    expect(
      source.contains('val temporalMix = blendAmount * normalizedWeight'),
      isTrue,
    );
    expect(
      source.contains(
          'canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)'),
      isTrue,
    );
  });

  test('manual temporal blur binds native pixel output before presentation',
      () async {
    final source = await professionalTransitionCompositorFile.readAsString();
    final frameBufferStart =
        source.lastIndexOf('fun planTransitionPixelFrameBuffer(');
    expect(frameBufferStart, isNonNegative);
    final frameBufferBody = source.substring(
      frameBufferStart,
      (frameBufferStart + 7000).clamp(0, source.length),
    );
    expect(frameBufferBody.contains('writerBackedPixelOutput'), isTrue);
    expect(
      frameBufferBody.contains(
        'if (writerBackedPixelOutput) {\n'
        '                mapOf(',
      ),
      isTrue,
    );
    expect(
      frameBufferBody.contains(
        '"outputTarget" to "nativeTransitionCanvasSurface"',
      ),
      isTrue,
    );
    expect(
      frameBufferBody
          .contains('"outputFramebufferBound" to outputFramebufferBound'),
      isTrue,
    );

    final writerStart =
        source.lastIndexOf('fun planTransitionPixelFrameBufferWriter(');
    expect(writerStart, isNonNegative);
    final writerEnd = source.indexOf(
        'private fun writeTemporalVideoPixelsToFrameBuffer(', writerStart);
    expect(writerEnd, greaterThan(writerStart));
    final writerBody = source.substring(writerStart, writerEnd);
    expect(writerBody.contains('"writerCreated" to writerCreated'), isTrue);
    expect(writerBody.contains('"writerBound" to writerBoundToFrameBuffer'),
        isTrue);

    final interactiveStart = source.indexOf('fun renderInteractiveFrame(');
    expect(interactiveStart, isNonNegative);
    final interactiveEnd =
        source.indexOf('private fun hasRequiredField(', interactiveStart);
    expect(interactiveEnd, greaterThan(interactiveStart));
    final interactiveBody = source.substring(interactiveStart, interactiveEnd);
    expect(
      interactiveBody.contains(
        'native_transition_motion_blur_pixel_delta_missing',
      ),
      isTrue,
    );
    expect(
        interactiveBody.contains('"writerCreated" to writerCreated'), isTrue);
    expect(interactiveBody.contains('"writerBound" to writerBound'), isTrue);
    expect(
      interactiveBody
          .contains('"outputFramebufferBound" to outputFramebufferBound'),
      isTrue,
    );
    expect(interactiveBody.contains('"rendererSampleCount" to sampleCount'),
        isTrue);
    expect(interactiveBody.contains('"rendererAmount" to motionBlurAmount'),
        isTrue);
  });

  test('manual motion blur debug gate is disabled in production by default',
      () async {
    final source = await screenFile.readAsString();
    final gateStart = source.indexOf('TRUEFRAME_DEBUG_VISUAL_GATE_ENABLED');
    expect(gateStart, isNonNegative);
    final gateBody = source.substring(
      gateStart,
      (gateStart + 900).clamp(0, source.length),
    );
    expect(gateBody.contains('TRUEFRAME_DEBUG_VISUAL_GATE_ENABLED'), isTrue);
    expect(
      gateBody.contains('TRUEFRAME_FORCE_SYNTHETIC_MOTION_BLUR_ENABLED'),
      isTrue,
    );
    expect(gateBody.contains("'forcedVisualTestPattern': true,"), isFalse);
    expect(gateBody.contains("'forcedSyntheticMotionBlur': true,"), isFalse);
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

  test(
      'trueframe backend requires production texture readiness for manual temporal blur',
      () async {
    final source = await trueFrameRenderBackendFile.readAsString();
    expect(
      source.contains(
          'manual_temporal_blur_production_texture_renderer_not_ready'),
      isTrue,
    );
    expect(source.contains('hasProductionTextureRenderer'), isTrue);
    expect(source.contains('hasRealFrameProof'), isTrue);
    expect(source.contains('hasPresentedFirstFrame'), isFalse);
  });

  test('professional surface enforces production real-frame proof contract',
      () async {
    final source = await professionalTransitionSurfaceFile.readAsString();
    expect(source.contains('result.rendererPath == \'productionTexture\''),
        isTrue);
    expect(source.contains('result.sourceProviderMode == \'decodedTexture\''),
        isTrue);
    expect(source.contains('result.realFrameProof'), isTrue);
    expect(source.contains('TF_MB_REALTIME_OWNER_PROOF'), isTrue);
  });

  test(
      'native interactive renderer reads production ownership path and keeps debug fallback',
      () async {
    final source = await professionalTransitionCompositorFile.readAsString();
    expect(source.contains('motionBlurVisibilityGate'), isTrue);
    expect(source.contains('stringValue("rendererPath")'), isTrue);
    expect(source.contains('?: "debugBitmapProof"'), isTrue);
    expect(source.contains('stringValue("sourceProviderMode")'), isTrue);
    expect(source.contains('?: "bitmapProof"'), isTrue);
    expect(source.contains('production_texture_renderer_not_ready'), isTrue);
    expect(source.contains('"realFrameProof" to realFrameProof'), isTrue);
  });
}
