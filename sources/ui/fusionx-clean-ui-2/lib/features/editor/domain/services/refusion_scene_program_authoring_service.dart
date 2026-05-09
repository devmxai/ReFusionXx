import 'package:flutter/foundation.dart';

import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';
import '../models/professional_motion_text_models.dart';
import '../models/refusion_scene_program_models.dart';
import 'professional_scene_timing_contract.dart';
import 'refusion_scene_program_import_service.dart';
import 'refusion_scene_program_lowerer.dart';
import 'scene_motion_continuity_validator.dart';
import 'scene_icon_alignment_validator.dart';
import 'scene_program_component_contract.dart';
import 'scene_program_layout_contract.dart';
import 'scene_visual_frame_qa_validator.dart';

@immutable
class ReFusionSceneProgramAuthoringRequest {
  const ReFusionSceneProgramAuthoringRequest({
    required this.source,
    this.fileName,
    this.projectId,
    this.sceneId,
    this.canvasSize = const MotionSize2D(width: 1080, height: 1920),
  });

  final String source;
  final String? fileName;
  final String? projectId;
  final String? sceneId;
  final MotionSize2D canvasSize;
}

@immutable
class ReFusionSceneProgramAuthoringResult {
  ReFusionSceneProgramAuthoringResult({
    required List<ReFusionSceneProgramIssue> issues,
    this.program,
    this.project,
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
    List<MotionTextAnimationBindingModel> textAnimationBindings =
        const <MotionTextAnimationBindingModel>[],
  })  : issues = List.unmodifiable(issues),
        channels = List.unmodifiable(channels),
        textAnimationBindings = List.unmodifiable(textAnimationBindings);

  final ReFusionSceneProgram? program;
  final MotionProjectModel? project;
  final List<MotionPropertyChannelModel> channels;
  final List<MotionTextAnimationBindingModel> textAnimationBindings;
  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid =>
      program != null &&
      project != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );

  bool get hasWarnings => issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.warning,
      );
}

class ReFusionSceneProgramAuthoringService {
  const ReFusionSceneProgramAuthoringService({
    ReFusionSceneProgramImportService importService =
        const ReFusionSceneProgramImportService(),
    ProfessionalSceneTimingContractValidator timingContractValidator =
        const ProfessionalSceneTimingContractValidator(),
    SceneProgramLayoutContractValidator layoutContractValidator =
        const SceneProgramLayoutContractValidator(),
    SceneProgramComponentContractValidator componentContractValidator =
        const SceneProgramComponentContractValidator(),
    SceneIconAlignmentValidator iconAlignmentValidator =
        const SceneIconAlignmentValidator(),
    SceneMotionContinuityValidator motionContinuityValidator =
        const SceneMotionContinuityValidator(),
    SceneVisualFrameQaValidator visualFrameQaValidator =
        const SceneVisualFrameQaValidator(),
    ReFusionSceneProgramLowerer lowerer = const ReFusionSceneProgramLowerer(),
  })  : _importService = importService,
        _timingContractValidator = timingContractValidator,
        _layoutContractValidator = layoutContractValidator,
        _componentContractValidator = componentContractValidator,
        _iconAlignmentValidator = iconAlignmentValidator,
        _motionContinuityValidator = motionContinuityValidator,
        _visualFrameQaValidator = visualFrameQaValidator,
        _lowerer = lowerer;

  final ReFusionSceneProgramImportService _importService;
  final ProfessionalSceneTimingContractValidator _timingContractValidator;
  final SceneProgramLayoutContractValidator _layoutContractValidator;
  final SceneProgramComponentContractValidator _componentContractValidator;
  final SceneIconAlignmentValidator _iconAlignmentValidator;
  final SceneMotionContinuityValidator _motionContinuityValidator;
  final SceneVisualFrameQaValidator _visualFrameQaValidator;
  final ReFusionSceneProgramLowerer _lowerer;

  ReFusionSceneProgramAuthoringResult importSceneProgram(
    ReFusionSceneProgramAuthoringRequest request,
  ) {
    final importResult = _importService.validate(
      source: request.source,
      fileName: request.fileName,
    );
    if (!importResult.isValid || importResult.program == null) {
      return ReFusionSceneProgramAuthoringResult(
        program: importResult.program,
        issues: importResult.issues,
      );
    }

    final timingResult = _timingContractValidator.validateSceneProgram(
      importResult.program!,
    );
    if (!timingResult.isValid) {
      return ReFusionSceneProgramAuthoringResult(
        program: importResult.program,
        issues: <ReFusionSceneProgramIssue>[
          ...importResult.issues,
          ...timingResult.issues,
        ],
      );
    }

    final layoutResult = _layoutContractValidator.validate(
      importResult.program!,
    );
    if (!layoutResult.isValid) {
      return ReFusionSceneProgramAuthoringResult(
        program: importResult.program,
        issues: <ReFusionSceneProgramIssue>[
          ...importResult.issues,
          ...timingResult.issues,
          ...layoutResult.issues,
        ],
      );
    }

    final componentResult = _componentContractValidator.validate(
      importResult.program!,
    );
    if (!componentResult.isValid) {
      return ReFusionSceneProgramAuthoringResult(
        program: importResult.program,
        issues: <ReFusionSceneProgramIssue>[
          ...importResult.issues,
          ...timingResult.issues,
          ...layoutResult.issues,
          ...componentResult.issues,
        ],
      );
    }

    final iconAlignmentResult = _iconAlignmentValidator.validate(
      importResult.program!,
    );
    if (!iconAlignmentResult.isValid) {
      return ReFusionSceneProgramAuthoringResult(
        program: importResult.program,
        issues: <ReFusionSceneProgramIssue>[
          ...importResult.issues,
          ...timingResult.issues,
          ...layoutResult.issues,
          ...componentResult.issues,
          ...iconAlignmentResult.issues,
        ],
      );
    }

    final continuityResult = _motionContinuityValidator.validate(
      importResult.program!,
    );
    if (!continuityResult.isValid) {
      return ReFusionSceneProgramAuthoringResult(
        program: importResult.program,
        issues: <ReFusionSceneProgramIssue>[
          ...importResult.issues,
          ...timingResult.issues,
          ...layoutResult.issues,
          ...componentResult.issues,
          ...iconAlignmentResult.issues,
          ...continuityResult.issues,
        ],
      );
    }

    final visualQaResult = _visualFrameQaValidator.validate(
      importResult.program!,
    );
    if (!visualQaResult.isValid) {
      return ReFusionSceneProgramAuthoringResult(
        program: importResult.program,
        issues: <ReFusionSceneProgramIssue>[
          ...importResult.issues,
          ...timingResult.issues,
          ...layoutResult.issues,
          ...componentResult.issues,
          ...iconAlignmentResult.issues,
          ...continuityResult.issues,
          ...visualQaResult.issues,
        ],
      );
    }

    final loweringResult = _lowerer.lower(
      ReFusionSceneProgramLoweringRequest(
        program: importResult.program!,
        projectId: request.projectId,
        sceneId: request.sceneId,
        canvasSize: request.canvasSize,
      ),
    );
    return ReFusionSceneProgramAuthoringResult(
      program: importResult.program,
      project: loweringResult.project,
      channels: loweringResult.channels,
      textAnimationBindings: loweringResult.textAnimationBindings,
      issues: <ReFusionSceneProgramIssue>[
        ...importResult.issues,
        ...timingResult.issues,
        ...layoutResult.issues,
        ...componentResult.issues,
        ...iconAlignmentResult.issues,
        ...continuityResult.issues,
        ...visualQaResult.issues,
        ...loweringResult.issues,
      ],
    );
  }
}
