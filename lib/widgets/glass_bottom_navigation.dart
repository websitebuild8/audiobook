import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single clipped backdrop, outside page-transition opacity layers.
/// Uses the same blur-and-translucent-tint approach as the web navigation.
class GlassBottomNavigation extends StatelessWidget {
  const GlassBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (label: 'މައި ޞަފްޙާ', icon: Icons.home_rounded),
    (label: 'އޯޑިއޯ', icon: Icons.headphones_rounded),
    (label: 'ބުކްމާކް', icon: Icons.bookmarks_rounded),
    (label: 'ފަހުން ކިޔެވުނު', icon: Icons.history_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(30);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .20 : .09),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  key: const ValueKey('navigation-glass-surface'),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dark
                          ? [const Color(0xBB25282C), const Color(0xA61B1E22)]
                          : [const Color(0xBFFFFFFF), const Color(0x8CF8FAFC)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: dark ? .19 : .72),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SizedBox(
                      height: 64,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          children: [
                            for (var index = 0; index < _items.length; index++)
                              Expanded(
                                child: Semantics(
                                  selected: selectedIndex == index,
                                  button: true,
                                  label: _items[index].label,
                                  child: Tooltip(
                                    message: _items[index].label,
                                    excludeFromSemantics: true,
                                    child: InkWell(
                                      key: ValueKey('navigation-tab-$index'),
                                      onTap: () => onSelected(index),
                                      borderRadius: BorderRadius.circular(24),
                                      splashFactory: NoSplash.splashFactory,
                                      child: AnimatedContainer(
                                        duration: duration,
                                        curve: Curves.easeOutCubic,
                                        alignment: Alignment.center,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          color: selectedIndex == index
                                              ? Colors.white.withValues(
                                                  alpha: dark ? .13 : .58)
                                              : Colors.transparent,
                                        ),
                                        child: Icon(
                                          _items[index].icon,
                                          size: 24,
                                          color: selectedIndex == index
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: .75),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reserve scrollable space, rather than painting an opaque strip behind glass.
/// Scaffold supplies the current navigation + mini-player height via MediaQuery.
class LibraryBottomInset extends StatelessWidget {
  const LibraryBottomInset({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 18),
      );
}
