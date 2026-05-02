const String kCrossDissolveTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "cross_dissolve",
  "name": "Cross Dissolve",
  "category": "basic",
  "rendererType": "primitive",
  "defaultDurationMs": 2000,
  "minDurationMs": 600,
  "maxDurationMs": 5000,
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
  "defaultDurationMs": 4000,
  "minDurationMs": 1200,
  "maxDurationMs": 5000,
  "requires": ["dual-texture", "opacity", "transform", "timeline-overlap", "live-video-surface", "motion-blur"],
  "parameters": [
    {
      "name": "outgoingBoostScale",
      "type": "number",
      "default": 3.0,
      "range": [1.05, 3.6],
      "ui": "slider"
    },
    {
      "name": "incomingStartScale",
      "type": "number",
      "default": 0.28,
      "range": [0.18, 1.0],
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
      "default": 18.0,
      "range": [0.0, 32.0],
      "ui": "slider"
    },
    {
      "name": "shakeAmount",
      "type": "number",
      "default": 5.0,
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
        { "t": 0.5, "value": "\$incomingStartScale", "easing": "linear" },
        { "t": 1.0, "value": 1.0, "easing": "easeOutCubic" }
      ]
    },
    {
      "target": "to",
      "property": "scaleY",
      "keyframes": [
        { "t": 0.5, "value": "\$incomingStartScale", "easing": "linear" },
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

const String kDistortionZoomInV1TransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "distortion_zoom_in_v1",
  "name": "Distortion Zoom Transition In V1",
  "category": "motion",
  "rendererType": "multiPassDeferred",
  "defaultDurationMs": 4000,
  "minDurationMs": 1800,
  "maxDurationMs": 6000,
  "requires": [
    "dual-texture",
    "transform",
    "timeline-overlap",
    "live-video-surface",
    "temporal-motion-blur",
    "mirror-tile",
    "lens-distortion"
  ],
  "parameters": [
    {
      "name": "outgoingBoostScale",
      "type": "number",
      "default": 3.0,
      "range": [1.2, 4.0],
      "ui": "slider"
    },
    {
      "name": "incomingStartScale",
      "type": "number",
      "default": 0.25,
      "range": [0.18, 1.0],
      "ui": "slider"
    },
    {
      "name": "lensDistortionPeak",
      "type": "number",
      "default": 0.32,
      "range": [0.0, 0.75],
      "ui": "slider"
    },
    {
      "name": "chromaticAberrationPeak",
      "type": "number",
      "default": 0.08,
      "range": [0.0, 0.18],
      "ui": "slider"
    },
    {
      "name": "motionTileOutputScaleX",
      "type": "number",
      "default": 4.0,
      "range": [1.0, 6.0],
      "ui": "slider"
    },
    {
      "name": "motionTileOutputScaleY",
      "type": "number",
      "default": 4.0,
      "range": [1.0, 6.0],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "scaleX",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInCubic" },
        { "t": 0.5, "value": "\$outgoingBoostScale", "easing": "easeInCubic" }
      ]
    },
    {
      "target": "from",
      "property": "scaleY",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInCubic" },
        { "t": 0.5, "value": "\$outgoingBoostScale", "easing": "easeInCubic" }
      ]
    },
    {
      "target": "to",
      "property": "scaleX",
      "keyframes": [
        { "t": 0.5, "value": "\$incomingStartScale", "easing": "easeOutCubic" },
        { "t": 1.0, "value": 1.0, "easing": "easeOutCubic" }
      ]
    },
    {
      "target": "to",
      "property": "scaleY",
      "keyframes": [
        { "t": 0.5, "value": "\$incomingStartScale", "easing": "easeOutCubic" },
        { "t": 1.0, "value": 1.0, "easing": "easeOutCubic" }
      ]
    },
    {
      "target": "transition",
      "property": "lensDistortion",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeInOut" },
        { "t": 0.5, "value": "\$lensDistortionPeak", "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeInOut" }
      ]
    },
    {
      "target": "transition",
      "property": "chromaticAberration",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeInOut" },
        { "t": 0.5, "value": "\$chromaticAberrationPeak", "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeInOut" }
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
  'distortion_zoom_in_v1': kDistortionZoomInV1TransitionDefinitionJson,
};
