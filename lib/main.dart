import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'domain.dart';
import 'reports.dart';
import 'store.dart';
import 'transfer.dart';

final storeProvider=Provider<AppStore>((ref) => throw UnimplementedError());
final router=GoRouter(routes:[ShellRoute(builder:(c,s,child) => AppFrame(path:s.uri.path,child:child),routes:[
  for(final path in ['/','/monthly','/assets','/analysis','/settings']) GoRoute(path:path,builder:(c,s) => BookPage(page:path)),
])]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store=AppStore();
  runApp(ProviderScope(overrides:[storeProvider.overrideWithValue(store)],child:const HomeReserveApp()));
  await store.initialize();
}

class HomeReserveApp extends ConsumerWidget {
  const HomeReserveApp({super.key});
  @override Widget build(BuildContext context,WidgetRef ref) {
    final store=ref.watch(storeProvider);
    return AnimatedBuilder(animation:store,builder:(c,_) {
      ThemeData theme(Brightness brightness) {
        final dark=brightness==Brightness.dark;
        final scheme=ColorScheme.fromSeed(seedColor:const Color(0xff27836d),brightness:brightness);
        return ThemeData(useMaterial3:true,colorScheme:scheme,brightness:brightness,scaffoldBackgroundColor:dark?const Color(0xff151718):const Color(0xfff4f5f7),
          appBarTheme:const AppBarTheme(backgroundColor:Colors.transparent,scrolledUnderElevation:0),
          cardTheme:CardThemeData(elevation:0,color:dark?const Color(0xff212425):Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22))),
          inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:dark?const Color(0xff2b2f30):const Color(0xfff2f4f5),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none),contentPadding:const EdgeInsets.all(16)),
          filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:22,vertical:17),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),
          textTheme:Typography.material2021().black.apply(bodyColor:scheme.onSurface,displayColor:scheme.onSurface),
          dividerTheme:DividerThemeData(color:scheme.outlineVariant.withValues(alpha:.5),space:24),
        );
      }
      final mode=switch(store.book.settings['theme']){'light'=>ThemeMode.light,'dark'=>ThemeMode.dark,_=>ThemeMode.system};
      return MaterialApp.router(title:'家有余',debugShowCheckedModeBanner:false,theme:theme(Brightness.light),darkTheme:theme(Brightness.dark),themeMode:mode,routerConfig:router,
        locale:const Locale('zh','CN'),supportedLocales:const [Locale('zh','CN')],localizationsDelegates:GlobalMaterialLocalizations.delegates,
        builder:(c,child) {
          if(store.error!=null) return Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Text('${store.error}\n原始数据未被覆盖。请关闭软件后备份数据目录再排查。'))));
          if(!store.ready) return const Scaffold(body:Center(child:CircularProgressIndicator()));
          return Stack(children:[child!,if(store.busy) const Positioned(top:0,left:0,right:0,child:LinearProgressIndicator())]);
        });
    });
  }
}

const destinations=[('总览',Icons.space_dashboard_outlined,'/'),('月度',Icons.calendar_month_outlined,'/monthly'),('资产',Icons.account_balance_wallet_outlined,'/assets'),('分析',Icons.insights_outlined,'/analysis'),('设置',Icons.tune_rounded,'/settings')];
class AppFrame extends StatelessWidget {
  const AppFrame({super.key,required this.path,required this.child});
  final String path;final Widget child;
  @override Widget build(BuildContext context) {
    final index=math.max(0,destinations.indexWhere((d) => d.$3==path));
    return LayoutBuilder(builder:(c,box) {
      final desktop=box.maxWidth>=850;
      return Scaffold(body:SafeArea(child:Row(children:[if(desktop) SizedBox(width:220,child:Padding(padding:const EdgeInsets.fromLTRB(18,32,12,20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(padding:const EdgeInsets.only(left:16,bottom:6),child:Icon(Icons.spa_outlined,color:Theme.of(c).colorScheme.primary,size:36)),
        const Padding(padding:EdgeInsets.only(left:16,bottom:4),child:Text('家有余',style:TextStyle(fontSize:27,fontWeight:FontWeight.w700))),
        const Padding(padding:EdgeInsets.only(left:16,bottom:30),child:Text('一起攒下小美好',style:TextStyle(fontSize:12))),
        for(var i=0;i<destinations.length;i++) Padding(padding:const EdgeInsets.only(bottom:8),child:ListTile(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),selected:i==index,selectedTileColor:Theme.of(c).colorScheme.primaryContainer.withValues(alpha:.6),leading:Icon(destinations[i].$2),title:Text(destinations[i].$1),onTap:() => c.go(destinations[i].$3))),
        const Spacer(),const Padding(padding:EdgeInsets.all(16),child:Text('FOR MIN, WITH LOVE\nMADE BY HE',style:TextStyle(fontSize:10,letterSpacing:1.5,height:1.8))),
      ]))),Expanded(child:child)])),bottomNavigationBar:desktop?null:NavigationBar(selectedIndex:index,onDestinationSelected:(i) => c.go(destinations[i].$3),destinations:[for(final d in destinations) NavigationDestination(icon:Icon(d.$2),label:d.$1)]));
    });
  }
}

