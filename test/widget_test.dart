import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MedicalWalletApp());
    await tester.pump();
  });
}
