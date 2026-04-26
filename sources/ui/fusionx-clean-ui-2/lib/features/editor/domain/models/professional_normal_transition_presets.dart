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
  "defaultDurationMs": 540,
  "minDurationMs": 160,
  "maxDurationMs": 3000,
  "requires": ["dual-texture", "color-overlay", "timeline-overlap"],
  "parameters": [
    {
      "name": "blackPeak",
      "type": "number",
      "default": 0.94,
      "range": [0.0, 1.0],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "transition",
      "property": "blackPeak",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeInOut" },
        { "t": 0.5, "value": 0.94, "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeInOut" }
      ]
    }
  ]
}
''';

const String kWhiteFlashTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "white_flash",
  "name": "White Flash",
  "category": "light",
  "rendererType": "primitive",
  "defaultDurationMs": 420,
  "minDurationMs": 120,
  "maxDurationMs": 1800,
  "requires": ["dual-texture", "color-overlay", "timeline-overlap"],
  "parameters": [
    {
      "name": "flashPeak",
      "type": "number",
      "default": 0.88,
      "range": [0.0, 1.0],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "transition",
      "property": "flashPeak",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeOut" },
        { "t": 0.46, "value": 0.88, "easing": "easeOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeIn" }
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
  "defaultDurationMs": 620,
  "minDurationMs": 180,
  "maxDurationMs": 3000,
  "requires": ["dual-texture", "scale", "opacity", "timeline-overlap"],
  "parameters": [
    {
      "name": "incomingStartScale",
      "type": "number",
      "default": 1.18,
      "range": [1.0, 1.45],
      "ui": "slider"
    },
    {
      "name": "outgoingBoostScale",
      "type": "number",
      "default": 1.05,
      "range": [1.0, 1.25],
      "ui": "slider"
    },
    {
      "name": "entryDelay",
      "type": "number",
      "default": 0.18,
      "range": [0.0, 0.48],
      "ui": "slider"
    },
    {
      "name": "bridgeDarkness",
      "type": "number",
      "default": 0.22,
      "range": [0.0, 0.65],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "scale",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeOut" },
        { "t": 1.0, "value": 1.05, "easing": "easeOut" }
      ]
    },
    {
      "target": "to",
      "property": "scale",
      "keyframes": [
        { "t": 0.18, "value": 1.18, "easing": "easeOut" },
        { "t": 1.0, "value": 1.0, "easing": "easeOut" }
      ]
    },
    {
      "target": "transition",
      "property": "bridgeDarkness",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeOut" },
        { "t": 0.5, "value": 0.22, "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeIn" }
      ]
    }
  ]
}
''';

const String kBlurDissolveTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "blur_dissolve",
  "name": "Blur Dissolve",
  "category": "blur",
  "rendererType": "primitive",
  "defaultDurationMs": 760,
  "minDurationMs": 180,
  "maxDurationMs": 3000,
  "requires": ["dual-texture", "opacity", "blur", "timeline-overlap"],
  "parameters": [
    {
      "name": "maxBlur",
      "type": "number",
      "default": 10.0,
      "range": [0.0, 24.0],
      "ui": "slider"
    },
    {
      "name": "softness",
      "type": "number",
      "default": 0.55,
      "range": [0.0, 1.0],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeInOut" }
      ]
    },
    {
      "target": "to",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 1.0, "easing": "easeInOut" }
      ]
    },
    {
      "target": "transition",
      "property": "blur",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeOut" },
        { "t": 0.5, "value": 10.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeIn" }
      ]
    }
  ]
}
''';

const String kPushLeftTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "push_left",
  "name": "Push Left",
  "category": "motion",
  "rendererType": "primitive",
  "defaultDurationMs": 640,
  "minDurationMs": 160,
  "maxDurationMs": 2400,
  "requires": ["dual-texture", "position", "timeline-overlap"],
  "parameters": [
    {
      "name": "distance",
      "type": "number",
      "default": 1.0,
      "range": [0.25, 1.25],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "positionX",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeInOut" },
        { "t": 1.0, "value": -1.0, "easing": "easeInOut" }
      ]
    },
    {
      "target": "to",
      "property": "positionX",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeInOut" }
      ]
    }
  ]
}
''';

