# CLAUDE.md — Jeopardy (macOS host app)

Solo SwiftUI + SwiftData project: a Jeopardy-style board game run by one Host
on a Mac. Read `Jeopardy/PROJECT.md` for the architecture map and data-model
rules; this file covers how to *work* here and, above all, the design rules.

## Build & verify

Xcode is installed; you can and should compile. (PROJECT.md §5 claims no
compiler is available. That is stale.)

```bash
xcodebuild -project Jeopardy.xcodeproj -scheme Jeopardy \
  -destination 'platform=macOS' -derivedDataPath <scratchpad>/dd \
  CODE_SIGNING_ALLOWED=NO build
```

- A green build is not a visual check. For anything touching color, spacing,
  or the board grid, say plainly that it was not eyeballed unless you ran the
  app and looked. Never claim an illusion is fixed from code alone.
- The project uses a `PBXFileSystemSynchronizedRootGroup`: new files under
  `Jeopardy/` are picked up automatically. Never hand-edit `project.pbxproj`.
- macOS only. `NSColor`/`NSOpenPanel` are used unguarded on purpose.
- Don't commit unless asked. `project.pbxproj` often shows Xcode-upgrade noise
  (`LastUpgradeCheck`, `DEAD_CODE_STRIPPING`); leave it out of unrelated work.

## Design philosophy (the point of this project)

This project is a deliberate exercise in applying **Nielsen's 10 usability
heuristics** and **Gestalt principles**, while meeting **WCAG 2.x** and
**APCA** color contrast. Treat those as requirements, not decoration.

- Every UI change should be justifiable under a named heuristic or principle.
  Existing code documents this in comments (e.g. "Nielsen #4 consistency",
  "Gestalt common region", "Fitts's Law", "WCAG 1.4.10 Reflow"). Keep doing
  that, but briefly: say *why* in one or two lines, not a paragraph.
