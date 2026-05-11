import 'dart:convert';
import 'dart:io';

abstract class RefusionMcpAuditPersistence {
  List<Map<String, Object?>> load();

  void save(List<Map<String, Object?>> entries);
}

class RefusionMcpFileAuditPersistence implements RefusionMcpAuditPersistence {
  RefusionMcpFileAuditPersistence({
    required this.path,
  });

  final String path;

  @override
  List<Map<String, Object?>> load() {
    final file = File(path);
    if (!file.existsSync()) {
      return const <Map<String, Object?>>[];
    }
    final raw = file.readAsStringSync();
    if (raw.trim().isEmpty) {
      return const <Map<String, Object?>>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <Map<String, Object?>>[];
    }
    final rows = <Map<String, Object?>>[];
    for (final entry in decoded) {
      if (entry is Map) {
        rows.add(entry.map((key, value) {
          return MapEntry(key.toString(), value);
        }));
      }
    }
    return rows;
  }

  @override
  void save(List<Map<String, Object?>> entries) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final serialized = const JsonEncoder.withIndent('  ').convert(entries);
    file.writeAsStringSync(serialized, flush: true);
  }
}
