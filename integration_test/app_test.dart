import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_reserve/main.dart';
import 'package:home_reserve/store.dart';

void main(){IntegrationTestWidgetsFlutterBinding.ensureInitialized();testWidgets('应用能启动并切换资产页',(tester) async {final store=AppStore(memoryOnly:true);await store.initialize();await tester.pumpWidget(ProviderScope(overrides:[storeProvider.overrideWithValue(store)],child:const HomeReserveApp()));await tester.pumpAndSettle();await tester.tap(find.text('资产').last);await tester.pumpAndSettle();expect(find.text('存款与理财'),findsOneWidget);});}
