# Stats and Streak

2026-09-24. Roadmap: `docs/roadmap-to-release.md`, Phase 1, "Stats and Streak".
Concept, playable: `docs/brainstorm/concepts.html#progress`.

The bottom bar's two inert tabs become real screens, and the first screen's
decorations (the day row's hearts, its chevron and the header's calendar
badge) start counting. The purpose is retention: a reason to come back
tomorrow that fits a cosy game.

## Decisions

Taken with the user on 2026-09-24:

1. **A day is kept by three solves.** The day row's three hearts count them.
2. **Earned freezes, called rest days on screen.** Every seven kept days in a
   row earn one, a player holds two at most, and a day that ends unkept
   spends one automatically.
3. **The header's calendar badge shows the current streak** and opens Streak.

Everything else below was the recommended option, which the user took
wholesale ("do all recommended") and may still overturn.

## 1. What counts

- **A solve** is the first solve of a board at a difficulty on a day. A
  replay of a solved daily is never counted again: it is the same puzzle, and
  it would inflate the best time. A Hidden Word that runs out of rows is not a
  solve.
- **A heart** is one **distinct board** solved today, at any difficulty, up
  to three.
- **A kept day** has three hearts. The day is `Daily.date_key()`, the boards'
  own UTC day, so the streak rolls over when the puzzles do.
- **The streak** is consecutive kept days up to yesterday, plus today once
  today is kept. Until then today is *pending*, never missed.
- **A rest day**: a kept day that brings the earning count to 7 resets it to 0
  and adds a rest day, capped at 2 (at the cap the count still resets). A day
  that ends unkept with a rest day held spends it: the streak neither grows
  nor breaks, and the earning count carries over. With none held the streak
  and the earning count go to 0.
- **The walk starts** at the first date with any solve. Days before it are
  not counted either way.
- **Best streak** is the highest the walk ever reached.

**None of the streak is stored.** Current, best, rest days held and the count
toward the next one are all derived by walking the log from its first date to
today, so no counter can drift from the log.

## 2. Data: the solve log (`core/progress.gd`)

A new `log` section in `user://progress.cfg`, one key per date
(`"20260924"`), each value an Array of records:

```
{"id": "queens", "d": 1, "t": 83.4, "m": 41, "h": 0}
```

`id` is the registry entry's id (not the `progress_id` with its difficulty
suffix), `d` the difficulty (0-3, or -1 when unknown), `t` seconds, `m` moves
and `h` hints.

- `Progress.log_solve(id, difficulty, stats, date_key)` appends a record
  unless one with the same `id` and `d` already exists on that date.
  `clear_completed` (the replay button) never touches the log.
- `Progress.solve_log() -> Dictionary` returns `{date_key(int): Array}`.
- `Progress.hearts(date_key) -> int` returns the distinct ids on that date,
  capped at 3.
- **Migration, once**, on the first `solve_log()` read: every
  `completed/<date>_<rest>` key becomes a record. If `rest` ends in
  `_<0-3>`, that suffix is `d` and the prefix is `id`; otherwise `id` is
  `rest` and `d` is -1. `completed_stats` of the same key supplies
  `seconds`, `moves` and `hints` when present. A `d = -1` record is dropped
  when a suffixed record for the same id and date exists (the menu also marks
  the plain id). The run sets `log_meta/migrated = true`.

## 3. Derivation: `core/streak.gd` and `core/player_stats.gd`

Pure static functions over the log, with no file access, so they can be
checked in isolation.

- `Streak.compute(log: Dictionary, today: int) -> Dictionary` returns
  `current`, `best`, `rest` (held), `toward` (0-6) and `days`
  (`{date_key: "kept" | "rest" | "partial" | "missed" | "today"}`). Dates
  step through `Time` (`get_unix_time_from_datetime_dict` plus 86,400,
  then back), never by integer arithmetic on the key.
- `PlayerStats.summary(log) -> Dictionary`: `solved` (all records),
  `days` (dates with at least one record).
- `PlayerStats.boards(log, difficulty) -> Dictionary`: `{id: {count, best,
  mean}}` over the records at that difficulty with `t > 0`.

## 4. Screens

