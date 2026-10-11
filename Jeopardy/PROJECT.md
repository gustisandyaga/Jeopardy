# Jeopardy (macOS Host App) — Project Notes

Read this first if you're picking this project back up (human or Claude).

**Last major change:** Accessibility pass — contrast tokens, a second board
theme ("Broadcast"), hover/VoiceOver tile actions, Reactivate All, Reduce
Motion, VoiceOver labels, delete confirmations. See CLAUDE.md for the rules
and §2/§4 for where things live.

## 1. Overview

A SwiftUI + SwiftData macOS app that replicates a Jeopardy-style board game,
run by a single "Host" on a Mac. The Host builds/loads a board of categories
and clues, players buzz in verbally/off-app, and the Host manually reveals
answers and adjusts scores.

**Scope boundary:** everything in this repo is the macOS host app only. A
future iOS companion app (buzzer, player auto-registration, team-ups, text
answers) is planned but **not started** — see §7 Backlog.

Xcode project uses a `PBXFileSystemSynchronizedRootGroup`: any file dropped
into `Jeopardy/Jeopardy/` is auto-picked-up by Xcode. You never need to
hand-edit `project.pbxproj` to add a new Swift file.

## 2. Architecture map

```
Jeopardy/
  JeopardyApp.swift          — @main, registers SwiftData models
  Theme/
    JeopardyColors.swift      — palette, semantic text/state tokens (measured),
                                 Color(hex:) and Color.adaptive(light:dark:)
    Motion.swift              — Reduce Motion helpers (withMotionPreference)
  Models/
    Clue.swift                — core @Model: one question/answer card
    CategoryInfo.swift        — per-category metadata (rules text only)
    Players.swift             — a player's name, score, gimmicks used
    GimmickType.swift          — enum of power-ups (phoneAFriend, fiftyFifty)
    BoardGridDensity.swift    — accessibility pref for board spacing
    BoardTheme.swift          — accessibility pref for board backdrop
                                 (Parchment / Broadcast) and everything that
                                 varies with it
    ClueDraft.swift            — value-type mirror of Clue's editable fields,
                                 used only by the editor (see §3)
  Services/
    MediaStore.swift          — copies imported video into Application
                                 Support so files survive sandbox/relaunch
    BoardStorage.swift        — export/import the whole board to/from one
                                 portable .json (NSSavePanel/NSOpenPanel,
                                 macOS-only)
  Views/
    ContentView.swift         — top-level layout: board + Final Jeopardy +
                                 player bar + toolbar
    BoardGridView.swift       — scrollable grid of categories × clue cards
    CategoryHeader.swift      — category tile: rename + rules popups
    EmptyBoardStateView.swift — entry-point tiles shown when board is empty
    PlayerView.swift          — one player chip + BottomPlayerBar
    SoundManager.swift        — plays "reveal_ding.mp3" from the bundle
    ClueCard/
      ClueCardView.swift        — the board tile's visuals only (points,
                                 opened state, theme outline)
      ClueTileView.swift        — interactive tile: NavigationLink + context
                                 menu + hover "⋯" menu + VoiceOver actions +
                                 delete confirmation
      ClueDetailView.swift      — the detail/edit screen: announcement ->
                                 question/media/multiple-choice -> reveal,
                                 plus the inline-edit swap
      Media/
        ClueMediaView.swift      — media-type dispatcher (image/video/
                                 audio, at most one per clue) +
                                 ExpandingClueImageView
      MultipleChoice/
        MultipleChoiceOptionsView.swift — tappable-options gameplay view
      Helpers/ImageCropView.swift, ChoiceLetter.swift
                                — ChoiceLetter stays here (not under
                                 MultipleChoice/) since ClueEditorView also
                                 depends on it
      Audio/, Video/, Lightbox/, Announcement/
      Edit/
        ClueEditorView.swift    — layout shell: adaptive 2-column split,
                                 status banner, toolbar, undo/save/cancel,
                                 General Info / Clue Type / Question&Answer
                                 sections
        SectionContainer.swift  — shared "title + help text + tinted
                                 background" wrapper used by every section
        MediaAttachmentSection.swift — file picker, drag & drop, paste,
                                 crop-sheet trigger (binds only to
                                 draft.media / draft.answerImageData)
        MultipleChoiceEditSection.swift — the "Multiple Choice (Optional)"
                                 toggle + option fields + correct-answer
                                 picker
        AddClueScreen.swift     — pushed screen, new-clue path only
    Gimmicks/
      GimmickBar.swift, GimmickBadgeView.swift
```

