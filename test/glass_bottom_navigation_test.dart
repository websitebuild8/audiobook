import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktaba_athariyya/theme/app_theme.dart';
import 'package:maktaba_athariyya/widgets/glass_bottom_navigation.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final dark in [false, true]) {
      testWidgets(
          '$platform glass navigation in ${dark ? 'dark' : 'light'} mode preserves safe areas and scroll reachability',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = 0;
        final bottom = platform == TargetPlatform.iOS ? 34.0 : 24.0;
        await tester.pumpWidget(MaterialApp(
          theme: (dark ? AppTheme.dark : AppTheme.light)
              .copyWith(platform: platform),
          home: MediaQuery(
            data: MediaQueryData(
                size: const Size(390, 844),
                padding: EdgeInsets.only(bottom: bottom),
                viewPadding: EdgeInsets.only(bottom: bottom)),
            child: Directionality(
                textDirection: TextDirection.rtl,
                child: StatefulBuilder(
                    builder: (context, setState) => Scaffold(
                          extendBody: true,
                          body: SafeArea(
                              bottom: false,
                              child: Builder(
                                  builder: (context) => CustomScrollView(
                                        key: const ValueKey('library-scroll'),
                                        slivers: [
                                          SliverList.builder(
                                              itemCount: 30,
                                              itemBuilder: (context, index) =>
                                                  SizedBox(
                                                      height: 80,
                                                      child: ColoredBox(
                                                          color: index.isEven
                                                              ? Colors.blue
                                                              : Colors.orange,
                                                          child: Text(
                                                              'Book $index')))),
                                          const LibraryBottomInset(),
                                        ],
                                      ))),
                          bottomNavigationBar:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            if (selected == 1) const SizedBox(height: 88),
                            GlassBottomNavigation(
                                selectedIndex: selected,
                                onSelected: (index) =>
                                    setState(() => selected = index)),
                          ]),
                        ))),
          ),
        ));
        await tester.pumpAndSettle();
        final glass = find.byKey(const ValueKey('navigation-glass-surface'));
        final initialRect = tester.getRect(glass);
        expect(initialRect.height, 64);
        expect(initialRect.bottom, 844 - bottom);
        expect(
            tester.getRect(find.byKey(const ValueKey('library-scroll'))).bottom,
            844);
        expect(find.byType(BackdropFilter), findsOneWidget);
        for (final index in [1, 2, 3, 0]) {
          await tester.tap(find.byKey(ValueKey('navigation-tab-$index')));
          await tester.pumpAndSettle();
          expect(selected, index);
          expect(tester.getRect(glass), initialRect);
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byKey(const ValueKey('navigation-tab-1')));
        await tester.pumpAndSettle();
        await tester.drag(find.byKey(const ValueKey('library-scroll')),
            const Offset(0, -3500));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('Book 29')).bottom,
            lessThan(initialRect.top - 88));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('compact landscape and reduced motion do not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          size: Size(320, 240),
          disableAnimations: true,
          padding: EdgeInsets.only(left: 20, right: 20, bottom: 21)),
      child: Scaffold(
          bottomNavigationBar:
              GlassBottomNavigation(selectedIndex: 2, onSelected: (_) {})),
    )));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('navigation-tab-0'))).width,
        greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
}
