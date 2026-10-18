# iPad screenshots using Codemagic

This separate, manually started workflow runs the real app on an iPad Pro simulator on Codemagic's Mac. It does not sign, upload, or publish a store build. Your existing release workflow can continue using Codemagic's Workflow Editor.

## Start it from Linux

1. Commit and push `codemagic.yaml`, `integration_test/`, `test_driver/`, the screenshot scripts in `scripts/`, and `pubspec.yaml` / `pubspec.lock` to the branch you build.
2. Open the app in Codemagic. Select the YAML configuration (`codemagic.yaml`) instead of the Workflow Editor for this run. If prompted, check for the configuration file on your pushed branch.
3. Select **iPad App Store Screenshots**, then **Start new build** on that branch. This uses your macOS build minutes. No signing certificates or App Store Connect API key are needed.
4. After success, open **Artifacts** and download `ipad-13-screenshots.zip` (individual PNGs are also listed).
5. Extract and inspect all ten screenshots. Reject blank covers, unreadable content, notices, overflow, or other visual issues before uploading. Automated size checks are not a substitute for this review.
6. In App Store Connect, open your version → App Previews and Screenshots → View All Sizes in Media Manager → iPad 13-inch. Upload the PNG files, not the ZIP. Choose the strongest images first; using all ten is optional.

## What is captured

Five real screens in light and dark mode: library home, scrolled book list, audiobook list, PDF reader, expanded audio player. The catalogue, covers, and PDF are loaded from the live public API. No sample books, invented progress, or downloaded-state badges are inserted. The player is displayed without starting audio or downloading chapters.

The workflow selects an available iPad Pro 13-inch or 12.9-inch simulator. It checks that every PNG is portrait 2064 × 2752 or 2048 × 2732, and that all ten files exist before creating the ZIP. It fails if required live content or the PDF cannot load. The PDF/audio example is the first audiobook in catalogue order.

Only run this integration test on a disposable simulator: it clears that app installation's preferences to start with a clean library and light theme. It does not alter the server catalogue or real users' data.

## Troubleshooting

- **Workflow not listed:** confirm the files were pushed to the selected branch and select YAML configuration.
- **No suitable simulator:** choose a Codemagic Xcode image with an installed iPad Pro 13-inch/12.9-inch iOS runtime.
- **Catalogue/PDF timeout:** check that the public site and first audiobook's PDF are accessible, then retry.
- **Dimension check failure:** inspect the simulator selection in the log; do not resize an iPhone image to bypass it.
- **Simulator compilation failure:** share the first underlying compiler error, not just the final failed-build line.

No app build-number increase is needed for this screenshot-only workflow. Actual captures require a successful run on Codemagic; Linux cannot run Apple's simulator.
