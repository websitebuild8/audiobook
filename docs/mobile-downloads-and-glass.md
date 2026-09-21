# Mobile download and glass update

The app now queues each PDF and audio chapter using background_downloader 9.6.2. The native service runs independently of library tabs. Plans are persisted before enqueueing, native statuses are restored at launch, and completed files are retained when retrying. Existing complete offline books remain compatible. The previous implementation's abandoned `.partial` folders cannot safely be resumed because it saved no HTTP resume metadata.

Backgrounding the app is supported. Force-quitting, force-stopping, battery restrictions, network conditions, and OS scheduling can still interrupt transfers. On reopening, interrupted native tasks are reconciled; failed tasks show Retry. Resuming an individual partial file depends on native resume data and server support. Completed chapters are retained. No claim of uninterrupted transfer after force-quit is made.

Privacy Policy is available through the shield icon beside the theme toggle on the home header. Its text is unchanged.

Glass uses liquid_glass_widgets 1.7.1, with standard quality on the header controls, bottom navigation and PDF scrubber. The adaptive scope and accessibility handling are enabled. This is Flutter-rendered styling on iOS and Android, not native UIKit glass. Package evaluation: cupertino_native 0.1.1 is an Apple-platform proof of concept; liquid_glass_renderer 0.2.0-dev.4 is experimental; liquid_glass_widgets has a newer stable release with cross-platform fallback support. Pub.dev likes/downloads are usage signals, not quality guarantees.

## Before public release

Use Codemagic to build both platforms with the committed lockfile and a Flutter version compatible with liquid_glass_widgets (at least 3.41; the development environment uses 3.47.2). Increment the build number above the latest uploaded value.

On an actual iPhone and Android device:
- Start a large audiobook; switch between all library tabs and start a second book. Confirm progress continues and both finish.
- Background and lock the phone for several minutes; return and confirm progress restores.
- Interrupt the network, restore it, and retry if necessary. Completed chapters should remain.
- Force-close, reopen, and confirm download recovery or a usable Retry action.
- Cancel, retry, and remove a book. Confirm another book's transfer is unaffected.
- Confirm complete books read/play offline and pre-update downloads still work.
- Check glass readability, scrolling and battery/frame performance, including a lower-end Android device and accessibility settings.

Automated tests use a fake native downloader to verify app orchestration and file retention. They do not replace native device background-transfer tests. No local store bundle was built during this change.
