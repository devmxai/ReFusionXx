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

const String kFadeBlackTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "fade_black",
  "name": "Fade Black",
  "category": "basic",
  "rendererType": "primitive",
  "defaultDurationMs": 900,
  "minDurationMs": 160,
  "maxDurationMs": 3000,
  "requires": ["dual-texture", "opacity", "timeline-overlap"],
  "parameters": [
    {
      "name": "hold",
      "type": "number",
      "default": 0.08,
      "range": [0.0, 0.35],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInOut" },
        { "t": 0.46, "value": 0.0, "easing": "linear" },
        { "t": 1.0, "value": 0.0, "easing": "linear" }
      ]
    },
    {
      "target": "to",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "linear" },
        { "t": 0.54, "value": 0.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 1.0, "easing": "linear" }
      ]
    }
  ]
}
''';

const String kZoomInCameraTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "zoom_in_camera",
  "name": "Zoom In Camera",
  "category": "motion",
  "rendererType": "primitive",
  "defaultDurationMs": 840,
  "minDurationMs": 180,
  "maxDurationMs": 2600,
  "requires": ["dual-texture", "opacity", "transform", "timeline-overlap"],
  "parameters": [
    {
      "name": "zoom",
      "type": "number",
      "default": 1.14,
      "range": [1.0, 1.45],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "scaleX",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInOut" },
        { "t": 1.0, "value": "\$zoom", "easing": "linear" }
      ]
    },
    {
      "target": "from",
      "property": "scaleY",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInOut" },
        { "t": 1.0, "value": "\$zoom", "easing": "linear" }
      ]
    },
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "linear" }
      ]
    },
    {
      "target": "to",
      "property": "scaleX",
      "keyframes": [
        { "t": 0.0, "value": "\$zoom", "easing": "easeInOut" },
        { "t": 1.0, "value": 1.0, "easing": "linear" }
      ]
    },
    {
      "target": "to",
      "property": "scaleY",
      "keyframes": [
        { "t": 0.0, "value": "\$zoom", "easing": "easeInOut" },
        { "t": 1.0, "value": 1.0, "easing": "linear" }
      ]
    },
    {
      "target": "to",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 1.0, "easing": "linear" }
      ]
    }
  ]
}
''';

const Map<String, String> kBuiltInNormalTransitionDefinitionJsonById =
    <String, String>{
  'cross_dissolve': kCrossDissolveTransitionDefinitionJson,
  'fade_black': kFadeBlackTransitionDefinitionJson,
  'zoom_in_camera': kZoomInCameraTransitionDefinitionJson,
};
