import 'package:flutter_test/flutter_test.dart';
import 'package:maktaba_athariyya/app.dart';

void main() {
  testWidgets('shows the Maktaba library heading', (tester) async {
    await tester.pumpWidget(const MaktabaApp());
    await tester.pumpAndSettle();

    expect(find.text('މަކްތަބާ އަޘަރިއްޔާ'), findsOneWidget);
  });
}
