enum RefusionMcpCapability {
  projectRead('project.read'),
  timelineRead('timeline.read'),
  timelineWrite('timeline.write'),
  motionWrite('motion.write'),
  sceneWrite('scene.write'),
  previewRead('preview.read'),
  transportControl('transport.control'),
  mediaImport('media.import'),
  exportStart('export.start'),
  filesystemRead('filesystem.read'),
  filesystemWrite('filesystem.write'),
  debugDiagnostics('debug.diagnostics');

  const RefusionMcpCapability(this.value);

  final String value;

  static RefusionMcpCapability? parse(String value) {
    for (final capability in RefusionMcpCapability.values) {
      if (capability.value == value) {
        return capability;
      }
    }
    return null;
  }
}
