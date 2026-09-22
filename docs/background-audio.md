# Background audiobook playback

Android and iOS use one app-owned `AudiobookAudioHandler`, powered by audio_service 0.18.19 and just_audio. The reader displays controls without owning/discarding the player. Opening another book does not interrupt the current audiobook; pressing Play on the other book switches playback.

- Playback continues when browsing, minimising the app, locking the screen, or opening another app that does not take audio focus.
- Android media notification and iOS Now Playing/Control Center expose book/chapter metadata, play/pause, seeking, and supported transport controls. Exact layout is chosen by the OS; iOS typically presents Pause rather than a separate Stop button.
- Reader and library mini-player both include Stop. Stop saves the position and releases playback resources. Play resumes the saved position; finishing the last chapter stops playback, and replay starts from the beginning.
- Chapters use a native playlist so the next chapter starts in the background. Position is saved every five seconds, on pause/stop, seek, and chapter change.
- The speech audio session respects phone calls, audio focus, and disconnected headphones. Force-stopping the app, iOS force-quitting, or OS process termination can stop playback; background playback cannot override those actions.

## Release and device verification

Commit/push these changes, use a fresh build number, then build Android and iOS in Codemagic as usual. No new signing keys or bundle identifiers are needed. The Android manifest declares mediaPlayback foreground service and wake lock permissions; iOS declares the audio background mode.

Before releasing publicly, test on physical Android and iPhone devices:

1. Download a multi-chapter audiobook; start playback; return to the library and switch sections. Verify playback and mini-player persist.
2. Open another book without pressing Play. The first audiobook must continue.
3. Lock the screen for several minutes and cross a chapter boundary. Verify title, seek bar, play/pause, and skip controls in notification/Control Center.
4. Use another app; then reopen the reader. Position and chapter must match, without a second audio stream.
5. Pause/resume through Bluetooth/headset controls; disconnect headphones and receive a phone call. Verify appropriate interruption behaviour.
6. Press Stop in the reader, mini-player, or supported system control. Verify audio stops, and Play resumes at the saved position.
7. Finish the last chapter and press Play again. Verify playback starts at chapter one.
8. Start loading and immediately press Stop. It must not start playing later.

Automated tests cover shared player ownership across reader disposal, saved positions, system commands/metadata, replacing the book queue, stop during loading, task removal, and replay after completion. Native background execution and phone-specific controls still require the device checks above.

Reference: https://pub.dev/packages/audio_service
