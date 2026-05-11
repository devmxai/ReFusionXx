import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/refusion_motion_director_models.dart';
import '../models/refusion_scene_program_models.dart';
import '../models/professional_motion_models.dart';
import '../services/refusion_motion_director_plan_import_service.dart';
import '../services/refusion_motion_director_scene_program_compiler.dart';
import '../services/refusion_scene_program_authoring_service.dart';
import '../services/refusion_scene_program_import_service.dart';
import '../services/scene_program_apply_transaction.dart';

@immutable
class RefusionMcpDirectorCompileResult {
  RefusionMcpDirectorCompileResult({
    required List<ReFusionMotionDirectorIssue> issues,
    this.plan,
    this.program,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionMotionDirectorIssue> issues;
  final ReFusionMotionDirectorPlan? plan;
  final ReFusionSceneProgram? program;

  bool get isValid =>
      plan != null &&
      program != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class RefusionMcpSceneProgramTools {
  const RefusionMcpSceneProgramTools({
    ReFusionSceneProgramImportService importService =
        const ReFusionSceneProgramImportService(),
    ReFusionSceneProgramAuthoringService authoringService =
        const ReFusionSceneProgramAuthoringService(),
    SceneProgramApplyTransaction applyTransaction =
        const SceneProgramApplyTransaction(),
    ReFusionMotionDirectorPlanImportService directorPlanImportService =
        const ReFusionMotionDirectorPlanImportService(),
    ReFusionMotionDirectorSceneProgramCompiler directorCompiler =
        const ReFusionMotionDirectorSceneProgramCompiler(),
  })  : _importService = importService,
        _authoringService = authoringService,
        _applyTransaction = applyTransaction,
        _directorPlanImportService = directorPlanImportService,
        _directorCompiler = directorCompiler;

  final ReFusionSceneProgramImportService _importService;
  final ReFusionSceneProgramAuthoringService _authoringService;
  final SceneProgramApplyTransaction _applyTransaction;
  final ReFusionMotionDirectorPlanImportService _directorPlanImportService;
  final ReFusionMotionDirectorSceneProgramCompiler _directorCompiler;

  ReFusionSceneProgramImportResult validateSceneProgram({
    required String source,
    String? fileName,
  }) {
    return _importService.validate(
      source: source,
      fileName: fileName,
    );
  }

  ReFusionSceneProgramAuthoringResult authorSceneProgram({
    required String source,
    String? fileName,
    String? projectId,
    String? sceneId,
    MotionSize2D canvasSize = const MotionSize2D(width: 1080, height: 1920),
  }) {
    return _authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: source,
        fileName: fileName,
        projectId: projectId,
        sceneId: sceneId,
        canvasSize: canvasSize,
      ),
    );
  }

  SceneProgramApplyTransactionResult? applySceneProgram(
    SceneProgramApplyTransactionRequest request,
  ) {
    return _applyTransaction.apply(request);
  }

  RefusionMcpDirectorCompileResult compileDirectorPlan({
    required String source,
  }) {
    final decoded = _decodeJson(source);
    if (decoded == null) {
      return RefusionMcpDirectorCompileResult(
        issues: const <ReFusionMotionDirectorIssue>[
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Director plan source must be valid JSON.',
            path: 'directorPlan',
          ),
        ],
      );
    }
    final importResult = _directorPlanImportService.importFromJson(decoded);
    if (!importResult.isValid || importResult.plan == null) {
      return RefusionMcpDirectorCompileResult(
        issues: importResult.issues,
        plan: importResult.plan,
      );
    }
    final compileResult = _directorCompiler.compile(importResult.plan!);
    return RefusionMcpDirectorCompileResult(
      plan: importResult.plan,
      program: compileResult.program,
      issues: <ReFusionMotionDirectorIssue>[
        ...importResult.issues,
        ...compileResult.issues,
      ],
    );
  }

  Object? _decodeJson(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }
}
