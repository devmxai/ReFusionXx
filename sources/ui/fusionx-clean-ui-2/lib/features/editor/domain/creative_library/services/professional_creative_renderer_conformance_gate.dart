import '../models/professional_creative_library_registry_models.dart';

enum CreativeExecutionMode {
  preview,
  playback,
  export,
}

class RendererConformanceGateDecision {
  const RendererConformanceGateDecision({
    required this.allowed,
    required this.mode,
    required this.capabilityId,
    this.blockerCode,
    this.blockerReason,
    this.fallbackMode,
    this.rendererPath,
    this.exportPath,
  });

  final bool allowed;
  final CreativeExecutionMode mode;
  final String capabilityId;
  final String? blockerCode;
  final String? blockerReason;
  final String? fallbackMode;
  final String? rendererPath;
  final String? exportPath;
}

class ProfessionalCreativeRendererConformanceGate {
  const ProfessionalCreativeRendererConformanceGate();

  RendererConformanceGateDecision evaluate({
    required CreativeLibraryItemDefinition item,
    required CreativeExecutionMode mode,
    bool requireDeterministic = true,
  }) {
    final previewConformance = item.rendererConformance;
    final exportConformance = item.exportConformance;
    final effective = mode == CreativeExecutionMode.export
        ? exportConformance
        : previewConformance;

    final supported = switch (mode) {
      CreativeExecutionMode.preview => effective.previewSupported,
      CreativeExecutionMode.playback => effective.previewSupported,
      CreativeExecutionMode.export => effective.exportSupported,
    };
    if (!supported) {
      return RendererConformanceGateDecision(
        allowed: false,
        mode: mode,
        capabilityId: item.id,
        blockerCode: mode == CreativeExecutionMode.export
            ? 'EXPORT_NOT_SUPPORTED'
            : 'PREVIEW_NOT_SUPPORTED',
        blockerReason: mode == CreativeExecutionMode.export
            ? 'Capability `${item.id}` is not supported by export renderer.'
            : 'Capability `${item.id}` is not supported by preview renderer.',
        fallbackMode: effective.fallbackMode,
        rendererPath: effective.rendererPath,
        exportPath: effective.exportPath,
      );
    }

    if (requireDeterministic && !effective.deterministic) {
      return RendererConformanceGateDecision(
        allowed: false,
        mode: mode,
        capabilityId: item.id,
        blockerCode: 'NON_DETERMINISTIC_CAPABILITY',
        blockerReason:
            'Capability `${item.id}` is non-deterministic for `${mode.name}` and blocked by strict gate.',
        fallbackMode: effective.fallbackMode,
        rendererPath: effective.rendererPath,
        exportPath: effective.exportPath,
      );
    }

    return RendererConformanceGateDecision(
      allowed: true,
      mode: mode,
      capabilityId: item.id,
      fallbackMode: effective.fallbackMode,
      rendererPath: effective.rendererPath,
      exportPath: effective.exportPath,
    );
  }
}
