# The Commons

A cozy, turn-based, multiplayer board-and-cards game: gardeners farm a shared
allotment, hatch critters to push out and shoo each other back, and each keeps
a sealed goal. Worked out 2026-10-26 from one reference and four rounds of
visual mocks. Nothing here is built; this is the design record for when it is.

The five mock pages are saved beside this file in `commons/` and were also
published as private claude.ai artifacts (links below). Open the local copies
in a browser; they are self-contained.

| Step | Local page | Artifact |
|---|---|---|
| 1 · References and three directions | `commons/1-references.html` | https://claude.ai/artifact/KcPpewTL7vM8CH715YXb6d |
| 2 · Allotment, hex board, playable mock | `commons/2-allotment-hex-mock.html` | https://claude.ai/artifact/HWt71y5cHU4rG3TrqsXHJh |
| 3 · Allotment storyboard, one mocked game | `commons/3-allotment-storyboard.html` | https://claude.ai/artifact/QDA2Uu2j2bMmfJXcfkEmbS |
| 4 · Allotment Island, plots under cloud, seed-packet cards | `commons/4-allotment-island.html` | https://claude.ai/artifact/5qoFQuUXXBoD2dkjtrnXAx |
| 5 · The Commons, four gardeners, pannable map, critters, sealed goals | `commons/5-the-commons.html` | https://claude.ai/artifact/FybjqfnZwD5kDYonAcdgfS |

The user's words, in order: "cozy board and turns, where player spawn cards to
conquer board and win, like a tower defense conquest game" → "a board with
hidden cells (instead of a regular board)" and "show some initial cards" with
a fanned, illustrated hand → "a wider one where player move camera around ...
up to 4 players at once ... a war mixed with a starcraft, warcraft, but using
board and cards, turns ... farm around, to spawn and increase troops ...
elements to make the board live and random every game ... different random
goals for every match for each player (like war). The life and lemon reference
is the playstyle that I loved, that is cozy, good to play."

## 1. The reference

**Life and Lemon** (Finn Truong, itch.io, solo, Unity + Illustrator,
name-your-price, browser/Windows/Android, "coming to Steam"). A
single-player cozy fruit-farming card game: drag crop cards onto an orchard
field, wait for growth, press-and-hold to harvest, sell, fuse cards into new
species (80+ cards, hidden traits, 15+ characters, biomes). No turns, no
opponent, no win condition. #1 overall and #1 presentation at GJL Game Parade
Spring 2025 (108 entries), #24 creativity; 4.5/5 from 176 ratings. A judge:
"lacking depth beyond placement"; a commenter: "lacks goals and any
possibility of defeat". That gap is what the turn-based opponent fills.

What to keep from it: the card is the only control and the plot it lands on
is the whole decision; fusion as progression; press-and-hold harvest; flat
Illustrator shapes, fruit icons, smooth jazz, soft pops; "moreish". What to
avoid: growth so fast it reads as action for its own sake, tiny hitboxes, no
tutorial, a fusion that resets rarity.

### Games that already do card-spawns-a-piece, hold the board, with turns

Closest first. Facts from one store listing are marked *per listing*.

- **Manahex** (Erik Svedäng, Steam 2024): hex map, 2–4 players, realtime or
  async online, you own a hex by moving your mage onto it, creatures and
  structures appear beside the mage, owned hexes refresh as mana, last mage
  standing. Closest single fit.
- **Faeria** (2017): hex ocean between two orbs, you place land each turn
  (Power Wheel: +1 faeria, draw, or land), creatures summon onto your land,
  wells give faeria to adjacent creatures, break the orb.
- **Stormbound** (2017, mobile): 4×5 lane board, your front line is the row
  of your furthest unit and that is where you may spawn, units march a row a
  turn, 10 damage to the base. The "tower defense" shape.
- **Summoner Wars 2e** (browser app): 6×8 grid, summon beside gates you hold.
- **Marvel Snap**: three locations, simultaneous six turns, hold 2 of 3.
- **Hero Academy** (2012): async turns, 5 actions a turn; the sequel went
  real-time; current server status unverified.
