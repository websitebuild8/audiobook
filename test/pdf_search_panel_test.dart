import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:maktaba_athariyya/services/pdf_search_service.dart';
import 'package:maktaba_athariyya/widgets/pdf_search_panel.dart';

void main() {
  testWidgets(
      'search results are usable on a narrow phone and clear when closed',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final search = PdfSearchService();
    await tester.runAsync(() => search.index(
        1,
        (_) async => const PdfPageText(
            pageNumber: 1,
            fullText: 'book book',
            charRects: [],
            fragments: [])));
    int? selected;
    var closed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnimatedBuilder(
      animation: search,
      builder: (_, __) => PdfSearchPanel(
          search: search,
          current: 0,
          onSelect: (value) => selected = value,
          onClose: () {
            closed = true;
            search.search('');
          }),
    ))));
    await tester.enterText(find.byType(TextFormField), 'book');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    expect(selected, 1);
    await tester.tap(find.byIcon(Icons.list));
    await tester.pump();
    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.close));
    expect(closed, true);
    expect(search.matches, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    search.dispose();
  });
}
