# Jeopardy (macOS Host App) — Project Notes

Read this first if you're picking this project back up (human or Claude).
It explains what exists, how it's wired together, and what's still open.

## What this is

A SwiftUI + SwiftData macOS app that replicates a Jeopardy-style board game,
run by a single "Host" on a Mac. The Host builds/loads a board of categories
and clues, players buzz in verbally/off-app, and the Host manually reveals
answers and adjusts scores. A future companion iOS app (buzzer, player
auto-registration, team-ups, text answers) is planned but **not started** —
everything below is the macOS host app only.

Xcode project uses a `PBXFileSystemSynchronizedRootGroup`, meaning **any
file you drop into `Jeopardy/Jeopardy/` is automatically picked up by
Xcode** — you never need to hand-edit `project.pbxproj` to add a new
Swift file. Just create it in the right folder.

## Architecture

```
Jeopardy/
  JeopardyApp.swift          — @main, registers SwiftData models
  Models/
    Clue.swift                — the core @Model: one question/answer card
    CategoryInfo.swift        — per-category metadata (currently just rules text)
    Players.swift             — a player's name + score
  Services/
    MediaStore.swift          — copies imported video files into Application
                                 Support so they survive sandbox/relaunch
    BoardStorage.swift        — export/import the whole board to/from a
                                 single portable .json file (NSSavePanel/
                                 NSOpenPanel, macOS-only, guarded by #if os(macOS))
  Views/
    ContentView.swift         — top-level layout: board + Final Jeopardy +
                                 bottom player bar + toolbar (add/save/load/reset)
    BoardGridView.swift       — scrollable grid of categories x clue cards
    CategoryHeader.swift      — category tile: rename (pencil) + rules (info) popups
    ImageCropView.swift       — drag-to-move / drag-corners-to-resize crop tool
                                 used from ClueFormView when attaching an image
    ClueCard/                 — clue card/detail views, media players, and
                                 announcement views split into focused folders
    AddClueView.swift         — actually defines `ClueFormView` + `ClueFormMode`,
                                 the single form used for Add / Edit / Final
                                 Jeopardy (kept this filename to avoid extra churn)
    FinalJeopardySectionView.swift — optional bonus-round row below the board
    PlayerView.swift          — PlayerView (one player chip) + BottomPlayerBar
    SoundManager.swift        — plays "reveal_ding.mp3" from the bundle
```

### Data model decisions

- **Categories are NOT a separate relational entity tied to clues.** A
  category is just a `String` on `Clue.category` (as it was originally).
  `CategoryInfo` is a *sidecar* table keyed by that same string, used only
  to store rules text. This kept the migration small, but it means:
  - Renaming a category (via `CategoryHeader`) has to cascade-update every
    `Clue.category` string that matches, plus rename/merge the matching
    `CategoryInfo` row. See `CategoryHeader.renameCategory()`.
  - If every clue in a category is deleted/renamed away, the `CategoryInfo`
    row for the old name is **not** automatically cleaned up (harmless
    orphan, but noted here — see Known Limitations).
- **`Clue.isOpened: Bool`** — flips to `true` the moment the Host taps into
  a clue from the board (`BoardGridView`'s tap gesture) or opens Final
  Jeopardy. Drives the greyed-out/checkmark "already used" look on the card.
- **`Clue.isFinalJeopardy: Bool`** — marks the (at most one, by convention)
  Final Jeopardy clue. It's still just a `Clue` row, just filtered out of
  the main board's `@Query` and surfaced by `FinalJeopardySectionView`
  instead. Nothing currently *enforces* only one — if you ever add a second
  via direct DB manipulation, `FinalJeopardySectionView` only shows
  `finalJeopardyClues.first`.
- **Final Jeopardy wagers** live on each `Players` row rather than on the
  clue: `finalJeopardyWager` holds the entered amount and
  `finalJeopardyResult` records `unresolved`, `correct`, or `incorrect`.
  This means the score adjustment always uses the wager belonging to the
  player being resolved, and prevents a result from being applied twice.
- **Video storage**: `Clue.videoFileName: String?` stores only a filename.
  The actual bytes live in `~/Library/Application Support/Jeopardy/Videos/`
  (see `MediaStore`). This is different from image/audio, which are stored
  directly as `Data` on the model via `@Attribute(.externalStorage)`. Videos
  are handled separately because they're large and a raw security-scoped
  `URL` wouldn't survive past the file-picker session in a sandboxed app —
  copying the bytes in is the standard fix.
- **`Clue.answerImageData`** existed on the model from early on but had no
  attach UI in `ClueFormView` until the crop feature was added. It's now
  populated exclusively through the image-crop flow (see "Image cropping"
  below) rather than a separate standalone attach button — this was a
  deliberate choice to avoid two independently-clearable checkmarks for
  what's really one decision (crop vs. keep full).
- **Board save/load format** (`BoardStorage`): a single self-contained
  `.json` file — categories + rules + all clues, with image/audio/video
  bytes embedded as base64. This makes the file fully portable (email it,
  drop it in iCloud Drive, whatever) at the cost of the file being large if
  there's a lot of media. Deliberately **does not include Players** — this
  saves the *board* (the trivia content), not a specific game session's
  roster/scores. Loading a board is destructive (wipes current
  Clue + CategoryInfo tables) and the UI confirms before doing it.

### Migration note

`Clue` picked up new stored properties (`isOpened`, `isFinalJeopardy`) and
the video field changed shape (`videoURL: URL?` → `videoFileName: String?`).
`Players` also now stores a Final Jeopardy wager and result, both with safe
defaults. These additions should be handled by SwiftData's lightweight
migration, but this hasn't been tested against a real existing
`.store` file with old data in it. If Xcode complains about migration on
first run after pulling these changes, easiest fix during development is
deleting the app's SwiftData store (Xcode > Product > Scheme > Edit Scheme >
uncheck "Use Same Debug Executable", or just delete the app's container in
`~/Library/Containers/`) and starting fresh — acceptable since this is
pre-release/dev data.

