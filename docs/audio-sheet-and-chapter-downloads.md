# Audio sheet and individual chapter downloads

The Android and iOS app now has a compact audio bar in the reader and library. Tap it or swipe upward to open a glass-styled modal sheet. Pull the sheet upward to expand its chapter list; scroll through all chapters. Pull downward to minimise/dismiss it, or use the down-arrow. Closing it keeps playback running.

The Audiobooks tab opens the sheet directly without requiring a PDF download. Each chapter can be played, downloaded, cancelled, retried, or removed separately. Its row shows file size, download progress, and offline availability. Tap a chapter to play it; tap the current playing chapter to pause it. Missing downloads stream using the original URL, so they require an internet connection. The player selects saved files when starting/resuming a book or selecting a chapter.

Library PDF download buttons now download only the PDF. A PDF can be opened while none or only some audio chapters are saved. Existing downloaded PDFs/audio use the same storage paths, and old native download plans continue to restore. Removing an individual chapter preserves the PDF and other chapters; the book's existing remove-all confirmation still removes all its saved files.

Background playback, system media controls, and background downloads are retained. No web or backend deployment is required for this mobile change. Build version: `1.0.0+6`.

## Device checks before release

1. From Audiobooks, open a book whose PDF has not been downloaded. Expand the sheet and select a chapter to stream.
2. Download just chapter two, close the sheet, browse other sections, and lock the phone. Confirm the download persists and the other chapters/PDF are not queued.
3. Reopen the app with airplane mode enabled. Select the downloaded chapter and verify local playback. Undownloaded chapters require connectivity.
4. Pause, minimise, expand, and resume. The position should be retained; no second player should start.
5. Download the PDF alone and open it while audio chapters are absent or downloading. Verify the compact player and PDF page scrollbar remain reachable.
6. Cancel/retry one chapter while another downloads; remove one completed chapter; verify sibling files remain available.
7. Check iPhone and Android screen-lock/media controls and chapter changes, including a book containing both downloaded and online chapters.
8. Upgrade with existing downloads and verify that those files are recognised without re-downloading.

Automated tests cover per-file task independence, retries/restarts, legacy file discovery, local source selection, direct chapter playback, sheet expansion/scrolling, and minimising without stopping audio.
