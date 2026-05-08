import 'dart:convert';
import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import 'scene_runtime_component_tree.dart';
import 'scene_visual_frame_qa_validator.dart';

class SceneDeterminismGeometrySample {
  const SceneDeterminismGeometrySample({
    required this.frameIndex,
    required this.timelineTimeMs,
    required this.nodeId,
    required this.worldBounds,
    required this.slotBounds,
    required this.textOverflow,
    required this.overflowPx,
    required this.clippingPx,
    required this.overlapDetected,
    required this.safeAreaViolation,
    required this.parentChildDesync,
  });

  final int frameIndex;
  final int timelineTimeMs;
  final String nodeId;
  final List<double> worldBounds;
  final List<double> slotBounds;
  final bool textOverflow;
  final double overflowPx;
  final double clippingPx;
  final bool overlapDetected;
  final bool safeAreaViolation;
  final bool parentChildDesync;

  String get sampleKey => '$frameIndex@$timelineTimeMs#$nodeId';
  String get frameKey => '$frameIndex@$timelineTimeMs';

  Map<String, Object?> toCanonicalMap() {
    return <String, Object?>{
      'frameIndex': frameIndex,
      'timelineTimeMs': timelineTimeMs,
      'nodeId': nodeId,
      'worldBounds': worldBounds.map(_normalizeNumber).toList(growable: false),
      'slotBounds': slotBounds.map(_normalizeNumber).toList(growable: false),
      'textOverflow': textOverflow,
      'overflowPx': _normalizeNumber(overflowPx),
      'clippingPx': _normalizeNumber(clippingPx),
      'overlapDetected': overlapDetected,
      'safeAreaViolation': safeAreaViolation,
      'parentChildDesync': parentChildDesync,
    };
  }

  double maxAbsDelta(SceneDeterminismGeometrySample other) {
    var maxDelta = 0.0;
    final worldCount = math.min(worldBounds.length, other.worldBounds.length);
    for (var index = 0; index < worldCount; index += 1) {
      final delta = (worldBounds[index] - other.worldBounds[index]).abs();
      if (delta > maxDelta) {
        maxDelta = delta;
      }
    }
    final slotCount = math.min(slotBounds.length, other.slotBounds.length);
    for (var index = 0; index < slotCount; index += 1) {
      final delta = (slotBounds[index] - other.slotBounds[index]).abs();
      if (delta > maxDelta) {
        maxDelta = delta;
      }
    }
    maxDelta = math.max(maxDelta, (overflowPx - other.overflowPx).abs());
    maxDelta = math.max(maxDelta, (clippingPx - other.clippingPx).abs());
    return maxDelta;
  }
}

class SceneDeterminismGeometrySnapshot {
  SceneDeterminismGeometrySnapshot({
    required this.samples,
    required this.probeHashes,
    required this.samplesByKey,
  });

  final List<SceneDeterminismGeometrySample> samples;
  final List<String> probeHashes;
  final Map<String, SceneDeterminismGeometrySample> samplesByKey;
}

class SceneDeterminismValidator {
  const SceneDeterminismValidator({
    SceneVisualFrameQaValidator? frameQaValidator,
  }) : _frameQaValidator = frameQaValidator ??
            const SceneVisualFrameQaValidator(
              enforceOverflowAsError: true,
            );

  static const String visualFrameProofTag = 'TF_SCENE_VISUAL_FRAME_QA_PROOF';

  final SceneVisualFrameQaValidator _frameQaValidator;

  Map<String, Object?> canonicalizeMap(Map<String, Object?> map) {
    final sortedKeys = map.keys.toList(growable: false)..sort();
    final normalized = <String, Object?>{};
    for (final key in sortedKeys) {
      normalized[key] = canonicalizeValue(map[key]);
    }
    return normalized;
  }

