# Maktaba Athariyya

A modern, fully offline Dhivehi/Arabic PDF and audiobook reader built with Flutter for Android and iOS.

## What is implemented

- Automatically discovers PDF books from the bundled collection folders.
- Search and collection filters.
- Animated Home and Bookmarks bottom navigation.
- Responsive two-column library with generated covers.
- Optional original cover images with generated-cover fallback.
- Featured audiobook carousel.
- Fast local PDF reader with zoom and text selection.
- Saves the last-read page independently for every book.
- Page bookmarks.
- A bookmark library that groups saved pages by book.
- Reader controls hide/show with a tap.
- Embedded audio player for the matching audiobook.
- Four audio chapters, seek bar, ±10/30 seconds, speed control, and chapter controls.
- Saves the last chapter and listening position locally.
- No account, server, internet connection, database, dark mode, or eye-comfort integration.

## Content layout

The application currently bundles these folders:

```text
books/
  Dar Al Fitya/
  Markaz Al Meezan/
  Markaz Al fursan/
audios/
  Markaz Al Fursan/
    hukum masala rujoo'a vaa aslu/
fonts/
  Faseyha_reg_hinted_v2.ttf
```

The visible book titles and short internal PDF paths are listed in `assets/catalog.json`. Short internal IDs avoid platform filename limits while retaining the complete original Dhivehi/Arabic titles in the interface.

The existing four MP3 files are connected to the PDF whose cleaned title contains `ރުޖޫޢަވާ`. This explicit rule lives in `lib/services/catalog_service.dart`; it prevents unrelated books from accidentally receiving the same audio.

## Adding another PDF-only book

1. Put the PDF in one of the existing `books/<collection>/` folders using a short ASCII filename such as `book_13.pdf`.
2. Add its path, visible title, and collection to `assets/catalog.json`.
3. Restart/rebuild the app so Flutter bundles the new asset.

For a brand-new collection, add its directory under `flutter/assets` in `pubspec.yaml`.

## Adding another audiobook

1. Add its PDF to a book collection.
2. Put its ordered MP3 chapters in a dedicated audio folder.
3. Add that audio folder under `flutter/assets` in `pubspec.yaml`.
4. Extend the audio-to-book matching rule in `CatalogService`.

For more audiobooks, extend the catalog with explicit audio relationships; the current first audiobook still uses one clear title-marker rule.

## Adding original book covers

1. Export each cover as a portrait WebP or JPEG image, ideally about 800 × 1200 pixels and below 300 KB.
2. Place it in `covers/` with a short ASCII filename, for example `meezan_04.webp`.
3. Add `"coverAsset": "covers/meezan_04.webp"` to that book's record in `assets/catalog.json`.
4. Rebuild the app so Flutter bundles the new image.

The original cover will then replace the generated design everywhere in the library. Books without a cover image keep the existing generated design.

## Running the project

Install Flutter stable, Android Studio/Android SDK, and Xcode on a Mac for iOS builds. Then run:

```sh
flutter create --platforms=android,ios --org com.maktabaathariyya .
flutter pub get
flutter analyze
flutter run
```

An iOS build must be signed and produced on macOS with Xcode. Android can be built from Linux, macOS, or Windows once the Android SDK is configured.

## Key source files

- `lib/screens/library_screen.dart` — home, search, filters, and carousel.
- `lib/screens/reader_screen.dart` — PDF reader, page restoration, and bookmarks.
- `lib/widgets/audio_player_panel.dart` — local audio controls and listening progress.
- `lib/services/catalog_service.dart` — asset discovery and book/audio mapping.
- `lib/services/progress_service.dart` — local preferences.
- `lib/theme/app_theme.dart` — colors, typography, and motion style.

## Before store release

- Replace generated covers with approved covers if desired.
- Review all Dhivehi interface wording.
- Confirm permission to distribute every PDF, recording, and font.
- Add final launcher icons and splash branding.
- Test the largest PDFs on low-memory Android devices.
- Test audio interruptions, Bluetooth controls, calls, and app relaunches.
