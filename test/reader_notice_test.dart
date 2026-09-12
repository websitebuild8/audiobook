import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktaba_athariyya/models/book.dart';
import 'package:maktaba_athariyya/services/catalog_service.dart';
import 'package:maktaba_athariyya/widgets/reader_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reader notices are opt-in and survive downloaded media substitution',
      () {
    const plain =
        Book(id: 'plain', title: '', category: '', pdfAsset: 'book.pdf');
    const selected = Book(
      id: 'selected',
      title: '',
      category: '',
      pdfAsset: 'book.pdf',
      showReaderNotice: true,
    );
    expect(plain.showReaderNotice, isFalse);
    expect(
        selected.copyWithLocalMedia(
            pdfPath: '/book.pdf', audioPaths: []).showReaderNotice,
        isTrue);
    expect(
        plain.copyWithLocalMedia(
            pdfPath: '/book.pdf', audioPaths: []).showReaderNotice,
        isFalse);
  });

  test('cached API data enables the notice only for an explicit true value',
      () async {
    SharedPreferences.setMockInitialValues({
      'remote_catalog_updated_at_v1': DateTime.now().millisecondsSinceEpoch,
      'remote_catalog_v1': jsonEncode([
        for (final flag in [true, false, null, 'true'])
          {
            'id': '$flag',
            'pdf': {'url': 'https://example.com/book.pdf'},
            if (flag != null) 'showReaderNotice': flag
          },
      ]),
    });
    final books = await CatalogService.load();
    expect(books.map((book) => book.showReaderNotice),
        [true, false, false, false]);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'glass notice is centered, scrollable and dismissible in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var closed = false;
      final text = List.filled(30, 'ތަންބީހު').join(' ');
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
            body: ReaderNotice(text: text, onClose: () => closed = true)),
      ));
      expect(tester.widget<Text>(find.text(text)).textAlign, TextAlign.center);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(closed, isTrue);
    });
  }
}
