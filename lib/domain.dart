import 'dart:convert';
import 'package:uuid/uuid.dart';

const sharedOwner = 'shared';
const categories = ['银行卡', '支付账户', '存款', '理财', '现金', '其他'];
const _uuid = Uuid();
String newId() => _uuid.v4();
String monthKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';
String dayKey(DateTime date) => '${monthKey(date)}-${date.day.toString().padLeft(2, '0')}';
String money(int cents) => '${cents < 0 ? '-' : ''}¥${(cents.abs() ~/ 100).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}.${(cents.abs() % 100).toString().padLeft(2, '0')}';
int parseMoney(String text, {bool signed = false}) {
  final value = text.trim();
  if (!RegExp(signed ? r'^-?\d{1,12}(\.\d{1,2})?$' : r'^\d{1,12}(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException('请输入有效金额，最多两位小数');
  }
  final negative = value.startsWith('-');
  final parts = value.replaceFirst('-', '').split('.');
  final amount = int.parse(parts.first) * 100 + (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return negative ? -amount : amount;
}
String editMoney(int? cents) => cents == null ? '' : '${cents < 0 ? '-' : ''}${cents.abs() ~/ 100}.${(cents.abs() % 100).toString().padLeft(2, '0')}';

/// Data payloads stay separate from provenance so repeated imports are idempotent.
class Entry {
  Entry({required this.id, required this.kind, required this.data, String? modified, this.source = '', this.importedAt = ''}) : modified = modified ?? DateTime.now().toUtc().toIso8601String();
  final String id, kind, modified, source, importedAt;
  final Map<String, dynamic> data;
  Entry change(Map<String, dynamic> values) => Entry(id: id, kind: kind, data: {...data, ...values}, source: source, importedAt: importedAt);
  Entry imported(String device, String time) => Entry(id: id, kind: kind, data: Map.from(data), modified: modified, source: device, importedAt: time);
  Map<String, dynamic> toJson() => {'id': id, 'kind': kind, 'data': data, 'modified': modified, 'source': source, 'importedAt': importedAt};
  factory Entry.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String || (json['id'] as String).isEmpty || json['kind'] is! String || json['data'] is! Map || json['modified'] is! String) {
      throw const FormatException('记录结构不正确');
    }
    final modified = json['modified'] as String;
    if (DateTime.tryParse(modified) == null) throw const FormatException('记录修改时间无效');
    return Entry(id: json['id'], kind: json['kind'], data: Map<String, dynamic>.from(json['data']), modified: modified, source: json['source'] as String? ?? '', importedAt: json['importedAt'] as String? ?? '');
  }
  bool same(Entry other) => kind == other.kind && canonical(data) == canonical(other.data);
  String get label => data['name'] as String? ?? '${data['month'] ?? data['date'] ?? ''}';
}

String canonical(dynamic value) {
  dynamic sorted(dynamic v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: sorted(v[k])};
    }
    if (v is List) return v.map(sorted).toList();
    return v;
  }
  return jsonEncode(sorted(value));
}

