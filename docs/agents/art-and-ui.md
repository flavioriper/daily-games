<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Art: shading direction

The look everything aims for is in `docs/art/shading-direction.md`: soft
painted cel, no harsh black outlines, warm muted pastels, diffuse and
painterly surfaces, soft coloured shadows, minimal specular, depth through
colour rather than fog. Read it before touching a shader, palette or light.

The HUD's paper takes the same wash through `CozyTheme.dress()`, installed
once by `world/main.gd` before any screen builds: every Button, Panel and
PanelContainer that enters the tree without a material gets the one shared
paper material (`shaders/paper_2d.gdshader`, measured in screen space), so
a new widget needs nothing. A widget that wants another surface sets its
own material and keeps it, the way the wood trays do. Harnesses that build
a screen without `main.tscn` show the faces flat; that is the harness, not
a regression.

**One button language since 2026-09-28 (UI polish).** Every button is
lifted paper: `CozyTheme.soft_button()` -- the fill, a 2 px hairline a shade
darker, a soft shadow warmed toward the fill -- and pressed sinks onto a
short shadow. The theme's variations, `lift_button()`, the digit pad and
the keyboard all go through it; the thick bottom edge (`card()`'s
`border_w`) is not used for a button any more. A labelled `IconButton` is a
pill (`_pill()`, radius clamped by StyleBoxFlat), an icon-only one keeps
its rounded square. Sheets and dialogs are `CozyTheme.sheet_card()`: a 44
radius, a faint hairline, a deep soft shadow, a grab handle drawn on the
card (`sheet.gd`), over a warm 0.42 scrim. The paper wash was calmed at the
same time: its cool end had read as blue-grey clouds on every white face.
Badges are coral with a cream ring.
**The bottom bar was redrawn to the user's mock on 2026-09-28**
(`ui/menu/bottom_bar.gd`): a hairline rim, a leaf sprig out of each round
end (one mesh, rooted inside the 40 px margin), filled icons in a warm dark
ink (`Icons` `swords` for Versus and `gamepad` for Arcade, whose buttons are
`holes`), and the current tab in a raised gold pill lettered in ink, with a
small sprig on its corner and a coral dot under it. 291 draw calls on page
one (282 before).

**Every sheet's head is one helper since the HUD mock of 2026-09-28**
(`sheet.gd`'s `_title_row`): the sheet's icon in ink with a sprout, the
title, and a round X that closes it; a sheet with a gold pill slots it
before the X. `_wide_primary` is the wide sun button a sheet ends on.
`ui/hud/sheet_parts.gd` holds the drawings: faint leaf sprigs on every
card (one cached mesh a card, rebuilt only on a resize, the first-play card
included), the badge, the sprout divider and a setting row's tinted icon
plaque. The settings rows carry a plaque, a label and a dim sub-line
(`SETTINGS_*_SUB`), the language sits on its own pill, and the secondary
buttons pack two to a row (`_pack_buttons`, re-run when Privacy's
visibility changes). A switch row keeps its face while on: a CheckButton's
"pressed" is its state, not a finger. Settings alone reads 371 draw calls
over the menu at 810x1440.
**A centred dialog is dressed like a sheet** (`ui/hud/dialog.gd`): the
sheets' warm scrim, paper and sprigs (`Dialog.card`, or `dress()` on a panel
of your own), the badge head, white tiles, and the sun button with a white
pill under it at one width after the sprout divider (`Dialog.buttons`). The
boost card, Second chance, Posy's offer, Lucky Thirteen's stuck card and
every Arcade and Versus end card go through it.
