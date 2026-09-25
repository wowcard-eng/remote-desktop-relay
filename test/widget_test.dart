import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:remote_control_app/main.dart';
import 'package:remote_control_app/providers/remote_provider.dart';

void main() {
  testWidgets('RemoteControlApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => RemoteProvider()),
        ],
        child: const RemoteControlApp(),
      ),
    );

    expect(find.text('TeamViewer Remote'), findsOneWidget);
    expect(find.text('Control Remote'), findsOneWidget);
  });
}
