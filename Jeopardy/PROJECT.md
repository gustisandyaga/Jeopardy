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
  Theme/
    JeopardyColors.swift      — centralized 60-30-10 palette constants +
                                 Color(hex:) extension (see "Color Theme"
                                 addendum below)
  Models/
    Clue.swift                — the core @Model: one question/answer card
    CategoryInfo.swift        — per-category metadata (currently just rules text)
    Players.swift             — a player's name + score
    BoardGridDensity.swift    — accessibility preference for board spacing
                                 (Comfortable vs. Tight — see "Hermann Grid
                                 Mitigation" addendum below)
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

# Addendum: GimmickSystem + Multiple Choice

(Append this section to `Jeopardy/PROJECT.md` under "What was implemented".)

## New files

```
Models/
  GimmickType.swift          — enum of power-ups (phoneAFriend, fiftyFifty):
                                icon, title, tooltip description, tint color
Views/Gimmicks/
  GimmickBadgeView.swift     — one small icon; .onHover shows a popover with
                                what it does; dims + disables once used
  GimmickBar.swift           — row of badges for one player; owns activation
                                logic (phone-a-friend is cosmetic-only; 50:50
                                eliminates two wrong multiple-choice options
                                on the active Clue)
```

## Data model changes

- **`Players.usedGimmicks: [String]`** — raw values of `GimmickType` this
  player has already used this game. Plain `[String]` rather than an enum
  array so SwiftData persists it without extra Codable ceremony, and adding
  a new `GimmickType` case never requires a migration. Helpers:
  `hasUsed(_:)`, `markUsed(_:)`, `markUnused(_:)`, `resetGimmicks()`.
  "Reset All Scores" in `BottomPlayerBar` now also calls `resetGimmicks()`
  on every player (confirmation text updated to mention this); there's also
  a per-player "Reset Power-ups" context menu item.
- **`Clue`** gained four stored properties:
  - `isMultipleChoice: Bool`
  - `choiceOptions: [String]` (2–4 options, authored in `ClueFormView`)
  - `correctChoiceIndex: Int`
  - `eliminatedChoiceIndices: [Int]` — which options are currently crossed
    out. This is playthrough state, same category as `isOpened`: it's reset
    to `[]` every time the clue is saved from `ClueFormView` (since editing
    options can shift indices), and it isn't reset just from opening the
    board — it persists until the Host edits that clue again.

## Gameplay flow

- `ClueFormView` has a new "Multiple Choice (Optional)" section: a toggle
  plus 4 text fields (A–D) and a "Correct Answer" picker scoped to whichever
  slots are filled in. `buildChoiceOptions()` filters out blank slots and
  remaps the correct index into the filtered list on save — so a host can
  leave slots C/D empty for a 2-option "true/false"-style clue.
- `ClueDetailView` renders `MultipleChoiceOptionsView` (in `ClueCard.swift`)
  under the question when `clue.isMultipleChoice`. Before reveal, tapping a
  wrong option crosses it out in place (meant for "a player guessed this
  and got it wrong" — the Host taps whatever the player said out loud);
  tapping the *correct* option calls the same `revealAnswer()` used by the
  "Reveal Answer" button. After reveal, the correct row turns green with a
  checkmark; everything else stays struck-through/dimmed as it was.
- `GimmickBar` (embedded in `PlayerView`, which now also takes
  `activeClue: Clue?` threaded down from `BottomPlayerBar`/`ContentView`)
  is what actually calls into the gimmick logic:
  - **Phone-a-Friend** is intentionally inert — the actual call happens off
    the app; tapping just flips it to "used" so the Host has something to
    point at when a player invokes it.
  - **50:50** is only enabled while there's an active, multiple-choice,
    not-yet-opened clue with at least one un-eliminated wrong option. On
    tap it eliminates up to two wrong indices at random (shuffled subset of
    `remainingWrongIndices`), leaving the correct answer plus at most one
    wrong option — same mechanism a manual host-tap uses, just applied by
    the gimmick instead of a player's spoken guess.

## Board export/import

`BoardStorage`'s `ClueExport` gained `isMultipleChoice`, `choiceOptions`,
`correctChoiceIndex`, and `eliminatedChoiceIndices`, all decoded with
`decodeIfPresent` + safe defaults so **older exported boards (format
version 1–2) still import fine** — they just come back in with multiple
choice off. Bumped `formatVersion` to 3 on new exports (informational only;
nothing currently branches on it, same as before).

Deliberately **not** touched: `Players`/`usedGimmicks` is not part of board
export, matching the existing decision that board files save trivia
content, not a session's roster/scores/state.

## Known follow-ups / not done here

- "50:50" currently always targets the single active clue, not a specific
  opposing player's guess — there's no concept yet of a gimmick "targeting"
  another player (e.g. a wager-reduction trap), which was mentioned as a
  possible future gimmick. `GimmickType` is structured so adding a new case
  plus its own branch in `GimmickBar.activate(_:)` is the only work needed;
  a "target another player" gimmick would additionally need a small picker
  UI to choose who it applies to.
- No enforced limit on how many multiple-choice clues exist per board —
  same "no server-side validation, Host is trusted" posture as the rest of
  the app.
- Elimination via tapping a wrong option in `MultipleChoiceOptionsView` is
  toggle-based (tap again to un-strike), in case the Host taps the wrong
  row by mistake; 50:50's eliminations are not currently reversible from
  the UI (would need to manually clear `eliminatedChoiceIndices` via the
  option rows, which stay enabled/tappable for that purpose as long as
  the answer hasn't been revealed yet).

--- Known limitations section ---
  (no change needed — this was never previously documented as a known
  limitation, since it was an undiscovered layout bug rather than a
  deliberate tradeoff)

--- What was implemented (append at end) ---

13. ✅ **Fixed BottomPlayerBar height mismatch overlapping Final Jeopardy
    row** — `ContentView` pinned `BottomPlayerBar` to a hardcoded
    `.frame(height: 220/180)`, but `PlayerView`'s actual content (Players
    header row + gimmick badges + wager controls during Final Jeopardy)
    needed roughly 270/230pt to render without clipping. Since SwiftUI
    doesn't clip content that's taller than a `.frame(height:)` constraint,
    the excess bled upward and visually overlapped the "FINAL JEOPARDY"
    section above it. Fixed by removing the hardcoded frame from
    `ContentView` entirely — `BottomPlayerBar`'s own `VStack` already sizes
    itself correctly from its children (the header row's natural height +
    the `GeometryReader` row's explicit `170/210`pt height), so there's no
    longer a second, independently-drifting number to keep in sync.

14. ✅ **Empty-board state with icon-tile entry points** — `BoardGridView`
    now checks `categories.isEmpty` and, when true, renders a new
    `EmptyBoardStateView` (`Views/EmptyBoardStateView.swift`) instead of a
    blank grid. It shows three large tiles — "5 × 5 Sample Board",
    "Import Board" (macOS only), and "Add a Clue" — each wired straight to
    the *existing* logic (`ContentView.createDummyBoard()`,
    `BoardStorage.importBoard`, and the Add Clue sheet) via closures passed
    into `BoardGridView`'s init. No new board-building logic was added;
    this only surfaces actions that previously lived solely in the toolbar.
    Motivated by two heuristics from the usability pass this session:
    - *Recognition rather than recall* (Nielsen) — the Host no longer has
      to remember that the toolbar's `+`/import/trash icons are "how you
      get started"; the empty grid itself now names the next step.
    - *Law of common region* (Gestalt) — the three tiles sit in one
      centered group so they read as "here's how to set up your board"
      rather than three unrelated buttons.
    Deliberately gave each tile its own accent color/icon rather than
    identical styling — full Gestalt-style uniformity across all three
    was judged to flatten their individual affordance/monotonize the row,
    so a little visual variety was kept intentionally.
    `onImportBoard` is `nil` on non-macOS builds (mirrors the toolbar's
    existing `#if os(macOS)` guard around Load Board), and
    `EmptyBoardStateView` simply omits that tile when it's `nil`.

## Known limitations / things to revisit (addendum)

- `EmptyBoardStateView` only triggers off `categories.isEmpty`, which is
  true whenever there are zero non-Final-Jeopardy clues — it does NOT
  check whether a Final Jeopardy clue exists on its own. Practically this
  matches "board is empty" as the Host would think of it (an
  FJ-only board with no categories still isn't really playable from the
  main grid), but worth noting if that ever needs to change.
- Tile styling (`EmptyStateTile`) uses `NSColor.controlBackgroundColor`
  and SwiftUI's `.gradient` modifier on `Color`, both macOS-only /
  fairly new APIs — consistent with the rest of this codebase's current
  macOS-only, un-guarded `NSColor` usage (see existing note above), but
  will need adjustment if/when this view needs to run cross-platform.

15. ✅ **Category header reflects completion state** — `CategoryHeader`
    now takes an `isCompleted: Bool` param; `BoardGridView` computes it per
    category via `isCategoryCompleted(_:)` (true when the category has at
    least one clue and every clue in it has `isOpened == true`) and passes
    it down alongside `title`. Previously a category with every clue
    answered still showed the same solid blue tile as an untouched one —
    the Host had to visually scan all five clue tiles in a column to infer
    "this category is done," even though the app already had that fact.
    Motivated by *visibility of system status* (Nielsen #1): surface a fact
    the system already knows rather than leaving the Host to infer it.
    Deliberately used a DIFFERENT grey from `ClueCardView`'s own
    answered-tile grey (`Color.gray.opacity(0.55)`) rather than the same
    value — `CategoryHeader` now uses `Color(red: 0.30, green: 0.33, blue:
    0.38).opacity(0.85)`, a cooler/darker slate. Both are legible as "done"
    (same grey family, same *meaning*), but a category header and a clue
    tile represent different kinds of information (an aggregate of several
    clues' state vs. one clue's own state), so this was a deliberate
    partial break from strict visual consistency (Nielsen #4) rather than
    an oversight — full pixel-identical styling was judged to blur that
    distinction rather than clarify it. See file-header comment in
    `CategoryHeader.swift` for the same reasoning in-code.
    The rename (pencil) and rules (info) buttons remain active regardless
    of completion state — a finished category can still be renamed or have
    its rules edited.

## Known limitations / things to revisit (addendum)

- `isCategoryCompleted` is recomputed on every `BoardGridView` body
  evaluation by filtering `clues` per category (O(categories × clues)).
  Fine at current board sizes (a handful of categories × 5 clues each);
  would be worth caching/memoizing if boards ever grow much larger.

# Addendum: Color Theme (60-30-10 Palette)

The original clue card color combo (`Color.blue` #0088FF background with
`.yellow` #FFCC00 text) scored a **2.33:1** contrast ratio on Coolors'
Contrast Checker — well below WCAG's 3:1 minimum for large text, let alone
the 4.5:1 minimum for normal text. This addendum documents the replacement
palette, the reasoning behind each color, and exactly what changed.

## New file

```
Theme/
  JeopardyColors.swift    — Color(hex:) extension + four named palette
                             constants, so every other view references
                             .jeopardyCard / .jeopardyBackground /
                             .jeopardyAccent / .jeopardyFinal instead of
                             raw Color.blue/.yellow or hex literals
```

## The palette (60-30-10 rule)

Colors were chosen by cross-referencing color psychology against the
app's actual roles (clue cards = "knowledge," background = "canvas,"
Final Jeopardy = "special occasion"), then validated for both meaning
*and* contrast — not picked for looks alone.

| Constant | Hex | Role | % | Why |
|---|---|---|---|---|
| `.jeopardyBackground` | `#F7F5F0` (Parchment) | Board grid backdrop | 60% | "Subtle, timeless" — a neutral canvas the cards read clearly against |
| `.jeopardyCard` | `#002147` (Oxford Blue) | Standard clue cards, active category headers | 30% | Named directly for the University of Oxford — a direct "knowledge/academia" association, stronger fit than a generic navy, and it happens to also produce better contrast numbers |
| `.jeopardyAccent` | `#E8B923` (Saffron) | Point values, small highlights only | 10% | "Sparks inspiration wherever it appears" — used sparingly, not as a large fill, since brighter golds ("radiant, catching every eye") were judged too overpowering at scale |
| `.jeopardyFinal` | `#4B2E83` (Indigo Velvet) | Final Jeopardy announcement only | reserved | "Rich with mystery, dazzling" — deliberately held back from everyday use so Final Jeopardy reads as a distinct occasion rather than another blue card |

**Contrast measurements** (WCAG relative luminance, same method that
produced the 2.33:1 figure above):

| Pair | Ratio | WCAG level |
|---|---|---|
| Saffron text on Oxford Blue card | 8.71:1 | AAA |
| White text on Oxford Blue card | 16.05:1 | AAA |
| White text on Indigo Velvet (Final Jeopardy) | 10.41:1 | AAA |
| Dark text on Parchment background | ~15:1+ | AAA |

Gold `#FFD700` was considered and dropped in favor of Saffron for the
accent role — same "bright, energetic" psychology, but Gold's own
description ("radiant, catching every eye") was judged too strong for
something that needed to stay a 10%-scale detail rather than compete with
the cards themselves.

## Files changed

- **`ClueCard.swift`** (`ClueCardView`) — card background `Color.blue` →
  `.jeopardyCard`; unopened point-value text `.yellow` → `.jeopardyAccent`.
  The opened/answered grey state is untouched — it's a state indicator,
  not a theme color, same reasoning as `CategoryHeader`'s existing
  completed-state grey.
- **`CategoryHeader.swift`** — active-state tile background
  `Color.blue.opacity(0.8)` → `.jeopardyCard` (full opacity — Oxford Blue
  is dark enough on its own, unlike the original bright blue). The
  completed-state slate grey is untouched, preserving the existing
  deliberate distinction documented in that file.
- **`BoardGridView.swift`** — grid background `Color.black.opacity(0.05)`
  → `.jeopardyBackground` (Parchment). Scoped to just this view.
- **`AnnouncementKind.swift`** — `.finalJeopardy`'s tint `.yellow` →
  `.jeopardyFinal` (Indigo Velvet), so the Final Jeopardy announcement
  screen is now visually distinct from Daily Double/Multiple People
  rather than sharing a generic accent color.

## Deliberately NOT touched (Parchment scope decision)

Parchment (`.jeopardyBackground`) is scoped to **`BoardGridView` only**.
`ContentView`'s outer window/`BottomPlayerBar` and `ClueDetailView` keep
their existing `Color(NSColor.windowBackgroundColor)` / default system
background, so the rest of the app continues to respect macOS light/dark
mode. Revisit if a fully-themed (non-adaptive) look is wanted later.

## Backlog — not restyled this pass

- **Daily Double** (`.orange`) and **Multiple People** (`.mint`) tints in
  `AnnouncementKind` were intentionally left as-is. They weren't part of
  the original color-psychology analysis that drove this palette, and
  restyling them wasn't a priority for this pass — worth a follow-up look
  so all three announcement kinds share one consistent design language
  rather than only Final Jeopardy being deliberately chosen.
- Revealed-answer text (`ClueDetailView`, `.green`) and the gimmick badge
  tints (`GimmickType.tint` — green for Phone-a-Friend, purple for 50:50)
  are also untouched. `GimmickType.fiftyFifty`'s existing `.purple` is
  worth a look later — it may already be close in spirit to
  `.jeopardyFinal` and could be worth aligning intentionally instead of
  coincidentally.

# Addendum: Hermann Grid Mitigation

After the palette change above, the board started showing a Hermann grid
illusion (phantom grey blobs at the intersections between clue cards) —
reported as adding real cognitive load while playing. This addendum
documents the cause and the fix.

## Why it was happening

The illusion needs three ingredients, and the board (post-palette-change)
had all three:

1. **A regular grid** — `BoardGridView` lays out clue cards at fixed
   200×120 sizes with uniform 20pt column / 15pt row spacing. A textbook
   repeating lattice.
2. **Flat, uniform luminance fields on both sides of each edge** — Oxford
   Blue cards (very dark) directly against Parchment (very light), both
   flat single-color fills.
3. **Hard, high-contrast, right-angle edges** — cards had only an 8pt
   corner radius, so intersections were close to a sharp 90° cross, which
   is the specific junction geometry the illusion depends on (retinal
   ganglion cells' center-surround receptive fields get fully inhibited
   only where the surround is entirely dark, i.e. at a crossing).

**Specific to this codebase, not just illusion theory in general:** every
`ClueCardView` also had `.shadow(radius: 5)` (a symmetric, ~33%-opacity
black spread on all sides). At every grid intersection, the shadows from
diagonally-adjacent cards were overlapping directly on top of each other —
*real*, additive darkening layered exactly where the illusion also
produces a phantom one, which is very likely why it read as unusually
strong rather than being a subtle, ignorable effect.

## Why the commonly-suggested fixes weren't used

- **Wavy grid lines** — breaks the illusion by breaking alignment, but
  Jeopardy specifically relies on that alignment: a Host or player scanning
  "all the $600 clues across categories" needs them to line up in a
  straight row. This is Nielsen's *recognition rather than recall* doing
  real work, not just a decorative grid — worth preserving.
- **Shrinking the grid** — board size is driven by however many
  categories/clues a Host builds; there's no fixed "grid size" to shrink
  without constraining what a Host can create.

## What was changed instead (`ClueCardView` in `ClueCard.swift`)

1. **`cornerRadius` 8 → 16.** Disrupts the sharp right-angle junction
   geometry at each intersection without touching row/column alignment.
2. **Shadow softened and made directional** — `.shadow(radius: 5)` →
   `.shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)`. Lower
   opacity plus a downward offset (instead of an even spread) means far
   less shadow reaches into the gap on every side, so adjacent cards'
   shadows no longer pile up at the corners.
3. **Flat fill → subtle gradient.** Added `.jeopardyCardHighlight`
   (`#123C69`, a slightly lighter navy) to `JeopardyColors.swift`, used
   only as the gradient's top-left stop (`.jeopardyCardHighlight` →
   `.jeopardyCard`, top-leading to bottom-trailing) via a new `cardFill`
   computed property. The gradient is subtle enough not to read as an
   intentional visual choice — its only purpose is to avoid a perfectly
   flat luminance field on the dark side of each edge, since flat fields
   on both sides of a hard boundary is what maximizes the retinal
   response driving the illusion. The opened/answered state got the same
   gradient treatment (`Color.gray.opacity(0.50)` → `0.60`) for
   consistency, since it sits in the same grid.

## Deliberately not changed

- **`CategoryHeader.swift`** — left with its original (sharper) corner
  radius/flat fill for now. It only forms one row along the top of the
  grid rather than sitting at four-way intersections the way clue cards
  do, so it wasn't the priority; revisit if the header row turns out to
  still show the effect once the cards below it are fixed.
- **Column/row spacing** — left at 20pt/15pt. Widening the "streets"
  between cards further would weaken the illusion too, but costs board
  density, and was treated as a lower-priority lever behind the three
  changes above (which cost no layout space).

## Follow-up: still noticeable after the first round

The corner-radius/shadow/gradient changes above address *secondary*
factors — junction geometry, real shadow-overlap darkening, and complete
fill flatness — but the effect was still clearly noticeable afterward.
That's a useful signal: the dominant cause is simpler and blunter than any
of those refinements — raw luminance contrast (~16:1) between the cards
and background, meeting at a genuinely hard edge, repeated at regular
intervals. Rounding a corner or adding a subtle gradient doesn't change
that underlying step.

There are two levers that act on that root cause directly, rather than
refining around it:

- **Widen the gaps** between cards — the illusion's strength depends on
  gap width relative to a retinal ganglion cell's receptive-field size, so
  widening it enough moves the intersections out of the range that
  triggers strong inhibition. Costs board density.
- **Blur the edge itself** — rather than a hard, single-pixel-sharp
  transition from card to background, render a soft ramp over a few
  points. This is the actual mechanism behind why a blurred rendering
  (World of Jeopardy, from the original reference comparison) showed a
  much fainter version of the illusion than a crisp one.

**Blur was chosen first** (density-neutral, cheaper to test). Implemented
by restructuring `ClueCardView.body` into a `ZStack`:

- A `RoundedRectangle` filled with the same `cardFill` gradient, blurred
  (`radius: 10`) and set to 60% opacity, sits behind everything. Blur
  renders the filled shape's color bleeding beyond its own original edges
  — that's what produces the soft ramp into the surrounding gap, rather
  than clipping at the shape boundary.
- The existing sharp, fully-opaque card (now `cardContent`, unchanged
  internally) sits on top at the same frame size, so the interior and all
  text stay perfectly crisp — only the halo bleeding out past that top
  layer's edges is soft.

If this alone isn't sufficient, the next step in line is widening
column/row spacing (`BoardGridView`'s `columnSpacing`/`VStack` spacing),
previously deferred specifically because of its board-density cost.

## Follow-up: CategoryHeader brought in line, plus an accessibility layout option

The blur/gradient/corner-radius treatment above was originally applied to
`ClueCardView` only — `CategoryHeader` was deliberately left with its
original flat fill and 8pt radius, on the reasoning that it only forms one
row along the top rather than sitting at four-way intersections. Once the
blur halo proved effective, that reasoning no longer mattered enough to
leave it inconsistent, so `CategoryHeader` now uses the same treatment:
a `headerFill` gradient (`.jeopardyCardHighlight` → `.jeopardyCard` for
the active state; the existing completed-state slate grey as a two-stop
gradient instead of flat), the same blurred-halo `ZStack` structure, and
the same density-driven corner radius. The completed/active state
*distinction* itself (documented at length in this file's original "Color
Theme" addendum and in `CategoryHeader.swift`'s header comment) is
untouched — only the flat-vs-gradient/hard-vs-soft-edge treatment changed.

### New: `BoardGridDensity` — an accessibility layout preference

Not everyone is affected by the Hermann grid illusion the same way, and
"subtle blur" isn't the only valid answer to it — a genuinely gapless
layout (as seen in one of the reference boards compared against, Heralen's
very tightly-packed grid) sidesteps the illusion entirely by removing the
regular "streets" it depends on, at the cost of a denser, more solid-
looking board. Rather than picking one aesthetic for everyone, this is now
a user-facing toggle.

**New file:** `Models/BoardGridDensity.swift` — a `String`-backed enum
with two cases:

- **`.comfortable`** (default) — the moderate-spacing, blurred-edge look
  from the sections above. `columnSpacing: 20`, `rowSpacing: 15`,
  `cardCornerRadius: 16`, `usesSoftEdge: true`.
- **`.tight`** — Heralen-style near-zero gaps. `columnSpacing: 3`,
  `rowSpacing: 3`, `cardCornerRadius: 6`, `usesSoftEdge: false` (the blur
  halo is skipped entirely — with cards nearly touching, a blurred halo
  would just muddy adjacent cards together rather than help; the near-zero
  gap is already what defeats the illusion in this mode).

Persisted via `@AppStorage(BoardGridDensity.storageKey)`, so the choice is
remembered across launches. `BoardGridView`, `ClueCardView`, and
`CategoryHeader` each read it directly (rather than threading a `Binding`
down through every initializer) — all three already read from the
environment/`@AppStorage` for other things, so this keeps the wiring
consistent with the existing pattern rather than introducing a new one
just for this preference.

**UI:** `ContentView`'s toolbar gained a "Board Layout" menu (between Load
Board and Reset Board) — a `Picker` bound to the same `@AppStorage` key,
so switching it live immediately re-lays-out `BoardGridView` and restyles
every `ClueCardView`/`CategoryHeader` without needing a relaunch.

### Known follow-ups

- Tight mode's smaller corner radius/no-halo styling was chosen to *look*
  intentional rather than like a bug, but hasn't been visually compared
  side-by-side against Heralen's actual reference board — worth a look to
  confirm it reads the way that reference did.
- No onboarding/first-run prompt surfaces this preference; a Host has to
  discover the toolbar menu themselves. Consider surfacing it once,
  contextually, if the Hermann grid issue turns out to affect a
  meaningful number of people rather than being this one report.

## Follow-up: fixed a real bug in CategoryHeader's halo sizing

After building the above, Comfortable density showed a large, oversized
grey-blue blur block sitting behind every category header — clearly wrong,
not just an aesthetic judgment call.

**Cause:** `ClueCardView`'s outer `ZStack` (halo + card) has
`.frame(maxWidth: .infinity, minHeight: 120)` applied directly to it, so
the blurred `RoundedRectangle` inside is bounded to that size before
blurring. `CategoryHeader`'s equivalent inner `ZStack` (halo + `Text`) had
**no frame of its own** — only the `Text` set `.frame(height: 60)` on
itself, internally. With nothing constraining the `RoundedRectangle`
directly, SwiftUI proposed it whatever height was available in that
column, which in the header row (no vertical `ScrollView` constraint at
that point in the layout) is effectively unbounded — so it stretched into
a large block instead of a 60pt-tall pill.

**Fix:** added `.frame(maxWidth: .infinity).frame(height: 60)` to the
inner `ZStack` itself, mirroring exactly what `ClueCardView` already does
— bounding the whole halo+content group to the pill's actual size before
the blur is applied, rather than relying on an inner child's own frame to
constrain everything around it.
