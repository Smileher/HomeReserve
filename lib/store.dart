import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'domain.dart';

class LocalDatabase extends GeneratedDatabase {
  LocalDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE entities (id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, body TEXT NOT NULL)',
      );
      await customStatement('CREATE INDEX entities_kind ON entities(kind)');
      await customStatement(
        'CREATE TABLE preferences (id INTEGER PRIMARY KEY CHECK (id=1), body TEXT NOT NULL)',
      );
    },
  );
  Future<Book> readBook() async {
    final rows = await customSelect('SELECT body FROM entities').get();
    final prefs = await customSelect('SELECT body FROM preferences WHERE id=1')
        .get();
    return Book.fromJson({
      'entries': rows.map((r) => jsonDecode(r.read<String>('body'))).toList(),
      'settings': prefs.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(prefs.first.read<String>('body')),
    });
  }

  Future<void> save(Book before, Book after) => transaction(() async {
    for (final id in before.entries.keys.where(
      (id) => !after.entries.containsKey(id),
    )) {
      await customStatement('DELETE FROM entities WHERE id=?', [id]);
    }
    for (final e in after.entries.values) {
      if (canonical(before.entries[e.id]?.toJson()) == canonical(e.toJson())) {
        continue;
      }
      await customStatement(
        'INSERT INTO entities(id,kind,body) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET kind=excluded.kind,body=excluded.body',
        [e.id, e.kind, jsonEncode(e.toJson())],
      );
    }
    await customStatement(
      'INSERT INTO preferences(id,body) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET body=excluded.body',
      [jsonEncode(after.settings)],
    );
  });
}

class AppStore extends ChangeNotifier {
  AppStore({this.memoryOnly = false});
  final bool memoryOnly;
  Book book = Book();
  bool ready = false, busy = false;
  String? error;
  LocalDatabase? db;
  Directory? directory;
  Future<void> initialize() async {
    try {
      if (!memoryOnly) {
        directory = await getApplicationSupportDirectory();
        await directory!.create(recursive: true);
        db = LocalDatabase(
          NativeDatabase.createInBackground(
            File(p.join(directory!.path, 'home_reserve.sqlite')),
          ),
        );
        book = await db!.readBook();
      }
      if (book.settings['initialized'] != true) {
        final next = book.copy();
        next.settings.addAll({
          'initialized': true,
          'theme': 'system',
          'device': '本机设备',
          'deviceId': newId(),
        });
        await db?.save(book, next);
        book = next;
      }
      ready = true;
    } catch (e) {
      error = '打开本地数据失败：$e';
    }
    notifyListeners();
  }

  Future<void> commit(Book next, {bool backup = false}) async {
    if (busy) throw StateError('正在保存，请稍后重试');
    next.validate();
    busy = true;
    notifyListeners();
    try {
      if (backup) await createBackup();
      await db?.save(book, next);
      book = next;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> put(Entry entry) async {
    final next = book.copy();
    next.entries[entry.id] = entry;
    await commit(next);
  }

  Future<void> settings(Map<String, dynamic> values) async {
    final next = book.copy();
    next.settings.addAll(values);
    await commit(next);
  }

  Future<void> deleteMonth(Entry e) async {
    final next = book.copy();
    final children = next.allocations
        .where((a) => a.data['record'] == e.id)
        .toList();
    for (final item in [e, ...children]) {
      next.entries.remove(item.id);
      final tomb = Entry(
        id: 'deleted-${item.id}',
        kind: 'tombstone',
        data: {
          'key': book.businessKey(item),
          'deletedKind': item.kind,
          'originalId': item.id,
          'label': item.label,
        },
      );
      next.entries[tomb.id] = tomb;
    }
    await commit(next, backup: true);
  }

  Future<void> createBackup() async {
    if (directory == null) return;
    final folder = Directory(p.join(directory!.path, 'backups'));
    await folder.create(recursive: true);
    final filename =
        'backup-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.json';
    await File(p.join(folder.path, filename))
        .writeAsString(jsonEncode(book.toJson()), encoding: utf8, flush: true);
    final files = await folder
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(10)) {
      await file.delete();
    }
  }

  Future<List<File>> backups() async {
    if (directory == null) return [];
    final folder = Directory(p.join(directory!.path, 'backups'));
    if (!await folder.exists()) return [];
    final files = await folder
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> restoreBackup(File file) async {
    final next = Book.fromJson(
      jsonDecode(await file.readAsString(encoding: utf8))
          as Map<String, dynamic>,
    );
    await commit(next, backup: true);
  }

  @override
  void dispose() {
    db?.close();
    super.dispose();
  }
}
