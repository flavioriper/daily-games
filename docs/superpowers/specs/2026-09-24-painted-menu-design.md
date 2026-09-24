# The first screen, painted

2026-09-24. Concept: `docs/brainstorm/concepts.html#menu2`. Mock:
`docs/art/concept-menu-painted2.png`. Supersedes the layout sections of
`2026-09-18-flat-menu-design.md` (sections 1 and 3), not its behaviour.

## 1. What and why

The first screen moves toward the user's painted mock. The goal is a screen
that looks more elegant and finished while staying cozy and warm. It keeps
the same bones (wordmark, day card, card grid, go-buttons, a three-tab bar)
and adds:

- **painted scenery** behind the header, the day card and every card's
  picture;
- **two columns** instead of three, so the cards are wider, the names bigger
  and the go-buttons larger;
- **depth**: soft shadows, a floating bar and filled hearts.

Decided with the user on 2026-09-24:

- **Hybrid medium.** The backdrops are painted images and the cast stays code
  (`ui/menu/card_art.gd`, `ui/faces/`), drawn on top so the faces stay live.
  This overturns the flat-menu spec's "never an image" rule **for backdrops
  only**. A character is still never an image.
- **Two across, paged.** Pages stay, as the user decided earlier (no
  scrolling).
- **Six vistas, supplied by the user**: `beach`, `dusk`, `meadow`, `night`,
  `autumn` and `sky`, in `assets/art/menu/vista_<name>.png`, each about
  877×288. The header, the day card and all twenty card banners are crops of
  these six. No per-card paintings are planned.

## 2. Height budget (1080×1920 design space)

Figures below are the design; see §13 for what shipped.

| Row | Height | Was |
|---|---|---|
| Margins, top and bottom | 40 + 40 | 40 + 40 |
| Header | 380 | 380 |
| Day card | 200 | 180 (it measured 188) |
| Grid | 4 × 246 + 3 × 20 = 1044, plus up to 36 of fit slack | 4 × 252 + 3 × gap |
| Bar | 120 | 150 |
| Column gaps | 3 × 20 | 3 × 20 |

1920 − 80 − 380 − 200 − 120 − 60 = 1080 for the grid. Four rows take 1044,
and the 36 left over goes through `_fit_grid`'s existing slack path (grow the
banner up to `ART_GROW`, then open the row gaps). The pager stays an overlay
centred just above the bar; `PAGER_MID` and `TOAST_OVER` are recomputed from
the new bar height.

`ui/menu.gd`: `MIN_CARD_W` 320 → **490**, `COLS` 3 → **2**, `PER_PAGE` 12 →
**8**. `_fit_grid` needs no new logic. At 1080 wide it fits two columns; a
1440-wide 4:3 screen fits two (1400 / 510); 9:20 fits 2×5. With twenty cards
the 1080×1920 pages hold 8, 8 and 4. Four cards over two columns fill two
whole rows, so no filler is built, but the filler path stays (see
CLAUDE.md).

## 3. One shader for every painted plate

`shaders/painted_plate_2d.gdshader`, on a `TextureRect` (never a Panel, so
`CozyTheme.dress()` leaves it alone). Everything happens in one draw call:

- `uv_rect` (vec4): the crop. It is computed in GDScript from the plate's
  size, the texture's size, a **zoom** (1.0 = cover) and a **focus** (0–1 on
  each axis, like CSS `background-position`).
- `radius`, `rect_size`: a rounded-rect SDF alpha mask with a one-pixel
  antialiased edge. `radius` 0 means square.
- `scrim` (vec3: strength, start, end): a horizontal wash toward `Pal.PAPER`
  from the left edge. Used behind the wordmark and the day card's text.
- `wash` (float): a radial paper glow centred under the cast. Card banners
  only.
- `fade` (vec2: from, to): a vertical fade to transparent. The header only.
- `fallback` (bool) with `top`/`bottom` colours: when the texture is missing,
  paint a sky-over-ground gradient in the card's colour instead. **A missing
  vista is a gradient, never an error.** This mirrors `Fx2D.cue()`'s rule
  that a missing sound is silence.

No `instance uniform` anywhere (memory: they return garbage on Android past
the sixteenth instance). Each plate owns its own `ShaderMaterial`. Every
plate has a different texture or crop anyway, so nothing batches either way.

## 4. `ui/menu/vistas.gd`, the one table

This is a static script and the only place painted art is named:

- `texture(name) -> Texture2D`: `load` if the file exists, else `null`, which
  triggers the fallback.
- `HEADER`: `dusk`, with its zoom and focus.
- `DAY`: `ISLAND_n` key → vista (the 24-row map on the concept page: Pebble
  Reach → beach, Windmere Rock → meadow, Lantern Cove → night, and so on),
  plus one focus point per vista.
- `CARDS`: puzzle id → `[vista, zoom, focus]`, copied from the concept page's
  table. An id missing from the table gets the fallback gradient, so a new
  board needs no painting.
