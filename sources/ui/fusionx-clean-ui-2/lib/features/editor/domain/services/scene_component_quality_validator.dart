import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import 'scene_coordinate_system.dart';
import 'scene_design_scorecard.dart';
import 'scene_evaluation_pipeline.dart';

class SceneComponentQualityValidationResult {
  SceneComponentQualityValidationResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List<ReFusionSceneProgramIssue>.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneComponentQualityValidator {
  const SceneComponentQualityValidator({
    SceneEvaluationPipeline evaluationPipeline =
        const SceneEvaluationPipeline(),
    SceneDesignScorecardEvaluator designScorecardEvaluator =
        const SceneDesignScorecardEvaluator(),
  })  : _evaluationPipeline = evaluationPipeline,
        _designScorecardEvaluator = designScorecardEvaluator;

  static const String proofTag = 'TF_SCENE_COMPONENT_QUALITY_GATE_PROOF';

  final SceneEvaluationPipeline _evaluationPipeline;
  final SceneDesignScorecardEvaluator _designScorecardEvaluator;

  SceneComponentQualityValidationResult validate(ReFusionSceneProgram program) {
    final issues = <ReFusionSceneProgramIssue>[];
    final elementRefs = _collectElementRefs(program);
    final elementById = <String, _ElementRef>{
      for (final ref in elementRefs) ref.element.id: ref,
    };
    final strictProfessional = _isProfessionalStrict(program, elementRefs);

    if (strictProfessional) {
      _lintRawLayerPromptBarBypass(
        elementRefs: elementRefs,
        issues: issues,
      );
      _lintPromptSplitShellFrame(
        elementRefs: elementRefs,
        issues: issues,
      );
      _lintPromptBorders(
        elementRefs: elementRefs,
        issues: issues,
      );
      _lintPromptIconContracts(
        elementRefs: elementRefs,
        issues: issues,
      );
      _lintLooseCoordinates(
        elementRefs: elementRefs,
        elementById: elementById,
        issues: issues,
      );
      _lintFadeOnlyPatterns(
        program: program,
        elementRefs: elementRefs,
        issues: issues,
      );
      _lintSiblingMotionVariety(
        program: program,
        elementRefs: elementRefs,
        elementById: elementById,
        issues: issues,
      );
      _lintGroupExitCoherence(
        program: program,
        elementRefs: elementRefs,
        issues: issues,
      );
    }

    final probeTimes = _collectProbeTimes(program);
    for (final probeTime in probeTimes) {
      _lintProbe(
        program: program,
        elementRefsById: elementById,
        timelineTimeMs: probeTime,
        issues: issues,
      );
    }
    final designScorecardResult = _designScorecardEvaluator.evaluate(
      program,
      strictProfessional: strictProfessional,
    );
    issues.addAll(designScorecardResult.issues);

    final structuralErrorCount = issues
        .where(
          (issue) =>
              issue.severity == ReFusionSceneProgramIssueSeverity.error &&
              issue.message.startsWith('COMPONENT_QA::'),
        )
        .length;
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$proofTag '
            'strictProfessional=${strictProfessional.toString()} '
            'probeCount=${probeTimes.length} '
            'issueCount=${issues.length} '
            'structuralErrorCount=$structuralErrorCount',
        path: 'scene.componentQuality',
      ),
    );

