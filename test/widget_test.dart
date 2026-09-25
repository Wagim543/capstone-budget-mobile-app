import 'package:flutter_test/flutter_test.dart';
import 'package:capstone_budget/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CapstoneBudgetApp());

    // Verify that the Capstone title appears.
    expect(find.text('Capstone Project Budget'), findsOneWidget);
  });
}
