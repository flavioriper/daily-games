# Golden Acorn

- **Golden Acorn is the thirty-third card** (2026-10-08,
  `puzzles/acorn2d.gd`, `puzzles/acorn_state.gd`, `ui/faces/acorn_art.gd`;
  no spec and no concept tab -- asked for and built in one sitting while the
  user was away). A quiz: a question on a card of paper, four answers on
  plates lettered A to D, one of them right. The puzzle id is `acorn`.
- **The games it follows are Show do Milhão and Who Wants to Be a
  Millionaire?, and those names go nowhere else**: not in code, comments,
  commits or on screen. The Brazilian show's shape was looked up on
  2026-10-08 (news pages, not its rulebook): four answers a question,
  questions that climb in difficulty and in prize, helps that are limited
  (a skip, cards that take wrong answers away, the audience's plates, the
  university students), stop and keep or miss and fall. Ours keeps the four
  answers, the lock that is asked for twice ("are you sure?" is the motto
  and the Lock button is the second asking), the climb and one help. Left
  out on purpose: money, a host, the skip, the audience and the students,
  stopping to keep, and any clock.
- **A search for the shows' names hits `tools/acorn/tier1.json` and
  `content/acorn.json`**: m031's wrong answer "Um milhão" / "A million". That
  is the number, not the show; leave it.
- **Its questions are written by a model, every day.** This is the first
  board whose day comes from the backend: `publishDay` asks Claude for the
  day, a second blind pass reviews it, and the phone reads the document
  (`docs/agents/turns-and-backend.md`, "A day written by a model", is the
  whole of that and the contract the next game follows). The board itself
  never talks to a model.
- **One move**: a tap picks an answer (its plate lights in sun; another tap
  moves the light), and **Lock** (the actions row's third button,
  `check_label` → `AC_LOCK`) makes it final. Lock with nothing picked is
  refused with a line. After a held breath (`HOLD`, 0.6 s, silent) the right
  plate turns leaf with a tick, the picked one berry with a cross when they
  differ, the other two stand back, and the question's `why` fades in at the
  paper's foot in the answer's colour. The button then reads **Next**
  (`AC_NEXT`; a tap on the card does the same) and, after the last question,
  **Finish** (`AC_DONE`): the day does not end by itself, so the last line
  can be read. No Undo on any band. **Reset has nothing to give**
  (`can_reset()` is false): an answer is final and a question is not asked
  twice. `check()` returns -1 always.
- **The bands** (`State.ASKS`): seven questions on Easy, Medium and Hard,
  each band its own difficulty of question and its own daily. **Easy to
  Hard cannot be lost**: the day ends when the last question is locked and
  finished, and the count of right answers is the result ("5 of 7 right").
  The bulb takes two wrong answers off the card (`State.cut_two`, once a
  question; two bulbs on Easy, one on Medium and Hard, none on Insane).
- **Insane is the Climb**: ten questions that rise from easy to what one
  adult in ten knows, with **two hearts**, one spent on each wrong lock.
  Hearts and not a move counter, for Trestle's reason
  (`docs/agents/flat-screens.md`, "Insane counts moves"): there is one move
  a question. Out of hearts is the out-of-hearts card. **Try again is a new
  Climb, not the same one** (`State.redeal`, from the bank): every answer of
  the lost one has just been shown. The video gives one heart and the Climb
  goes on from the question that was lost.
- **The seal**: a day with nothing wrong ("Perfect"), and any Climb that
  reached the top ("Golden", or "Perfect"). It drops on the paper's top
  right corner and the question re-wraps narrower to make room.
- **Where a deal's questions come from** (`_deal`):
  1. A daily (`daily_key != 0`) whose document this phone already holds
     (`Backend.cached_day`): at once. `world/main.gd` asks for today's
     behind the menu at boot, so this is the usual case.
  2. A daily with the network up and no document yet: "Fetching today's
     questions…" on the paper while `Backend.day_content` is awaited, and
     after `FETCH_WAIT` (4 s) the bank deals instead.
  3. Everything else -- unstarted backend (every harness), no network, a
     document that does not validate, a board dealt from New, a second try
     at the Climb -- is the **bank**: `content/acorn.json`, by
     `State.bank_band(key, band)`.
  **`build()` deals nothing.** The host sets `daily_key` only after
  `start()` returns, so `build()` clears the card and defers `_deal` by a
  frame; `capabilities()`, `rules()`, `check_label()` and the rest answer
  from the band alone until then. A harness that asks the state for its
  count on the frame it opens the board reads zero.