- **Error prevention / user control (Nielsen #3, #5):** destructive actions get
  a confirmation; edits go through `ClueDraft` so they are undoable and
  discardable. Never write to SwiftData from the editor before an explicit Save.
- **Recognition over recall (#6):** don't hide primary actions only in context
  menus or tooltips; surface them visibly too.
- **Don't encode state in color alone (WCAG 1.4.1).** Existing good pattern:
  opened tile = checkmark + strikethrough + grey; result = text label + color.
- **Gestalt is not "make everything uniform".** Group with common region and
  proximity, but keep differentiation where it carries meaning (see the header
  comment in `EmptyBoardStateView`).
- Use the theme constants in `Theme/JeopardyColors.swift`. Don't add new raw
  `.green/.yellow/.orange/.blue` literals (there are ~35 already; see debt below).

## Color & contrast rules

Contrast is checked with **both** metrics. WCAG 2.x ratio alone is not enough
(it is polarity-blind and over-rates some dark-blue/saturated pairs). APCA Lc
is the second opinion.

| Text role | WCAG | APCA \|Lc\| |
|---|---|---|
| Body text | ≥ 4.5:1 | ≥ 75 (≥ 60 acceptable for large/bold) |
| Large text (≥ 24px, or ≥ 19px bold) | ≥ 3:1 (aim 4.5) | ≥ 60 |
| Incidental / disabled-state text | no formal floor, but keep ≥ 3:1 | ≥ 45 |
| Non-text UI boundaries (WCAG 1.4.11) | ≥ 3:1 | n/a |

Rules:

1. **Semi-transparent foregrounds must be computed after compositing.**
   `white.opacity(0.6)` on a translucent grey over parchment is *not* white on
   grey. Blend against the real backdrop first, then measure. Several current
   bugs come from skipping this.
2. **SwiftUI system colors (`.green`, `.yellow`, `.orange`, `.mint`) are tuned
   for dark and mid backgrounds and fail on white/parchment.** Don't use them
   for text in light mode. Use a defined palette color, or a darker variant.
3. **Text on a gradient: measure the worst stop**, not the average.
4. Never use `jeopardyAccent` (Saffron) as text on parchment (1.7:1) or as a
   large fill. It is for point values on navy only.
5. `jeopardyBackground` is scoped to the board grid only; the rest of the app
   follows system light/dark mode. Anything outside the grid must work in both.
6. When you change a color, **re-run the contrast math** and put the numbers in
   your reply. A small script (WCAG relative luminance + APCA 0.0.98G) is enough;
   write it in the scratchpad, not the repo.

### Measured values (palette hexes exact; system window colors approximated as #FFFFFF/#ECECEC light, #2B2B2B dark)

All of these live in `Theme/JeopardyColors.swift`. Use them instead of raw system colors.

| Role | Token | WCAG | APCA \|Lc\| |
|---|---|---|---|
| White on Oxford Blue (header/card text) | `jeopardyCard` | 16.05 | 105 |
| Saffron on Oxford Blue → on `#123C69` (points) | `jeopardyAccent` | 8.71 → 6.07 | 66 → 60 |
| Opened tile text/check, on `#C4C2BB`–`#BDBBB4` | `jeopardyOpenedText` | 6.6–7.1 | 60–64 |
| Completed header, white on `#566173`–`#4A5463` | `jeopardyCompleted*` | 6.3–7.7 | 86–91 |
| Correct (answer reveal, results) | `jeopardyCorrect` | 5.6–6.8 light, 7.9 dark | 71–83 light |
| Incorrect | `jeopardyIncorrect` | 6.2–7.3 light, 5.1 dark | 72–84 light, 45 dark |
| Gold (Daily Double label, Final star, play button) | `jeopardyGold` | 5.4–6.4 light, 10.0 dark | 70–82 light |
| Amber text (Multiple People label) | `jeopardyAmberText` | 5.5–6.5 light, 6.9 dark | 70–81 light |
| Announcement icons on navy/indigo | `color` in `AnnouncementKind` | 5.3–9.3 | 53–70 |
| "Show Clue" button, navy on Saffron | — | 8.71 | 66 |
| Empty-state tile glyph, white on tint | `jeopardyTile*` | 6.1–16 | 85–105 |

Known remaining below-target: red in dark mode is Lc 45 (fine for incidental
text, below 60 for body); white announcement title was not re-measured against
the new opaque backgrounds beyond the ≥ 10:1 figures for white on indigo/navy.
The old failures (green answer text 2.2, yellow 1.5, opened-tile text 1.5,
completed header 2.5–3.0, indigo-on-indigo icon 1.7–2.8, white on orange 2.2)
were fixed by introducing these tokens.

PROJECT.md used to claim "all pairings pass AAA, ≥ 8.7:1". That was only true for
Saffron on the darkest navy and white on navy; don't restore it.

## The Hermann grid problem (read before touching the board)

The board is a regular grid of dark cards on a light backdrop, which is the
textbook trigger for the Hermann grid illusion (grey ghost blobs at the
intersections between cards). Chasing high WCAG/APCA contrast pushes the
*wrong* way here: the illusion's strength scales with the luminance difference
between blocks and the "streets" between them, and the card/backdrop pair is at
14.7:1.

Established facts and decisions (don't re-litigate without new evidence):

- Mitigations in place: rounded corners, a soft directional shadow (low
  opacity, offset downward so adjacent shadows don't stack at corners), a
  subtle gradient fill, and a blurred halo behind each card (Comfortable
  density only). **Tight density** removes the streets entirely (3pt gaps) and
  is the strongest fix. Both are Host-toggleable on purpose.
- **Broadcast theme (shipped)** lowers the card/backdrop gap from 14.7:1 to
  ~1.2:1 — the strongest lever short of Tight density. Not yet A/B tested with
  someone who sees the illusion strongly; ask before declaring it solved.
- Rejected: wavy grid lines and shrinking the grid (break row/column alignment
  the Host relies on).
- **Text contrast and card-vs-backdrop contrast are separate requirements.**
  WCAG 1.4.11 needs ~3:1 for a boundary that identifies a component, not 14:1.
  The text *inside* the card must stay high-contrast; the *backdrop* is free to
  move closer to the card. Lowering card/backdrop contrast (a mid-tone backdrop,
  or cards and backdrop in the same hue family) is the principled lever that
  reduces the illusion without touching any text-contrast guarantee. Prefer it
  over adding more blur/shadow.
- Don't add anything with sharp 90° corners aligned to the grid; don't add
  hairline grid dividers (those create bright/dark streets, which is worse).
- Don't "fix" the illusion by making the grey ghost *real* (e.g. a visible
  fill between cards). Any change to board spacing/radius/backdrop must still
  work in both densities.

## Accessibility conventions (all in place — keep them)

- **Board theme.** Anything drawn on the board backdrop asks `BoardTheme`
  (`Models/BoardTheme.swift`): backdrop, text on it, card outline, opened-tile
  and completed-header fills. Don't hard-code `.black`/Parchment-dependent
  colors in board views. Two themes: Parchment (light) and Broadcast (near-black
  navy, ~1.2:1 against the cards, thin outline carries each card's edge).
- **Motion.** Never call `withAnimation` / `.transition(.move…)` / `.scaleEffect`
  directly for UI effects. Read `\.accessibilityReduceMotion` and use
  `withMotionPreference(reduceMotion:)` / `.slideAndFade(edge:reduceMotion:)`
  from `Theme/Motion.swift`. Reduce Motion removes movement and scaling (slides,
  springs, hover grow, zoom-reset) and keeps simple fades. Content and layout
  never change.
- **VoiceOver.** Every icon-only button gets `.accessibilityLabel` (`.help` is
  only a tooltip). Decorative icons get `.accessibilityHidden(true)`. Board
  tiles are one element ("$400, History" / value "Opened") with custom actions
  (Edit / Reactivate / Delete) because VoiceOver can't right-click or hover.
- **Tile actions are discoverable three ways**, from one shared `actionButtons`
  in `ClueTileView`: right-click, hover "⋯" menu, VoiceOver actions. The "⋯"
  menu is a SIBLING of the NavigationLink, not inside its label; putting it
  inside would let a click also open the clue and fire the link's
  simultaneous tap gesture (which sets `activeClue`/`selectedPoints`).
- **Reactivate.** `Clue.reactivate()` resets exactly the playthrough fields the
  board export saves (`isOpened`, `eliminatedChoiceIndices`, `fiftyFiftyUsed`).
  If a new playthrough field is added to `Clue`, add it there. Reactivate All
  (toolbar) never touches players/scores.

## Known debt

1. **Interaction not exercised.** Hover menu, context menu, confirmation
   dialogs, the Appearance menu and Reactivate All have been built and
   reviewed, not clicked: no UI automation is available. Verify by hand.
2. Keyboard-only users can't reach the hover "⋯" menu (it's `opacity 0` until
   hovered; VoiceOver has the custom actions instead). A focus-visible state
   would fix that.
3. The Broadcast opened tile's outline is 2.6:1 (deliberately dim, below the
   3:1 boundary guidance); the check + struck-through text carry the state.
4. Red in dark mode is Lc 45 (fine for incidental text, below 60 for body).
5. Many views still lack accessibility review beyond the controls listed
   above (e.g. the editor's text fields rely on placeholder labels).
6. The Final Jeopardy footer sits on the system window color, so under
   Broadcast it's a light strip below a dark board (clean seam, but two
   different regions).

## Verifying visuals without the screen

The user has **declined Screen Recording and System Events (Apple Events)
permissions**. Don't request them or work around them (`screencapture`,
`osascript` UI scripting). To check how something actually looks, compile the
real view files into a throwaway command-line harness in the scratchpad and
render them with SwiftUI `ImageRenderer` to PNG (use an in-memory
`ModelContainer`, set `\.colorScheme` for light/dark, then Read the PNGs). That
needs no permissions and caught three bugs the contrast math missed: a drop
shadow smearing text, a glow showing through a knocked-out "2" glyph, and
`.disabled` greying every multiple-choice row after reveal.

Caveats: `ImageRenderer` won't draw ScrollView/NavigationStack/popovers
reliably, so compose the pieces by hand. Running the unsigned build also uses
an unsandboxed store at `~/Library/Application Support/default.store`, not the
real container; back it up before launching and restore after.

## Code conventions

- Match the surrounding style: SwiftUI, `// MARK:` sections, file header
  comment explaining the file's job, comments explain *why*.
- Editor state lives in `ClueDraft` (value type); views under `Edit/` bind to it
  and never touch a live `Clue`/`ModelContext`.
- Category is a `String` on `Clue`; renaming must cascade to `CategoryInfo`
  (see PROJECT.md §3). Playthrough state vs. content state is split; don't mix.
- Gimmicks UI (`GimmickBar`) is intentionally hidden in `PlayerView`; leave it.
- Several file headers are duplicated (an auto-generated "Created by" block
  followed by a hand-written one) and some comments reference renamed files
  (`ClueFormView`, `ClueCard.swift`). Fix opportunistically, don't do a sweep.
- Update `Jeopardy/PROJECT.md` when architecture or design rules change, and
  correct its stale claims (§4 contrast claim, §5 "no compiler") when you're there.
