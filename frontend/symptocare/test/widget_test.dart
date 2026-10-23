
import 'package:flutter_test/flutter_test.dart';
import 'package:symptocare/main.dart';

void main() {
  testWidgets('SymptoCare app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const SymptoCareApp());

    expect(find.text('SymptoCare'), findsOneWidget);
  });
}