const String kPushRightTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "push_right",
  "name": "Push Right",
  "category": "motion",
  "rendererType": "primitive",
  "defaultDurationMs": 640,
  "minDurationMs": 160,
  "maxDurationMs": 2400,
  "requires": ["dual-texture", "position", "timeline-overlap"],
  "parameters": [
    {
      "name": "distance",
      "type": "number",
      "default": 1.0,
      "range": [0.25, 1.25],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "positionX",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 1.0, "easing": "easeInOut" }
      ]
    },
    {
      "target": "to",
      "property": "positionX",
      "keyframes": [
        { "t": 0.0, "value": -1.0, "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeInOut" }
      ]
    }
  ]
}
''';

const String kZoomOutCameraTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "zoom_out_camera",
  "name": "Zoom Out Camera",
  "category": "motion",
  "rendererType": "primitive",
  "defaultDurationMs": 680,
  "minDurationMs": 180,
  "maxDurationMs": 3000,
  "requires": ["dual-texture", "scale", "opacity", "timeline-overlap"],
  "parameters": [
    { "name": "outgoingStartScale", "type": "number", "default": 1.14, "range": [1.0, 1.45], "ui": "slider" },
    { "name": "incomingStartScale", "type": "number", "default": 1.04, "range": [1.0, 1.25], "ui": "slider" },
    { "name": "bridgeDarkness", "type": "number", "default": 0.18, "range": [0.0, 0.65], "ui": "slider" }
  ],
  "channels": [
    {
      "target": "from",
      "property": "scale",
      "keyframes": [
        { "t": 0.0, "value": 1.14, "easing": "easeOut" },
        { "t": 1.0, "value": 1.0, "easing": "easeOut" }
      ]
    },
    {
      "target": "to",
      "property": "scale",
      "keyframes": [
        { "t": 0.0, "value": 1.04, "easing": "easeOut" },
        { "t": 1.0, "value": 1.0, "easing": "easeOut" }
      ]
    },
    {
      "target": "transition",
      "property": "bridgeDarkness",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "easeOut" },
        { "t": 0.5, "value": 0.18, "easing": "easeInOut" },
        { "t": 1.0, "value": 0.0, "easing": "easeIn" }
      ]
    }
  ]
}
''';

const String kWhipPanLeftTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "whip_pan_left",
  "name": "Whip Pan Left",
  "category": "motion",
  "rendererType": "primitive",
  "defaultDurationMs": 460,
  "minDurationMs": 120,
  "maxDurationMs": 1600,
  "requires": ["dual-texture", "position", "blur", "color-overlay", "timeline-overlap"],
  "parameters": [
    { "name": "distance", "type": "number", "default": 1.15, "range": [0.5, 1.5], "ui": "slider" },
    { "name": "maxBlur", "type": "number", "default": 16.0, "range": [0.0, 32.0], "ui": "slider" },
    { "name": "flashPeak", "type": "number", "default": 0.22, "range": [0.0, 1.0], "ui": "slider" }
  ],
  "channels": [
    { "target": "from", "property": "positionX", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 1.0, "value": -1.15 }] },
    { "target": "to", "property": "positionX", "keyframes": [{ "t": 0.0, "value": 1.15 }, { "t": 1.0, "value": 0.0 }] },
    { "target": "transition", "property": "blur", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 0.5, "value": 16.0 }, { "t": 1.0, "value": 0.0 }] },
    { "target": "transition", "property": "flashPeak", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 0.5, "value": 0.22 }, { "t": 1.0, "value": 0.0 }] }
  ]
}
''';

const String kWhipPanRightTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "whip_pan_right",
  "name": "Whip Pan Right",
  "category": "motion",
  "rendererType": "primitive",
  "defaultDurationMs": 460,
  "minDurationMs": 120,
  "maxDurationMs": 1600,
  "requires": ["dual-texture", "position", "blur", "color-overlay", "timeline-overlap"],
  "parameters": [
    { "name": "distance", "type": "number", "default": 1.15, "range": [0.5, 1.5], "ui": "slider" },
    { "name": "maxBlur", "type": "number", "default": 16.0, "range": [0.0, 32.0], "ui": "slider" },
    { "name": "flashPeak", "type": "number", "default": 0.22, "range": [0.0, 1.0], "ui": "slider" }
  ],
  "channels": [
    { "target": "from", "property": "positionX", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 1.0, "value": 1.15 }] },
    { "target": "to", "property": "positionX", "keyframes": [{ "t": 0.0, "value": -1.15 }, { "t": 1.0, "value": 0.0 }] },
    { "target": "transition", "property": "blur", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 0.5, "value": 16.0 }, { "t": 1.0, "value": 0.0 }] },
    { "target": "transition", "property": "flashPeak", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 0.5, "value": 0.22 }, { "t": 1.0, "value": 0.0 }] }
  ]
}
''';

