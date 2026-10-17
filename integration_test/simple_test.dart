import 'package:defile/main.dart';
import 'package:defile/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Shows the file explorer shell', (WidgetTester tester) async {
    await tester.pumpWidget(const RootApp());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Defile'), findsOneWidget);
  });
}
