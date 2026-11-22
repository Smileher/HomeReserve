import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import 'domain.dart';
import 'transfer.dart';

class ReportData {
  ReportData(this.book, this.year);
  final Book book;
  final int year;
  List<Entry> get records =>
      book.months
          .where((e) => (e.data['month'] as String).startsWith('$year-'))
          .toList()
        ..sort(
          (a, b) => '${a.data['month']}:${book.name(a.data['member'])}'
              .compareTo('${b.data['month']}:${book.name(b.data['member'])}'),
        );
  List<List<String>> get rows => [
    ['月份', '成员', '收入（元）', '净存入（元）', '备注'],
    ...records.map(
      (e) => [
        e.data['month'] as String,
        book.name(e.data['member']),
        editMoney(e.data['income']),
        editMoney(e.data['saving']),
        e.data['note'] as String,
      ],
    ),
  ];
  int get income =>
      records.fold(0, (sum, e) => sum + (e.data['income'] as int? ?? 0));
  int get saving =>
      records.fold(0, (sum, e) => sum + (e.data['saving'] as int? ?? 0));
  String get completeness {
    final recorded = records.map((e) => e.data['month'] as String).toSet();
    final complete = recorded
        .where((m) => MonthSummary(book, m).complete)
        .length;
    return '已记录 ${recorded.length} 个月，其中 $complete 个月填写完整；缺失金额不计为零。';
  }

