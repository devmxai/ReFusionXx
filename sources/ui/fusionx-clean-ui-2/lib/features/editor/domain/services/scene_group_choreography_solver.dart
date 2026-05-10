import '../models/refusion_motion_director_models.dart';

class SceneGroupChoreographySolveResult {
  const SceneGroupChoreographySolveResult({
    required this.components,
    required this.primitives,
    required this.issues,
    required this.groupedCardCount,
  });

  final List<ReFusionMotionDirectorComponent> components;
  final List<ReFusionMotionDirectorPrimitive> primitives;
  final List<ReFusionMotionDirectorIssue> issues;
  final int groupedCardCount;
}

class SceneGroupChoreographySolver {
  const SceneGroupChoreographySolver({
    this.enterStaggerMs = 80,
    this.exitStaggerMs = 45,
  });

  final int enterStaggerMs;
  final int exitStaggerMs;

  SceneGroupChoreographySolveResult solve({
    required List<ReFusionMotionDirectorComponent> components,
    required List<ReFusionMotionDirectorPrimitive> primitives,
    required String featureBeatId,
    required String outroBeatId,
  }) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final cardIndexes = _cardIndexesFromComponents(components);
    if (cardIndexes.length < 2) {
      return SceneGroupChoreographySolveResult(
        components: List<ReFusionMotionDirectorComponent>.unmodifiable(
          components,
        ),
        primitives: List<ReFusionMotionDirectorPrimitive>.unmodifiable(
          primitives,
        ),
        issues: const <ReFusionMotionDirectorIssue>[],
        groupedCardCount: cardIndexes.length,
      );
    }

    final mutable = primitives.toList(growable: true);
    final sortedIndexes = cardIndexes.toList(growable: false)..sort();
    _applyBeatStagger(
      mutable: mutable,
      sortedCardIndexes: sortedIndexes,
      beatId: featureBeatId,
      roleSuffix: 'shell',
      staggerMs: enterStaggerMs,
      issues: issues,
      issueCode: 'FEATURE_CARD_CASCADE_APPLIED',
    );
    _applyBeatStagger(
      mutable: mutable,
      sortedCardIndexes: sortedIndexes,
      beatId: outroBeatId,
      roleSuffix: 'shell',
      staggerMs: exitStaggerMs,
      issues: issues,
      issueCode: 'FEATURE_CARD_EXIT_COHERENCE_APPLIED',
    );

    _applyMirrorDirection(
      mutable: mutable,
      sortedCardIndexes: sortedIndexes,
      beatId: featureBeatId,
      issues: issues,
    );

