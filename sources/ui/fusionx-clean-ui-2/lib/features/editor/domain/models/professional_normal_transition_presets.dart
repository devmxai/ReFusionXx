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
  "defaultDurationMs": 560,
  "minDurationMs": 180,
  "maxDurationMs": 2600,
  "requires": ["dual-texture", "opacity", "transform", "timeline-overlap", "boundary-frames", "motion-blur"],
  "parameters": [
    {
      "name": "outgoingBoostScale",
      "type": "number",
      "default": 1.95,
      "range": [1.05, 2.6],
      "ui": "slider"
    },
    {
      "name": "incomingStartScale",
      "type": "number",
      "default": 1.95,
      "range": [1.18, 2.6],
      "ui": "slider"
    },
    {
      "name": "entryDelay",
      "type": "number",
      "default": 0.12,
      "range": [0.0, 0.32],
      "ui": "slider"
    },
    {
      "name": "bridgeDarkness",
      "type": "number",
      "default": 0.12,
      "range": [0.0, 0.65],
      "ui": "slider"
    },
    {
      "name": "motionBlurAmount",
      "type": "number",
      "default": 12.0,
      "range": [0.0, 28.0],
      "ui": "slider"
    },
    {
      "name": "shakeAmount",
      "type": "number",
      "default": 7.0,
      "range": [0.0, 24.0],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "scaleX",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInOut" },
        { "t": 0.5, "value": "\$outgoingBoostScale", "easing": "easeInCubic" },
        { "t": 1.0, "value": "\$outgoingBoostScale", "easing": "linear" }
      ]
    },
    {
      "target": "from",
      "property": "scaleY",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInOut" },
        { "t": 0.5, "value": "\$outgoingBoostScale", "easing": "easeInCubic" },
        { "t": 1.0, "value": "\$outgoingBoostScale", "easing": "linear" }
      ]
    },
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "linear" },
        { "t": 0.42, "value": 1.0, "easing": "linear" },
        { "t": 0.58, "value": 0.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "linear" }
      ]
    },
    {
      "target": "to",
      "property": "scaleX",
      "keyframes": [
        { "t": 0.38, "value": "\$incomingStartScale", "easing": "linear" },
        { "t": 1.0, "value": 1.0, "easing": "easeOutCubic" }
      ]
    },
    {
      "target": "to",
      "property": "scaleY",
      "keyframes": [
        { "t": 0.38, "value": "\$incomingStartScale", "easing": "linear" },
        { "t": 1.0, "value": 1.0, "easing": "easeOutCubic" }
      ]
    },
    {
      "target": "to",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "linear" },
        { "t": 0.42, "value": 0.0, "easing": "linear" },
        { "t": 0.58, "value": 1.0, "easing": "easeInOut" },
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
