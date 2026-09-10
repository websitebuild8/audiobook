import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktaba_athariyya/app.dart';
import 'package:maktaba_athariyya/models/book.dart';
import 'package:maktaba_athariyya/services/catalog_service.dart';

void main() {
  setUp(
    () => CatalogService.testBooks = const [
      Book(
        id: 'test-book',
        title: 'ފޮތް',
        category: 'ބައި',
        pdfAsset: 'https://example.com/book.pdf',
      ),
    ],
  );
  tearDown(() => CatalogService.testBooks = null);

  testWidgets('shows the Maktaba library heading', (tester) async {
    await tester.pumpWidget(const MaktabaApp());
    await tester.pumpAndSettle();

    final heading = find.text('މަކްތަބާ އަޘަރިއްޔާ');
    expect(heading, findsOneWidget);
    expect(
      () => MaterialLocalizations.of(tester.element(heading)),
      returnsNormally,
    );
  });
}
