import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_reserve/main.dart';
import 'package:home_reserve/store.dart';
import 'package:home_reserve/domain.dart';
import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => glass.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false),
  );
  testWidgets('原生窗口可新增成员、记录月度、切换主题并确认重置测试账本', (tester) async {
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.book.entries, isEmpty);
    await tester.tap(find.text('月度').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加成员'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, '测试成员');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('编辑月度记录'));
    await tester.tap(find.byTooltip('编辑月度记录'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('本月收入（元，可留空）')),
      '3000.00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('本月净存入（元，可为负，可留空）')),
      '500.00',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final record = store.book.monthly(
      store.book.members.single.id,
      monthKey(DateTime.now()),
    )!;
    expect(record.data['income'], 300000);
    expect(record.data['saving'], 50000);
    await tester.tap(find.text('设置').hitTestable().first);
    await tester.pumpAndSettle();
    final chooser = tester.widget<glass.GlassSegmentedControl>(
      find.byType(glass.GlassSegmentedControl).last,
    );
    for (final index in [1, 1, 2, 0, 2]) {
      chooser.onSegmentSelected(index);
    }
    await tester.pumpAndSettle();
    expect(store.book.settings['theme'], 'dark');
    expect(find.textContaining('正在保存'), findsNothing);
    await tester.tap(find.text('资产').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('存款与理财'), findsOneWidget);
    expect(find.text('添加第一个账户'), findsOneWidget);
    await tester.tap(find.text('设置').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('重置所有本机数据'));
    await tester.tap(find.text('重置所有本机数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, '清空');
    await tester.tap(find.text('清空所有数据'));
    await tester.pumpAndSettle();
    expect(store.book.entries, isEmpty);
    expect(store.book.settings['device'], '本机设备');
    expect(store.book.settings['theme'], 'system');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
}
