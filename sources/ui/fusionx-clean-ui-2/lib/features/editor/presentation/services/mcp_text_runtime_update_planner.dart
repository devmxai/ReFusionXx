enum McpTextRuntimeApplyDecisionType {
  insertNew,
  updateExisting,
  blockUnresolvedUpdate,
  skipDuplicateApply,
}

class McpTextRuntimeApplyDiagnostic {
  const McpTextRuntimeApplyDiagnostic({
    required this.decision,
    required this.createdNewText,
    required this.updatedExistingText,
    required this.blockedUnresolvedUpdate,
    required this.skippedDuplicateApply,
    required this.remoteLayerId,
    required this.resolvedElementId,
    required this.resolvedLayerId,
    required this.textElementCountBefore,
    required this.textElementCountAfter,
    required this.payloadSignature,
  });

  final McpTextRuntimeApplyDecisionType decision;
  final bool createdNewText;
  final bool updatedExistingText;
  final bool blockedUnresolvedUpdate;
  final bool skippedDuplicateApply;
  final String remoteLayerId;
  final String? resolvedElementId;
  final String? resolvedLayerId;
  final int textElementCountBefore;
  final int textElementCountAfter;
  final String payloadSignature;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'decision': decision.name,
      'createdNewText': createdNewText,
      'updatedExistingText': updatedExistingText,
      'blockedUnresolvedUpdate': blockedUnresolvedUpdate,
      'skippedDuplicateApply': skippedDuplicateApply,
      'remoteLayerId': remoteLayerId,
      'resolvedElementId': resolvedElementId,
      'resolvedLayerId': resolvedLayerId,
      'textElementCountBefore': textElementCountBefore,
      'textElementCountAfter': textElementCountAfter,
      'payloadSignature': payloadSignature,
    };
  }
}

class McpTextRuntimeUpdatePlanner {
  const McpTextRuntimeUpdatePlanner();

  McpTextRuntimeApplyDiagnostic plan({
    required String remoteLayerId,
    required String payloadSignature,
    required int textElementCountBefore,
    required bool updateIntent,
    required bool blockInsert,
    required bool hasResolvedTextTarget,
    required String? resolvedLayerId,
    required String? resolvedElementId,
    required String? previousPayloadSignature,
  }) {
    if (hasResolvedTextTarget &&
        previousPayloadSignature != null &&
        previousPayloadSignature == payloadSignature) {
      return McpTextRuntimeApplyDiagnostic(
        decision: McpTextRuntimeApplyDecisionType.skipDuplicateApply,
        createdNewText: false,
        updatedExistingText: false,
        blockedUnresolvedUpdate: false,
        skippedDuplicateApply: true,
        remoteLayerId: remoteLayerId,
        resolvedElementId: resolvedElementId,
        resolvedLayerId: resolvedLayerId,
        textElementCountBefore: textElementCountBefore,
        textElementCountAfter: textElementCountBefore,
        payloadSignature: payloadSignature,
      );
    }
    if (hasResolvedTextTarget) {
      return McpTextRuntimeApplyDiagnostic(
        decision: McpTextRuntimeApplyDecisionType.updateExisting,
        createdNewText: false,
        updatedExistingText: true,
        blockedUnresolvedUpdate: false,
        skippedDuplicateApply: false,
        remoteLayerId: remoteLayerId,
        resolvedElementId: resolvedElementId,
        resolvedLayerId: resolvedLayerId,
        textElementCountBefore: textElementCountBefore,
        textElementCountAfter: textElementCountBefore,
        payloadSignature: payloadSignature,
      );
    }
    if (blockInsert || updateIntent) {
      return McpTextRuntimeApplyDiagnostic(
        decision: McpTextRuntimeApplyDecisionType.blockUnresolvedUpdate,
        createdNewText: false,
        updatedExistingText: false,
        blockedUnresolvedUpdate: true,
        skippedDuplicateApply: false,
        remoteLayerId: remoteLayerId,
        resolvedElementId: resolvedElementId,
        resolvedLayerId: resolvedLayerId,
        textElementCountBefore: textElementCountBefore,
        textElementCountAfter: textElementCountBefore,
        payloadSignature: payloadSignature,
      );
    }
    return McpTextRuntimeApplyDiagnostic(
      decision: McpTextRuntimeApplyDecisionType.insertNew,
      createdNewText: true,
      updatedExistingText: false,
      blockedUnresolvedUpdate: false,
      skippedDuplicateApply: false,
      remoteLayerId: remoteLayerId,
      resolvedElementId: resolvedElementId,
      resolvedLayerId: resolvedLayerId,
      textElementCountBefore: textElementCountBefore,
      textElementCountAfter: textElementCountBefore + 1,
      payloadSignature: payloadSignature,
    );
  }
}

enum McpTextMotionTargetDecision {
  element,
  timelineClipFallback,
  blockedUnresolvedTextTarget,
}

class McpTextMotionTargetPlanner {
  const McpTextMotionTargetPlanner();

  McpTextMotionTargetDecision decide({
    required bool hasElementContext,
    required bool isTextLayerHint,
    required bool hasFallbackClip,
  }) {
    if (hasElementContext) {
      return McpTextMotionTargetDecision.element;
    }
    if (isTextLayerHint) {
      return McpTextMotionTargetDecision.blockedUnresolvedTextTarget;
    }
    return hasFallbackClip
        ? McpTextMotionTargetDecision.timelineClipFallback
        : McpTextMotionTargetDecision.blockedUnresolvedTextTarget;
  }
}
