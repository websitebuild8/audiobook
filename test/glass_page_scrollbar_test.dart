import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktaba_athariyya/widgets/glass_page_scrollbar.dart';

void main() {
  testWidgets(
      'dragging reaches the last page and shows its label only while pressed',
      (tester) async {
    var page = 1;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => SizedBox(
          width: 120,
          height: 500,
          child: GlassPageScrollbar(
              page: page,
              pageCount: 20,
              onChanged: (value) => setState(() => page = value))),
    ))));
    expect(find.text('1 / 20'), findsNothing);
    final gesture = await tester
        .startGesture(tester.getCenter(find.byIcon(Icons.drag_handle_rounded)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('1 / 20'), findsOneWidget);
    await gesture.moveBy(const Offset(0, 460));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(page, 20);
    expect(find.text('20 / 20'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(find.text('20 / 20'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one-page documents do not show an unnecessary scrollbar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: GlassPageScrollbar(page: 1, pageCount: 1, onChanged: (_) {})));
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
  });
}
