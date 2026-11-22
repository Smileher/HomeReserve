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
  testWidgets('原生窗口可新增成员、保存月度记录、切换主题和资产页', (tester) async {
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
    await tester.tap(find.text('深色').hitTestable().first);
    await tester.pumpAndSettle();
    expect(store.book.settings['theme'], 'dark');
    await tester.tap(find.text('资产').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('存款与理财'), findsOneWidget);
    expect(find.text('添加第一个账户'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.go('/');
  });
}