    return SceneComponentQualityValidationResult(issues: issues);
  }

  void _lintProbe({
    required ReFusionSceneProgram program,
    required Map<String, _ElementRef> elementRefsById,
    required int timelineTimeMs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final evaluation = _evaluationPipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: program,
        globalTimeMs: timelineTimeMs,
      ),
    );

    final nodesById = evaluation.truth.nodesById;
    for (final node in nodesById.values) {
      if (node.sourceElementId == null) {
        continue;
      }
      final ref = elementRefsById[node.sourceElementId!];
      if (ref == null) {
        continue;
      }
      final parentNodeId = node.parentNodeId;
      if (parentNodeId != null) {
        final parentNode = nodesById[parentNodeId];
        if (parentNode != null) {
          if (node.active && !parentNode.active) {
            issues.add(
              _componentError(
                code: 'CHILD_OUTLIVES_PARENT',
                message:
                    'Child `${node.sourceElementId}` remains active while parent `${parentNode.sourceElementId ?? parentNode.nodeId}` is inactive at ${timelineTimeMs}ms.',
                path: 'layers[${ref.layerIndex}].elements[${ref.elementIndex}]',
                repairPayload: <String, Object?>{
                  'action': 'matchChildLifecycleToParent',
                  'targetElementId': node.sourceElementId,
                  'parentElementId': parentNode.sourceElementId,
                  'timelineTimeMs': timelineTimeMs,
                },
              ),
            );
          }
          if (node.visible && !parentNode.visible) {
            issues.add(
              _componentError(
                code: 'CHILD_VISIBLE_WHILE_PARENT_INVISIBLE',
                message:
                    'Child `${node.sourceElementId}` is visible while parent `${parentNode.sourceElementId ?? parentNode.nodeId}` is hidden at ${timelineTimeMs}ms.',
                path: 'layers[${ref.layerIndex}].elements[${ref.elementIndex}]',
                repairPayload: <String, Object?>{
                  'action': 'inheritParentVisibility',
                  'targetElementId': node.sourceElementId,
                  'parentElementId': parentNode.sourceElementId,
                  'timelineTimeMs': timelineTimeMs,
                },
              ),
            );
          }
        }
      }

      final slotBounds = node.slotBoundsCenter;
      if (slotBounds == null) {
        continue;
      }
      final worldBounds = node.worldBoundsCenter;
      final slotRect = SceneCoordinateSystem.centerRectToViewportRect(
        rect: slotBounds,
        canvas: evaluation.truth.canvas,
      );
      final worldRect = SceneCoordinateSystem.centerRectToViewportRect(
        rect: worldBounds,
        canvas: evaluation.truth.canvas,
      );
      final insideSlot = _containsRect(
        container: slotRect,
        child: worldRect,
        tolerance: 1.0,
      );
      if (insideSlot) {
        continue;
      }
      final nodeType = node.nodeType.trim().toLowerCase();
      if (nodeType == 'text') {
        issues.add(
          _componentError(
            code: 'TEXT_EXCEEDS_TEXT_SLOT',
            message:
                'Text `${node.sourceElementId}` exceeds slot `${node.slotId ?? 'unknown'}` at ${timelineTimeMs}ms.',
            path: 'layers[${ref.layerIndex}].elements[${ref.elementIndex}]',
            repairPayload: <String, Object?>{
              'action': 'fitTextToSlot',
              'targetElementId': node.sourceElementId,
              'slotId': node.slotId,
              'fitPolicy': 'shrinkToFit',
              'timelineTimeMs': timelineTimeMs,
            },
          ),
        );
      } else if (nodeType == 'icon') {
        issues.add(
          _componentError(
            code: 'ICON_EXCEEDS_SLOT',
            message:
                'Icon `${node.sourceElementId}` exceeds slot `${node.slotId ?? 'unknown'}` at ${timelineTimeMs}ms.',
            path: 'layers[${ref.layerIndex}].elements[${ref.elementIndex}]',
            repairPayload: <String, Object?>{
              'action': 'fitIconToSlot',
              'targetElementId': node.sourceElementId,
              'slotId': node.slotId,
              'timelineTimeMs': timelineTimeMs,
            },
          ),
        );
      }
    }
  }

  void _lintRawLayerPromptBarBypass({
    required List<_ElementRef> elementRefs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final promptShells = elementRefs.where((ref) {
      if (_normalize(ref.element.kind) != 'shape') {
        return false;
      }
      final id = _normalize(ref.element.id);
      return id.contains('promptshell') ||
          id.contains('promptbar') ||
          id.contains('inputbar');
    });

    for (final shell in promptShells) {
      final componentType = _componentType(shell.element.properties);
      final componentId = _componentId(shell.element.properties);
      if (componentType != null && componentId != null) {
        continue;
      }
      issues.add(
        _componentError(
          code: 'PROMPT_BAR_SPLIT_SHELL_FRAME',
          message:
              'Prompt shell `${shell.element.id}` is authored as raw layers in professional mode.',
          path: 'layers[${shell.layerIndex}].elements[${shell.elementIndex}]',
          repairPayload: <String, Object?>{
            'action': 'useRuntimeComponent',
            'componentType': 'PromptInputBar',
            'shellElementId': shell.element.id,
          },
        ),
      );
    }
  }

  void _lintPromptSplitShellFrame({
    required List<_ElementRef> elementRefs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final shells = elementRefs.where(_isPromptShell).toList(growable: false);
    if (shells.length < 2) {
      return;
    }
    final byComponentId = <String, List<_ElementRef>>{};
    for (final shell in shells) {
      final componentId =
          _componentId(shell.element.properties) ?? '__prompt-shell-raw__';
      byComponentId.putIfAbsent(componentId, () => <_ElementRef>[]).add(shell);
    }
    for (final entry in byComponentId.entries) {
      final refs = entry.value;
      if (refs.length < 2) {
        continue;
      }
      refs.sort((a, b) => a.layer.startMs.compareTo(b.layer.startMs));
      for (var i = 0; i < refs.length - 1; i += 1) {
        final current = refs[i];
        final next = refs[i + 1];
        final currentEnd = current.layer.startMs + current.layer.durationMs;
        final nextEnd = next.layer.startMs + next.layer.durationMs;
        final overlaps =
            current.layer.startMs < nextEnd && next.layer.startMs < currentEnd;
        if (!overlaps) {
          continue;
        }
        issues.add(
          _componentError(
            code: 'PROMPT_BAR_SPLIT_SHELL_FRAME',
            message:
                'Prompt bar shell is split across overlapping shells `${current.element.id}` and `${next.element.id}`.',
            path: 'layers[${next.layerIndex}].elements[${next.elementIndex}]',
            repairPayload: <String, Object?>{
              'action': 'mergePromptShells',
              'componentId': entry.key,
              'shellIds': <String>[
                current.element.id,
                next.element.id,
              ],
            },
          ),
        );
      }
    }
  }

  void _lintPromptBorders({
    required List<_ElementRef> elementRefs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    for (final ref in elementRefs) {
      if (!_isPromptShell(ref)) {
        continue;
      }
      final borderWidth = _doubleFromMap(
            ref.element.properties,
            const <String>['borderWidth', 'strokeWidth', 'stroke'],
          ) ??
          0.0;
      if (borderWidth >= 1.0) {
        final shellWidth = _doubleFromMap(
          ref.element.properties,
          const <String>['width'],
        );
        final shellHeight = _doubleFromMap(
          ref.element.properties,
          const <String>['height'],
        );
        if (shellWidth == null || shellHeight == null) {
          issues.add(
            _componentError(
              code: 'COMPONENT_INTRINSIC_SIZE_MISSING',
              message:
                  'PromptInputBar shell `${ref.element.id}` is missing intrinsic size (width/height).',
              path: 'layers[${ref.layerIndex}].elements[${ref.elementIndex}]',
              repairPayload: <String, Object?>{
                'action': 'setIntrinsicSize',
                'targetElementId': ref.element.id,
                'width': 860,
                'height': 112,
              },
            ),
          );
          continue;
        }
        final looksCanvasSized =
            shellWidth >= 1000.0 || shellHeight >= 360.0 || shellHeight <= 64.0;
        if (looksCanvasSized) {
          issues.add(
            _componentError(
              code: 'COMPONENT_SIZED_AS_CANVAS',
              message:
                  'PromptInputBar shell `${ref.element.id}` resolved to non-professional bounds ${shellWidth.toStringAsFixed(1)}x${shellHeight.toStringAsFixed(1)}.',
              path: 'layers[${ref.layerIndex}].elements[${ref.elementIndex}]',
              repairPayload: <String, Object?>{
                'action': 'normalizePromptIntrinsicSize',
                'targetElementId': ref.element.id,
                'widthRange': '560-980',
                'heightRange': '84-140',
              },
            ),
          );
        }
        continue;
      }
      issues.add(
        _componentError(
          code: 'BORDER_CONTRACT_NOT_RENDERED',
          message:
              'PromptInputBar shell `${ref.element.id}` must keep visible border (>= 1px).',
          path: 'layers[${ref.layerIndex}].elements[${ref.elementIndex}]',
          repairPayload: <String, Object?>{
            'action': 'setBorderWidth',
            'targetElementId': ref.element.id,
            'borderWidth': 1.0,
          },
        ),
      );
    }
  }

  void _lintPromptIconContracts({
    required List<_ElementRef> elementRefs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final promptEntries = elementRefs.where((ref) {
      final type = _normalize(_componentType(ref.element.properties) ?? '');
      return type == 'promptinputbar';
    }).toList(growable: false);
    if (promptEntries.isEmpty) {
      return;
    }
    final byComponentId = <String, List<_ElementRef>>{};
    for (final entry in promptEntries) {
      final componentId = _componentId(entry.element.properties);
      if (componentId == null || componentId.trim().isEmpty) {
        continue;
      }
      byComponentId.putIfAbsent(componentId, () => <_ElementRef>[]).add(entry);
    }
    for (final entry in byComponentId.entries) {
      final refs = entry.value;
      final hasPlus = refs.any((ref) {
        if (_normalize(ref.element.kind) != 'icon') {
          return false;
        }
        final icon = _normalize(
          _stringFromMap(ref.element.properties, const <String>['icon']) ?? '',
        );
        return icon == 'plus';
      });
      final hasMic = refs.any((ref) {
        if (_normalize(ref.element.kind) != 'icon') {
          return false;
        }
        final icon = _normalize(
          _stringFromMap(ref.element.properties, const <String>['icon']) ?? '',
        );
        return icon == 'mic' || icon == 'microphone';
      });
      final hasTrailingVoice = refs.any((ref) {
        if (_normalize(ref.element.kind) != 'icon') {
          return false;
        }
        final icon = _normalize(
          _stringFromMap(ref.element.properties, const <String>['icon']) ?? '',
        );
        return icon == 'volume' ||
            icon == 'audiowave' ||
            icon == 'waveform' ||
            icon == 'speaker' ||
            icon == 'send' ||
            icon == 'arrowup';
      });
      if (hasPlus && hasMic && hasTrailingVoice) {
        continue;
      }
      final anchor = refs.first;
      issues.add(
        _componentError(
          code: 'ICON_CONTRACT_NOT_RENDERED',
          message:
              'PromptInputBar `${entry.key}` is missing required icon contract (plus=$hasPlus mic=$hasMic voice=$hasTrailingVoice).',
          path: 'layers[${anchor.layerIndex}]',
          repairPayload: <String, Object?>{
            'action': 'restorePromptIcons',
            'componentId': entry.key,
            'requiredIcons': const <String>['plus', 'mic', 'send'],
          },
        ),
      );
    }
  }

  void _lintLooseCoordinates({
    required List<_ElementRef> elementRefs,
    required Map<String, _ElementRef> elementById,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    for (final ref in elementRefs) {
      final parentId = _stringFromMap(
        ref.element.properties,
        const <String>['parentId', 'parent', 'containerId', 'parentGroup'],
      );
      if (parentId == null || parentId.trim().isEmpty) {
        continue;
      }
      final parent = elementById[parentId];
      if (parent == null) {
        continue;
      }
      final childPosition = _mapFromMap(
        ref.element.properties,
        const <String>['position'],
      );
      final parentWidth = _doubleFromMap(
        parent.element.properties,
        const <String>['width'],
      );
      final parentHeight = _doubleFromMap(
        parent.element.properties,
        const <String>['height'],
      );
      if (childPosition == null ||
          parentWidth == null ||
          parentHeight == null) {
        continue;
      }
      final x = _doubleFromMap(childPosition, const <String>['x']);
      final y = _doubleFromMap(childPosition, const <String>['y']);
      if (x == null || y == null) {
        continue;
      }
      final maxLocalX = (parentWidth / 2.0) + 36.0;
      final maxLocalY = (parentHeight / 2.0) + 36.0;
      final loose = x.abs() > maxLocalX || y.abs() > maxLocalY;
      if (!loose) {
        continue;
      }
      issues.add(
        _componentError(
          code: 'RAW_CHILD_POSITION_INSIDE_KNOWN_COMPONENT',
          message:
              'Child `${ref.element.id}` uses loose/global coordinates inside parent `${parent.element.id}`.',
          path: 'layers[${ref.layerIndex}].elements[${ref.elementIndex}]',
          repairPayload: <String, Object?>{
            'action': 'convertToLocalCoordinates',
            'targetElementId': ref.element.id,
            'parentElementId': parent.element.id,
          },
        ),
      );
    }
  }

  bool _isPromptShell(_ElementRef ref) {
    if (_normalize(ref.element.kind) != 'shape') {
      return false;
    }
    final componentType =
        _normalize(_componentType(ref.element.properties) ?? '');
    if (componentType == 'promptinputbar') {
      final id = _normalize(ref.element.id);
      final width = _doubleFromMap(ref.element.properties, const <String>[
            'width',
          ]) ??
          0.0;
      final height = _doubleFromMap(ref.element.properties, const <String>[
            'height',
          ]) ??
          0.0;
      final layoutRole = _normalize(
        _stringFromMap(ref.element.properties, const <String>['layoutRole']) ??
            '',
      );
      final looksPrimaryShell = id.contains('promptframe') ||
          id.contains('promptshell') ||
          (layoutRole == 'container' && width >= 320.0 && height >= 80.0);
      return looksPrimaryShell;
    }
    final id = _normalize(ref.element.id);
    return id.contains('promptshell') ||
        id.contains('promptbar') ||
        id.contains('inputbar');
  }

  void _lintFadeOnlyPatterns({
    required ReFusionSceneProgram program,
    required List<_ElementRef> elementRefs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final entriesByComponentId = <String, List<_ElementRef>>{};
    for (final ref in elementRefs) {
      final componentId = _componentId(ref.element.properties);
      if (componentId == null || componentId.trim().isEmpty) {
        continue;
      }
      entriesByComponentId
          .putIfAbsent(componentId, () => <_ElementRef>[])
          .add(ref);
    }
    for (final componentId in entriesByComponentId.keys) {
      final refs = entriesByComponentId[componentId]!;
      if (refs.length < 3) {
        continue;
      }
      var fadeOnlyCount = 0;
      for (final ref in refs) {
        final animationShape = _animationShapeFor(
          program: program,
          ref: ref,
        );
        final fadeOnly = animationShape.hasOpacity && !animationShape.hasMotion;
        if (fadeOnly) {
          fadeOnlyCount += 1;
        }
      }
      final ratio = fadeOnlyCount / refs.length;
      if (ratio <= 0.60) {
        continue;
      }
      final anchor = refs.first;
      issues.add(
        _componentError(
          code: 'REPEATED_UNCOORDINATED_FADES',
          message:
              'Component `$componentId` uses fade-only motion on ${(ratio * 100).toStringAsFixed(0)}% of children.',
          path: 'layers[${anchor.layerIndex}]',
          repairPayload: <String, Object?>{
            'action': 'applyMotionVariety',
            'componentId': componentId,
            'minimumVarietyRatio': 0.40,
          },
        ),
      );
    }
  }

  void _lintGroupExitCoherence({
    required ReFusionSceneProgram program,
    required List<_ElementRef> elementRefs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final byComponentId = <String, List<_ElementRef>>{};
    for (final ref in elementRefs) {
      final componentId = _componentId(ref.element.properties);
      if (componentId == null || componentId.trim().isEmpty) {
        continue;
      }
      byComponentId.putIfAbsent(componentId, () => <_ElementRef>[]).add(ref);
    }
    for (final entry in byComponentId.entries) {
      final refs = entry.value;
      if (refs.length < 3) {
        continue;
      }
      final endTimes = <int>[];
      for (final ref in refs) {
        endTimes.add(ref.layer.startMs + ref.layer.durationMs);
      }
      endTimes.sort();
      final spread = endTimes.last - endTimes.first;
      if (spread <= 260) {
        continue;
      }
      final anchor = refs.first;
      issues.add(
        _componentError(
          code: 'GROUP_EXIT_INCOHERENT',
          message:
              'Component `${entry.key}` exit timing spread is ${spread}ms; children must exit coherently.',
          path: 'layers[${anchor.layerIndex}]',
          repairPayload: <String, Object?>{
            'action': 'alignGroupExit',
            'componentId': entry.key,
            'maxSpreadMs': 220,
          },
        ),
      );
    }
  }

  void _lintSiblingMotionVariety({
    required ReFusionSceneProgram program,
    required List<_ElementRef> elementRefs,
    required Map<String, _ElementRef> elementById,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final rootsByType = <String, List<_ElementRef>>{};
    final seenComponentIds = <String>{};
    for (final ref in elementRefs) {
      final componentId = _componentId(ref.element.properties);
      final componentType = _componentType(ref.element.properties);
      if (componentId == null ||
          componentType == null ||
          componentId.isEmpty ||
          componentType.isEmpty) {
        continue;
      }
      if (!seenComponentIds.add(componentId)) {
        continue;
      }
      final rootRef = _resolveComponentRootRef(
        componentId: componentId,
        elementRefs: elementRefs,
        elementById: elementById,
      );
      if (rootRef == null) {
        continue;
      }
      rootsByType
          .putIfAbsent(_normalize(componentType), () => <_ElementRef>[])
          .add(rootRef);
    }

    for (final entry in rootsByType.entries) {
      final refs = entry.value;
      if (refs.length < 3) {
        continue;
      }
      if (_hasGroupRecipeOverride(refs)) {
        continue;
      }
      final signatureCounts = <String, int>{};
      for (final ref in refs) {
        final signature = _motionSignatureForRoot(program: program, ref: ref);
        signatureCounts[signature] = (signatureCounts[signature] ?? 0) + 1;
      }
      if (signatureCounts.isEmpty) {
        continue;
      }
      final total = refs.length;
      var dominantSignature = '';
      var dominantCount = 0;
      signatureCounts.forEach((signature, count) {
        if (count > dominantCount) {
          dominantCount = count;
          dominantSignature = signature;
        }
      });
      final ratio = dominantCount / total;
      if (ratio <= 0.60) {
        continue;
      }
      final anchor = refs.first;
      issues.add(
        _componentError(
          code: 'MOTION_VARIETY_LOW',
          message:
              'Sibling `${entry.key}` components repeat `$dominantSignature` on ${(ratio * 100).toStringAsFixed(0)}% of roots.',
          path: 'layers[${anchor.layerIndex}]',
          repairPayload: <String, Object?>{
            'action': 'applyMotionVariety',
            'componentType': entry.key,
            'dominantSignature': dominantSignature,
            'dominantRatio': ratio.toStringAsFixed(3),
            'maxAllowedRatio': 0.60,
          },
        ),
      );
    }
  }

  List<int> _collectProbeTimes(ReFusionSceneProgram program) {
    final probes = <int>{0, program.durationMs};
    for (final layer in program.layers) {
      probes.add(layer.startMs.clamp(0, program.durationMs));
      probes
          .add((layer.startMs + layer.durationMs).clamp(0, program.durationMs));
      for (final channel in layer.channels) {
        for (final keyframe in channel.keyframes) {
          probes.add(keyframe.timeMs.clamp(0, program.durationMs));
        }
      }
      for (final element in layer.elements) {
        for (final channel in element.channels) {
          for (final keyframe in channel.keyframes) {
            probes.add(keyframe.timeMs.clamp(0, program.durationMs));
          }
        }
      }
    }
    final sorted = probes.toList(growable: false)..sort();
    if (sorted.length <= 9) {
      return sorted;
    }
    final trimmed = <int>{sorted.first, sorted.last};
    final step = (sorted.length - 1) / 8;
    for (var index = 1; index < 8; index += 1) {
      trimmed.add(sorted[(step * index).round()]);
    }
    final finalSorted = trimmed.toList(growable: false)..sort();
    return finalSorted;
  }

  List<_ElementRef> _collectElementRefs(ReFusionSceneProgram program) {
    final refs = <_ElementRef>[];
    for (var layerIndex = 0;
        layerIndex < program.layers.length;
        layerIndex += 1) {
      final layer = program.layers[layerIndex];
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex += 1) {
        refs.add(
          _ElementRef(
            layerIndex: layerIndex,
            elementIndex: elementIndex,
            layer: layer,
            element: layer.elements[elementIndex],
          ),
        );
      }
    }
    return refs;
  }

  bool _isProfessionalStrict(
    ReFusionSceneProgram program,
    List<_ElementRef> refs,
  ) {
    if (_normalize(program.name).contains('professional')) {
      return true;
    }
    for (final ref in refs) {
      final properties = ref.element.properties;
      final strictFlag = _boolFromMap(
            properties,
            const <String>['professional', 'professionalStrict', 'strictQa'],
          ) ??
          false;
      if (strictFlag) {
        return true;
      }
      final qualityMode = _stringFromMap(
        properties,
        const <String>['qualityMode', 'qualityTier', 'sceneTier'],
      );
      final normalizedMode = _normalize(qualityMode ?? '');
      if (normalizedMode == 'professional' || normalizedMode == 'strict') {
        return true;
      }
      final componentType = _componentType(properties);
      if (componentType != null && componentType.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  _AnimationShape _animationShapeFor({
    required ReFusionSceneProgram program,
    required _ElementRef ref,
  }) {
    final channels = <ReFusionSceneProgramChannel>[
      ...ref.layer.channels.where(
        (channel) => _normalize(channel.target) == _normalize(ref.element.id),
      ),
      ...ref.element.channels,
    ];
    var hasOpacity = false;
    var hasMotion = false;
    for (final channel in channels) {
      final property = _normalize(channel.property);
      if (property == 'opacity' || property == 'alpha') {
        hasOpacity = true;
        continue;
      }
      if (property == 'x' ||
          property == 'y' ||
          property == 'positionx' ||
          property == 'positiony' ||
          property == 'position.x' ||
          property == 'position.y' ||
          property == 'scale' ||
          property == 'scalex' ||
          property == 'scaley' ||
          property == 'rotation' ||
          property == 'rotationdeg' ||
          property == 'width' ||
          property == 'height') {
        hasMotion = true;
      }
    }
    return _AnimationShape(hasOpacity: hasOpacity, hasMotion: hasMotion);
  }

  String _motionSignatureForRoot({
    required ReFusionSceneProgram program,
    required _ElementRef ref,
  }) {
    final channels = _channelsFor(program: program, ref: ref);
    if (channels.isEmpty) {
      return 'static';
    }
    var hasOpacity = false;
    var hasX = false;
    var hasY = false;
    var hasScale = false;
    var hasRotation = false;
    for (final channel in channels) {
      final property = _normalize(channel.property);
      if (property == 'opacity' || property == 'alpha') {
        hasOpacity = true;
        continue;
      }
      if (property == 'x' ||
          property == 'positionx' ||
          property == 'position.x') {
        hasX = true;
        continue;
      }
      if (property == 'y' ||
          property == 'positiony' ||
          property == 'position.y') {
        hasY = true;
        continue;
      }
      if (property == 'scale' ||
          property == 'scalex' ||
          property == 'scaley' ||
          property == 'width' ||
          property == 'height') {
        hasScale = true;
        continue;
      }
      if (property == 'rotation' || property == 'rotationdeg') {
        hasRotation = true;
      }
    }
    if (hasOpacity && !hasX && !hasY && !hasScale && !hasRotation) {
      return 'fadeOnly';
    }
    final parts = <String>[];
    if (hasX) {
      parts.add('slideX');
    }
    if (hasY) {
      parts.add('slideY');
    }
    if (hasScale) {
      parts.add('scale');
    }
    if (hasRotation) {
      parts.add('rotate');
    }
    if (hasOpacity) {
      parts.add('fade');
    }
    if (parts.isEmpty) {
      return 'static';
    }
    return parts.join('+');
  }

  _ElementRef? _resolveComponentRootRef({
    required String componentId,
    required List<_ElementRef> elementRefs,
    required Map<String, _ElementRef> elementById,
  }) {
    final refs = elementRefs
        .where((ref) => _componentId(ref.element.properties) == componentId)
        .toList(growable: false);
    if (refs.isEmpty) {
      return null;
    }
    for (final ref in refs) {
      final role = _normalize(
        _stringFromMap(
              ref.element.properties,
              const <String>['layoutRole', 'role'],
            ) ??
            '',
      );
      if (role == 'container' || role == 'shell' || role == 'root') {
        return ref;
      }
    }
    for (final ref in refs) {
      final parentId = _stringFromMap(
        ref.element.properties,
        const <String>['parentId', 'parent', 'containerId', 'parentGroup'],
      );
      if (parentId == null || parentId.isEmpty) {
        return ref;
      }
      final parent = elementById[parentId];
      if (parent == null) {
        return ref;
      }
      if (_componentId(parent.element.properties) != componentId) {
        return ref;
      }
    }
    return refs.first;
  }

  bool _hasGroupRecipeOverride(List<_ElementRef> refs) {
    for (final ref in refs) {
      final recipe = _normalize(
        _stringFromMap(
              ref.element.properties,
              const <String>['groupMotionRecipe', 'motionRecipe', 'recipeId'],
            ) ??
            '',
      );
      if (recipe.contains('cascade') ||
          recipe.contains('group') ||
          recipe.contains('stagger')) {
        return true;
      }
    }
    return false;
  }

  List<ReFusionSceneProgramChannel> _channelsFor({
    required ReFusionSceneProgram program,
    required _ElementRef ref,
  }) {
    return <ReFusionSceneProgramChannel>[
      ...ref.layer.channels.where(
        (channel) => _normalize(channel.target) == _normalize(ref.element.id),
      ),
      ...ref.element.channels,
    ];
  }

  ReFusionSceneProgramIssue _componentError({
    required String code,
    required String message,
    required String path,
    required Map<String, Object?> repairPayload,
  }) {
    return ReFusionSceneProgramIssue(
      severity: ReFusionSceneProgramIssueSeverity.error,
      message:
          'COMPONENT_QA::$code $message repair=${_repairPayloadString(repairPayload)}',
      path: path,
    );
  }

  String _repairPayloadString(Map<String, Object?> payload) {
    final parts = <String>[];
    final keys = payload.keys.toList(growable: false)..sort();
    for (final key in keys) {
      final value = payload[key];
      parts.add('$key=${value is String ? value : value.toString()}');
    }
    return parts.join(',');
  }

  bool _containsRect({
    required SceneViewportRect container,
    required SceneViewportRect child,
    required double tolerance,
  }) {
    final leftPass = child.left >= container.left - tolerance;
    final topPass = child.top >= container.top - tolerance;
    final rightPass = child.left + child.width <=
        container.left + container.width + tolerance;
    final bottomPass = child.top + child.height <=
        container.top + container.height + tolerance;
    return leftPass && topPass && rightPass && bottomPass;
  }

  String? _componentId(Map<String, Object?> properties) {
    return _stringFromMap(
      properties,
      const <String>['componentId', 'layout.componentId'],
    );
  }

  String? _componentType(Map<String, Object?> properties) {
    return _stringFromMap(
      properties,
      const <String>['componentType', 'layout.componentType'],
    );
  }

  Map<String, Object?>? _mapFromMap(
    Map<String, Object?> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map<String, Object?>) {
        return value;
      }
    }
    return null;
  }

  bool? _boolFromMap(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) {
        return value;
      }
      if (value is String) {
        final normalized = _normalize(value);
        if (normalized == 'true') {
          return true;
        }
        if (normalized == 'false') {
          return false;
        }
      }
    }
    return null;
  }

  String? _stringFromMap(
    Map<String, Object?> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final direct = map[key];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }
      if (key.contains('.')) {
        final parts = key.split('.');
        Map<String, Object?>? cursor = map;
        for (var index = 0; index < parts.length - 1; index += 1) {
          final child = cursor?[parts[index]];
          if (child is Map<String, Object?>) {
            cursor = child;
            continue;
          }
          cursor = null;
          break;
        }
        if (cursor == null) {
          continue;
        }
        final nested = cursor[parts.last];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
    }
    return null;
  }

  double? _doubleFromMap(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  String _normalize(String raw) =>
      raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
}

class _ElementRef {
  const _ElementRef({
    required this.layerIndex,
    required this.elementIndex,
    required this.layer,
    required this.element,
  });

  final int layerIndex;
  final int elementIndex;
  final ReFusionSceneProgramLayer layer;
  final ReFusionSceneProgramElement element;
}

class _AnimationShape {
  const _AnimationShape({
    required this.hasOpacity,
    required this.hasMotion,
  });

  final bool hasOpacity;
  final bool hasMotion;
}