## 3. Key data-model decisions

Only the non-obvious rules that would cause a bug if violated:

- **Category is a `String` on `Clue`, not a relation.** `CategoryInfo` is a
  sidecar table keyed by that same string (rules text only). Renaming a
  category (`CategoryHeader.renameCategory()`) must cascade-update every
  matching `Clue.category` *and* rename/merge the matching `CategoryInfo`
  row. Orphaned `CategoryInfo` rows aren't cleaned up automatically — see §6.
- **Video ≠ image/audio storage.** `Clue.videoFileName: String?` stores only
  a filename; bytes live in `~/Library/Application Support/Jeopardy/Videos/`
  via `MediaStore` (a raw security-scoped URL wouldn't survive past the
  file-picker session in a sandboxed app). Image/audio are stored directly
  as `Data` via `@Attribute(.externalStorage)`.
- **Playthrough state vs. persistent content**, both on `Clue`:
  - `isOpened`, `eliminatedChoiceIndices`, `fiftyFiftyUsed` = playthrough
    state. Reset by editing that clue's options, or by "Reactivate Clue,"
    but **not** by "Reset All Scores" (that only touches `Players`).
  - `category`/`question`/`answer`/`choiceOptions` etc. = persistent content.
- **Final Jeopardy wagers live on `Players`, not `Clue`** —
  `finalJeopardyWager` + `finalJeopardyResult` (`unresolved`/`correct`/
  `incorrect`) — so resolving one player never double-applies a result.
- **`ClueDraft` is a plain value type**, not `@State` scattered across ~15
  variables. `ClueEditorView` operates only on a `ClueDraft` binding, never
  a live `Clue`/`ModelContext`, so undo/discard reduces to `draft != snapshot`
  and nothing writes to SwiftData until the Host explicitly saves.
  `MediaAttachment` (`.none/.image/.audio/.video`) makes "at most one
  medium" a type-level invariant instead of a convention.
- **Board export (`BoardStorage`) deliberately excludes `Players`** — it
  saves the *board* (trivia content), not a session's roster/scores.
  Loading a board is destructive; UI confirms before wiping the current one.

## 4. Design system reference

**Palette** (`Theme/JeopardyColors.swift`), chosen via the 60-30-10 rule and
validated for WCAG contrast. White-on-navy is 16:1; Saffron-on-navy is 8.7:1 (6.1:1 at the lighter gradient stop). Text/state colors outside the palette (correct/incorrect, gold, opened/completed fills, announcement backgrounds) are tokens in the same file, measured with WCAG + APCA — see CLAUDE.md for the table:

| Constant | Hex | Role |
|---|---|---|
| `.jeopardyBackground` | `#F7F5F0` Parchment | Board grid backdrop (60%) — scoped to `BoardGridView` only; rest of the app keeps system light/dark mode |
| `.jeopardyCard` | `#002147` Oxford Blue | Clue cards, active category headers (30%) |
| `.jeopardyCardHighlight` | `#123C69` | Gradient top-left stop only, never a standalone fill |
| `.jeopardyAccent` | `#E8B923` Saffron | Point values, small highlights only (10%) |
| `.jeopardyFinal` | `#4B2E83` Indigo Velvet | Final Jeopardy announcement only — reserved so it reads as a distinct occasion |

**Hermann grid mitigation** — the board's regular dark-card/light-background
grid triggers a Hermann-grid illusion (phantom grey blobs at intersections).
Current rule, in `BoardGridDensity.swift` + `ClueCardView`/`CategoryHeader`:
- **Comfortable** (default): 16pt corner radius, soft directional shadow,
  subtle gradient fill, and a blurred halo behind each card/header — blur
  bleeds color past the shape's edge, turning the hard boundary into a ramp.
