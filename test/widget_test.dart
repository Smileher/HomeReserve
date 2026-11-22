import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_reserve/main.dart';
import 'package:home_reserve/store.dart';

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
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
