import 'mcp_universal_layer_identity.dart';

class McpTextLayerResolution {
  const McpTextLayerResolution._();

  static String? resolveCandidateLayerId({
    required String remoteLayerId,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
    required bool Function(String layerId) exists,
  }) {
    const resolver = UniversalMcpLayerIdentityResolver();
    final resolution = resolver.resolve(
      remoteLayerId: remoteLayerId,
      payload: payload,
      updates: updates,
      payloadPayload: payloadPayload,
      updatesPayload: updatesPayload,
      exists: exists,
      targetKind: UniversalLayerTargetKind.textElement,
      targetFamily: 'text',
    );
    return resolution.target?.canonicalTargetId;
  }

  static bool requestsUpdate({
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
  }) {
    const classifier = UniversalLayerApplyIntentClassifier();
    final intent = classifier.classify(
      payload: payload,
      updates: updates,
      payloadPayload: payloadPayload,
      updatesPayload: updatesPayload,
    );
    return intent != UniversalLayerApplyIntent.insert;
  }

  static bool shouldBlockInsert({
    required bool updateIntent,
    required String? resolvedLayerId,
    required bool resolvedTargetIsTextElement,
  }) {
    if (!updateIntent) {
      return false;
    }
    if (resolvedLayerId == null || resolvedLayerId.isEmpty) {
      return true;
    }
    return !resolvedTargetIsTextElement;
  }
}
