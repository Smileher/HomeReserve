import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_reserve/domain.dart';
import 'package:home_reserve/transfer.dart';

Book sample() {
  final member=Entry(id:'min',kind:'member',data:{'name':'min','active':true,'order':0});
  final account=Entry(id:'bank',kind:'account',data:{'name':'银行卡','owner':sharedOwner,'category':'银行卡','note':'','archived':false});
  final month=Entry(id:'month',kind:'month',data:{'member':'min','month':'2026-10','income':1000000,'saving':300000,'note':'生活 & 储蓄'});
  final balance=Entry(id:'balance',kind:'balance',data:{'account':'bank','date':'2026-10-31','amount':800000,'note':''});
  return Book(entries:{for(final e in [member,account,month,balance])e.id:e},settings:{'theme':'dark','device':'min 的手机'});
}
void main(){
  test('金额以分精确处理，不接受超过两位小数或科学计数法',(){expect(parseMoney('0.29'),29);expect(parseMoney('-12.03',signed:true),-1203);expect(()=>parseMoney('-1'),throwsFormatException);expect(()=>parseMoney('1.234'),throwsFormatException);expect(()=>parseMoney('1e3'),throwsFormatException);expect(money(123456789),'¥1,234,567.89');});
  test('共享资产只计一次，净存入不增加余额',(){final book=sample();book.validate();expect(book.assets(),800000);expect(book.assets(at:'2026-10-01'),0);expect(MonthSummary(book,'2026-10').saving,300000);});
  test('零与缺失不同，零收入储蓄率为空',(){final book=sample();book.entries['month']=book.entries['month']!.change({'income':0,'saving':-100});expect(MonthSummary(book,'2026-10').complete,true);expect(MonthSummary(book,'2026-10').rate,null);book.entries['month']=book.entries['month']!.change({'income':null});expect(MonthSummary(book,'2026-10').complete,false);});
  test('数据包校验、往返与重复导入幂等',(){final source=sample();final package=DataPackage.decode(DataPackage.create(source).encode());final target=Book();final first=ImportPlan(target,package)..prepare();final result=first.result();expect(result.assets(),source.assets());final second=ImportPlan(result,package)..prepare();expect(second.additions,isEmpty);expect(second.conflicts,isEmpty);expect(second.sameCount,4);final corrupt=jsonDecode(package.encode()) as Map<String,dynamic>;corrupt['device']='篡改';expect(()=>DataPackage.decode(jsonEncode(corrupt)),throwsFormatException);});
  test('业务键相同而标识不同也会展示冲突',(){final source=sample();final local=sample();local.entries.remove('month');local.entries['other']=Entry(id:'other',kind:'month',data:{...source.entries['month']!.data,'saving':200000});final plan=ImportPlan(local,DataPackage.create(source))..prepare();expect(plan.conflicts.length,1);expect(plan.result().entries['other']!.data['saving'],200000);plan.conflicts.first.useIncoming=true;expect(plan.result().entries['other']!.data['saving'],300000);});
  test('删除后导入旧包不会无提示复活',(){final source=sample();final local=sample();local.entries.remove('month');local.entries['deleted-month']=Entry(id:'deleted-month',kind:'tombstone',data:{'key':'month:min:2026-10','deletedKind':'month','originalId':'month'});final plan=ImportPlan(local,DataPackage.create(source))..prepare();expect(plan.conflicts.single.deleted,true);expect(plan.result().months,isEmpty);plan.conflicts.single.useIncoming=true;expect(plan.result().months.length,1);});
  test('同名对象要求映射，映射后引用一致',(){final source=sample();final local=Book(entries:{'local-min':Entry(id:'local-min',kind:'member',data:{'name':'min','active':true,'order':0})});final plan=ImportPlan(local,DataPackage.create(source));expect(()=>plan.prepare(),throwsFormatException);plan.mapping['min']='local-min';plan.prepare();final result=plan.result();expect(result.months.single.data['member'],'local-min');expect(result.members.length,1);});
  test('跨月重复、无效关联和分配超额不能写入',(){final book=sample();book.entries['duplicate']=Entry(id:'duplicate',kind:'month',data:book.months.single.data);expect(()=>book.validate(),throwsFormatException);book.entries.remove('duplicate');book.entries['allocation']=Entry(id:'allocation',kind:'allocation',data:{'record':'month','account':'bank','amount':400000});expect(()=>book.validate(),throwsFormatException);});
  test('完整恢复不覆盖设备名称',(){final local=sample();local.settings['device']='he 的电脑';final plan=ImportPlan(local,DataPackage.create(sample()))..restore=true;final result=plan.result();expect(result.settings['device'],'he 的电脑');expect(result.settings['theme'],'dark');});
}
