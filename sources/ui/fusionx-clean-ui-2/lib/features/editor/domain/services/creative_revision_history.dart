import 'unified_creative_apply_engine.dart';

class CreativeRevisionHistory {
  const CreativeRevisionHistory({
    this.past = const <UnifiedCreativeState>[],
    this.present,
    this.future = const <UnifiedCreativeState>[],
  });

  final List<UnifiedCreativeState> past;
  final UnifiedCreativeState? present;
  final List<UnifiedCreativeState> future;

  CreativeRevisionHistory seed(UnifiedCreativeState state) {
    return CreativeRevisionHistory(
      past: const <UnifiedCreativeState>[],
      present: state,
      future: const <UnifiedCreativeState>[],
    );
  }

  CreativeRevisionHistory commit(UnifiedCreativeState next) {
    final current = present;
    if (current == null) {
      return CreativeRevisionHistory(
        past: const <UnifiedCreativeState>[],
        present: next,
        future: const <UnifiedCreativeState>[],
      );
    }
    return CreativeRevisionHistory(
      past: <UnifiedCreativeState>[...past, current],
      present: next,
      future: const <UnifiedCreativeState>[],
    );
  }

  CreativeRevisionHistory undo() {
    if (past.isEmpty || present == null) {
      return this;
    }
    final previous = past.last;
    final remainingPast = past.sublist(0, past.length - 1);
    return CreativeRevisionHistory(
      past: remainingPast,
      present: previous,
      future: <UnifiedCreativeState>[present!, ...future],
    );
  }

  CreativeRevisionHistory redo() {
    if (future.isEmpty || present == null) {
      return this;
    }
    final next = future.first;
    final remainingFuture = future.sublist(1);
    return CreativeRevisionHistory(
      past: <UnifiedCreativeState>[...past, present!],
      present: next,
      future: remainingFuture,
    );
  }
}
