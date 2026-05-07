import 'dart:convert';
import 'dart:developer' as developer;

import '../models/professional_motion_animation_models.dart';
import 'motion_interpolation_truth_compiler.dart';

class SpeedGraphCustomPresetRecord {
  const SpeedGraphCustomPresetRecord({
    required this.presetId,
    required this.label,
    required this.curveHash,
    required this.bezier,
    required this.createdAtMs,
    required this.lastUsedAtMs,
  });

  final String presetId;
  final String label;
  final String curveHash;
  final MotionBezierControlPoints bezier;
  final int createdAtMs;
  final int lastUsedAtMs;

  SpeedGraphCustomPresetRecord copyWith({
    String? presetId,
    String? label,
    String? curveHash,
    MotionBezierControlPoints? bezier,
    int? createdAtMs,
    int? lastUsedAtMs,
  }) {
    return SpeedGraphCustomPresetRecord(
      presetId: presetId ?? this.presetId,
      label: label ?? this.label,
      curveHash: curveHash ?? this.curveHash,
      bezier: bezier ?? this.bezier,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastUsedAtMs: lastUsedAtMs ?? this.lastUsedAtMs,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'presetId': presetId,
      'label': label,
      'curveHash': curveHash,
      'bezier': <String, double>{
        'x1': bezier.x1,
        'y1': bezier.y1,
        'x2': bezier.x2,
        'y2': bezier.y2,
      },
      'createdAtMs': createdAtMs,
      'lastUsedAtMs': lastUsedAtMs,
    };
  }

