import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_reserve/main.dart';
import 'package:home_reserve/store.dart';
import 'package:home_reserve/domain.dart';
import 'package:home_reserve/app_widgets.dart';
import 'package:home_reserve/transfer.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;

import 'domain_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => glass.LiquidGlassWidgets.initialize(
      enablePerformanceMonitor: false,
      warmUpMode: glass.GlassWarmUpMode.never,
    ),
  );
  testWidgets('新账本为空，添加成员后可记录月度收入和净存入', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    expect(store.book.entries, isEmpty);
    expect(store.book.settings['device'], '本机设备');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('日子，慢慢有余'), findsOneWidget);
    expect(find.text('记录家庭收入、储蓄与账户资产'), findsOneWidget);
    await tester.tap(find.text('月度').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('月度记录'), findsOneWidget);
    expect(find.text('先添加家庭成员'), findsOneWidget);
    await tester.tap(find.text('添加成员'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, '成员甲');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('成员甲'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('编辑月度记录').last);
    await tester.tap(find.byTooltip('编辑月度记录').last);
    await tester.pumpAndSettle();
    expect(find.text('本月收入（元，可留空）'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('本月收入（元，可留空）')),
      '12345.67',
    );
    await tester.enterText(
      find.byKey(const ValueKey('本月净存入（元，可为负，可留空）')),
      '-200.29',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final record = store.book.monthly(
      store.book.members.single.id,
      monthKey(DateTime.now()),
    )!;
    expect(record.data['income'], 1234567);
    expect(record.data['saving'], -20029);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
  testWidgets('彩蛋仅随指定成员称呼出现，改名后恢复普通文案', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    router.go('/settings');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('愿你眼里有光'), findsNothing);
    await tester.ensureVisible(find.byTooltip('添加成员'));
    await tester.tap(find.byTooltip('添加成员'));
    await tester.pumpAndSettle();
    // Keep the personal trigger out of public test descriptions and fixtures.
    final trigger = String.fromCharCodes([0x738b, 0x654f]);
    await tester.enterText(find.byType(EditableText).first, trigger);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('愿你眼里有光'), findsOneWidget);
    await tester.ensureVisible(find.text(trigger));
    await tester.tap(find.text(trigger));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, '成员乙');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('愿你眼里有光'), findsNothing);
    expect(find.textContaining('简单记录家庭收入'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
  testWidgets('手机可直接选择跨年月份、取消选择及选择分析年份', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    router.go('/monthly');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('选择月份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().year} 年').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('2030'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(YearPicker),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.textContaining('2030'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11 月'));
    await tester.pumpAndSettle();
    expect(find.text('2030 年 11 月'), findsOneWidget);
    await tester.tap(find.byTooltip('选择月份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('2030 年 11 月'), findsOneWidget);
    await tester.tap(find.text('分析').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('选择年份'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('2028'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(YearPicker),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.textContaining('2028'));
    await tester.pumpAndSettle();
    expect(find.text('2028 年'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
  testWidgets('手机主题卡片可即时切换并跟随系统', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    router.go('/settings');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    await tester.pumpAndSettle();
    for (final choice in [
      ('浅色', 'light', Brightness.light),
      ('深色', 'dark', Brightness.dark),
      ('跟随系统', 'system', Brightness.dark),
    ]) {
      await tester.tap(find.text(choice.$1).hitTestable().first);
      await tester.pumpAndSettle();
      expect(store.book.settings['theme'], choice.$2);
      expect(
        Theme.of(tester.element(find.text(choice.$1).hitTestable().first))
            .brightness,
        choice.$3,
      );
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
  testWidgets('玻璃账户选择与余额核对保持金额和归档校验', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    await store.put(
      Entry(
        id: 'member-a',
        kind: 'member',
        data: {'name': '成员甲', 'active': true, 'order': 0},
      ),
    );
    router.go('/assets');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加第一个账户'));
    await tester.tap(find.text('添加第一个账户'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('账户名称，例如：工资卡、支付宝')),
      '工资卡',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AppChoice).first,
        matching: find.byType(glass.GlassPicker),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('成员甲').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppChoice).last,
        matching: find.byType(glass.GlassPicker),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('存款').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.book.accounts.single.data['owner'], 'member-a');
    expect(store.book.accounts.single.data['category'], '存款');
    await tester.ensureVisible(find.text('核对余额'));
    await tester.tap(find.text('核对余额'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('实际余额（元）')), '-1');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请输入有效金额'), findsOneWidget);
    expect(store.book.balances, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('实际余额（元）')), '500.00');
    await tester.tap(find.text(dayKey(DateTime.now())));
    await tester.pumpAndSettle();
    expect(find.byType(glass.GlassDatePicker), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.book.balances.single.data['amount'], 50000);
    await tester.ensureVisible(find.byTooltip('编辑账户'));
    await tester.tap(find.byTooltip('编辑账户'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('归档账户'));
    await tester.tap(find.text('归档账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('实际余额为 0，再归档'), findsOneWidget);
    expect(store.book.accounts.single.data['archived'], false);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
  testWidgets('玻璃导入弹窗保留冲突选择与完整恢复二次确认', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(960, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    final local = fixture.sample();
    local.settings['device'] = '本机设备';
    await store.commit(local);
    router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    await tester.pumpAndSettle();
    final incoming = fixture.sample();
    incoming.entries['month'] = incoming.entries['month']!.change({
      'saving': 400000,
    });
    var dialog = showDialog<void>(
      context: tester.element(find.byType(AppFrame)),
      builder: (_) =>
          ImportDialog(store: store, package: DataPackage.create(incoming)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('使用导入内容'));
    await tester.tap(find.text('使用导入内容'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认合并导入'));
    await tester.pumpAndSettle();
    await dialog;
    expect(store.book.months.single.data['saving'], 400000);
    expect(store.book.months.single.source, '测试手机');
    dialog = showDialog<void>(
      context: tester.element(find.byType(AppFrame)),
      builder: (_) => ImportDialog(
        store: store,
        package: DataPackage.create(fixture.sample()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('完整恢复：替换本机全部数据'));
    await tester.tap(find.text('完整恢复：替换本机全部数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完整恢复'));
    await tester.pumpAndSettle();
    expect(find.text('确认完整替换？'), findsOneWidget);
    expect(store.book.months.single.data['saving'], 400000);
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(store.book.months.single.data['saving'], 400000);
    await tester.tap(find.text('完整恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认替换'));
    await tester.pumpAndSettle();
    await dialog;
    expect(store.book.months.single.data['saving'], 300000);
    expect(store.book.settings['device'], '本机设备');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
  testWidgets('桌面深色主题与资产空态可用', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    await store.settings({'theme': 'dark'});
    router.go('/assets');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('存款与理财'), findsOneWidget);
    expect(find.text('添加第一个账户'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
  testWidgets('桌面最小内容尺寸下各页面与月度表单可用', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(960, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    await store.put(
      Entry(
        id: 'member-a',
        kind: 'member',
        data: {'name': '成员甲', 'active': true, 'order': 0},
      ),
    );
    router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    for (final theme in ['light', 'dark']) {
      await store.settings({'theme': theme});
      await tester.pumpAndSettle();
      for (final destination in destinations) {
        await tester.tap(find.text(destination.$1).hitTestable().first);
        await tester.pumpAndSettle();
        final scroll = find.byType(SingleChildScrollView).first;
        await tester.drag(scroll, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$theme ${destination.$3}',
        );
      }
      await tester.tap(find.text('月度').hitTestable().first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('编辑月度记录').last);
      await tester.tap(find.byTooltip('编辑月度记录').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存'));
      expect(find.text('保存').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$theme 月度表单');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
}