  String get generated =>
      '生成时间：${DateTime.now().toLocal().toString().split('.').first} · 人民币';
  String csv() =>
      '\uFEFF${rows.map((row) => row.asMap().entries.map((cell) {
        final value = cell.value;
        final numeric = (cell.key == 2 || cell.key == 3) && RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(value);
        // User text must not become a formula; signed numeric money remains numeric.
        final safe = !numeric && RegExp(r'^[\s]*[=+@-]|^[\t\r]').hasMatch(value) ? "'$value" : value;
        return '"${safe.replaceAll('"', '""')}"';
      }).join(',')).join('\r\n')}';
  Uint8List xlsx() {
    final excel = Excel.createExcel();
    final sheet = excel['月度记录'];
    excel.delete('Sheet1');
    sheet.appendRow(rows.first.map(TextCellValue.new).toList());
    for (final e in records) {
      sheet.appendRow([
        TextCellValue(e.data['month']),
        TextCellValue(book.name(e.data['member'])),
        e.data['income'] == null
            ? TextCellValue('未填写')
            : DoubleCellValue((e.data['income'] as int) / 100),
        e.data['saving'] == null
            ? TextCellValue('未填写')
            : DoubleCellValue((e.data['saving'] as int) / 100),
        TextCellValue(e.data['note']),
      ]);
    }
    final overview = excel['年度汇总'];
    for (final row in <List<CellValue>>[
      [TextCellValue('$year 年家庭收入与储蓄报告')],
      [TextCellValue('收入（元）'), DoubleCellValue(income / 100)],
      [TextCellValue('净存入（元）'), DoubleCellValue(saving / 100)],
      [TextCellValue(completeness)],
      [TextCellValue(generated)],
    ]) {
      overview.appendRow(row);
    }
    final accounts = excel['资产核对历史'];
    accounts.appendRow(
      ['账户', '归属', '类别', '核对日期', '余额（元）', '备注'].map(TextCellValue.new).toList(),
    );
    final balances = book.balances.toList()
      ..sort(
        (a, b) =>
            (a.data['date'] as String).compareTo(b.data['date'] as String),
      );
    for (final b in balances) {
      final a = book.entries[b.data['account']]!;
      accounts.appendRow([
        TextCellValue(a.label),
        TextCellValue(book.name(a.data['owner'])),
        TextCellValue(a.data['category']),
        TextCellValue(b.data['date']),
        DoubleCellValue((b.data['amount'] as int) / 100),
        TextCellValue(b.data['note']),
      ]);
    }
    final members = excel['成员汇总'];
    members.appendRow(
      ['成员', '收入（元）', '净存入（元）'].map(TextCellValue.new).toList(),
    );
    for (final m in book.members) {
      final list = records.where((e) => e.data['member'] == m.id);
      members.appendRow([
        TextCellValue(m.label),
        DoubleCellValue(
          list.fold(0, (int v, e) => v + (e.data['income'] as int? ?? 0)) / 100,
        ),
        DoubleCellValue(
          list.fold(0, (int v, e) => v + (e.data['saving'] as int? ?? 0)) / 100,
        ),
      ]);
    }
    return Uint8List.fromList(excel.encode()!);
  }

  Uint8List docx() {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    String para(String s, {bool title = false}) =>
        '<w:p><w:pPr>${title ? '<w:spacing w:after="240"/>' : ''}</w:pPr><w:r><w:rPr><w:rFonts w:ascii="Calibri" w:eastAsia="Microsoft YaHei"/>${title ? '<w:b/><w:sz w:val="36"/>' : ''}</w:rPr><w:t xml:space="preserve">${esc(s)}</w:t></w:r></w:p>';
    final table =
        '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="4"/><w:bottom w:val="single" w:sz="4"/><w:insideH w:val="single" w:sz="4"/></w:tblBorders></w:tblPr>${rows.map((r) => '<w:tr>${r.map((c) => '<w:tc><w:tcPr><w:tcW w:w="1800" w:type="dxa"/></w:tcPr>${para(c)}</w:tc>').join()}</w:tr>').join()}</w:tbl>';
    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${para('家有余 · $year 年家庭报告', title: true)}${para(generated)}${para('收入 ${money(income)}    净存入 ${money(saving)}')}${para(completeness)}$table${para('累计净存入不等于资产余额；账户余额以实际核对为准。')}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="900" w:bottom="1134" w:left="900"/></w:sectPr></w:body></w:document>';
    final files = {
      '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
      '_rels/.rels': '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
      'word/document.xml': document,
    };
    final zip = Archive();
    for (final file in files.entries) {
      final bytes = utf8.encode(file.value);
      zip.addFile(ArchiveFile(file.key, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(zip)!);
  }
}

/// Template import enters the same preview/conflict pipeline as a full package.
DataPackage parseTable(List<int> bytes, String extension, Book local) {
  List<List<String>> rows;
  if (extension == 'xlsx') {
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables['月度记录'] ?? workbook.tables.values.first;
    rows = sheet.rows
        .map((r) => r.map((c) => c?.value.toString() ?? '').toList())
        .toList();
  } else {
    rows = _csvRows(utf8.decode(bytes).replaceFirst('\uFEFF', ''));
  }
  if (rows.isEmpty ||
      rows.first.length < 4 ||
      rows.first[0] != '月份' ||
      rows.first[1] != '成员') {
    throw const FormatException('请使用本软件导出的月度记录模板');
  }
  final incoming = Book();
  for (final row in rows.skip(1)) {
    if (row.every((c) => c.trim().isEmpty)) continue;
    if (row.length < 4) throw const FormatException('表格列数不足');
    final name = row[1].trim();
    if (name.isEmpty) throw const FormatException('成员名称不能为空');
    var member = incoming.members.where((e) => e.label == name).firstOrNull;
    member ??= local.members.where((e) => e.label == name).firstOrNull;
    member ??= Entry(
      id: newId(),
      kind: 'member',
      data: {'name': name, 'active': true, 'order': incoming.members.length},
    );
    incoming.entries[member.id] = member;
    final record = Entry(
      id: newId(),
      kind: 'month',
      data: {
        'member': member.id,
        'month': row[0].trim(),
        'income': row[2].trim().isEmpty || row[2] == '未填写'
            ? null
            : parseMoney(row[2]),
        'saving': row[3].trim().isEmpty || row[3] == '未填写'
            ? null
            : parseMoney(row[3], signed: true),
        'note': row.length > 4 ? row[4] : '',
      },
    );
    incoming.entries[record.id] = record;
  }
  incoming.validate();
  return DataPackage(
    book: incoming,
    device: '表格导入',
    exportedAt: DateTime.now().toUtc().toIso8601String(),
    batch: newId(),
    offset: DateTime.now().timeZoneOffset.inMinutes,
  );
}

List<List<String>> _csvRows(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (c == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      row.add(cell.toString());
      cell = StringBuffer();
    } else if ((c == '\n' || c == '\r') && !quoted) {
      if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(cell.toString());
      rows.add(row);
      row = [];
      cell = StringBuffer();
    } else {
      cell.write(c);
    }
  }
  if (quoted) throw const FormatException('CSV 引号未闭合');
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}