## What was implemented (this session)

11. ✅ **Unified Final Jeopardy flow and persistent wagers** — Final Jeopardy
    now uses the same `NavigationLink` → announcement → clue/answer flow as
    a normal card, so the bottom player bar remains available. During Final
    Jeopardy, each player gets an individual saved wager field plus Correct /
    Incorrect controls; resolving a player changes only that player's score
    by their wager, and Undo reverses it safely.
12. ✅ **Drag & drop, clipboard paste, and image cropping for clue media**
    — `ClueFormView`'s three media rows (image/audio/video) are each
    wrapped in a `MediaDropZone` (dashed-border drop target) and accept
    `.onDrop` in addition to the existing `.fileImporter` buttons. Paste is
    handled via explicit "Paste" buttons reading `NSPasteboard.general`
    directly (macOS `AppKit`), **not** `onPasteCommand` — SwiftUI's
    `Form` auto-focuses its first text field, which intercepts Cmd+V
    before the form-level paste handler ever sees it, so a pasteboard-read
    button was the only reliable route.
    Every image source (file picker, drop, or paste) now routes through
    `ImageCropView`, a custom drag-to-move / drag-corners-to-resize
    cropper (no built-in AppKit/SwiftUI cropper exists). The crop sheet
    has a "Also save the uncropped image as the Answer Image" toggle and
    a "Skip Crop, Use Full Image" button, so cropping and setting
    `Clue.answerImageData` happen in one step instead of two — this also
    gave `answerImageData` its first real attach UI (see Data model
    decisions above). A "Re-crop" button lets the Host redo the crop
    later; it re-opens against the stored `answerImageData` (the
    original, full-resolution source) when one exists, falling back to
    `imageData` otherwise, so repeated re-crops don't compound resolution
    loss from cropping an already-cropped image.
    Fixed along the way: the crop rectangle's drag gestures originally
    accumulated `DragGesture.translation` (which is cumulative since
    drag-start, not a per-frame delta) onto an already-moved rect, causing
    it to fly off exponentially — fixed by snapshotting the rect once at
    drag-start and always computing from `start + translation`. Also fixed
    a blank/bugged "Re-crop" sheet on existing clues: `populateFieldsIfNeeded()`
    was loading `selectedImageData` from `clue.imageData` but never
    backfilling `pendingOriginalImageData` (the crop sheet's required
    source image), so the sheet's `if let` silently rendered nothing.

8. ✅ **Special-clue announcements** — standard clues can now be marked as
   **Daily Double** or **Multiple People** in `ClueFormView`; opening them
   shows a dedicated announcement screen before the clue. Final Jeopardy
   uses the same flow. These flags are retained by board export/import
   (format version 2; version 1 imports remain supported).
9. ✅ **Multiline question and answer editing** — the clue form now uses
   `TextEditor` controls, so Return inserts as many line breaks as needed
   for lists, multiple-choice options, and formatted answers.
10. ✅ **5 × 5 dummy board** — Reset Board now asks whether to clear the
   board or replace it with five sample categories containing five clues
   each ($200 through $1000). Both choices replace the existing board.

Everything from the "Current to-do-list" in the original request:

1. ✅ **Opened-state indicator on clue cards** — `ClueCardView` reads
   `clue.isOpened`, dims the tile, strikes through the price, shows a
   checkmark. Set to `true` on tap (`BoardGridView`) and on opening Final
   Jeopardy.
2. ✅ **Short video support in clue cards** — attach via `ClueFormView`
   ("Attach Video"), stored via `MediaStore`, played inline with AVKit's
   `VideoPlayer` (`VideoClueView`), which has built-in scrub/play/pause.
