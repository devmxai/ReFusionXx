import 'package:flutter/foundation.dart';

import 'refusion_mcp_session.dart';

class RefusionMcpSessionStore {
  RefusionMcpSessionStore({
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final Map<String, RefusionMcpSession> _byId = <String, RefusionMcpSession>{};

  void upsert(RefusionMcpSession session) {
    _byId[session.id] = session.copyWith(lastSeenAt: _clock());
  }

  RefusionMcpSession? get(String id) {
    final session = _byId[id];
    if (session == null) {
      return null;
    }
    final touched = session.copyWith(lastSeenAt: _clock());
    _byId[id] = touched;
    return touched;
  }

  bool remove(String id) {
    return _byId.remove(id) != null;
  }

  List<RefusionMcpSession> list() {
    final sessions = _byId.values.toList(growable: false);
    sessions.sort((left, right) => left.id.compareTo(right.id));
    return sessions;
  }
}