**The header and the bottom bar stay; a tab's body replaces the day row, the
grid and the pager** (the column's 1,270 at 1080x1920). Home puts them back.
Switching fades the new body in over `Motion`'s appear. Reduce motion makes it
instant. Swiping pages only works on Home.

`ui/menu/streak_tab.gd`, from the top:
- **Streak card**: the current streak in Fredoka 700 at 160 (`ACCENT_2`, or
  `TEXT_DIM` at 0) over "day streak". On the right: Best, the rest days as two
  leaf discs (filled when held), and seven pips toward the next one.
- **Today card**: three hearts at the day row's size, and one line: "Solve
  three to keep the streak", "Two more keep the streak", "One more keeps the
  streak" or "Day kept".
- **Calendar card**: month and year with prev and next chevrons (from the
  first logged month to today's). Monday first. A kept day is a filled
  `ACCENT_2` disc with its date in paper; a rest day is a pale leaf disc; a
  partial day is an `ACCENT_2` ring with `n/3`; any other day is its date in
  dim ink; today wears an ink ring; future days are faint. Drawn in one
  `_draw` on one Control, which is cheap for a static page (under 50
  commands).

`ui/menu/stats_tab.gd`, from the top:
- **Three tiles**: Solved, Days played, Best streak.
- **A difficulty strip**: Easy, Medium, Hard and Insane as four chips. Insane
  is the night chip (ink fill, paper lettering, a `SUN` ring when on). The
  choice is kept in `progress.cfg` under `stats/difficulty`.
- **A board grid**: every `Registry.PUZZLES` entry, four across, rows as
  needed, in registry order. Each tile: a `Pal.CAT` dot (the card's own
  colour, by index), the title fitted down to 18 px, "N solved" and
  "best · average" in `m:ss`. An unsolved tile shows a dash and is drawn at
  60% alpha. The whole grid is drawn in one `_draw` so twenty tiles are not
  twenty nodes.

**First screen:**
- `day_row.gd`: `set_hearts(n, pop)` replaces `HEARTS_FULL`. When the count
  rose since the last show, the new heart pops (`Motion.pop_in_scale` read as
  a curve), after the row's entrance. The chevron emits `open_streak`.
- `menu_header.gd`: `set_streak(n)`. The badge hides at 0 and grows into a
  pill for two or three digits. The calendar opens Streak.
- `bottom_bar.gd`: all three tabs are live, and `unbuilt` goes.
- `ui/menu.gd`: `_show_tab(key)`; `_show_list()` refreshes hearts and badge.

**The win screen** (`ui/flat/flat_host.gd`): the stats card's second line,
the island name, becomes the hearts line after the solve: "2 of 3 today",
"Day kept · 5-day streak", or "5-day streak" once the hearts were already
full.

## 5. Analytics

`puzzle_complete` gains `hearts` (today's count after the solve) and `streak`
(current). A new `tab_opened` event carries `{tab}`. Both go through
`Analytics.track` as everything else does.

## 6. Localisation

Every new string is keyed in `locale/ui.csv` (en, pt-BR, es), formatted
through `tr()`: tile labels, the difficulty chips (the existing `DIFF_*`), the
today lines, "day streak", Best, Rest days, Next rest day, the win lines and
the month names (`MONTH_1`..`MONTH_12`) and weekday initials
(`WEEKDAY_INITIALS`). `MENU_CALENDAR_SOON` and `MENU_TAB_SOON` are deleted.

## 7. Verification

The project's MVP rule is "no new tests, only throwaway self-driven checks",
so:
- A throwaway probe runs `Streak.compute` over hand-built logs: a clean run
  of 7 (one rest day earned), a miss covered, a miss uncovered, a miss with
  the cap at 2, today pending against today kept, a month boundary and a year
  boundary. It also runs the migration over a hand-written `progress.cfg`.
- The suite stays green.
- `tests/_shot_menu.gd` shoots the Streak and Stats tabs at `--resolution
  810x1440` (before `--script`). Draw calls are read against the 855 budget,
  with page one's 330 as the control.

## Out of scope

Cloud backup (its own roadmap item), sharing a streak, notifications,
showing moves and hints on Stats, and a median.