  Object? canonicalizeValue(Object? value) {
    if (value is Map<String, Object?>) {
      return canonicalizeMap(value);
    }
    if (value is Map) {
      final converted = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is String) {
          converted[entry.key as String] = entry.value;
        }
      }
      return canonicalizeMap(converted);
    }
    if (value is List) {
      return value.map(canonicalizeValue).toList(growable: false);
    }
    return value;
  }

  String hashCanonical(Map<String, Object?> value) {
    final encoded = jsonEncode(value);
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in encoded.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    if (hash < 0) {
      hash = hash & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  String hashTokenReferences(Map<String, Object?> payload) {
    final tokens = <String>[];

    void walk(Object? node) {
      if (node is String) {
        if (node.startsWith(r'$')) {
          tokens.add(node);
        }
        return;
      }
      if (node is List) {
        for (final item in node) {
          walk(item);
        }
        return;
      }
      if (node is Map) {
        for (final entry in node.entries) {
          walk(entry.value);
        }
      }
    }

    walk(payload);
    tokens.sort();
    final canonical = <String, Object?>{'tokens': tokens};
    return hashCanonical(canonical);
  }

  String hashRuntimeTree(SceneRuntimeComponentTree tree) {
    final sortedIds = tree.nodeById.keys.toList(growable: false)..sort();
    final nodes = <Object?>[];
    for (final id in sortedIds) {
      final node = tree.nodeById[id]!;
      nodes.add(
        <String, Object?>{
          'id': node.id,
          'nodeType': node.nodeType.name,
          'parentId': node.parentId,
          'zOrder': node.zOrder,
          'sourceComponentId': node.sourceComponentId,
          'sourceLayerId': node.sourceLayerId,
          'slotId': node.slotId,
          'metadata': canonicalizeValue(node.metadata),
        },
      );
    }
    return hashCanonical(
      canonicalizeMap(
        <String, Object?>{
          'rootNodeId': tree.rootNodeId,
          'nodes': nodes,
        },
      ),
    );
  }

  String hashTraversalOrder(SceneRuntimeComponentTree tree) {
    final ids =
        tree.depthFirstNodes().map((node) => node.id).toList(growable: false);
    return hashCanonical(
      canonicalizeMap(
        <String, Object?>{
          'depthFirstNodeIds': ids,
        },
      ),
    );
  }

  SceneDeterminismGeometrySnapshot geometrySnapshot(
    ReFusionSceneProgram program,
  ) {
    final validation = _frameQaValidator.validate(program);
    final samples = <SceneDeterminismGeometrySample>[];
    for (final issue in validation.issues) {
      if (!issue.message.contains(visualFrameProofTag)) {
        continue;
      }
      final sample = _parseProbeSample(issue.message);
      if (sample != null) {
        samples.add(sample);
      }
    }
    samples.sort((left, right) {
      final byFrame = left.frameIndex.compareTo(right.frameIndex);
      if (byFrame != 0) {
        return byFrame;
      }
      final byTime = left.timelineTimeMs.compareTo(right.timelineTimeMs);
      if (byTime != 0) {
        return byTime;
      }
      return left.nodeId.compareTo(right.nodeId);
    });

    final samplesByFrame = <String, List<SceneDeterminismGeometrySample>>{};
    final samplesByKey = <String, SceneDeterminismGeometrySample>{};
    for (final sample in samples) {
      samplesByFrame.putIfAbsent(
          sample.frameKey, () => <SceneDeterminismGeometrySample>[]);
      samplesByFrame[sample.frameKey]!.add(sample);
      samplesByKey[sample.sampleKey] = sample;
    }

    final sortedFrameKeys = samplesByFrame.keys.toList(growable: false)..sort();
    final probeHashes = <String>[];
    for (final frameKey in sortedFrameKeys) {
      final frameSamples = samplesByFrame[frameKey]!
        ..sort((left, right) => left.nodeId.compareTo(right.nodeId));
      final canonical = canonicalizeMap(
        <String, Object?>{
          'frameKey': frameKey,
          'samples': frameSamples
              .map((sample) => sample.toCanonicalMap())
              .toList(growable: false),
        },
      );
      probeHashes.add(hashCanonical(canonical));
    }

    return SceneDeterminismGeometrySnapshot(
      samples: List<SceneDeterminismGeometrySample>.unmodifiable(samples),
      probeHashes: List<String>.unmodifiable(probeHashes),
      samplesByKey: Map<String, SceneDeterminismGeometrySample>.unmodifiable(
        samplesByKey,
      ),
    );
  }

  double normalizedDrift({
    required SceneDeterminismGeometrySnapshot baseline,
    required SceneDeterminismGeometrySnapshot candidate,
  }) {
    if (baseline.samplesByKey.length != candidate.samplesByKey.length) {
      return double.infinity;
    }
    var maxDrift = 0.0;
    for (final entry in baseline.samplesByKey.entries) {
      final candidateSample = candidate.samplesByKey[entry.key];
      if (candidateSample == null) {
        return double.infinity;
      }
      final delta = entry.value.maxAbsDelta(candidateSample);
      if (delta > maxDrift) {
        maxDrift = delta;
      }
    }
    return _normalizeNumber(maxDrift);
  }

  SceneDeterminismGeometrySample? _parseProbeSample(String message) {
    final frameIndex = _readInt(message, 'frameIndex=');
    final timelineTimeMs = _readInt(message, 'timelineTimeMs=');
    final nodeId = _readField(message, 'nodeId=');
    final worldBoundsText = _readField(message, 'worldBounds=');
    final slotBoundsText = _readField(message, 'slotBounds=');
    final overflowPx = _readDouble(message, 'overflowPx=');
    final clippingPx = _readDouble(message, 'clippingPx=');
    if (frameIndex == null ||
        timelineTimeMs == null ||
        nodeId == null ||
        worldBoundsText == null ||
        slotBoundsText == null ||
        overflowPx == null ||
        clippingPx == null) {
      return null;
    }
    final worldBounds = _parseRect(worldBoundsText);
    final slotBounds = _parseRect(slotBoundsText);
    if (worldBounds == null || slotBounds == null) {
      return null;
    }
    return SceneDeterminismGeometrySample(
      frameIndex: frameIndex,
      timelineTimeMs: timelineTimeMs,
      nodeId: nodeId,
      worldBounds: worldBounds,
      slotBounds: slotBounds,
      textOverflow: _readBool(message, 'textOverflow='),
      overflowPx: overflowPx,
      clippingPx: clippingPx,
      overlapDetected: _readBool(message, 'overlapDetected='),
      safeAreaViolation: _readBool(message, 'safeAreaViolation='),
      parentChildDesync: _readBool(message, 'parentChildDesync='),
    );
  }

  String? _readField(String message, String marker) {
    final escaped = RegExp.escape(marker);
    final match = RegExp('$escaped([^ ]+)').firstMatch(message);
    return match?.group(1);
  }

  int? _readInt(String message, String marker) {
    final value = _readField(message, marker);
    return value == null ? null : int.tryParse(value);
  }

  double? _readDouble(String message, String marker) {
    final value = _readField(message, marker);
    return value == null ? null : double.tryParse(value);
  }

  bool _readBool(String message, String marker) {
    final value = _readField(message, marker);
    return value == 'true';
  }

  List<double>? _parseRect(String value) {
    final parts = value.split(',');
    if (parts.length != 4) {
      return null;
    }
    final parsed = <double>[];
    for (final part in parts) {
      final number = double.tryParse(part);
      if (number == null) {
        return null;
      }
      parsed.add(number);
    }
    return List<double>.unmodifiable(parsed);
  }
}

double _normalizeNumber(double value) {
  if (value.isNaN || value.isInfinite) {
    return value;
  }
  return double.parse(value.toStringAsFixed(4));
}