- **The Battle of Polytopia**: async since 2018, 30-turn score mode, "adorable"
  low-poly; **Antiyoy**: hotseat up to 7 *per listing*; **Small World**:
  decline a race and pick a new one; **Spirit Island**: co-op defence against
  a scheduled invader; **Kingdomino / Carcassonne**: cozy tile layers, not
  conquest.
- Weaker: Spells and Sploobies, Battleboard, Attack on Hex Island, Duelyst,
  Ironclad Tactics.

**The gap**: every turn-based-tower-defense-with-cards search returned only
real-time games (Tower Duel, War of Towers, Conquest Tale). Nothing cozy,
nothing turn-based, nothing on a shared board.

## 2. The three directions (step 1)

- **A · The Allotment** (Manahex/Faeria shape): hex plots, two gardeners,
  play a seed on a plot touching ground you hold, plants grow and spread,
  bigger plants shade smaller ones which wilt, most plots after 12 turns.
- **B · Hedgerow** (Stormbound shape): 4-wide strip between two cottages,
  critters hop a row a turn, your hedge line is your furthest critter.
  Recommended at the time as the only "tower defense conquest" shape.
- **C · Three Beds** (Snap shape): three beds, simultaneous six turns.

The user's later asks (resources to farm, wild enemies, hidden cells, a wide
map, four players) pulled the design to A's field, then to C below.

## 3. The Allotment rules as mocked (steps 2–3)

- Hex field 5×8 (odd-r offset). Plots: soil, meadow (+1 sun a turn while
  held), pond (cannot plant; plants beside it grow an extra step), bramble
  patch (+1 card a turn with your bush on it), den (a slug or crow every third
  turn), two cottages (held ground).
- Sun: 2 a turn + meadows, cap 6. Draw 1 + bramble bonus; hand cap 6.
- Plants: sprout → bush → tree (clover max bush, grows 2; apple max tree,
  grows 1, shades, drops a sprout on even turns to the free neighbour nearest
  the enemy; bramble max bush). At your turn start: your plants beside a
  bigger enemy plant wilt a step, then grow, then trees spread.
- Cards (21): Clover seed 1, Apple seed 2, Bramble seed 2, Thorn hedge 2
  (wilds and sprouts cannot pass), Scarecrow 3 (a wild beside it at round end
  runs off, owner draws 2), Graft 1 (+2 steps on a plant touching another of
  yours), Watering can 1.
- Wilds: slug (moves 1, eats a step a turn, cannot cross water), crow (flies
  2, pecks once, leaves). BFS to the nearest plant of anyone.
- Win: most plots held after turn 12.

**What the storyboard found** (one scripted game, Clay 17 – Sky 13):
1. Pond + apple on turn 1 is a tree by turn 2 and seeds the middle for free;
   the pond is the opening every time.
2. A wild on a pond plant is a standoff: eats one, regrows two, the plot is
   held forever but never finishes.
3. A scarecrow touching a den is a free card engine (+2 every third turn).
4. By turn 8 there is nowhere left to seed; the middle never gets fought
   over; turns 9–12 need a reason to exist.

## 4. Allotment Island (step 4): plots under cloud

Square plots on an isometric floating island, ragged shape, most of it under
cloud. You see the plots beside your cottage. Every plot you hold thins the
cloud on its 4-neighbours; dotted clouds lift at the start of your turn.
Under a cloud: soil mostly, meadow, stream, bramble patch, **seed cache**
(draw a card when uncovered), **den** (sleeps until uncovered; whoever lifts
the cloud wakes it). Clouds block planting, spread and wild movement.

This answers findings 1 and 4: the stream is not visible from the cottage, and
the middle is uncovered last and contested. Cards became fanned seed packets
with a picture window and a ribbon name (house motif; the reference uses
burlap sacks). Owner is always a ring at the piece's base, never a shade.

## 5. The Commons (step 5): four gardeners

- **Map**: 20×20 isometric island dealt from a seed: three wandering streams,
  meadow and orchard clusters, bramble patches, 7 dens, 14 seed caches, 3
  lakes, the **Old Oak** at the centre (a plant beside it draws an extra card;
  two goals want it), one meadow and one orchard in sight of every cottage.
  Cottages in the corners: Clay (17,17), Sky (2,2), Plum (2,17), Ash (17,2).
  Camera pans (drag), minimap, jump buttons to each gardener and the Oak.