const String kSlideBlurLeftTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "slide_blur_left",
  "name": "Slide Blur Left",
  "category": "blur",
  "rendererType": "primitive",
  "defaultDurationMs": 680,
  "minDurationMs": 160,
  "maxDurationMs": 2400,
  "requires": ["dual-texture", "position", "blur", "timeline-overlap"],
  "parameters": [
    { "name": "distance", "type": "number", "default": 1.0, "range": [0.25, 1.25], "ui": "slider" },
    { "name": "maxBlur", "type": "number", "default": 8.0, "range": [0.0, 24.0], "ui": "slider" }
  ],
  "channels": [
    { "target": "from", "property": "positionX", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 1.0, "value": -1.0 }] },
    { "target": "to", "property": "positionX", "keyframes": [{ "t": 0.0, "value": 1.0 }, { "t": 1.0, "value": 0.0 }] },
    { "target": "transition", "property": "blur", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 0.5, "value": 8.0 }, { "t": 1.0, "value": 0.0 }] }
  ]
}
''';

const String kSlideBlurRightTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "slide_blur_right",
  "name": "Slide Blur Right",
  "category": "blur",
  "rendererType": "primitive",
  "defaultDurationMs": 680,
  "minDurationMs": 160,
  "maxDurationMs": 2400,
  "requires": ["dual-texture", "position", "blur", "timeline-overlap"],
  "parameters": [
    { "name": "distance", "type": "number", "default": 1.0, "range": [0.25, 1.25], "ui": "slider" },
    { "name": "maxBlur", "type": "number", "default": 8.0, "range": [0.0, 24.0], "ui": "slider" }
  ],
  "channels": [
    { "target": "from", "property": "positionX", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 1.0, "value": 1.0 }] },
    { "target": "to", "property": "positionX", "keyframes": [{ "t": 0.0, "value": -1.0 }, { "t": 1.0, "value": 0.0 }] },
    { "target": "transition", "property": "blur", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 0.5, "value": 8.0 }, { "t": 1.0, "value": 0.0 }] }
  ]
}
''';

const String kFlashZoomTransitionDefinitionJson = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "flash_zoom",
  "name": "Flash Zoom",
  "category": "light",
  "rendererType": "primitive",
  "defaultDurationMs": 520,
  "minDurationMs": 140,
  "maxDurationMs": 2200,
  "requires": ["dual-texture", "scale", "color-overlay", "timeline-overlap"],
  "parameters": [
    { "name": "incomingStartScale", "type": "number", "default": 1.24, "range": [1.0, 1.55], "ui": "slider" },
    { "name": "outgoingBoostScale", "type": "number", "default": 1.12, "range": [1.0, 1.35], "ui": "slider" },
    { "name": "flashPeak", "type": "number", "default": 0.72, "range": [0.0, 1.0], "ui": "slider" },
    { "name": "bridgeDarkness", "type": "number", "default": 0.16, "range": [0.0, 0.65], "ui": "slider" }
  ],
  "channels": [
    { "target": "from", "property": "scale", "keyframes": [{ "t": 0.0, "value": 1.0 }, { "t": 1.0, "value": 1.12 }] },
    { "target": "to", "property": "scale", "keyframes": [{ "t": 0.0, "value": 1.24 }, { "t": 1.0, "value": 1.0 }] },
    { "target": "transition", "property": "flashPeak", "keyframes": [{ "t": 0.0, "value": 0.0 }, { "t": 0.5, "value": 0.72 }, { "t": 1.0, "value": 0.0 }] }
  ]
}
''';

const Map<String, String> kBuiltInNormalTransitionDefinitionJsonById =
    <String, String>{
  'cross_dissolve': kCrossDissolveTransitionDefinitionJson,
  'fade_black': kFadeBlackTransitionDefinitionJson,
  'white_flash': kWhiteFlashTransitionDefinitionJson,
  'zoom_in_camera': kZoomInCameraTransitionDefinitionJson,
  'blur_dissolve': kBlurDissolveTransitionDefinitionJson,
  'push_left': kPushLeftTransitionDefinitionJson,
  'push_right': kPushRightTransitionDefinitionJson,
  'zoom_out_camera': kZoomOutCameraTransitionDefinitionJson,
  'whip_pan_left': kWhipPanLeftTransitionDefinitionJson,
  'whip_pan_right': kWhipPanRightTransitionDefinitionJson,
  'slide_blur_left': kSlideBlurLeftTransitionDefinitionJson,
  'slide_blur_right': kSlideBlurRightTransitionDefinitionJson,
  'flash_zoom': kFlashZoomTransitionDefinitionJson,
};
