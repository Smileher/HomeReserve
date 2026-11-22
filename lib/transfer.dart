import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'domain.dart';

class DataPackage {
  DataPackage({
    required this.book,
    required this.device,
    required this.exportedAt,
    required this.batch,
    required this.offset,
  });
  final Book book;
  final String device, exportedAt, batch;
  final int offset;
  factory DataPackage.create(Book book) => DataPackage(
    book: book,
    device: book.settings['device'] as String? ?? '未命名设备',
    exportedAt: DateTime.now().toUtc().toIso8601String(),
    batch: newId(),
    offset: DateTime.now().timeZoneOffset.inMinutes,
  );
  Map<String, dynamic> get payload => {
    'format': 'HomeReserve',
    'version': 1,
    'device': device,
    'exportedAt': exportedAt,
    'offsetMinutes': offset,
    'batch': batch,
    'book': book.toJson(),
  };
  String encode() {
    final data = payload;
    return const JsonEncoder.withIndent('  ').convert({
      ...data,
      'sha256': sha256.convert(utf8.encode(canonical(data))).toString(),
    });
  }

  factory DataPackage.decode(String text) {
    if (utf8.encode(text).length > 20 * 1024 * 1024) {
      throw const FormatException('数据包超过 20 MB，请检查文件');
    }
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic> ||
        value['format'] != 'HomeReserve' ||
        value['version'] != 1) {
      throw const FormatException('不是有效的数据包，或需要更新软件后再导入');
    }
    final data = Map<String, dynamic>.from(value);
    final hash = data.remove('sha256');
    if (hash != sha256.convert(utf8.encode(canonical(data))).toString()) {
      throw const FormatException('文件校验失败，内容可能已损坏或被修改');
    }
    if (data['device'] is! String ||
        data['exportedAt'] is! String ||
        DateTime.tryParse(data['exportedAt']) == null ||
        data['batch'] is! String ||
        data['offsetMinutes'] is! int) {
      throw const FormatException('导出信息不完整');
    }
    if ((data['offsetMinutes'] as int).abs() > 840 ||
        (data['device'] as String).length > 120) {
      throw const FormatException('导出设备名称或时区无效');
    }
    return DataPackage(
      book: Book.fromJson(Map<String, dynamic>.from(data['book'] as Map)),
      device: data['device'],
      exportedAt: data['exportedAt'],
      batch: data['batch'],
      offset: data['offsetMinutes'],
    );
  }
}

class ImportConflict {
  ImportConflict(this.incoming, this.local, {this.deleted = false});
  final Entry incoming;
  final Entry? local;
  final bool deleted;
  bool useIncoming = false;
}

/// An import is first resolved in memory, then validated and committed atomically.
class ImportPlan {
  ImportPlan(this.local, this.package);
  final Book local;
  final DataPackage package;
  final Map<String, String> mapping = {};
  final List<ImportConflict> conflicts = [];
  final List<Entry> additions = [];
  int sameCount = 0;
  bool applySettings = false;
  bool restore = false;
  List<Entry> get ambiguous => package.book.entries.values
      .where(
        (e) =>
            (e.kind == 'member' || e.kind == 'account') &&
            !local.entries.containsKey(e.id) &&
            local
                .of(e.kind)
                .any(
                  (l) =>
                      l.label.trim().toLowerCase() ==
                      e.label.trim().toLowerCase(),
                ),
      )
      .toList();
  void prepare() {
    additions.clear();
    conflicts.clear();
    sameCount = 0;
    if (ambiguous.any((e) => !mapping.containsKey(e.id))) {
      throw const FormatException('请先确认同名成员与账户的对应关系');
    }
    final ids = <String, String>{...mapping};
    final pending =
        package.book.entries.values.where((e) => e.kind != 'tombstone').toList()
          ..sort((a, b) => _rank(a.kind).compareTo(_rank(b.kind)));
    final seen = local.copy();
    for (final original in pending) {
      final data = Map<String, dynamic>.from(original.data);
      for (final field in ['owner', 'member', 'account', 'record']) {
        if (data[field] is String) {
          data[field] = ids[data[field]] ?? data[field];
        }
      }
      var item = Entry(
        id: ids[original.id] ?? original.id,
        kind: original.kind,
        data: data,
        modified: original.modified,
        source: original.source,
        importedAt: original.importedAt,
      );
      // Explicit identity mapping merges references without renaming the local owner/account.
      if (mapping.containsKey(original.id) &&
          mapping[original.id] != original.id) {
        sameCount++;
        continue;
      }
      final key = seen.businessKey(item);
      final match =
          seen.entries[item.id] ??
          seen
              .of(item.kind)
              .where((e) => seen.businessKey(e) == key)
              .firstOrNull;
      if (match != null && match.kind != item.kind) {
        throw const FormatException('记录标识与本机类型冲突');
      }
      if (match != null) {
        ids[original.id] = match.id;
        item = Entry(
          id: match.id,
          kind: item.kind,
          data: item.data,
          modified: item.modified,
          source: item.source,
          importedAt: item.importedAt,
        );
        if (match.same(item)) {
          sameCount++;
        } else {
          conflicts.add(ImportConflict(item, match));
        }
      } else {
        ids[original.id] = item.id;
        final deleted = local
            .of('tombstone')
            .any(
              (e) =>
                  e.data['originalId'] == original.id || e.data['key'] == key,
            );
        if (deleted) {
          conflicts.add(ImportConflict(item, null, deleted: true));
        } else {
          additions.add(item);
        }
        seen.entries[item.id] = item;
      }
    }
  }

  int _rank(String kind) => switch (kind) {
    'member' => 0,
    'account' => 1,
    'month' => 2,
    'balance' => 3,
    'allocation' => 4,
    _ => 5,
  };
  Book result() {
    final time = DateTime.now().toUtc().toIso8601String();
    if (restore) {
      final next = package.book.copy();
      final personal = Map<String, dynamic>.from(local.settings);
      if (applySettings) {
        personal['theme'] = package.book.settings['theme'] ?? 'system';
      }
      next.settings
        ..clear()
        ..addAll(personal);
      for (final e in next.entries.values.toList()) {
        if (e.kind != 'tombstone') {
          next.entries[e.id] = e.imported(package.device, time);
        }
      }
      next.validate();
      return next;
    }
    final next = local.copy();
    for (final e in [
      ...additions,
      ...conflicts.where((c) => c.useIncoming).map((c) => c.incoming),
    ]) {
      // A deleted parent kept locally must not silently regain its dependent allocations.
      if (e.kind == 'allocation' &&
          next.entries[e.data['record']]?.kind != 'month') {
        continue;
      }
      next.entries[e.id] = e.imported(package.device, time);
      next.entries.removeWhere(
        (id, t) =>
            t.kind == 'tombstone' &&
            (t.data['originalId'] == e.id ||
                t.data['key'] == next.businessKey(e)),
      );
    }
    if (applySettings) {
      next.settings['theme'] = package.book.settings['theme'] ?? 'system';
    }
    next.settings['lastImport'] = {
      'device': package.device,
      'time': time,
      'batch': package.batch,
    };
    next.validate();
    return next;
  }
}