- `plate(name, zoom, focus, ...) -> TextureRect`: builds the rect and its
  material. It sets `uv_rect` on `resized`, so the crop follows the fit.

## 5. The header

- A **full-bleed backdrop** is added to `_list_root` right after the paper
  `Page` rect and before the margins. It is anchored top-wide, from y 0 to
  `margin_top + HEADER.HEIGHT + 120`, so it runs under the safe area at the
  top and fades behind the day card's upper edge. It uses the `dusk` vista
  cropped to the treehouse deck on the right, with `scrim` from the left
  (about 0.78 at the edge to 0 at 62%) behind the wordmark and motto, and a
  `fade` over its bottom third.
- The **sun and moon** grow (`SUN_SEAT` 190 → about 250, `MOON_SEAT` 166 →
  about 220) and move down so they sit on the deck. The final numbers are set
  against the rendered frame, not by eye in the browser.
- The wordmark, sun-dot, sprig, motto, buttons, badge and entrance are
  unchanged. The settings and calendar buttons get the soft shadow (section
  8).

## 6. The day card (`ui/menu/day_row.gd`)

- `HEIGHT` 180 → **200**. The tree plate is removed. The day's vista fills the
  card as a plate with `radius` 36 and `scrim` from the left (0.94 to 0 at
  66%), behind the kicker, `Day N` and the island name.
- **Hearts are red**: a new `Pal.HEART` (`e0574f`) fill for an earned heart.
  An unearned heart is a paper fill with the `LINE` outline, because a bare
  outline disappears on a painting. The pop is unchanged.
- The chevron is unchanged apart from the soft shadow.
- `set_day` also picks the vista from the island key.
  `Progress.island_name()` already returns `ISLAND_n`.

## 7. The card (`ui/menu/puzzle_card_2d.gd`)

- `CARD_H` 252 → **246**. The card is 490 wide at 1080.
- **Banner:** `ART_H` 92 → **108**, inset **10** from the card's edge on the
  top, left and right, with `radius` 28 and `wash` on. `CardArt` is a child on
  top of it, exactly as it sat in the old plate. The old pale swatch
  (`_art_style`, `ART_TINT`) goes, and the fallback gradient replaces it.
- **Text:** the name, blurb and go-button sit in their own margin, 18 in from
  the card's own 10. Name at **44** (was 34) and blurb at **26** (was 23);
  the plan checks whether `CardName` and `CardBlurb` are used anywhere other
  than these cards before changing the theme sizes, and otherwise adds
  menu-only variations. `GO` 68 → **80**.
- The done seal, the press squash and the `soon` path are unchanged. The seal
  still pins the banner's top right corner.
- **Depth:** the card's stylebox gets a soft warm shadow in place of the
  6-pixel bottom border (section 8).

## 8. Depth

This is the soft shadow from the concept: `StyleBoxFlat.shadow_color`
`Color(0.35, 0.23, 0.12, 0.14)`, `shadow_size` about 12, `shadow_offset`
(0, 6). It goes on the cards, the day card, the bar, the pager pill and the
two header buttons, which replaces the hard `border_width_bottom` "tactile
edge" on those widgets only. If a shadow costs a draw call it gets measured
(section 10); it is dropped if it breaks the budget.

The bar (`ui/menu/bottom_bar.gd`): `HEIGHT` 150 → **120**, fully round
(radius 60), with the same shadow. Tabs and icons are unchanged.

## 9. Assets

- `assets/art/menu/vista_*.png`, imported as 2D textures with **lossy (WebP)
  compression at about 0.85**, mipmaps off, and filter linear. VRAM
  compression (ETC2) would smear painted art. Six files come to well under
  1 MB in the APK.
- The user may send full-size originals later. Swapping a file in needs no
  code change, because crops are fractions and not pixels.
- `docs/brainstorm/cast/*.png` are concept-page renders only, and never
  loaded by the game.

## 10. What gets measured, not assumed

With `tests/_shot_menu.gd` at `--resolution 810x1440`, two sequential
readings each:

- **Draw calls** on page one, page two, Streak and Stats, against today's
  334 / 181 / 142 / 148 and the 855 budget. Twenty plates, one header, one
  day card and the shadows are expected to add fewer than thirty.
- **Idle ms**, compared only within the same session.
- **Card width** reads 490 on the frame (the check that the resolution flag
  landed before `--script`).
- **ANGLE** (`--rendering-driver opengl3_angle`): the plates render, and the
  settled frame matches the default driver to edge antialiasing.
- A **missing-vista run**: rename one vista away, and the fallback gradient
  shows with no error in the log.

No new test suites (MVP rule). The existing suite has to stay green, and any
test that asserts the old `COLS`, `PER_PAGE` or `CARD_H` is updated to the new
figures, not deleted.

## 11. Out of scope

