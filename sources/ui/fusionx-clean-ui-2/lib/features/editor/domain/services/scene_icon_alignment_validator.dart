import '../models/refusion_scene_program_models.dart';
import 'scene_icon_alignment_engine.dart';
import 'scene_optical_bounds.dart';

const String kSceneIconAlignmentProofTag = 'TF_SCENE_ICON_ALIGNMENT_PROOF';

class SceneIconAlignmentValidationResult {
  SceneIconAlignmentValidationResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneIconAlignmentValidator {
  const SceneIconAlignmentValidator({
    this.maxCenterDeltaPx = 3.0,
    this.maxCenterDeltaRatio = 0.05,
    this.buttonIconMaxCenterDeltaPx = 1.0,
    this.appGlyphMaxCenterDeltaPx = 1.5,
    SceneIconAlignmentEngine alignmentEngine = const SceneIconAlignmentEngine(),
  }) : _alignmentEngine = alignmentEngine;

  final double maxCenterDeltaPx;
  final double maxCenterDeltaRatio;
  final double buttonIconMaxCenterDeltaPx;
  final double appGlyphMaxCenterDeltaPx;
  final SceneIconAlignmentEngine _alignmentEngine;

  SceneIconAlignmentValidationResult validate(ReFusionSceneProgram program) {
    final issues = <ReFusionSceneProgramIssue>[];
    var evaluated = 0;
    var errors = 0;
    for (final layer in program.layers) {
      final elementsById = <String, ReFusionSceneProgramElement>{
        for (final element in layer.elements) element.id: element,
      };
      for (final element in layer.elements) {
        if (!SceneOpticalBounds.looksLikeAlignableIcon(element)) {
          continue;
        }
        final rawParentId = element.properties['parentId'];
        if (rawParentId is! String || rawParentId.trim().isEmpty) {
          continue;
        }
        final parentId = rawParentId.trim();
        final parent = elementsById[parentId] ??
            _findParentAcrossLayers(program: program, parentId: parentId);
        if (parent == null) {
          continue;
        }
        if (_shouldSkipAccessorySlotAlignment(
          child: element,
          parent: parent,
          parentId: parentId,
        )) {
          continue;
        }
        final parentRect = SceneOpticalBounds.rectFor(parent);
        final rawIconRect = SceneOpticalBounds.rectFor(element);
        if (parentRect == null || rawIconRect == null) {
          continue;
        }
        final iconRect = _resolveIconRect(
          element: element,
          parentRect: parentRect,
          rawIconRect: rawIconRect,
        );
        final profile = SceneOpticalBounds.profileFor(element);
        final measurement = _alignmentEngine.measure(
          parentRect: parentRect,
          iconRect: iconRect,
          profile: profile,
        );
        final allowedDelta = _maxAllowedCenterDelta(
          parentMinDimension: parentRect.minDimension,
          profile: profile,
          element: element,
          parent: parent,
        );
        final centerAligned = measurement.centerDeltaDistance <= allowedDelta;
        final safeZoneSatisfied = measurement.safeZoneSatisfied;
        final passed = centerAligned && safeZoneSatisfied;
        evaluated += 1;
        if (!passed) {
          errors += 1;
        }

        final fallbackReason =
            passed ? 'none' : (!centerAligned ? 'center_delta' : 'safe_zone');
        final severity = passed
            ? ReFusionSceneProgramIssueSeverity.info
            : ReFusionSceneProgramIssueSeverity.error;
        issues.add(
          ReFusionSceneProgramIssue(
            severity: severity,
            message: '$kSceneIconAlignmentProofTag '
                'sceneId=${program.name} '
                'layerId=${layer.id} '
                'targetId=${element.id} '
                'parentId=$parentId '
                'profileId=${profile.id} '
                'centerDeltaPx=${measurement.centerDeltaDistance.toStringAsFixed(2)} '
                'allowedDeltaPx=${allowedDelta.toStringAsFixed(2)} '
                'safeZoneSatisfied=${safeZoneSatisfied.toString()} '
                'safeZoneMinX=${measurement.requiredSafeMarginX.toStringAsFixed(2)} '
                'safeZoneMinY=${measurement.requiredSafeMarginY.toStringAsFixed(2)} '
                'actualMinMarginX=${measurement.minMarginX.toStringAsFixed(2)} '
                'actualMinMarginY=${measurement.minMarginY.toStringAsFixed(2)} '
                'fallbackReason=$fallbackReason',
            path: 'layers.${layer.id}.elements.${element.id}',
          ),
        );
      }
    }

    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneIconAlignmentProofTag '
            'sceneId=${program.name} '
            'evaluated=$evaluated '
            'errors=$errors '
            'status=${errors == 0 ? 'pass' : 'fail'}',
        path: r'$',
      ),
    );

