# Five Clues

- **Five Clues is a Puzzles card (2026-10-22)**, roadmap item 9, under
  Words. Clue cards on a cork board turn one at a time; type the idea they
  share. Spec `docs/superpowers/specs/2026-10-22-clues-design.md`. Id
  `clues`, prefix `FC_`.
- Files: `puzzles/clues2d.gd`, `puzzles/clues_state.gd`,
  `puzzles/clues_world.gd`, `ui/faces/clues_art.gd` (card, back, pin, the
  round pills), `ui/hud/clues_tutorial_diagram.gd`, `ui/menu/cards/clues.gd`;
  the night's `server/functions/src/clues.ts`. Hearts on Insane are
  `shelves_art.gd`'s.
- **It types on the phone's own keyboard (2026-10-28)**, `"tray": "none"`.
  The user: "nobody likes it ... Users hate the ingame keyboard, they want
  to use their own device keyboard" -- this reverses the 2026-10-15 call to
  keep Hidden Word's keyboard for every typing board (Hidden Word and Pearl
  Dive still have it). The board holds an unseen `LineEdit` (`_field`)
  over the slate, `keep_editing_on_text_submit` so the keyboard stays up
  between guesses; any tap on the board in play calls it up (`_summon`,
  `edit()`: a touch is not a click here). `_watch_osk` follows
  `virtual_keyboard_get_height()` (window px, scaled to the viewport) and
  lays the board out *tight* above it: a 16:9 phone leaves some 600 of the
  1920 between the top rows and the keyboard. `osk_override` stands in for
  the keyboard off a phone (`_shot_clues.gd osk=806`, `_win.gd` checks the
  slate and cards land above 42% of the screen). Autocorrect can rewrite a
  guess; Godot has no per-field switch, the forgiving judge is the answer.
- **Made fun (2026-10-28)**, after Pinpoint, skribbl.io's "close" and the
  players' word that it was no fun:
  - forgiving judge: the label's own telling words count (typed as whole
    words; "fruit" names Citrus fruits, "grapefruit" does not), and a typed
    word of 6+ letters one letter off a form is right (two off a 9+ one);
    one letter further is `Said.NEAR`, "So close! Check the spelling", free.
    6, not 5: at 5, pt "pente" (a clue) read as "dentes" (the idea).
    `GENERIC` lists the label words that say nothing alone (things, types,
    coisas, cosas...);
  - a tap on the next face-down card turns it (it breathes "tap for a
    clue"); Enter on an empty line still does;
  - wrong lines stay pinned struck through under the slate (`_tried`);
  - a found round stamps praise by cards (`FC_PRAISE_1..5`, confetti at 1-2)
    and every round over moves on by itself (2.6 s found, 3.6 s lost), a tap
    or Enter sooner after a 0.6 s guard.
- **A typed line is judged as the server judges it**: `State.accepts` and
  `clues.ts accepts` fold the same way (`norm`) and accept the same
  (parity probed 2026-10-28 over 12,888 bank lines, 0 differences; no bank
  round newly refused). Change one and change both. The server's copy is
  undeployed until a person runs `tools/deploy_functions.sh`; until then the
  night checks its rounds with the old, stricter judge, and the phone only
  accepts more than it, never less.
- **A card is up only once it has a turn time** (`_turned_at[i] > -INF`):
  the first build read -INF as long turned and showed every word at once.
- The bank's order is the server's (`ordered`, double FNV of
  `clues|<day>|<id>`); Hard takes the hard tier's head, Insane its tail.
- Harness: `tests/_win.gd -- clues` (the keyboard's field fed and
  submitted: the keyboard-up layout, a real touch on a face-down card, a
  wrong word struck, a two-letter slip refused free, the bulb, a typo of the
  key word accepted with praise, the first round moving on by itself, the
  rest by a tap);
  `tests/_shot_clues.gd -- <dir> d=<0..3> [tut=<page>|card]`.
