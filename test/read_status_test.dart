import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktaba_athariyya/services/progress_service.dart';
import 'package:maktaba_athariyya/widgets/read_status.dart';

void main() {
  testWidgets('confirmation controls completion and updates the cover badge',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(children: [
      ReadStatus(bookId: 'a', interactive: true),
      ReadStatus(bookId: 'a'),
    ]))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(await ProgressService.isRead('a'), isFalse);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(await ProgressService.isRead('a'), isTrue);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(await ProgressService.isRead('a'), isFalse);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });
}