class BookPage extends ConsumerStatefulWidget {
  const BookPage({super.key,required this.page});final String page;
  @override ConsumerState<BookPage> createState()=>_BookPageState();
}
class _BookPageState extends ConsumerState<BookPage> {
  DateTime selected=DateTime(DateTime.now().year,DateTime.now().month);
  AppStore get store=>ref.read(storeProvider);
  Book get book=>store.book;
  String get month=>monthKey(selected);
  void message(Object text){if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$text')));}
  Future<void> guard(Future<void> Function() fn) async {try{await fn();}catch(e){message(e is FormatException?e.message:e);}}
  @override Widget build(BuildContext context) {
    final title=switch(widget.page){'/monthly'=>'月度记录','/assets'=>'存款与理财','/analysis'=>'看见积累','/settings'=>'设置与数据',_=>'日子，慢慢有余'};
    final subtitle=switch(widget.page){'/monthly'=>'每个月，留下一份认真生活的记录','/assets'=>'每一份安心，都有它的位置','/analysis'=>'让数字讲述我们一起积攒的时光','/settings'=>'按喜欢的方式，照顾好我们的记录',_=>'给 min，和 he 一起积攒小美好'};
    return SingleChildScrollView(padding:EdgeInsets.all(MediaQuery.sizeOf(context).width<600?20:36),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1120),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w700,letterSpacing:-.8)),const SizedBox(height:8),Text(subtitle,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,height:1.5)),const SizedBox(height:28),
      ...switch(widget.page){'/monthly'=>monthly(),'/assets'=>assets(),'/analysis'=>analysis(),'/settings'=>settings(),_=>overview()},
      const SizedBox(height:24),
    ]))));
  }
  Widget card(Widget child,{Color? color})=>Card(color:color,margin:const EdgeInsets.only(bottom:16),child:Padding(padding:const EdgeInsets.all(22),child:child));
  Widget section(String title,{Widget? trailing})=>Padding(padding:const EdgeInsets.only(top:8,bottom:14),child:Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w600))),?trailing]));
  Widget muted(String text)=>Text(text,style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant,height:1.7));
  Widget metric(String label,String value,IconData icon,{String? hint})=>card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,size:20,color:Theme.of(context).colorScheme.primary),const SizedBox(width:9),Text(label)]),const SizedBox(height:16),FittedBox(fit:BoxFit.scaleDown,child:Text(value,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w700,letterSpacing:-.8))),if(hint!=null)...[const SizedBox(height:6),muted(hint)]]));
  Widget metricGrid(List<Widget> children)=>LayoutBuilder(builder:(c,b){final count=b.maxWidth>700?3:b.maxWidth>450?2:1;return Wrap(spacing:16,children:[for(final child in children) SizedBox(width:(b.maxWidth-16*(count-1))/count,child:child)]);});
  Widget period({bool yearOnly=false})=>Row(children:[IconButton(tooltip:'上一${yearOnly?'年':'月'}',onPressed:()=>setState(()=>selected=DateTime(selected.year-(yearOnly?1:0),selected.month-(yearOnly?0:1))),icon:const Icon(Icons.chevron_left)),Expanded(child:Center(child:Text(yearOnly?'${selected.year} 年':'${selected.year} 年 ${selected.month} 月',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w600)))),IconButton(tooltip:'下一${yearOnly?'年':'月'}',onPressed:()=>setState(()=>selected=DateTime(selected.year+(yearOnly?1:0),selected.month+(yearOnly?0:1))),icon:const Icon(Icons.chevron_right))]);
  Widget empty(IconData icon,String title,String detail,{VoidCallback? onTap,String? action})=>card(Column(children:[Icon(icon,size:42,color:Theme.of(context).colorScheme.primary),const SizedBox(height:14),Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w600)),const SizedBox(height:8),muted(detail),if(onTap!=null)...[const SizedBox(height:16),FilledButton(onPressed:onTap,child:Text(action??'开始记录'))]]));
  List<Widget> overview() {
    final summary=MonthSummary(book,monthKey(DateTime.now()));
    final active=book.accounts.where((a)=>a.data['archived']==false).toList();
    final missing=active.where((a)=>book.latestBalance(a.id)==null).length;
    final stale=active.where((a){final b=book.latestBalance(a.id);return b!=null&&DateTime.now().difference(DateTime.parse(b.data['date'])).inDays>31;}).length;
    return [
      card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.spa_outlined),const SizedBox(width:10),const Expanded(child:Text('最近已记录资产',style:TextStyle(fontSize:16))),IconButton(tooltip:'查看账户',onPressed:()=>context.go('/assets'),icon:const Icon(Icons.arrow_forward_rounded))]),const SizedBox(height:12),FittedBox(child:Text(money(book.assets()),style:const TextStyle(fontSize:42,fontWeight:FontWeight.w700,letterSpacing:-1.4))),const SizedBox(height:12),muted('${active.length} 个在用账户 · $missing 个未核对 · $stale 个超过 31 天未核对\n汇总各账户最近核对余额，可能不是同一天的实际总额。')]),color:Theme.of(context).colorScheme.primaryContainer.withValues(alpha:.5)),
      metricGrid([metric('本月收入',money(summary.income),Icons.south_west_rounded),metric('本月净存入',money(summary.saving),Icons.savings_outlined),metric('本月储蓄率',summary.rate==null?'—':'${summary.rate!.toStringAsFixed(1)}%',Icons.donut_large_rounded,hint:summary.complete?'本月成员记录完整':'部分成员尚未填完整')]),
      if(!summary.complete) card(Row(children:[const Icon(Icons.edit_calendar_outlined),const SizedBox(width:12),Expanded(child:Text('本月待补充：${summary.missingMembers.join('、')}')),TextButton(onPressed:()=>context.go('/monthly'),child:const Text('去记录'))])),
      section('近 12 个月 · 储蓄的脚步'),chart(12,rolling:true),
      if(book.months.isEmpty) empty(Icons.favorite_border_rounded,'从这个月开始','不用记每一笔消费，只记收入与净存入。',onTap:()=>context.go('/monthly')),
      muted('累计净存入不是资产余额；账户之间转移资金不属于新增储蓄。'),
    ];
  }
  List<Widget> monthly()=>[
    card(period()),
    for(final member in book.members.where((m)=>m.data['active']==true||book.monthly(m.id,month)!=null)) card(Builder(builder:(c){final record=book.monthly(member.id,month);return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[CircleAvatar(backgroundColor:Theme.of(c).colorScheme.primaryContainer,child:Text(member.label.substring(0,1))),const SizedBox(width:12),Expanded(child:Text(member.label,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w600))),IconButton(tooltip:'编辑月度记录',onPressed:()=>editMonth(member,record),icon:const Icon(Icons.edit_outlined))]),const SizedBox(height:20),Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[muted('本月收入'),const SizedBox(height:5),Text(record?.data['income']==null?'未填写':money(record!.data['income']),style:const TextStyle(fontSize:23,fontWeight:FontWeight.w600))])),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[muted('本月净存入'),const SizedBox(height:5),Text(record?.data['saving']==null?'未填写':money(record!.data['saving']),style:const TextStyle(fontSize:23,fontWeight:FontWeight.w600))]))]),
      if(record!=null)...[if((record.data['note'] as String).isNotEmpty)...[const SizedBox(height:14),muted(record.data['note'])],const Divider(),for(final a in book.allocations.where((a)=>a.data['record']==record.id)) Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[const Icon(Icons.account_balance_outlined,size:16),const SizedBox(width:8),Expanded(child:Text(book.name(a.data['account']))),Text(money(a.data['amount']))])),
        if(record.data['saving']!=null) muted('未分配：${money((record.data['saving'] as int)-book.allocations.where((a)=>a.data['record']==record.id).fold(0,(v,a)=>v+(a.data['amount'] as int)))} · 分配不自动变更账户余额'),
        if(record.source.isNotEmpty) muted('来源：${record.source} · ${record.importedAt.split('T').first} 导入'),
      ]else...[const SizedBox(height:16),OutlinedButton.icon(onPressed:()=>editMonth(member,null),icon:const Icon(Icons.add),label:const Text('填写这个月'))],
    ]})),
    muted('净存入允许负数。留空表示未填写，输入 0 表示已确认没有。'),
  ];
  List<Widget> assets()=>[
    metricGrid([metric('最近已记录资产',money(book.assets()),Icons.account_balance_wallet_outlined),metric('个人账户', '${book.accounts.where((a)=>a.data['owner']!=sharedOwner&&a.data['archived']==false).length} 个',Icons.person_outline),metric('共同账户','${book.accounts.where((a)=>a.data['owner']==sharedOwner&&a.data['archived']==false).length} 个',Icons.people_outline)]),
    section('钱在哪里',trailing:FilledButton.icon(onPressed:()=>editAccount(null),icon:const Icon(Icons.add,size:18),label:const Text('添加账户'))),
    if(book.accounts.isEmpty) empty(Icons.account_balance_outlined,'给每一份积累安个家','添加银行卡、支付宝、存款或理财账户。',onTap:()=>editAccount(null),action:'添加第一个账户'),
    for(final account in book.accounts) accountCard(account),
    muted('理财填写当前总价值。资产变化可能包含投入、取出和估值变化，不代表投资收益。'),
  ];
  Widget accountCard(Entry account) {
    final balance=book.latestBalance(account.id);final archived=account.data['archived']==true;
    final stale=balance!=null&&DateTime.now().difference(DateTime.parse(balance.data['date'])).inDays>31;
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(14)),child:Icon(categoryIcon(account.data['category']))),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(account.label,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w600)),muted('${book.name(account.data['owner'])} · ${account.data['category']}${archived?' · 已归档':''}')])),IconButton(tooltip:'编辑账户',onPressed:()=>editAccount(account),icon:const Icon(Icons.more_horiz))]),const SizedBox(height:18),Text(balance==null?'尚未核对':money(balance.data['amount']),style:const TextStyle(fontSize:30,fontWeight:FontWeight.w700)),const SizedBox(height:6),muted(balance==null?'请填写实际余额':"${balance.data['date']} 核对${stale?' · 建议重新核对':''}"),if((account.data['note'] as String).isNotEmpty) muted(account.data['note']),const SizedBox(height:12),Wrap(spacing:8,children:[if(!archived) FilledButton.tonalIcon(onPressed:()=>editBalance(account),icon:const Icon(Icons.fact_check_outlined,size:18),label:const Text('核对余额')),TextButton.icon(onPressed:()=>balanceHistory(account),icon:const Icon(Icons.history,size:18),label:const Text('核对历史'))]) ]));
  }
  IconData categoryIcon(String category)=>switch(category){'银行卡'=>Icons.account_balance_outlined,'支付账户'=>Icons.phone_android_outlined,'存款'=>Icons.savings_outlined,'理财'=>Icons.show_chart_rounded,'现金'=>Icons.payments_outlined,_=>Icons.wallet_outlined};
  List<Widget> analysis() {
    final report=ReportData(book,selected.year);final recorded=report.records.map((r)=>r.data['month'] as String).toSet();final complete=recorded.where((m)=>MonthSummary(book,m).complete).toList();
    final average=complete.isEmpty?null:complete.fold(0,(v,m)=>v+MonthSummary(book,m).saving)~/complete.length;
    return [card(period(yearOnly:true)),metricGrid([metric('年度收入',money(report.income),Icons.south_west_rounded),metric('年度净存入',money(report.saving),Icons.savings_outlined),metric('完整月份平均净存入',average==null?'—':money(average),Icons.equalizer_rounded,hint:'仅统计 ${complete.length} 个完整月份')]),muted(report.completeness),section('收入与储蓄趋势'),chart(12),
      section('成员与账户分布'),for(final m in [...book.members,Entry(id:sharedOwner,kind:'member',data:{'name':'家庭共同'})]) card(Builder(builder:(c){final r=report.records.where((e)=>e.data['member']==m.id);final income=r.fold(0,(v,e)=>v+(e.data['income'] as int? ?? 0));final saving=r.fold(0,(v,e)=>v+(e.data['saving'] as int? ?? 0));final accounts=book.accounts.where((a)=>a.data['owner']==m.id);final assets=accounts.fold(0,(v,a)=>v+(book.latestBalance(a.id)?.data['amount'] as int? ?? 0));return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(m.label,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w600)),const SizedBox(height:12),if(m.id!=sharedOwner) muted('年度收入 ${money(income)} · 年度净存入 ${money(saving)}'),muted('最近已记录资产 ${money(assets)}')]);})),
      section('每月回顾'),for(var i=12;i>=1;i--) monthReview('${selected.year}-${i.toString().padLeft(2,'0')}'),
      section('导出年度报告'),Wrap(spacing:10,runSpacing:10,children:[for(final ext in ['xlsx','csv','docx','pdf']) OutlinedButton.icon(onPressed:()=>exportReport(ext),icon:const Icon(Icons.file_download_outlined),label:Text(ext.toUpperCase()))]),
    ];
  }
  Widget monthReview(String key) {
    final current=MonthSummary(book,key);final d=DateTime.parse('$key-01');final previous=MonthSummary(book,monthKey(DateTime(d.year,d.month-1)));final lastYear=MonthSummary(book,monthKey(DateTime(d.year-1,d.month)));
    String change(MonthSummary base)=>!current.complete||!base.complete?'数据不完整':base.saving==0?'基期为零':'${((current.saving-base.saving)/base.saving.abs()*100).toStringAsFixed(1)}%';
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(key,style:const TextStyle(fontWeight:FontWeight.w600))),Icon(current.complete?Icons.check_circle_outline:Icons.pending_outlined,size:18,color:current.complete?Theme.of(context).colorScheme.primary:null)]),const SizedBox(height:8),muted('收入 ${money(current.income)} · 净存入 ${money(current.saving)}'),muted('储蓄环比 ${change(previous)} · 同比 ${change(lastYear)}'),if(!current.complete) muted('待补充：${current.missingMembers.join('、')}')]));
  }
  Widget chart(int count,{bool rolling=false}) {
    final end=rolling?DateTime.now():DateTime(selected.year,12);final periods=[for(var i=count-1;i>=0;i--) monthKey(DateTime(end.year,end.month-i))];
    final summaries=periods.map((m)=>MonthSummary(book,m)).toList();
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Wrap(spacing:18,children:[Text('● 收入',style:TextStyle(color:Theme.of(context).colorScheme.primary)),const Text('● 净存入',style:TextStyle(color:Color(0xff7d91ba)))]),const SizedBox(height:24),SizedBox(height:210,child:LineChart(LineChartData(minX:0,maxX:(count-1).toDouble(),gridData:const FlGridData(show:true,drawVerticalLine:false),borderData:FlBorderData(show:false),titlesData:FlTitlesData(topTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),rightTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),leftTitles:const AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:44)),bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,interval:2,getTitlesWidget:(v,m)=>Padding(padding:const EdgeInsets.only(top:8),child:Text(v.toInt()>=0&&v.toInt()<periods.length?'${int.parse(periods[v.toInt()].substring(5))}月':'',style:const TextStyle(fontSize:10)))))),lineBarsData:[for(var series=0;series<2;series++) LineChartBarData(color:series==0?Theme.of(context).colorScheme.primary:const Color(0xff7d91ba),barWidth:2.5,isCurved:false,dotData:const FlDotData(show:true),spots:[for(var i=0;i<count;i++) summaries[i].completeMembers.isEmpty&&book.months.every((e)=>e.data['month']!=periods[i])?FlSpot.nullSpot:FlSpot(i.toDouble(),(series==0?summaries[i].income:summaries[i].saving)/100)])]))),const SizedBox(height:12),muted('单位：元 · 未记录月份断开显示；部分记录仅代表已填写金额。')]));
  }
  List<Widget> settings()=>[
    section('显示与个性'),card(Column(children:[DropdownButtonFormField<String>(initialValue:['system','light','dark'].contains(book.settings['theme'])?book.settings['theme']:'system',decoration:const InputDecoration(labelText:'主题'),items:const [DropdownMenuItem(value:'system',child:Text('跟随系统')),DropdownMenuItem(value:'light',child:Text('浅色')),DropdownMenuItem(value:'dark',child:Text('深色'))],onChanged:(v)=>guard(()=>store.settings({'theme':v}))),const SizedBox(height:14),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.devices_outlined),title:const Text('这台设备的名称'),subtitle:Text(book.settings['device'] as String? ?? ''),trailing:const Icon(Icons.edit_outlined),onTap:editDevice)])),
    section('家庭成员',trailing:IconButton(tooltip:'添加成员',onPressed:()=>editMember(null),icon:const Icon(Icons.person_add_alt_1_outlined))),card(Column(children:[for(final m in book.members) ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Text(m.label.substring(0,1))),title:Text(m.label),subtitle:Text(m.data['active']==true?'使用中':'已停用 · 历史保留'),trailing:const Icon(Icons.edit_outlined),onTap:()=>editMember(m))])),
    section('备份与迁移'),card(Column(children:[ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.ios_share_outlined),title:const Text('导出完整数据包'),subtitle:const Text('手机与电脑互导，包含成员、账户和所有历史'),onTap:()=>guard(()=>saveFile('HomeReserve-${dayKey(DateTime.now())}.homereserve.json',utf8.encode(DataPackage.create(book).encode()),'application/json'))),const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.file_open_outlined),title:const Text('导入数据或表格'),subtitle:const Text('先预览时间、来源、差异和冲突，再确认'),onTap:importFile),const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.restore_rounded),title:const Text('本机恢复备份'),subtitle:const Text('导入和删除前自动保存，最近 10 份'),onTap:restoreBackup)])),
    section('关于家有余'),card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.spa_outlined),SizedBox(width:10),Text('家有余 · HomeReserve',style:TextStyle(fontSize:19,fontWeight:FontWeight.w600))]),const SizedBox(height:14),const Text('给 min 制作，和 he 一起，\n把日子过好，把幸福慢慢攒下。',style:TextStyle(height:1.8)),const SizedBox(height:14),muted('版本 1.0.0 · 本地离线 · 人民币\n数据保存在本机，不会上传财务数据。请定期导出备份。'),const SizedBox(height:12),Wrap(spacing:8,children:[TextButton.icon(onPressed:()=>openUrl('https://github.com/Smileher/HomeReserve/releases/latest'),icon:const Icon(Icons.system_update_outlined),label:const Text('查看最新版本')),TextButton.icon(onPressed:()=>openUrl('https://github.com/Smileher/HomeReserve'),icon:const Icon(Icons.code_rounded),label:const Text('开源项目'))])])),
  ];

  Future<void> openUrl(String url)=>guard(() async {if(!await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication)) throw const FormatException('无法打开链接，请检查浏览器和网络');});
  Future<void> saveFile(String name,List<int> bytes,String mime) async {
    if(Platform.isAndroid){await SharePlus.instance.share(ShareParams(files:[XFile.fromData(Uint8List.fromList(bytes),mimeType:mime,name:name)],fileNameOverrides:[name],sharePositionOrigin:const Rect.fromLTWH(0,0,1,1)));return;}
    final location=await getSaveLocation(suggestedName:name);if(location==null)return;
    await File(location.path).writeAsBytes(bytes,flush:true);message('已保存：${location.path}');
  }
  Future<void> exportReport(String ext)=>guard(() async {
    final data=ReportData(book,selected.year);final bytes=switch(ext){'xlsx'=>data.xlsx(),'docx'=>data.docx(),'pdf'=>await data.pdf(),_=>utf8.encode(data.csv())};
    await saveFile('家有余-${selected.year}.$ext',bytes,switch(ext){'pdf'=>'application/pdf','xlsx'=>'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','docx'=>'application/vnd.openxmlformats-officedocument.wordprocessingml.document',_=>'text/csv'});
  });
  Future<bool> confirm(String title,String description,{String button='确认'}) async => await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(description),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('取消')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(button))]))??false;
  Future<void> form(String title,List<Widget> Function(StateSetter update) fields,Future<void> Function() save,{Widget? extra}) async {
    String? error;bool saving=false;
    await showDialog<void>(context:context,builder:(dialog)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:Text(title),content:SizedBox(width:490,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[...fields(update),if(error!=null) Padding(padding:const EdgeInsets.only(top:14),child:Text(error!,style:TextStyle(color:Theme.of(c).colorScheme.error)))]))),actions:[?extra,TextButton(onPressed:saving?null:()=>Navigator.pop(c),child:const Text('取消')),FilledButton(onPressed:saving?null:() async {update(()=>saving=true);try{await save();if(c.mounted)Navigator.pop(c);}catch(e){if(c.mounted)update((){error=e is FormatException?'${e.message}':'$e';saving=false;});}},child:Text(saving?'保存中…':'保存'))])));
    if(mounted)setState((){});
  }
  Widget field(TextEditingController controller,String label,{bool money=false,bool signed=false,int lines=1})=>Padding(padding:const EdgeInsets.only(bottom:14),child:TextField(controller:controller,decoration:InputDecoration(labelText:label),maxLines:lines,maxLength:money?16:lines>1?2000:60,keyboardType:money?TextInputType.numberWithOptions(decimal:true,signed:signed):null));
  Future<void> editDevice() async {
    final name=TextEditingController(text:book.settings['device'] as String? ?? '');
    await form('设备名称',(_)=>[field(name,'例如：min 的手机')],() async {if(name.text.trim().isEmpty)throw const FormatException('请填写设备名称');await store.settings({'device':name.text.trim()});});name.dispose();
  }
  Future<void> editMember(Entry? member) async {
    final name=TextEditingController(text:member?.label??'');var active=member?.data['active'] as bool? ?? true;
    await form(member==null?'添加成员':'编辑成员',(update)=>[field(name,'称呼（最多 40 字）'),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('使用中'),subtitle:const Text('停用后保留已有记录'),value:active,onChanged:(v)=>update(()=>active=v))],() async {if(name.text.trim().isEmpty||name.text.trim().length>40)throw const FormatException('称呼需要 1～40 字');if(book.members.any((e)=>e.id!=member?.id&&e.label.trim().toLowerCase()==name.text.trim().toLowerCase()))throw const FormatException('已有同名成员');await store.put(Entry(id:member?.id??newId(),kind:'member',data:{'name':name.text.trim(),'active':active,'order':member?.data['order']??book.members.length}));});name.dispose();
  }
  Future<void> editAccount(Entry? account) async {
    final name=TextEditingController(text:account?.label??'');final note=TextEditingController(text:account?.data['note'] as String? ?? '');var owner=account?.data['owner'] as String? ?? sharedOwner;var category=account?.data['category'] as String? ?? categories.first;var archived=account?.data['archived'] as bool? ?? false;
    await form(account==null?'添加账户':'编辑账户',(update)=>[field(name,'账户名称，例如：min 的支付宝'),DropdownButtonFormField<String>(initialValue:owner,decoration:const InputDecoration(labelText:'归属'),items:[const DropdownMenuItem(value:sharedOwner,child:Text('家庭共同')),for(final m in book.members)DropdownMenuItem(value:m.id,child:Text(m.label))],onChanged:(v)=>owner=v!),const SizedBox(height:14),DropdownButtonFormField<String>(initialValue:category,decoration:const InputDecoration(labelText:'类别'),items:categories.map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>category=v!),const SizedBox(height:14),field(note,'备注（不要填写完整银行卡号）',lines:2),if(account!=null)SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('归档账户'),subtitle:const Text('最新核对余额需为零，历史保留'),value:archived,onChanged:(v)=>update(()=>archived=v))],() async {
      if(name.text.trim().isEmpty)throw const FormatException('请填写账户名称');if(book.accounts.any((a)=>a.id!=account?.id&&a.label.trim().toLowerCase()==name.text.trim().toLowerCase()))throw const FormatException('已有同名账户，请使用可区分的名称');
      if(archived&&(book.latestBalance(account!.id)?.data['amount'] as int? ?? -1)!=0)throw const FormatException('请先核对该账户实际余额为 0，再归档');
      await store.put(Entry(id:account?.id??newId(),kind:'account',data:{'name':name.text.trim(),'owner':owner,'category':category,'note':note.text,'archived':archived}));
    });name.dispose();note.dispose();
  }
  Future<void> editBalance(Entry account,{Entry? original}) async {
    var date=original?.data['date'] as String? ?? dayKey(DateTime.now());final amount=TextEditingController(text:editMoney(original?.data['amount']));final note=TextEditingController(text:original?.data['note'] as String? ?? '');
    await form('核对 · ${account.label}',(update)=>[muted('填写此账户当前实际总价值，不会与月度净存入重复累计。'),const SizedBox(height:14),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.event_outlined),title:Text(date),trailing:const Icon(Icons.edit_calendar_outlined),onTap:() async {final picked=await showDatePicker(context:context,initialDate:DateTime.parse(date),firstDate:DateTime(2000),lastDate:DateTime.now());if(picked!=null)update(()=>date=dayKey(picked));}),field(amount,'实际余额（元）',money:true),field(note,'核对备注',lines:2)],() async {
      final existing=book.balances.where((b)=>b.data['account']==account.id&&b.data['date']==date).firstOrNull;
      if(existing!=null&&existing.id!=original?.id){if(!await confirm('当天已有核对记录','将用本次金额替换 ${date} 的余额 ${money(existing.data['amount'])}。'))return;}
      if(original!=null&&existing!=null&&existing.id!=original.id)throw const FormatException('该日期已有记录，请直接编辑当天记录');
      await store.put(Entry(id:original?.id??existing?.id??newId(),kind:'balance',data:{'account':account.id,'date':date,'amount':parseMoney(amount.text),'note':note.text}));
    });amount.dispose();note.dispose();
  }
  Future<void> balanceHistory(Entry account) async {
    final list=book.balances.where((b)=>b.data['account']==account.id).toList()..sort((a,b)=>(b.data['date'] as String).compareTo(a.data['date'] as String));
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text('${account.label} · 核对历史'),content:SizedBox(width:480,child:list.isEmpty?const Text('还没有核对记录'):ListView(shrinkWrap:true,children:[for(final b in list)ListTile(title:Text('${b.data['date']}   ${money(b.data['amount'])}'),subtitle:Text('${b.data['note']}${b.source.isEmpty?'':'\n来源：${b.source}'}'),trailing:const Icon(Icons.edit_outlined),onTap:(){Navigator.pop(c);editBalance(account,original:b);})])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('关闭'))]));
  }
  Future<void> editMonth(Entry member,Entry? original) async {
    final income=TextEditingController(text:editMoney(original?.data['income']));final saving=TextEditingController(text:editMoney(original?.data['saving']));final note=TextEditingController(text:original?.data['note'] as String? ?? '');
    final accounts=book.accounts.where((a)=>a.data['archived']==false||book.allocations.any((r)=>r.data['record']==original?.id&&r.data['account']==a.id)).toList();
    final allocated={for(final a in accounts)a.id:TextEditingController(text:editMoney(book.allocations.where((e)=>e.data['record']==original?.id&&e.data['account']==a.id).firstOrNull?.data['amount']))};
    await form('${member.label} · $month',(_)=>[field(income,'本月收入（元，可留空）',money:true),field(saving,'本月净存入（元，可为负，可留空）',money:true,signed:true),field(note,'这个月的小记',lines:2),if(accounts.isNotEmpty)...[const Divider(),muted('可选：这笔净存入放在哪里？填写分配不会自动增加账户余额。'),const SizedBox(height:14),for(final a in accounts)field(allocated[a.id]!,'${a.label}（元）',money:true,signed:true)]],() async {
      final next=book.copy();final id=original?.id??newId();
      next.entries[id]=Entry(id:id,kind:'month',data:{'member':member.id,'month':month,'income':income.text.trim().isEmpty?null:parseMoney(income.text),'saving':saving.text.trim().isEmpty?null:parseMoney(saving.text,signed:true),'note':note.text},source:original?.source??'',importedAt:original?.importedAt??'');
      final old=next.allocations.where((a)=>a.data['record']==id).toList();for(final a in old){next.entries.remove(a.id);}
      for(final a in accounts){final text=allocated[a.id]!.text.trim();if(text.isEmpty)continue;final previous=old.where((e)=>e.data['account']==a.id).firstOrNull;final allocation=Entry(id:previous?.id??newId(),kind:'allocation',data:{'record':id,'account':a.id,'amount':parseMoney(text,signed:true)});next.entries[allocation.id]=allocation;}
      await store.commit(next);
    },extra:original==null?null:TextButton(onPressed:() async {if(await confirm('删除这条月度记录？','将保留删除标记，并在删除前备份本机数据。',button:'删除')){try{await store.deleteMonth(original);if(mounted)Navigator.of(context,rootNavigator:true).pop();}catch(e){message(e);}}},child:const Text('删除')));
    income.dispose();saving.dispose();note.dispose();for(final c in allocated.values){c.dispose();}
  }
  Future<void> importFile()=>guard(() async {
    final file=await openFile(acceptedTypeGroups:[const XTypeGroup(label:'数据包或月度表格',extensions:['json','xlsx','csv'])]);if(file==null)return;
    if(await file.length()>20*1024*1024)throw const FormatException('请选择小于 20 MB 的数据文件');
    final bytes=await file.readAsBytes();final ext=file.name.split('.').last.toLowerCase();final package=ext=='json'?DataPackage.decode(utf8.decode(bytes)):parseTable(bytes,ext,book);
    if(!mounted)return;
    await showDialog<void>(context:context,builder:(c)=>ImportDialog(store:store,package:package));
  });
  Future<void> restoreBackup()=>guard(() async {
    final files=await store.backups();if(!mounted)return;
    final selected=await showDialog<File>(context:context,builder:(c)=>AlertDialog(title:const Text('本机恢复备份'),content:SizedBox(width:500,child:files.isEmpty?const Text('暂无备份。导入或删除前会自动生成。'):ListView(shrinkWrap:true,children:[for(final file in files)ListTile(leading:const Icon(Icons.restore),title:Text(file.uri.pathSegments.last.replaceFirst('backup-','').replaceFirst('.json','')),onTap:()=>Navigator.pop(c,file))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('取消'))]));
    if(selected==null)return;
    final snapshot=Book.fromJson(jsonDecode(await selected.readAsString(encoding:utf8)) as Map<String,dynamic>);
    if(await confirm('完整恢复本机备份？','备份包含 ${snapshot.members.length} 位成员、${snapshot.accounts.length} 个账户、${snapshot.months.length} 条月度记录。将替换当前数据；恢复前仍会备份当前状态。',button:'完整恢复')){await store.restoreBackup(selected);message('已恢复本机备份');}
  });
}

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key,required this.store,required this.package});final AppStore store;final DataPackage package;
  @override State<ImportDialog> createState()=>_ImportDialogState();
}
class _ImportDialogState extends State<ImportDialog> {
  late ImportPlan plan;String? error;bool saving=false;bool prepared=false;
  @override void initState(){super.initState();plan=ImportPlan(widget.store.book,widget.package);prepare();}
  void prepare(){try{if(plan.ambiguous.every((e)=>plan.mapping.containsKey(e.id))){plan.prepare();prepared=true;error=null;}}catch(e){error='$e';}}
  String describe(Entry e){final data=Map<String,dynamic>.from(e.data);for(final k in ['income','saving','amount']){if(data[k] is int)data[k]=money(data[k]);}for(final k in ['member','owner','account']){if(data[k] is String)data[k]=widget.store.book.entries[data[k]]?.label??widget.package.book.entries[data[k]]?.label??data[k];}return data.entries.map((f)=>'${switch(f.key){'income'=>'收入','saving'=>'净存入','amount'=>'金额','note'=>'备注','month'=>'月份','date'=>'日期','name'=>'名称','member'=>'成员','owner'=>'归属','account'=>'账户',_=>f.key}}：${f.value??'未填写'}').join('\n');}
  @override Widget build(BuildContext context) {
    final p=widget.package;final months=p.book.months.map((e)=>e.data['month'] as String).toList()..sort();final offset=p.offset;final localTime=DateTime.parse(p.exportedAt).toUtc().add(Duration(minutes:offset)).toString().split('.').first;
    return AlertDialog(title:const Text('导入前，先确认一下'),content:SizedBox(width:700,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('来源：${p.device}\n导出时间：$localTime（UTC${offset>=0?'+':'-'}${offset.abs()~/60}:${(offset.abs()%60).toString().padLeft(2,'0')}）\n${p.book.members.length} 位成员 · ${p.book.accounts.length} 个账户\n${p.book.months.length} 条月度记录 · ${p.book.balances.length} 条余额记录\n月份范围：${months.isEmpty?'无月度记录':'${months.first} 至 ${months.last}'}',style:const TextStyle(height:1.8)),const Divider(),
      for(final e in plan.ambiguous) Padding(padding:const EdgeInsets.only(bottom:14),child:DropdownButtonFormField<String>(decoration:InputDecoration(labelText:'同名${e.kind=='member'?'成员':'账户'}：${e.label}'),items:[DropdownMenuItem(value:e.id,child:const Text('作为不同对象新增')),for(final target in plan.local.of(e.kind))DropdownMenuItem(value:target.id,child:Text('对应本机：${target.label}'))],onChanged:(v)=>setState((){plan.mapping[e.id]=v!;prepare();}))),
      if(prepared)...[Text('新增 ${plan.additions.length} 条 · 相同跳过 ${plan.sameCount} 条 · 冲突 ${plan.conflicts.length} 条',style:const TextStyle(fontWeight:FontWeight.w600)),const SizedBox(height:10),const Text('默认保留本机。修改时间较晚也不会自动覆盖。'),
        for(final conflict in plan.conflicts)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(conflict.deleted?'本机已删除的记录':'内容冲突',style:TextStyle(color:Theme.of(context).colorScheme.error,fontWeight:FontWeight.w600)),const SizedBox(height:10),SelectableText('本机：\n${conflict.local==null?'已删除':describe(conflict.local!)}\n\n导入：\n${describe(conflict.incoming)}',style:const TextStyle(fontSize:12,height:1.7)),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('使用导入内容'),value:conflict.useIncoming,onChanged:(v)=>setState(()=>conflict.useIncoming=v))]))),
      ],
      const Divider(),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('同时应用导入的主题设置'),subtitle:const Text('不会覆盖这台设备的名称'),value:plan.applySettings,onChanged:(v)=>setState(()=>plan.applySettings=v)),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('完整恢复：替换本机全部数据'),subtitle:Text('当前 ${plan.local.months.length} 条月度、${plan.local.balances.length} 条余额记录将被替换；默认关闭'),value:plan.restore,onChanged:(v)=>setState(()=>plan.restore=v)),
      if(plan.restore)const Text('完整恢复使用整个数据包，上方逐条冲突选择不再适用。',style:TextStyle(color:Colors.deepOrange)),
      if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    ]))),actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(context),child:const Text('取消')),FilledButton(onPressed:saving||(!prepared&&!plan.restore)?null:() async {
      if(plan.restore){final accepted=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('确认完整替换？'),content:const Text('当前全部业务数据将替换为这份数据包。替换前会自动备份本机数据。'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('返回')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('确认替换'))]));if(accepted!=true)return;}
      setState(()=>saving=true);
      try{final result=plan.result();await widget.store.commit(result,backup:true);if(context.mounted){Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(plan.restore?'完整恢复完成':'导入完成：新增 ${plan.additions.length}，替换 ${plan.conflicts.where((c)=>c.useIncoming).length}，相同跳过 ${plan.sameCount}'))));}}
      catch(e){if(mounted)setState((){error='未写入数据：$e\n如涉及月度净存入和账户分配，请一起核对关联冲突。';saving=false;});}
    },child:Text(saving?'正在写入…':plan.restore?'完整恢复':'确认合并导入'))]);
  }
}