  static SpeedGraphCustomPresetRecord? tryParse(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return null;
    }
    final presetId = value['presetId']?.toString().trim();
    final curveHash = value['curveHash']?.toString().trim();
    final bezierMap = value['bezier'];
    if (presetId == null ||
        presetId.isEmpty ||
        curveHash == null ||
        curveHash.isEmpty ||
        bezierMap is! Map<Object?, Object?>) {
      return null;
    }
    final x1 = _asDouble(bezierMap['x1']);
    final y1 = _asDouble(bezierMap['y1']);
    final x2 = _asDouble(bezierMap['x2']);
    final y2 = _asDouble(bezierMap['y2']);
    if (x1 == null || y1 == null || x2 == null || y2 == null) {
      return null;
    }
    return SpeedGraphCustomPresetRecord(
      presetId: presetId,
      label: value['label']?.toString().trim().isNotEmpty == true
          ? value['label']!.toString().trim()
          : 'My Curve',
      curveHash: curveHash,
      bezier: MotionBezierControlPoints(
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
      ),
      createdAtMs: _asInt(value['createdAtMs']) ?? 0,
      lastUsedAtMs: _asInt(value['lastUsedAtMs']) ?? 0,
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

abstract class SpeedGraphCustomPresetStorageDriver {
  String? readSnapshot();
  void writeSnapshot(String encoded);
}

class InMemorySpeedGraphCustomPresetStorageDriver
    implements SpeedGraphCustomPresetStorageDriver {
  InMemorySpeedGraphCustomPresetStorageDriver();

  static String? _snapshot;

  @override
  String? readSnapshot() => _snapshot;

  @override
  void writeSnapshot(String encoded) {
    _snapshot = encoded;
  }
}

class SpeedGraphCustomPresetPersistenceService {
  SpeedGraphCustomPresetPersistenceService({
    MotionInterpolationTruthCompiler? truthCompiler,
    SpeedGraphCustomPresetStorageDriver? storageDriver,
  })  : _truthCompiler =
            truthCompiler ?? const MotionInterpolationTruthCompiler(),
        _storageDriver =
            storageDriver ?? InMemorySpeedGraphCustomPresetStorageDriver();

  static final SpeedGraphCustomPresetPersistenceService instance =
      SpeedGraphCustomPresetPersistenceService();

  final MotionInterpolationTruthCompiler _truthCompiler;
  final SpeedGraphCustomPresetStorageDriver _storageDriver;

  bool _hydrated = false;
  final Map<String, SpeedGraphCustomPresetRecord> _byCurveHash =
      <String, SpeedGraphCustomPresetRecord>{};

  List<SpeedGraphCustomPresetRecord> listPresets() {
    _ensureHydrated();
    final list = _byCurveHash.values.toList()
      ..sort((a, b) => b.lastUsedAtMs.compareTo(a.lastUsedAtMs));
    return List<SpeedGraphCustomPresetRecord>.unmodifiable(list);
  }

  SpeedGraphCustomPresetRecord? saveInterpolation({
    required MotionInterpolationSpec interpolation,
    String? label,
    String selectedLaneId = 'unknown',
    String selectedKeyframeId = 'unknown',
  }) {
    _ensureHydrated();
    final compiled = _truthCompiler.compileFromInterpolation(
      interpolation: interpolation,
      inputMode: MotionInterpolationCompileInputMode.existingSpec,
    );
    final bezier = compiled.interpolation.bezier;
    if (bezier == null) {
      _emitProof(
        action: 'save',
        presetId: 'none',
        curveHash: compiled.curveHash,
        selectedLaneId: selectedLaneId,
        selectedKeyframeId: selectedKeyframeId,
        fallbackReason: 'non_bezier_interpolation',
      );
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _byCurveHash[compiled.curveHash];
    if (existing != null) {
      final next = existing.copyWith(
        label:
            label?.trim().isNotEmpty == true ? label!.trim() : existing.label,
        bezier: bezier,
        lastUsedAtMs: now,
      );
      _byCurveHash[compiled.curveHash] = next;
      _persist();
      _emitProof(
        action: 'save',
        presetId: next.presetId,
        curveHash: next.curveHash,
        selectedLaneId: selectedLaneId,
        selectedKeyframeId: selectedKeyframeId,
        fallbackReason: 'deduplicated_by_curve_hash',
      );
      return next;
    }
    final presetId =
        'custom_curve_${compiled.curveHash.hashCode.abs().toRadixString(16)}';
    final entry = SpeedGraphCustomPresetRecord(
      presetId: presetId,
      // Keep a concise default label to avoid colliding with the tab title.
      label: label?.trim().isNotEmpty == true ? label!.trim() : 'My Curve',
      curveHash: compiled.curveHash,
      bezier: bezier,
      createdAtMs: now,
      lastUsedAtMs: now,
    );
    _byCurveHash[compiled.curveHash] = entry;
    _persist();
    _emitProof(
      action: 'save',
      presetId: entry.presetId,
      curveHash: entry.curveHash,
      selectedLaneId: selectedLaneId,
      selectedKeyframeId: selectedKeyframeId,
      fallbackReason: 'none',
    );
    return entry;
  }

  MotionInterpolationSpec? loadInterpolationByPresetId(
    String presetId, {
    String selectedLaneId = 'unknown',
    String selectedKeyframeId = 'unknown',
  }) {
    _ensureHydrated();
    final entry = _byCurveHash.values.firstWhere(
      (candidate) => candidate.presetId == presetId,
      orElse: () => const SpeedGraphCustomPresetRecord(
        presetId: '',
        label: '',
        curveHash: '',
        bezier:
            MotionBezierControlPoints(x1: 0.3333, y1: 0.0, x2: 0.6667, y2: 1.0),
        createdAtMs: 0,
        lastUsedAtMs: 0,
      ),
    );
    if (entry.presetId.isEmpty) {
      _emitProof(
        action: 'load',
        presetId: presetId,
        curveHash: 'none',
        selectedLaneId: selectedLaneId,
        selectedKeyframeId: selectedKeyframeId,
        fallbackReason: 'preset_not_found',
      );
      return null;
    }
    final updated =
        entry.copyWith(lastUsedAtMs: DateTime.now().millisecondsSinceEpoch);
    _byCurveHash[entry.curveHash] = updated;
    _persist();
    _emitProof(
      action: 'load',
      presetId: updated.presetId,
      curveHash: updated.curveHash,
      selectedLaneId: selectedLaneId,
      selectedKeyframeId: selectedKeyframeId,
      fallbackReason: 'none',
    );
    _emitProof(
      action: 'apply',
      presetId: updated.presetId,
      curveHash: updated.curveHash,
      selectedLaneId: selectedLaneId,
      selectedKeyframeId: selectedKeyframeId,
      fallbackReason: 'none',
    );
    return MotionInterpolationSpec.cubicBezier(bezier: updated.bezier);
  }

  bool deletePreset(
    String presetId, {
    String selectedLaneId = 'unknown',
    String selectedKeyframeId = 'unknown',
  }) {
    _ensureHydrated();
    String? curveHashToDelete;
    for (final entry in _byCurveHash.entries) {
      if (entry.value.presetId == presetId) {
        curveHashToDelete = entry.key;
        break;
      }
    }
    if (curveHashToDelete == null) {
      _emitProof(
        action: 'delete',
        presetId: presetId,
        curveHash: 'none',
        selectedLaneId: selectedLaneId,
        selectedKeyframeId: selectedKeyframeId,
        fallbackReason: 'preset_not_found',
      );
      return false;
    }
    final removed = _byCurveHash.remove(curveHashToDelete);
    _persist();
    _emitProof(
      action: 'delete',
      presetId: presetId,
      curveHash: removed?.curveHash ?? curveHashToDelete,
      selectedLaneId: selectedLaneId,
      selectedKeyframeId: selectedKeyframeId,
      fallbackReason: 'none',
    );
    return true;
  }

  List<Map<String, Object?>> exportPresetMaps() {
    _ensureHydrated();
    return listPresets().map((preset) => preset.toJson()).toList();
  }

  void importPresetMaps(
    List<Map<String, Object?>> maps, {
    String selectedLaneId = 'unknown',
    String selectedKeyframeId = 'unknown',
  }) {
    _ensureHydrated();
    for (final map in maps) {
      final parsed = SpeedGraphCustomPresetRecord.tryParse(map);
      if (parsed == null) {
        continue;
      }
      final existing = _byCurveHash[parsed.curveHash];
      if (existing == null || parsed.lastUsedAtMs >= existing.lastUsedAtMs) {
        _byCurveHash[parsed.curveHash] = parsed;
      }
    }
    _persist();
    _emitProof(
      action: 'apply',
      presetId: 'import',
      curveHash: 'bulk',
      selectedLaneId: selectedLaneId,
      selectedKeyframeId: selectedKeyframeId,
      fallbackReason: 'none',
    );
  }

  void clearForTest() {
    _byCurveHash.clear();
    _hydrated = false;
    _storageDriver.writeSnapshot(jsonEncode(const <Object?>[]));
  }

  void _ensureHydrated() {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    final encoded = _storageDriver.readSnapshot();
    if (encoded == null || encoded.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List<Object?>) {
        return;
      }
      for (final entry in decoded) {
        final parsed = SpeedGraphCustomPresetRecord.tryParse(entry);
        if (parsed == null) {
          continue;
        }
        _byCurveHash[parsed.curveHash] = parsed;
      }
    } catch (_) {
      _byCurveHash.clear();
    }
  }

  void _persist() {
    final encoded = jsonEncode(
      listPresets().map((preset) => preset.toJson()).toList(),
    );
    _storageDriver.writeSnapshot(encoded);
  }

  void _emitProof({
    required String action,
    required String presetId,
    required String curveHash,
    required String selectedLaneId,
    required String selectedKeyframeId,
    required String fallbackReason,
  }) {
    developer.log(
      'TF_SPEED_GRAPH_CUSTOM_PRESET_PROOF '
      'action=$action '
      'presetId=$presetId '
      'curveHash=$curveHash '
      'storedAsBezierTruth=true '
      'velocityOnlyPersistence=false '
      'selectedLaneId=$selectedLaneId '
      'selectedKeyframeId=$selectedKeyframeId '
      'fallbackReason=$fallbackReason',
      name: 'ReFusionXx.SpeedGraph',
    );
  }
}