3. ✅ **Audio player: seek, pause, stop, finished indicator** — full rewrite
   in `ClueCard.swift`: `AudioPlayerController` (AVAudioPlayerDelegate-backed)
   + `AudioPlayerView` with a `Slider` scrubber, separate Pause vs Stop
   buttons, and a "Finished" status label that appears via the delegate
   callback when playback completes.
4. ✅ **Optional Final Jeopardy card** — `FinalJeopardySectionView`, shown
   below `BoardGridView` inside `ContentView`. Just a slim prompt row when
   unset; a clickable summary card once set.
5. ✅ **Save/reuse the board** — `BoardStorage` + toolbar "Save Board" /
   "Load Board" buttons (macOS-only, `#if os(macOS)`), using
   `NSSavePanel`/`NSOpenPanel`. Load confirms via `.confirmationDialog`
   before wiping the current board.
6. ✅ **Edit existing clues + rename categories** — `ClueFormView` now
   handles `.add`, `.edit(Clue)`, and `.finalJeopardy(Clue?)` in one form,
   reachable via right-click on a card ("Edit Clue") or a pencil button
   inside `ClueDetailView`. Save is disabled unless category/question/answer
   are non-empty and points > 0 (see `ClueFormView.isValid`).
   Category rename is separate — pencil icon on `CategoryHeader` — since
   editing one clue's category field shouldn't silently rename the whole
   category (it should just move that one clue to a different category).
7. ✅ **Custom point values** — `ClueFormView`'s Points picker has the
   original 200/400/600/800/1000 plus a "Custom…" option that reveals a
   free-text amount field.
8. ✅ **Category rules info button** — the (i) icon on `CategoryHeader`
   opens a popover showing `CategoryInfo.rulesText`, with an "Edit Rules"
   toggle to edit inline, and the placeholder text "No rules setup for this
   currently" when empty.

## Known limitations / things to revisit

- Orphaned `CategoryInfo` rows aren't cleaned up when a category's last
  clue is deleted or renamed away (see Data model decisions above). Cosmetic
  only — just means `BoardStorage` exports might include unused category
  rows.
- If a clue's video is swapped out or removed via `ClueFormView`'s Cancel
  button *right after* a fresh import, the newly-copied file is cleaned up
  from disk — but there's no periodic sweep for truly orphaned video files
  (e.g. if the app quits mid-edit). Not expected to matter much in practice.
- No automated tests / no way to compile-check in this sandbox (no Xcode
  toolchain here) — everything was written and reviewed by hand. Build in
  Xcode first before relying on it.
- `NSColor`/`NSImage` usage (in `ContentView`, `ClueMediaView`) is
  macOS-only and un-guarded, same as the original codebase. Fine for now
  since this is explicitly the macOS Host app, but will need `#if os(macOS)`
  treatment (or a cross-platform image/color abstraction) if this codebase
  is ever extended to also build for iOS/iPadOS, rather than iOS being a
  fully separate companion app.
- Had an error where I couldn't attach any other medias other than Video.
  Solved this by attaching each .fileImporter directly to its own specific
  HStack, rather than grouping them all at the end of the Section.
- Had an error where NSSaveFile couldn't properly save nor load the board.
  Fixed by going to Project's Signing & Capabilities, changing User Selected
  Files to Read/Write, not just Read-only
- Drag & drop and paste are macOS-only for now (`NSItemProvider` drop
  works cross-platform in principle, but the paste buttons use `AppKit`'s
  `NSPasteboard` directly and are wrapped in `#if os(macOS)`). Consistent
  with the rest of the app being macOS-only per the header above, but
  will need a `UIPasteboard` equivalent if this ever needs to run on
  iOS/iPadOS outside the planned separate companion app.
- `ImageCropView` is free-form aspect ratio only — no rotation, no locked
  aspect ratio (e.g. matching the 16:9/9:16 handling `VideoClueView`
  already does for video). Fine for now; revisit if inconsistent crop
  shapes across clues become a visual problem on the board.

## Backlog (from the "Future implementations" section — iOS companion)

Not started. Listed here so priorities aren't lost:

- iPhone/iPad companion app that connects to the Mac host (likely
  Multipeer Connectivity or a local network protocol) and acts as a player
  device.
- Digital buzzer on the companion app, replacing third-party buzzer sites/apps.
- Player auto-registration from the companion app, instead of the Host
  manually adding/removing players via `BottomPlayerBar`'s + button.
- Player team-ups (grouping multiple companion devices into one team/score).
- Text-based answer submission from companion devices for clues that call
  for a written response instead of a buzz-in.

None of the current codebase assumes networking yet — `Players` is a plain
local SwiftData model with no device/session concept, so this will need
real design work (likely a new `Services/Connectivity/` layer plus rethinking
how `Players` maps to a physical device) rather than being a small add-on.
