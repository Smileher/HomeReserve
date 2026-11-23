import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:home_reserve/domain.dart';
import 'package:home_reserve/reports.dart';
import 'package:home_reserve/store.dart';

import 'domain_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('初始化保留已经保存的成员、记录和设备设置', () async {
    final store = AppStore(memoryOnly: true);
    store.book = fixture.sample();
    store.book.settings['initialized'] = true;
    final before = canonical(store.book.toJson());
    await store.initialize();
    expect(canonical(store.book.toJson()), before);
    store.dispose();
  });
  test('SQLite 持久化完整恢复数据及整数金额', () async {
    final db = LocalDatabase(NativeDatabase.memory());
    final book = fixture.sample();
    await db.save(Book(), book);
    final restored = await db.readBook();
    expect(canonical(restored.toJson()), canonical(book.toJson()));
    await db.close();
  });
  test('重置清空持久化账本、设置和自动备份，保留外部导出文件', () async {
    final directory = await Directory.systemTemp.createTemp(
      'home-reserve-reset-',
    );
    final db = LocalDatabase(
      NativeDatabase(File('${directory.path}/test.sqlite')),
    );
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    store.db = db;
    store.directory = directory;
    await store.commit(fixture.sample());
    final oldDeviceId = store.book.settings['deviceId'];
    await store.createBackup();
    final exported = File('${directory.path}/exported.json');
    await exported.writeAsString('exported data', encoding: utf8);
    await store.resetData();
    expect(store.book.entries, isEmpty);
    expect(store.book.settings['theme'], 'system');
    expect(store.book.settings['device'], '本机设备');
    expect(store.book.settings['deviceId'], isNot(oldDeviceId));
    expect(store.book.settings['initialized'], isTrue);
    expect(await store.backups(), isEmpty);
    expect(await exported.exists(), isTrue);
    expect(
      canonical((await db.readBook()).toJson()),
      canonical(store.book.toJson()),
    );
    expect(store.busy, isFalse);
    store.db = null;
    store.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });
  test('重置保留写入锁，事务失败后不清空账本和备份', () async {
    final directory = await Directory.systemTemp.createTemp(
      'home-reserve-reset-fail-',
    );
    final db = LocalDatabase(NativeDatabase.memory());
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    store.db = db;
    store.directory = directory;
    await store.commit(fixture.sample());
    await store.createBackup();
    final original = canonical(store.book.toJson());
    store.busy = true;
    await expectLater(store.resetData(), throwsStateError);
    store.busy = false;
    await db.customStatement(
      "CREATE TRIGGER fail_reset BEFORE DELETE ON entities BEGIN SELECT RAISE(ABORT, 'test reset failure'); END",
    );
    await expectLater(store.resetData(), throwsA(isA<Exception>()));
    expect(canonical(store.book.toJson()), original);
    expect(canonical((await db.readBook()).toJson()), original);
    expect(await store.backups(), hasLength(1));
    expect(store.busy, isFalse);
    store.db = null;
    store.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });
  test('Excel 金额为数值，CSV 往返保留中文备注，Word 为有效 OOXML', () {
    final book = fixture.sample();
    final report = ReportData(book, 2026);
    final excel = Excel.decodeBytes(report.xlsx());
    expect(
      excel.tables['月度记录']!.rows[1][2]!.value,
      anyOf(isA<DoubleCellValue>(), isA<IntCellValue>()),
    );
    final imported = parseTable(utf8.encode(report.csv()), 'csv', book);
    expect(imported.book.months.single.data['saving'], 300000);
    expect(imported.book.months.single.data['note'], '生活 & 储蓄');
    final archive = ZipDecoder().decodeBytes(report.docx());
    expect(archive.files.any((f) => f.name == 'word/document.xml'), true);
  });
  test('CSV 文本不会成为公式，同时保留负净存入', () {
    final book = fixture.sample();
    book.entries['month'] = book.entries['month']!.change({
      'note': '-123+456',
      'saving': -1203,
    });
    final csv = ReportData(book, 2026).csv();
    expect(csv, contains("'-123+456"));
    expect(csv, contains('"-12.03"'));
  });
  test('SQLite 事务失败后保留原始账本', () async {
    final db = LocalDatabase(NativeDatabase.memory());
    await db.save(Book(), fixture.sample());
    await expectLater(
      db.transaction(() async {
        await db.customStatement('DELETE FROM entities');
        throw StateError('模拟导入写入失败');
      }),
      throwsStateError,
    );
    expect((await db.readBook()).months.length, 1);
    await db.close();
  });
}