    final componentOrder = _applyZOrder(components, sortedIndexes);
    return SceneGroupChoreographySolveResult(
      components: componentOrder,
      primitives: List<ReFusionMotionDirectorPrimitive>.unmodifiable(mutable),
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
      groupedCardCount: sortedIndexes.length,
    );
  }

  Set<int> _cardIndexesFromComponents(
    List<ReFusionMotionDirectorComponent> components,
  ) {
    final indexes = <int>{};
    for (final component in components) {
      final parsed = _parseCardIndex(component.id);
      if (parsed != null) {
        indexes.add(parsed);
      }
    }
    return indexes;
  }

  int? _parseCardIndex(String id) {
    final match = RegExp(r'^feature-card-(\d+)-').firstMatch(id);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  String _componentIdFor(int index, String suffix) =>
      'feature-card-$index-$suffix';

  void _applyBeatStagger({
    required List<ReFusionMotionDirectorPrimitive> mutable,
    required List<int> sortedCardIndexes,
    required String beatId,
    required String roleSuffix,
    required int staggerMs,
    required List<ReFusionMotionDirectorIssue> issues,
    required String issueCode,
  }) {
    int? baseStart;
    int? beatStart;
    int? beatEnd;
    for (final primitive in mutable) {
      if (primitive.beatId != beatId) {
        continue;
      }
      beatStart = beatStart == null
          ? primitive.startMs
          : (primitive.startMs < beatStart ? primitive.startMs : beatStart);
      beatEnd = beatEnd == null
          ? primitive.endMs
          : (primitive.endMs > beatEnd ? primitive.endMs : beatEnd);
    }
    for (final index in sortedCardIndexes) {
      final target = _componentIdFor(index, roleSuffix);
      final first = mutable
          .where((primitive) =>
              primitive.beatId == beatId &&
              primitive.targetComponentId == target)
          .toList(growable: false)
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
      if (first.isEmpty) {
        continue;
      }
      baseStart ??= first.first.startMs;
    }
    if (baseStart == null) {
      return;
    }

    for (var order = 0; order < sortedCardIndexes.length; order += 1) {
      final index = sortedCardIndexes[order];
      final shellTarget = _componentIdFor(index, roleSuffix);
      final first = mutable
          .where((primitive) =>
              primitive.beatId == beatId &&
              primitive.targetComponentId == shellTarget)
          .toList(growable: false)
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
      if (first.isEmpty) {
        continue;
      }
      final desiredStart = baseStart + (order * staggerMs);
      var delta = desiredStart - first.first.startMs;
      if (beatStart != null && beatEnd != null) {
        final cardPrimitives = mutable.where((primitive) {
          final belongsToCard =
              primitive.targetComponentId.startsWith('feature-card-$index-');
          return belongsToCard && primitive.beatId == beatId;
        }).toList(growable: false);
        if (cardPrimitives.isNotEmpty) {
          var cardMinStart = cardPrimitives.first.startMs;
          var cardMaxEnd = cardPrimitives.first.endMs;
          for (final primitive in cardPrimitives.skip(1)) {
            if (primitive.startMs < cardMinStart) {
              cardMinStart = primitive.startMs;
            }
            if (primitive.endMs > cardMaxEnd) {
              cardMaxEnd = primitive.endMs;
            }
          }
          final minDelta = beatStart - cardMinStart;
          final maxDelta = beatEnd - cardMaxEnd;
          if (delta < minDelta) {
            delta = minDelta;
          } else if (delta > maxDelta) {
            delta = maxDelta;
          }
        }
      }
      if (delta == 0) {
        continue;
      }
      final cardPrefix = 'feature-card-$index-';
      for (var i = 0; i < mutable.length; i += 1) {
        final primitive = mutable[i];
        final belongsToCard =
            primitive.targetComponentId.startsWith(cardPrefix);
        if (!belongsToCard || primitive.beatId != beatId) {
          continue;
        }
        final nextStart = primitive.startMs + delta;
        final nextEnd = primitive.endMs + delta;
        mutable[i] = ReFusionMotionDirectorPrimitive(
          id: primitive.id,
          beatId: primitive.beatId,
          targetComponentId: primitive.targetComponentId,
          kind: primitive.kind,
          startMs: nextStart,
          endMs: nextEnd <= nextStart ? nextStart + 1 : nextEnd,
          property: primitive.property,
          fromValue: primitive.fromValue,
          toValue: primitive.toValue,
          easing: primitive.easing,
          note: primitive.note,
        );
      }
    }

    issues.add(
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.info,
        message: '$issueCode beatId=$beatId '
            'staggerMs=$staggerMs '
            'cardCount=${sortedCardIndexes.length}',
        path: 'groupChoreography.$beatId',
      ),
    );
  }

  void _applyMirrorDirection({
    required List<ReFusionMotionDirectorPrimitive> mutable,
    required List<int> sortedCardIndexes,
    required String beatId,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    var mirrorFixes = 0;
    for (var order = 0; order < sortedCardIndexes.length; order += 1) {
      final cardIndex = sortedCardIndexes[order];
      if (order.isEven) {
        continue;
      }
      final shellTarget = _componentIdFor(cardIndex, 'shell');
      for (var i = 0; i < mutable.length; i += 1) {
        final primitive = mutable[i];
        if (primitive.beatId != beatId ||
            primitive.targetComponentId != shellTarget ||
            primitive.kind != 'slide' ||
            primitive.property != 'position') {
          continue;
        }
        final mirrored = _mirrorPositionX(primitive.fromValue);
        if (mirrored == null) {
          continue;
        }
        mutable[i] = ReFusionMotionDirectorPrimitive(
          id: primitive.id,
          beatId: primitive.beatId,
          targetComponentId: primitive.targetComponentId,
          kind: primitive.kind,
          startMs: primitive.startMs,
          endMs: primitive.endMs,
          property: primitive.property,
          fromValue: mirrored,
          toValue: primitive.toValue,
          easing: primitive.easing,
          note: primitive.note,
        );
        mirrorFixes += 1;
      }
    }
    if (mirrorFixes > 0) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.info,
          message:
              'FEATURE_CARD_COUNTER_DIRECTION_APPLIED beatId=$beatId fixes=$mirrorFixes',
          path: 'groupChoreography.counterDirection',
        ),
      );
    }
  }

  Object? _mirrorPositionX(Object? value) {
    if (value is Map<String, double>) {
      final x = value['x'];
      if (x == null) {
        return value;
      }
      return <String, double>{
        ...value,
        'x': -x,
      };
    }
    if (value is Map<String, Object?>) {
      final rawX = value['x'];
      final x = rawX is num ? rawX.toDouble() : null;
      if (x == null) {
        return value;
      }
      return <String, Object?>{
        ...value,
        'x': -x,
      };
    }
    return value;
  }

  List<ReFusionMotionDirectorComponent> _applyZOrder(
    List<ReFusionMotionDirectorComponent> components,
    List<int> sortedCardIndexes,
  ) {
    final byIndexOrder = <int, int>{
      for (var order = 0; order < sortedCardIndexes.length; order += 1)
        sortedCardIndexes[order]: order,
    };
    return components.map((component) {
      final cardIndex = _parseCardIndex(component.id);
      if (cardIndex == null) {
        return component;
      }
      final order = byIndexOrder[cardIndex] ?? 0;
      final baseZ = 300 - (order * 10);
      return ReFusionMotionDirectorComponent(
        id: component.id,
        role: component.role,
        label: component.label,
        layerId: component.layerId,
        elementId: component.elementId,
        properties: <String, Object?>{
          ...component.properties,
          'zIndex': baseZ,
          'groupOrder': order,
        },
      );
    }).toList(growable: false);
  }
}