- **Tight**: near-zero gaps (3pt spacing, 6pt radius, no halo) — removes the
  regular "streets" the illusion depends on instead of softening the edge.

**Broadcast theme** (`BoardTheme.swift`): a near-black navy backdrop drops the
card/backdrop contrast from 14.7:1 to ~1.2:1, which weakens the illusion at its
source; a 1pt lighter outline keeps cards visibly separate, and opened tiles
recede into the dark. Theme and density are independent and both live in the
toolbar's "Board Appearance" menu.

Both are valid, user-toggleable answers to the same problem — not one
"correct" fix. Wavy grid lines and shrinking the grid were considered and
rejected (they break category/point-row alignment the Host relies on, or
aren't compatible with Host-defined board size).

## 5. ⚠️ Unverified / needs confirmation in a real Xcode build

`xcodebuild` is available (see CLAUDE.md) and the project builds, but none of
the items below have been exercised in a running app or checked visually:

- **SwiftData lightweight migration** — `Clue`/`Players` picked up new
  stored properties across sessions; untested against a real existing
  `.store` file with old data. If Xcode complains on first run, delete the
  app's container (`~/Library/Containers/`) and start fresh (acceptable —
  pre-release data).
- **`.navigationBarBackButtonHidden(true)`** in `ClueEditorView` — intended
  to suppress the native back chevron on a macOS-hosted `NavigationStack`,
  but this modifier's behavior there (vs. its more established iOS/UIKit
  origin) hasn't been confirmed. Check for a duplicate/ghost back control.
- **`ViewThatFits` 700pt two-column breakpoint** in `ClueEditorView` — a
  starting guess, not measured against real window/device widths.
- **Undo granularity** — the undo stack snapshots on every `onChange(of:
  draft)`, so typing in Question/Answer pushes one snapshot per keystroke
  (character-level, not action-level). Also unverified: whether Cmd+Z is
  intercepted by `TextEditor`'s own native undo before reaching this
  handler while a text field has focus.
- **Save-validation regression check** — verify in Xcode that (a) the
  toolbar Save/Add button stays disabled with blank Q&A, (b) the discard
  dialog's "Save Changes" button is also disabled in that state, (c) no
  other call path can bypass `ClueDraft.isValid(...)`.

## 6. Known limitations

- Orphaned `CategoryInfo` rows aren't cleaned up when a category's last
  clue is deleted/renamed away (cosmetic — just unused rows in exports).
- No periodic sweep for orphaned video files if the app quits mid-edit
  (only the "Cancel right after fresh import" path cleans up).
- `NSColor`/`NSImage` usage is macOS-only and un-guarded throughout —
  fine while this is explicitly macOS-only, but needs `#if os(macOS)`
  treatment if ever extended to iOS/iPadOS directly (vs. a separate
  companion app).
- `isCategoryCompleted` in `BoardGridView` recomputes O(categories × clues)
  on every body evaluation — fine at current sizes, worth memoizing if
  boards grow much larger.
- `ImageCropView` is free-form aspect ratio only — no rotation, no locked
  aspect ratio.
- The discard-confirmation flow only intercepts the in-editor Cancel
  action, not the system's own back navigation away from `ClueDetailView`
  entirely while mid-edit.
- `EmptyBoardStateView` triggers off `categories.isEmpty` only — does not
  separately check whether a Final-Jeopardy-only clue exists.
- Announcement screens now use opaque palette-based backgrounds and measured
  icon colors, but have not been checked visually in a running app.

## 7. Backlog (iOS companion — not started)

- iPhone/iPad companion app connecting to the Mac host (likely Multipeer
  Connectivity or a local network protocol), acting as a player device.
- Digital buzzer, replacing third-party buzzer sites/apps.
- Player auto-registration from the companion app, instead of the Host
  manually adding/removing players.
- Player team-ups (grouping multiple companion devices into one score).
- Text-based answer submission from companion devices.

None of the current codebase assumes networking — `Players` is a plain
local SwiftData model with no device/session concept. This needs real
design work (a new `Services/Connectivity/` layer, rethinking how
`Players` maps to a physical device), not a small add-on.
