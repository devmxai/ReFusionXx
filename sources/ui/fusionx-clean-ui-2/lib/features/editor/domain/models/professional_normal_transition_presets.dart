const String kCrossDissolveTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "cross_dissolve",
  "name": "Cross Dissolve",
  "category": "basic",
  "rendererType": "primitive",
  "defaultDurationMs": 720,
  "minDurationMs": 120,
  "maxDurationMs": 3000,
  "requires": ["dual-texture", "opacity", "timeline-overlap"],
  "parameters": [
    {
      "name": "softness",
      "type": "number",
      "default": 0.5,
      "range": [0.0, 1.0],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "linear" },
        { "t": 1.0, "value": 0.0, "easing": "linear" }
      ]
    },
    {
      "target": "to",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "linear" },
        { "t": 1.0, "value": 1.0, "easing": "linear" }
      ]
    }
  ]
}
''';

const Map<String, String> kBuiltInNormalTransitionDefinitionJsonById =
    <String, String>{
  'cross_dissolve': kCrossDissolveTransitionDefinitionJson,
};
