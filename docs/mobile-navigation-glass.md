# Mobile navigation glass fix — build 8

The library keeps one floating, rounded navigation surface over its scrolling
content. Its backdrop uses Flutter's clipped `BackdropFilter` with a neutral tint,
a thin highlight border, and a subtle shadow. It does not use adaptive shader
quality or nested glass layers for navigation. Other glass components are unchanged.

The library body no longer consumes Scaffold's bottom navigation padding as a
SafeArea. Each of the four tabs instead adds that space to the end of its scroll
content, so books can scroll behind the glass but the last book and pagination
remain reachable. The reserved space includes the mini-player when it is visible.

Android system navigation uses a transparent background with theme-appropriate
icons. The bar respects iOS/Android bottom and landscape safe areas, preserving
the bottom inset when the keyboard opens. Tab selection keeps fixed dimensions
and respects reduced-motion settings.

Before release, check build 1.0.0+8 on Android and iPhone: scroll every tab,
switch tabs quickly, toggle both themes, open/close search keyboard, and start
an audiobook to show the mini-player. Check gesture navigation and Android
three-button navigation, plus iPhone landscape/home indicator. Widget tests
exercise both platform themes and layout constraints; they cannot prove GPU
performance on a physical phone.
