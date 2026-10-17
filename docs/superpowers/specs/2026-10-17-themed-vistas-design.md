# Themed vistas

The user, 2026-10-17: "we must generate new background images for each daily
theme" -- "the set of background images used on the day card, the difficulty
background cards". Chosen in chat: the theme's place painted at four times of
day, one a difficulty row (keeping the sheet's day-going-down ladder), the day
card taking one of them; "all good, build it".

## What a day gets

Four paintings of the theme's `scene`, wide (21:9), in the bundled vistas'
painted style: **morning** (Easy), **afternoon** (Medium, and the day card),
**dusk** (Hard), **night** (Insane). The six bundled vistas
(`assets/art/menu/vista_*.png`) stay as the fallback, and they are what
everything else (the header, the board cards, Streak, the store) keeps.

## Night (server/functions/src/vistas.ts, themeday.ts)

- The morning is painted from the scene with `vista_meadow.png` attached as
  the style (copied to `lib/vista_style.png` by the build); the prompt copies
  the style and never the meadow's place.
- Afternoon, dusk and night are each the morning attached and painted again at
  their time, same place and framing, so the four are one place.
- Opus reviews each one (the morning on its own, the others beside the morning).
  It turns down text, letters, people, anything unsuitable, a non-landscape, the
  wrong time, or a different place.
- Model: `vistaModel()`, the shape boards' flash on Vertex (its own quota, not
  the pixel pictures' pro); `DAILY_VISTA_MODEL` overrides it. One trial day
  (20261019) took about 60 s for all four, every one passed on the first try.
- Each painting is shrunk to 1024 wide JPEG (q82, lower when its base64 would
  pass 200 KB; the trial's were 72-92 KB).
- `themeDay` steps `vista0..3` after the pixel pictures, one painting a run
  (TRIES 2 a step), staged as `themes/{day}/vistas/{time}` `{jpg}` (four
  JPEGs would crowd the day's own staging document).
- `publishVistas` writes `days/{day}/turns/vistas` `{json: {v: 1, theme,
  times: {morning, afternoon, dusk, night}}}` only when all four are there: a
  ladder of half themed, half bundled reads as two places. It is called by
  themeWork for today and tomorrow and by publishDays.
- `finished()` walks the vista steps too, so a staged day's `pictures` waits
  for them before it is published ahead of time (up to four more half-hour
  runs on a day staged fresh); today's publishes with what there is anyway.

## Phone (core/themed_vistas.gd, ui/menu/vistas.gd)

- `world/main.gd` fetches `vistas` behind the menu like `pictures`. When the
  fetch answers, the `themed_vistas` group (the menu's day row and the flat
  day card) is told, so a card already showing changes in place.
- `ThemedVistas.texture(time)` decodes today's cached document once (no
  mipmaps, like the bundled imports). With no document or an unstarted
  backend (the suite, every harness) it answers null.
- `Vistas.level_row(d)` gives the difficulty sheet its row: the themed
  texture at `THEMED_LEVEL` (zoom 1.15, centred), or `LEVELS[d]`.
  `set_day_vista` takes the afternoon at `THEMED_DAY` before the island's
  vista.
- `point_at` takes a texture as well as a vista name.

## Seeing it before a phone does

- `node lib/cli.js vistas tools/days/themed-vistas/<day>.json` (a copy of a
  made day) paints the four beside it, with the reviewer's word on each.
- The dashboard's Themed days shows them (`python3 tools/build_dashboard.py`).
- `tools/themed_play.sh <day> vistas` puts them in this Mac's game as today's.

Checked 2026-10-17: the menu and the difficulty sheet (`_shot_menu.gd diff`
with the trial day adopted, opengl3_angle, 810x1440): 179 draw calls idle,
239 with the sheet open. Suite 248522/0.

## Open

- The user's verdict on the paintings, and whether the island name under
  "Day N" should become the theme's name on a themed day (not done).
- The functions are not deployed: nothing is painted at night until
  `tools/deploy_functions.sh` is run.