- **Two resources**: ☀ Sun every turn (2 + meadows + windmills), pays for
  cards. ✿ Blossom, a stock, +1 a turn per orchard held (+1 per hive beside
  an orchard), pays for critters.
- **Critters** (troops), hatched beside a burrow or hive you hold:
  Hedgehog 2✿ walks 2, size ●●; Bee 1✿ flies 3 over water and hedges,
  size ●; Snail 3✿ walks 1, size ●●●. Fights have no numbers: bigger shoos
  smaller back a plot, equals both wilt a step, a critter at nothing goes
  home. A critter on another gardener's plant wilts it a step. Plants hold
  ground; critters hold it only while standing on it.
- **Deck** (30 a gardener, same for all): Apple seed 2☀ ×4, Clover seed 1☀
  ×4, Bramble seed 2☀ ×3, Hedgehog ×4, Bee ×4, Snail ×2, Burrow 2☀ ×2, Hive
  2☀ ×2, Windmill 3☀ ×1, Thorn hedge 2☀ ×3, Scarecrow 3☀ ×2, Graft 1☀ ×2,
  Watering can 1☀ ×2, Whistle 1☀ ×1 (a critter walks again).
- **Sealed goals**: two dealt, one kept, nobody sees it until done. Complete
  it while holding your cottage and the match ends with you ahead; otherwise
  most plots at turn 20. Pack so far: Keeper of the Old Oak (a plant beside
  it two turns running), On their doorstep (a plant touching another
  cottage), Orchardist (six trees), Warden (six wilds sent off), Stream-wright
  (five stream-side plots), Hedgerow (a ring of eight hedges around your
  cottage with nothing of anyone else's inside).
- **Seasons**: every third turn a card turns up for three turns: Rain (every
  plant +1 step, stream-side spreads), Long evenings (sun paid twice, bees
  free, clouds do not lift), Fog (cloud returns over empty plots, critters
  walk one less), Swarm (dens let out two, scarecrows pay 3).
- **Neutral wilds**: slug, crow, fox (shoos hedgehogs, scatters bees, ignores
  snails). Everyone's problem.
- **The turn, simultaneous**: 1 Orders (each gardener sends one message:
  cards and where, critters and where to) → 2 The garden grows (sun and
  blossom paid, grow, wilt, spread, clouds lift) → 3 Critters walk (all
  moves together, shoos resolved) → 4 Wilds and the season. A minute live or
  a day by post; nobody waits.

## 6. What it needs from the house

- **A new room on the server.** `versus/online/match.gd` is two seats taking
  turns (a move, then the other's, a minute each, writes out of turn
  refused). This is four seats writing one order each and a resolve step once
  all four are in or a clock runs out. New rules, deployed by the user.
  Friends invites and the lobby carry over.
- **Camera and draw calls**: Tally's sheet already pans and zooms a field
  bigger than the screen and draws only the squares in view, batched. A
  400-plot map with clouds, plants and critters lives inside 855 draw calls
  the same way (`docs/agents/arcade.md`, Tally).
- **A computer gardener** for empty seats: a cheap order-writer that pushes
  toward the nearest resource and fences its den. Solo and two-player on the
  four-corner map both run with bots in the other corners.
- **House rules that bite**: renamed genre (the page may name the inspiring
  games once; the board never does, in code, UI or name); a house set, not
  stock pieces; owner by ring, never a shade of the piece's colour; world
  fills the screen; characters are code (`ui/faces/`); sounds are pops from
  `tools/sfx_bank`; text through locale keys.
- **Untuned, all of it**: map size, cloud reach, critter reach, blossom
  rates, twenty turns, the goal pack. Next step when picked up: a canvas mock
  played a few dozen times, then a spec in `docs/superpowers/specs/`.

## Open questions

- Hex (steps 2–3) or square plots (steps 4–5)? Square reads as the reference
  and gives 4-neighbour rules; hex gave better adjacency play. The stream
  read as stepping stones on squares.
- Should a scared wild still pay the scarecrow's owner in cards (finding 3),
  or should dens not spawn beside a scarecrow?
- Reveal reach: neighbours only, or two deep? Can a wild wander under cloud?
- Secret goals revealed at the end, or when completed?
- Name: "The Commons" is the working title; Allotment and Hedgerow are taken
  by steps A and B above.
