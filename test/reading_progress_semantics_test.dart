import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktaba_athariyya/services/progress_service.dart';
import 'package:maktaba_athariyya/widgets/reading_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final completed in [0, 1, 38]) {
    testWidgets('accessible progress accepts $completed of 38 books',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final semantics = tester.ensureSemantics();
      final ids = List.generate(38, (index) => 'book-$index');
      for (final id in ids.take(completed)) {
        await ProgressService.setRead(id, true);
      }
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ReadingProgress(bookIds: ids)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('$completed/38'), findsOneWidget);
      final node = tester.getSemantics(find.byType(LinearProgressIndicator));
      expect(node.value, '${(completed / 38 * 100).round()}');
      expect(node.label, contains('$completed/38'));
      semantics.dispose();
    });
  }
}