- The boards, the win screen, the Stats and Streak tab bodies, and the rules
  and settings sheets.
- Paintings made for individual cards, and any animated scenery (the vistas
  are still images, and only the cast moves).
- New icons for the bar.

## 12. Docs

CLAUDE.md's "The first screen" section changes from three columns, twelve a
page and the pale-swatch card picture to two columns, eight a page and
painted plates. It states the new budget and the draw-call readings from
section 10, and states that "never an image" now means never a character.
The flat-menu spec gets a one-line pointer to this one.

## 13. Measured

### Superseded in implementation

Sections 2-7 above are left as the design record, not corrected in place.
Where the shipped code differs:

- **`TextureRect`** (§3, §4) shipped as a `ColorRect` with the vista as a
  `sampler2D` uniform, not `TEXTURE`, so a missing file can still draw the
  fallback gradient -- `TextureRect` has no hook for that.
- **`plate(name, zoom, focus, ...) -> TextureRect`** (§4) shipped as five
  named calls on `ui/menu/vistas.gd` -- `card_plate`, `day_plate`,
  `header_plate`, `set_day_vista`, and `set_top_pad` (added in the
  2026-09-24 final fix wave, F1) -- rather than one generic constructor,
  because the header, the day card and a card banner each need a different
  set of shader parameters wired (`scrim`, `wash`, `fade`) and a single
  `plate()` would need to take all of them optionally.
- **`ART_H` 108** (§7) shipped as **100**: a properly-settled probe (task 2,
  fix round 1) measured the name and blurb's real font metrics at 122, not
  the 96 the 108 figure assumed, so 108 ran the card 8 over its 246 budget.
- **The backdrop's "+120"** (§5) shipped as **`BACKDROP_BLEED` 140**: the
  extra 20 is how far past the day-card's own fade the dusk vista needed to
  run for the fade band itself to read as a fade rather than a hard cut.
- **"The pager stays an overlay"** (§2): true, but it gained its own 20px
  seam (`PAGER_SEAM`) rather than floating on the bare column gap, because
  the 490x246 card put the old bare-gap position about 18px over the last
  row's blurb. `_fit_grid` now reserves `PAGER_SEAM` plus one more `GAP` out
  of the grid's room for it (see CLAUDE.md's "The first screen" section).

Taken 2026-09-24 with `tests/_shot_menu.gd` at `--resolution 810x1440`,
`--resolution` before `--script` in every invocation, `git checkout --
project.godot` after each, two sequential readings with the second quoted:

- **Page one**: 255 / 255 draw calls, 8.33 / 8.33 ms mean idle. **255**
  against the section 10 estimate of "fewer than thirty" over the old 334 --
  it landed lower still, because eight cards now stand where twelve did.
- **Page two** (`-- page2`): 255 / 255 on the Home shot and 224 / 224 on the
  turned page, 8.39 then 8.33 ms (page2's own idle 8.33 both times).
- **Streak** (`-- streak`): 112 / 112 draw calls, 8.33 / 8.33 tab idle.
- **Stats** (`-- stats`): 149 / 149 draw calls, 8.33 / 8.34 tab idle.

All four are well inside the 855 budget.

- **Card width**: measured on `/tmp/shot_menu_1.png` (810x1440) at two rows
  clear of any art or text (y=680 and y=700), where the card's shadow-lifted
  panel runs a clean 364-365 px between background-coloured margins and
  the inter-column gap. Expected 367-368 (490 x 0.75); the few pixels short
  are the lifted stylebox's own shadow blur softening the true edge, not a
  scale error. A card anywhere near 430 wide would have meant the flag
  landed after `--script`; it did not.
- **ANGLE**: `--rendering-driver opengl3_angle` read the same 255 draw
  calls, with a painted plate on every card. Compared against the default
  driver's page-one shot with Pillow (`ImageChops.difference`), max delta
  190 and a bbox of the whole frame at the loosest threshold, but only 695
  of 1,166,400 pixels differ by more than 30 levels, and their bounding box
  (x497-773, y105-284) sits entirely inside the header's sun-and-moon box --
  the sun-dot's glint, on its own clock, differing between two runs of the
  same build. No plate anywhere is missing or garbled.
- **Missing vista**: `assets/art/menu/vista_night.png`, its `.import` file,
  and the matching `.godot/imported/vista_night.png-*.ctex`/`.md5` were
  moved aside (moving the source alone was not enough -- Godot's import
  cache still serves the old texture) and the page-one shot re-run. The log
  had no `error` or `warn` line. Untangle's and Light Up's banners drew the
  sky-over-ground colour gradient in place of the night vista, and draw
  calls held at 255. Every moved file was restored byte-for-byte afterwards;
  `git status` on `assets/art/menu/` came back clean.

The suite (`godot --headless --path . --script tests/run_tests.gd`) passed
at `failed=0` after these readings, with `project.godot` checked out clean
between every windowed run.
