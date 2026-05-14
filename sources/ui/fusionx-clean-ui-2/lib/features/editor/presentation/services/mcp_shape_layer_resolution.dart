import 'mcp_text_layer_resolution.dart';
import 'mcp_universal_layer_identity.dart';

class McpShapeLayerResolution {
  const McpShapeLayerResolution._();

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
      targetKind: UniversalLayerTargetKind.shapeElement,
      targetFamily: 'shape',
    );
    return resolution.target?.canonicalTargetId;
  }

  static bool requestsUpdate({
    required String operation,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
    required List<String> aliases,
  }) {
    const classifier = UniversalLayerApplyIntentClassifier();
    final baseIntent = classifier.classify(
      payload: payload,
      updates: updates,
      payloadPayload: payloadPayload,
      updatesPayload: updatesPayload,
      operationHint: operation,
    );
    final hasAliasHints = aliases.isNotEmpty;
    if (baseIntent == UniversalLayerApplyIntent.insert && !hasAliasHints) {
      return false;
    }
    return baseIntent != UniversalLayerApplyIntent.insert || hasAliasHints;
  }

  static bool shouldBlockInsert({
    required bool updateIntent,
    required String? resolvedLayerId,
    required bool resolvedTargetIsShapeElement,
  }) {
    return McpTextLayerResolution.shouldBlockInsert(
      updateIntent: updateIntent,
      resolvedLayerId: resolvedLayerId,
      resolvedTargetIsTextElement: resolvedTargetIsShapeElement,
    );
  }
}