- **The bank** is 144 questions, 36 a tier (easy, medium, hard, expert), in
  en, pt-BR and es, four a subject over nine subjects. **The source is
  `tools/acorn/tier0..3.json`; `python3 tools/build_acorn.py` checks every
  one against `tools/acorn/CONTRACT.md` and writes `content/acorn.json`**
  (edit the tiers, not the output). A band is the head of its tier's order
  for the day and the Climb the tail of every tier's (three easy, three
  medium, two hard, two expert), so the four bands of a day share no
  question. The order is by `fnv1a` of the day and the id, **hashed twice**:
  FNV's last byte barely stirs the top bits, and ids that differ in their
  last digit sorted side by side until it was. The server sorts the same way
  (`bankDay` in `acorn.ts`); `tests/_shot_acorn.gd -- bank` and
  `tools/acorn_day.sh` print the same week. Offline, a band repeats a
  question about every five days.
- **Who wrote the bank**: four model sessions, one a tier, told to use only
  facts they were sure of; I replaced four medium questions that repeated
  easy ones. Nobody has read all 144 for truth, level or language. The
  expert tier's own author flagged three as nearer Hard (rhino horn, the
  stapes, braille's six dots) and one that a Brazilian can get by
  elimination (x027: the three wrong answers are men).
- **The answers are shuffled on the phone**, by the deal's key and the
  question's id, so a document always stores `right` and three `wrong` and
  the model's habit of where it puts the right one never reaches a player.
- **The question's language is the screen's** (`State.wording` reads
  `TranslationServer.get_locale()`), not `Locale.current()`: a probe run with
  `lang=en` on this Mac showed English chrome over Portuguese questions
  until it did. A language changed mid-day re-reads the same question.
- **Drawn as**: `_still` (the card and the question's paper; a layout),
  `_live` (the four plates, their letters' discs, ticks and crosses; rebuilt
  only on a frame something moves), and a layer of words over both (the
  pills, the subject, the question, the answers, the why, the seal, the
  toast). The words on a plate go through one `draw_set_transform_matrix` a
  plate, so they pop, sink and shiver with it. Question and answers are
  fitted down a list of sizes (`Q_FONTS`, `A_FONTS`) until they wrap into
  their box. 80-114 draw calls on both drivers. No mascot: the pieces are
  marks, the acorn is a prize (the Code Break friend's nut without its
  face), and the win keeps the family's sun and moon.
- **Motion that is this board's own**: the held breath between a lock and
  its answer (the locked plate swells twice, in silence), the wrong plate's
  shiver, the why coming a beat after the colours. The rest is the flat
  vocabulary read as curves.
- **A completed daily is put back** on its last question from the cached
  document, or the bank when the cache is gone. `completion_record` keeps
  the picks, what was right, and `set` (a hash of the questions' ids): when
  the questions put back are not the ones that were answered, the picks are
  dropped and only right and wrong are kept, so the pips and the count stay
  true.
- **Harnesses**: `tests/_shot_acorn.gd` (rest, play, perfect, hint, out,
  doc, restore; `bank` prints a week headless); `tests/_probe_perf.gd --
  acorn`; `tests/_win.gd -- acorn` (1/1 on 2026-10-08). All three wait for
  the deal.
- **The tutorial** (`ui/hud/acorn_tutorial_diagram.gd`, four pages on every
  band: pick, lock, why, and then the bulb, or on Insane the Climb and its
  hearts): the board itself on two hand-written questions with
  the right answer at C, played through its own input path under a drawn
  finger. The page lays the board 760 tall and draws it at about 0.4, so an
  answer reads at roughly 15 px in the shots.
- **Not seen on a phone.** Shots and probes on this Mac only. The sounds
  are one take a cue and unheard by the user; the pt and es lines of the
  chrome and of all 144 questions are unreviewed; **the model's day has
  never been written**, because there is no Anthropic key on this Mac (the
  pipeline ran against a stand-in and the publish against the emulator).
- **Calls made without the user** (2026-10-08): the name and the acorn as
  the prize; a board with four bands rather than one ladder; seven
  questions a band and ten on the Climb; Lock as its own press and Finish
  after the last answer; one help only (the bulb as the cards), none on the
  Climb; two hearts; Try again dealing a new Climb; no money, no clock, no
  stop-and-keep; a silent held breath in place of a drum roll; the why line
  in berry after a wrong answer; nine subjects; the model (Claude Opus 5.5)
  and its two passes; the bank falling in for a short or failed night; no
  score sent to the crowd.
