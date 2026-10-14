# Audible Genius edits to JUCE

This repo is upstream JUCE plus a small set of our own edits, used by **Syntorial** and **Primer**
(both build against this folder as `../../JUCE/modules`). This file lists every edit: what it does,
why, and who relies on it. It exists so that a JUCE update never drops one silently.

**Updating JUCE?** Follow the routine at the bottom. In short: tag before, merge, then run
`ag-tools/check-customizations.sh survived <tag>` and settle every line it reports.

**Adding a new edit to JUCE?** Add an entry here in the same commit, then run
`ag-tools/check-customizations.sh inventory`. It fails if any file we've changed has no entry.

Compared against: upstream `8.0.12-4-g501c07674e` (the 8.0.12 merge, March 2026).
Whitespace-only differences are ignored by the check and not listed.

---

## Live edits

Each entry: **what**, **why**, **used by**, and **retire when** (the condition under which we can
drop it and take JUCE's version).

### Wine: use software drawing when running under Wine
- `modules/juce_gui_basics/native/juce_Windowing_windows.cpp`
- `modules/juce_graphics/native/juce_Direct2DImage_windows.cpp`
- `modules/juce_graphics/native/juce_DirectWriteTypeface_windows.cpp`
- **What:** under Wine, windows draw with JUCE's software renderer and images live in plain memory
  instead of Direct2D. No change on real Windows.
- **Why:** JUCE 8.0.12's Direct2D path needs calls Wine doesn't implement, so Syntorial's windows
  never drew for a customer on Linux/Proton (Oct 2026). Cherry-pick of upstream `5179690f`.
- **Used by:** all Windows builds (Syntorial, Primer).
- **Retire when:** we update to JUCE 8.0.13 or later. It IS upstream there, so `survived` will
  show these lines as present (or harmlessly reworded). Expected; just confirm and delete this entry.

### iOS deep links reach the app
- `modules/juce_gui_basics/native/juce_Windowing_ios.mm`
- **What:** the scene delegate forwards `openURLContexts` (cold start and while running) to
  `JUCEApplicationBase::anotherInstanceStarted (url)`.
- **Why:** JUCE 8 moved iOS to scenes and stopped delivering opened URLs to the app. Syntorial's iPad
  deep links (`syntorial://...`) rely on it. Restored after the 8.0.12 update (`8dde852a23`).
- **Used by:** Syntorial iPad (`anotherInstanceStarted` in `Main.cpp`); Primer has the same handler.
- **Retire when:** JUCE delivers scene URLs to `anotherInstanceStarted` itself.

### Mac: don't observe the light/dark theme change
- `modules/juce_gui_basics/native/juce_Windowing_mac.mm`
- **What:** the `AppleInterfaceThemeChangedNotification` observer is commented out.
- **Why:** it crashed Syntorial whenever macOS switched between light and dark (`fd31ec399c`, Jan 2024).
- **Used by:** Syntorial and Primer on Mac.
- **Retire when:** someone confirms the crash no longer reproduces with JUCE's observer restored.

### Aspect ratio that ignores the title bar
- `modules/juce_gui_basics/layout/juce_ComponentBoundsConstrainer.cpp`
- `modules/juce_gui_basics/layout/juce_ComponentBoundsConstrainer.h`
- **What:** `setFixedAspectRatio (ratio, heightOffset)`: an optional second argument subtracts a
  fixed height (the native title bar) before applying the ratio.
- **Why:** keep the window's *content* at the right shape when resizing, not the whole window (`d91e51a4fd`).
- **Used by:** Primer (calls it with two arguments).
- **Retire when:** never, unless the caller changes. JUCE has no equivalent.

### Viewport: allow drag-scrolling on one axis only
- `modules/juce_gui_basics/layout/juce_Viewport.cpp`
- `modules/juce_gui_basics/layout/juce_Viewport.h`
- **What:** `setAllowHorizontalDrag (bool)` / `setAllowVerticalDrag (bool)`.
- **Why:** scrolling lists by drag on iPad without the other axis wobbling (`24c559d7cc`, restored `ed0a8b07b3`).
- **Used by:** Syntorial (7 files) and Primer (3) call `setAllowHorizontalDrag`.
- **Retire when:** never; JUCE has no equivalent.

### On-screen MIDI keyboard
- `modules/juce_audio_utils/gui/juce_MidiKeyboardComponent.cpp`
- `modules/juce_audio_utils/gui/juce_MidiKeyboardComponent.h`
- `modules/juce_audio_utils/gui/juce_KeyboardComponentBase.h`
- **What:** (1) skips a null key in the computer-keyboard mapping, which made the keyboard fire an
  F5 (`e8f0ce7f34`); (2) a `shouldCheckMousePos` timer that re-reads the finger/mouse position while
  held, so sliding across keys on iPad works (`77592e99ee`); `disableMousePosCheck()` (iOS) turns it
  off; (3) `handleNoteOn/Off` and `setLowestVisibleKeyFloat` made public so the app can call them.
- **Used by:** Syntorial and Primer (`setLowestVisibleKeyFloat`, `disableMousePosCheck`).
- **Retire when:** never for (2) and (3); (1) when JUCE's mapping no longer contains a null.

### Audio device: remember devices by unique ID, extra iOS hooks
- `modules/juce_audio_devices/audio_io/juce_AudioDeviceManager.cpp`
- `modules/juce_audio_devices/audio_io/juce_AudioDeviceManager.h`
- `modules/juce_audio_devices/audio_io/juce_AudioIODevice.h`
- `modules/juce_audio_devices/audio_io/juce_AudioIODeviceType.h`
- **What:** `AudioDeviceSetup` gains `inputDeviceUID` / `outputDeviceUID`, filled from a new
  `AudioIODeviceType::getDeviceUID()`; setup is refreshed when a device starts; the destructor calls
  a new `closeAudioUnit()`. `AudioIODevice` also gains empty virtuals for host transport (Audiobus /
  Inter-App Audio: `toggleHostPlayback`, `getHostIcon`, `isHostConnectedViaIAA`, ...).
- **Why:** route video audio to the same output device as the synth on Mac (`77a7a9b939`, Peter 2019);
  host-transport controls for iPad Audiobus/IAA.
- **Used by:** Syntorial reads `outputDeviceUID` (1 file) and `getHostIcon` (1 file). Nothing in
  JUCE overrides `getDeviceUID`, so it always returns empty. See "Suspected dead" below.
- **Retire when:** see "Suspected dead".

### Analytics timestamps are wall-clock, 64-bit
- `modules/juce_analytics/analytics/juce_Analytics.cpp`
- `modules/juce_analytics/destinations/juce_AnalyticsDestination.h`
- **What:** event timestamp is `Time::currentTimeMillis()` as `int64`, not the 32-bit uptime counter.
- **Why:** stored analytics events need a real date (`9d72521e71`, `14766c844e`, Peter 2018).
- **Used by:** Syntorial (2 files use `juce::Analytics`).
- **Retire when:** never; JUCE's design is deliberately relative.

### TextEditor: is the iPad on-screen keyboard showing?
- `modules/juce_gui_basics/widgets/juce_TextEditor.cpp`
- `modules/juce_gui_basics/widgets/juce_TextEditor.h`
- **What:** `static bool TextEditor::virtualKeyboardIsShowing`.
- **Used by:** Syntorial `CustomControls.cpp` (shared with Primer), `iOS/Upgrade/UpgradeComponent.cpp`,
  `iOS/Upgrade/RegisterComponent.cpp`.
- **BROKEN since 2023, see "Lost in past updates" below.** Nothing sets it any more.

### Menu bar height follows the look-and-feel (Windows)
- `modules/juce_gui_basics/windows/juce_DocumentWindow.cpp`
- **What:** the menu bar's height comes from `getLookAndFeel().getDefaultMenuBarHeight()`.
- **Why:** let the menu bar grow and shrink with the app's zoom on Windows (`7575dfbbc6`, Peter 2022).
- **Used by:** Syntorial and Primer (both override `getDefaultMenuBarHeight`).

### "Show/Hide advanced settings" is translatable
- `modules/juce_audio_utils/gui/juce_AudioDeviceSelectorComponent.cpp`
- **What:** wraps the button text in `TRANS()` (`33a71126f7`).
- **Used by:** the audio settings panel in both apps. Note: `TRANS()` on a non-literal is invisible to
  the extractor (see the syntorial memory `trans-on-literals-only`); the two literals here are fine.

### JUCE's own video player (Mac): audio device, no scroll-wheel seeking
- `modules/juce_video/juce_video.cpp`
- `modules/juce_video/native/juce_Video_mac.h`
- `modules/juce_video/native/myAVPlayer.h`
- `modules/juce_video/playback/juce_VideoComponent.cpp`
- `modules/juce_video/playback/juce_VideoComponent.h`
- **What:** `VideoComponent::setAudioOutput (deviceUID)` (Mac); `MyAVPlayerView` disables scroll-wheel
  fast-forward.
- **DORMANT.** Both apps play video through VLC (`#define VLC`); `juce::VideoComponent` is only used
  when VLC is off. And `MyAVPlayerView` is defined but no longer used by JUCE's player, so the
  scroll-wheel fix is already gone. Keep only while the non-VLC path is kept.

### Small leftovers
- `modules/juce_core/system/juce_CompilerSupport.h`: defines `JUCE_OBJC_HAS_AVAILABLE_FEATURE`, an old
  macro something once needed for the iOS build (`3f0fa56daf`). Probably unused; try removing at the
  next update.
- `modules/juce_dsp/maths/juce_LookupTable.h`: documentation only (`@code` blocks), a stale upstream
  doc version that survived a merge. Take JUCE's version at the next update.

---

## Lost in past updates (open, needs a decision)

Found on 2026-10-14 by running `survived` against the old updates. **None of these were deliberate.**

1. **iPad on-screen keyboard tracking (lost 2023, JUCE 7.0.x).** Our `keyboardDidShow/keyboardDidHide`
   observers in the iOS view controller set `TextEditor::virtualKeyboardIsShowing`. JUCE renamed
   `juce_ios_UIViewComponentPeer.mm` to `juce_UIViewComponentPeer_ios.mm` (`05d5c94990`); our version
   was left behind as `.orig` (deleted 2026-10-14, recoverable from git) and the flag has been
   **always false** since. Effects to verify on iPad: `IOSTextEditor` never sees the keyboard
   appear, so its tap-out-to-dismiss never runs; the Upgrade and Register screens never re-lay-out
   when the keyboard shows. **Checked 2026-10-14: cosmetic only, left as is (Joe).** iOS shows the
   keyboard itself, so typing works. The Upgrade/Register re-layout code is already commented out.
   What's actually lost: a text box stays focused (cursor still showing) after the keyboard is
   dismissed, and a 500 ms timer keeps polling after a tap.
2. **iPad Dropbox setup (lost in the 8.0.12 update, March 2026, so since 2.3.400).** Our iOS app
   delegate called `[DBClientsManager setupWithAppKey:]` at launch and passed Dropbox's sign-in
   redirect to `handleRedirectURL`. Both are gone and nothing else in either app does them, so
   **iPad Dropbox is probably broken** (`Source/iOS/Dropbox/`). **DECIDED (Joe, 2026-10-14): leave it
   broken, do not restore.** Dropbox support is being dropped anyway, and new users never get it.
3. **iPad "don't back up downloads to iCloud" (same update).** At launch we created
   `Application Support/Resources` and set `NSURLIsExcludedFromBackupKey` on it. Gone. The flag
   stays on the folder for existing installs, so only fresh installs since 2.3.400 are affected:
   their downloaded lessons now count against the user's iCloud backup. Apple's review guidelines
   also ask that re-downloadable content be excluded from backup. **FIXED IN APP CODE (2026-10-14,
   syntorial `7c3e0ce6`, ships in 2.3.600):** `ResourceCopier::excludeResourcesFromBackup()`, called
   from `TopComponent::setupPaths()`. Deliberately not put back into JUCE.
4. Also dropped in that update, probably harmless: an iCloud key-value-store change observer (it only
   logged) and our older push-notification delegate plumbing (JUCE 8 has its own).

All four are now decided (see each item). Rule going forward: app behaviour that doesn't need to
live inside JUCE goes in app code, where a JUCE update can't drop it.

## Suspected dead (check, then remove at the next update)

- `AudioIODevice` host-transport virtuals (`toggleHostPlayback` etc.) and `closeAudioUnit`: nothing in
  JUCE overrides them, so they do nothing. Syntorial calls `getHostIcon` once, and it always gets null.
- `getDeviceUID` / `inputDeviceUID` / `outputDeviceUID`: always empty for the same reason, though
  Syntorial reads `outputDeviceUID` once.

## Not edits (ignore)

Differences under `examples/`, `extras/` and `docs/` are IDE and build-file churn from regenerating
JUCE's own demo projects. Neither app uses them, and the check only looks at `modules/`.

---

## Updating JUCE: the routine

1. **Before.** On a clean `dev`: `git fetch upstream --tags` and
   `git tag ag-pre-update-<new version>`. Run `ag-tools/check-customizations.sh inventory` and fix any
   UNNOTED file first.
2. **Merge** the new release tag into a branch, e.g. `git checkout -b dev-pull-upstream-<ver> dev &&
   git merge <ver>`. On every conflict in a file listed above, keep our edit unless its "retire when"
   says otherwise.
3. **Check.** `ag-tools/check-customizations.sh survived ag-pre-update-<ver>`. Every reported line
   gets one of two answers: re-applied, or retired (JUCE now does it) with this file updated. A **GONE**
   file means JUCE renamed it: find the new name and re-apply there. This is exactly how item 1 above
   was lost.
4. **Inventory again** (`inventory`), then update "Compared against" at the top.
5. **Build** Syntorial on Mac, iPad and Windows, and Primer. The check proves the code is there; only
   a build proves it still compiles against the new JUCE.
6. Merge to `dev` and push. Syntorial and Primer pick it up from the sibling folder on their next build.