    return SceneIconAlignmentValidationResult(issues: issues);
  }

  double _maxAllowedCenterDelta({
    required double parentMinDimension,
    required SceneOpticalBoundsProfile profile,
    required ReFusionSceneProgramElement element,
    required ReFusionSceneProgramElement parent,
  }) {
    final profileRatio = profile.maxCenterDeltaRatio ?? maxCenterDeltaRatio;
    final profilePx = profile.maxCenterDeltaPx ?? maxCenterDeltaPx;
    final baseRatioAllowance = parentMinDimension * profileRatio;
    var allowed =
        baseRatioAllowance > profilePx ? baseRatioAllowance : profilePx;

    final childRole = _normalize(
      _readString(element.properties, const <String>['layoutRole', 'role']) ??
          '',
    );
    final parentRole = _normalize(
      _readString(parent.properties, const <String>['layoutRole', 'role']) ??
          '',
    );
    final isButtonIcon = childRole.contains('accessory') ||
        parentRole.contains('button') ||
        _normalize(parent.id).contains('button');
    if (isButtonIcon && allowed > buttonIconMaxCenterDeltaPx) {
      allowed = buttonIconMaxCenterDeltaPx;
    }
    final glyph = (element.text ?? '').trim().toUpperCase();
    if (glyph == 'R' && allowed > appGlyphMaxCenterDeltaPx) {
      allowed = appGlyphMaxCenterDeltaPx;
    }
    return allowed;
  }

  ReFusionSceneProgramElement? _findParentAcrossLayers({
    required ReFusionSceneProgram program,
    required String parentId,
  }) {
    for (final layer in program.layers) {
      for (final element in layer.elements) {
        if (element.id == parentId) {
          return element;
        }
      }
    }
    return null;
  }

  bool _shouldSkipAccessorySlotAlignment({
    required ReFusionSceneProgramElement child,
    required ReFusionSceneProgramElement parent,
    required String parentId,
  }) {
    final childRole = _normalize(
      _readString(
            child.properties,
            const <String>['layoutRole', 'role'],
          ) ??
          '',
    );
    final parentRole = _normalize(
      _readString(
            parent.properties,
            const <String>['layoutRole', 'role'],
          ) ??
          '',
    );
    final normalizedParentId = _normalize(parentId);
    final isPromptShellParent = normalizedParentId.contains('promptshell') ||
        normalizedParentId.contains('inputbar');
    final accessoryRole =
        childRole == 'leadingaccessory' || childRole == 'trailingaccessory';
    final childHasIconToken = _readString(
          child.properties,
          const <String>['icon', 'iconName', 'glyph', 'symbol'],
        ) !=
        null;
    final childKind = _normalize(child.kind);
    if (accessoryRole && parentRole == 'container') {
      return true;
    }

    if (isPromptShellParent &&
        parentRole == 'container' &&
        (accessoryRole || childKind == 'icon' || childHasIconToken)) {
      return true;
    }
    return false;
  }

  SceneOpticalRect _resolveIconRect({
    required ReFusionSceneProgramElement element,
    required SceneOpticalRect parentRect,
    required SceneOpticalRect rawIconRect,
  }) {
    final position = element.properties['position'];
    if (position is! Map<String, Object?>) {
      return rawIconRect;
    }
    final localX = _readDouble(position['x']);
    final localY = _readDouble(position['y']);
    if (localX == null || localY == null) {
      return rawIconRect;
    }
    final parentIsOffset =
        parentRect.centerX.abs() > (parentRect.width / 2.0) + 20.0 ||
            parentRect.centerY.abs() > (parentRect.height / 2.0) + 20.0;
    final localWithinParent = localX.abs() <= (parentRect.width / 2.0) + 1.0 &&
        localY.abs() <= (parentRect.height / 2.0) + 1.0;
    if (!parentIsOffset || !localWithinParent) {
      return rawIconRect;
    }
    return SceneOpticalRect(
      centerX: parentRect.centerX + localX,
      centerY: parentRect.centerY + localY,
      width: rawIconRect.width,
      height: rawIconRect.height,
    );
  }

  String? _readString(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  double? _readDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  String _normalize(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').toLowerCase();
  }
}
