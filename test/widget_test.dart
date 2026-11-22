import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_reserve/main.dart';
import 'package:home_reserve/store.dart';
import 'package:home_reserve/domain.dart';

void main() {
  testWidgets('窄屏首页、月度入口及 min 专属文案可用', (tester) async {
    final store = AppStore(memoryOnly: true);
    await store.initialize();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const HomeReserveApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('日子，慢慢有余'), findsOneWidget);
    expect(find.textContaining('给 min'), findsOneWidget);
    await tester.tap(find.text('月度').last);
    await tester.pumpAndSettle();
    expect(find.text('月度记录'), findsOneWidget);
    expect(find.text('min'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('编辑月度记录').last);
    await tester.tap(find.byTooltip('编辑月度记录').last);
    await tester.pumpAndSettle();
    expect(find.text('本月收入（元，可留空）'), findsOneWidget);
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '本月收入（元，可留空）',
      ),
      '12345.67',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '本月净存入（元，可为负，可留空）',
      ),
      '-200.29',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final record = store.book.monthly('member-min', monthKey(DateTime.now()))!;
    expect(record.data['income'], 1234567);
    expect(record.data['saving'], -20029);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets('桌面深色主题与资产空态可用', (tester) async {
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
}