class Book {
  Book({Map<String, Entry>? entries, Map<String, dynamic>? settings}) : entries = entries ?? {}, settings = settings ?? {};
  final Map<String, Entry> entries;
  final Map<String, dynamic> settings;
  Book copy() => Book(entries: Map.from(entries), settings: Map.from(settings));
  List<Entry> of(String kind) => entries.values.where((e) => e.kind == kind).toList();
  List<Entry> get members => of('member')..sort((a,b) => (a.data['order'] as int).compareTo(b.data['order'] as int));
  List<Entry> get accounts => of('account');
  List<Entry> get months => of('month');
  List<Entry> get balances => of('balance');
  List<Entry> get allocations => of('allocation');
  String name(String? id) => id == sharedOwner ? '家庭共同' : entries[id]?.label ?? '未知';
  String businessKey(Entry e) => switch(e.kind) {
    'month' => 'month:${e.data['member']}:${e.data['month']}',
    'balance' => 'balance:${e.data['account']}:${e.data['date']}',
    'allocation' => 'allocation:${e.data['record']}:${e.data['account']}',
    _ => '${e.kind}:${e.id}',
  };
  Entry? monthly(String member, String month) => months.where((e) => e.data['member'] == member && e.data['month'] == month).firstOrNull;
  Entry? latestBalance(String account, {String? at}) {
    final list = balances.where((e) => e.data['account'] == account && (at == null || (e.data['date'] as String).compareTo(at) <= 0)).toList()
      ..sort((a,b) => (b.data['date'] as String).compareTo(a.data['date'] as String));
    return list.firstOrNull;
  }
  int assets({String? at}) => accounts.fold(0, (v,a) => v + (latestBalance(a.id, at: at)?.data['amount'] as int? ?? 0));
  Map<String, dynamic> toJson() => {'entries': entries.values.map((e) => e.toJson()).toList(), 'settings': settings};
  factory Book.fromJson(Map<String, dynamic> json) {
    if (json['entries'] is! List || json['settings'] is! Map) throw const FormatException('账本结构无效');
    final list = (json['entries'] as List).map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    if (list.map((e) => e.id).toSet().length != list.length) throw const FormatException('记录标识重复');
    final book = Book(entries: {for(final e in list) e.id:e}, settings: Map<String, dynamic>.from(json['settings']));
    book.validate();
    return book;
  }
  void validate() {
    final keys = <String>{};
    void requiredText(Entry e, String key, [int max = 2000]) {
      final v = e.data[key];
      if (v is! String || v.length > max) throw FormatException('${e.kind}：$key 无效');
    }
    void amount(Entry e, String key, {bool negative = false, bool nullable = false}) {
      final v = e.data[key];
      if (v == null && nullable) return;
      if (v is! int || v.abs() > 99999999999999 || (!negative && v < 0)) throw FormatException('${e.label}：金额无效');
    }
    void reference(Entry e, String field, String kind, {bool shared = false}) {
      if (shared && e.data[field] == sharedOwner) return;
      if (entries[e.data[field]]?.kind != kind) throw FormatException('${e.label}：关联$kind不存在');
    }
    for (final e in entries.values) {
      if (!keys.add(businessKey(e))) throw FormatException('${e.label}：同一期间记录重复');
      switch (e.kind) {
        case 'member':
          requiredText(e,'name',40);
          if ((e.data['name'] as String).trim().isEmpty || e.data['active'] is! bool || e.data['order'] is! int) throw const FormatException('成员信息无效');
        case 'account':
          requiredText(e,'name',60); requiredText(e,'note');
          if ((e.data['name'] as String).trim().isEmpty || !categories.contains(e.data['category']) || e.data['archived'] is! bool) throw const FormatException('账户信息无效');
          reference(e,'owner','member',shared:true);
        case 'month':
          reference(e,'member','member'); requiredText(e,'note');
          if (e.data['month'] is! String || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(e.data['month'])) throw const FormatException('月份无效');
          amount(e,'income',nullable:true); amount(e,'saving',negative:true,nullable:true);
        case 'balance':
          reference(e,'account','account'); requiredText(e,'note'); amount(e,'amount');
          final date = e.data['date'];
          if (date is! String || DateTime.tryParse(date) == null || dayKey(DateTime.parse(date)) != date || date.compareTo(dayKey(DateTime.now())) > 0) throw const FormatException('余额核对日期无效或在未来');
        case 'allocation':
          reference(e,'record','month'); reference(e,'account','account'); amount(e,'amount',negative:true);
        case 'tombstone':
          if (e.data['key'] is! String || e.data['deletedKind'] is! String) throw const FormatException('删除标记无效');
        default: throw FormatException('不支持的记录类型：${e.kind}');
      }
    }
    for (final record in months) {
      final list = allocations.where((a) => a.data['record'] == record.id);
      final total = list.fold(0,(v,e) => v + (e.data['amount'] as int));
      final saving = record.data['saving'] as int?;
      // Mixed positive/negative allocations are valid; the residual is explicit.
      if (saving == null && list.isNotEmpty) throw const FormatException('请先填写净存入再分配账户');
      if (saving != null && ((saving >= 0 && (total < 0 || total > saving)) || (saving < 0 && (total > 0 || total < saving)))) {
        throw const FormatException('账户分配合计必须介于零与本月净存入之间');
      }
    }
  }
}

class MonthSummary {
  MonthSummary(Book book, this.month) {
    final records = book.months.where((e) => e.data['month'] == month);
    for (final e in records) {
      income += e.data['income'] as int? ?? 0;
      saving += e.data['saving'] as int? ?? 0;
      if (e.data['income'] != null && e.data['saving'] != null) completeMembers.add(e.data['member'] as String);
    }
    final expected = book.members.where((e) => e.data['active'] == true || records.any((r) => r.data['member'] == e.id));
    missingMembers = expected.where((e) => !completeMembers.contains(e.id)).map((e) => e.label).toList();
  }
  final String month;
  int income = 0, saving = 0;
  final Set<String> completeMembers = {};
  List<String> missingMembers = [];
  bool get complete => missingMembers.isEmpty && completeMembers.isNotEmpty;
  double? get rate => income == 0 ? null : saving / income * 100;
}
