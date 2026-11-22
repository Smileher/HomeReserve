import 'dart:convert';

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
  test('SQLite 持久化完整恢复数据及整数金额', () async {
    final db = LocalDatabase(NativeDatabase.memory());
    final book = fixture.sample();
    await db.save(Book(), book);
    final restored = await db.readBook();
    expect(canonical(restored.toJson()), canonical(book.toJson()));
    await db.close();
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
  test('PDF 使用打包中文字体生成完整文件', () async {
    final bytes = await ReportData(fixture.sample(), 2026).pdf();
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
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
