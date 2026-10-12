# Trivet: the thirteenth Arcade game

2026-10-12. Built unattended. The user, of a screenshot of a browser game:
"is the next arcade game to be created, check any reference you need on
web, wire everything even sound, do autonomous, no questions. Cozy
animations, good animations on key events, satisfactory sounds on combos".

## 1. What it follows, and what it may not be

The reference is the stacking genre sold as *Hexa Sort* (many apps and
portal games share the name and the rules). **That name is written here
once, to forbid it**: it appears nowhere in code, comments, commits, locale
or on screen, and neither does a word made from it. Nothing of any of them
is here: no art, sound, text, code or number. The rules were read from the
screenshot, from portal and store descriptions, and from a 2026 paper that
formalises the game on a graph (a stack placed on an empty vertex, the
matching neighbours moving onto one stack, a stack of the threshold
vanishing).

What is kept is the shape: **a tray of six-sided places, a hand of three
stacks, tops that match gathering into one stack, ten of a colour put
away, the tray full ending the run, and a score that opens levels and
places.** What is not: the plastic chips and grey board, coins that buy a
place, a level that ends and starts a new board, timers, and lives.

## 2. The game

**Trivet**: felt mats (the kind set under a hot pot) sorted into stacks on
a wooden tray, on a table under a lamp. A run for a score, like Beeline or
Deckchair: `Record.add("trivet", score, level)`, gold for the run, the
Second chance once.

- The tray is every place within two of the middle: 19. The six corners
  start under a wooden lid; 13 are open.
- The hand is three stacks on a cloth at the foot. One is carried to an
  empty place (or tapped, then the place is). When all three are down the
  next three come.
- **Gathering.** After a stack is set down, the stacks that touch one
  after another with the same colour on top hand those mats to one of
  them: the one of the fewest colours, then the one with the most of that
  colour on top, then the one just touched. So a stack of one colour takes
  the others' and what was under them is uncovered. Each stack hands its
  mats to the one a step nearer, the furthest first.
- **Putting away.** Ten or more of one colour on a stack's top go: a point
  a mat. What is uncovered gathers in its turn, and the second stack one
  move puts away counts double, the third three times.
- **Levels.** The score that ends level L is `10 * L * (L + 3)`: 40, 100,
  180, 280, 400. One run, one tray; a level changes nothing on it but:
  a lid lifted at levels 2, 3, 5, 6, 8 and 9 (a corner at random), a
  colour more at 2, 4 and 7 (three at first, six at most), and a tool: a
  brush at an even level, a fresh hand at an odd one, nine of each at most.
- **The tools.** A run starts with one brush (tap it, then a stack: the
  stack is taken off, nothing scored) and one fresh hand (three new stacks
  for the three held).
- **The end.** The tray full with a brush held is not the end: the brush
  must be used. Full with none, the run is over. The Second chance takes
  the four tallest stacks off.
- A stack offered is two to six mats in one, two or three runs of colour;
  more of the mixed ones as the levels go.

## 3. The numbers

`tests/_probe_trivet.gd`, 200 runs each: a bot setting stacks at random
ends at a median of 94 stacks, 278 points, level 4; one that sets each
stack beside the most mats of its top colour at 215 stacks, 763 points,
level 8 (best 2,865 and level 16). A chain of two is common, of three
rare.

## 4. The screen

The table is the whole screen (the house's pattern since 2026-10-10): the
planks run edge to edge, the top bar and three plates (score, best, the
level with the score over its goal) lie over them, the tray is in the
middle under a pool of lamplight and the cloth with the hand at the foot.
The two tools are round buttons on the left of the cloth, clear of the
right thumb.

A mat is a six-sided piece of felt seen from a little above, with a mark
pressed into its top, one a colour (a dot, a ring, a triangle, a diamond,
a cross, three dots), so no colour is told by hue alone. Two or more of a
colour on top wear a cream button with their count. No state is a shade
of a mat: the place a carried stack would take is a cream halo, a tight
tray rings its last places in amber, an armed brush rings the stacks.

`arcade/trivet_sim.gd` is the rules as data and tells a move as events;
`arcade/trivet_board.gd` is the table as its own Control, playing those
events one after another on its clock and saying `beat` as each is shown;
`arcade/trivet_screen.gd` is the chrome, the sound and the cards;
`ui/hud/trivet_tutorial_diagram.gd` is the table with a scripted hand.

## 5. Moments, sound and feel

- A stack lifted leans into the way it is taken and stands larger; set
  down, it swells and settles and a ring leaves its place.
- Mats hop one after another, 0.07 s apart, turning over at the top of
  the hop; the stack they land on swells with each. Their tick climbs
  half a semitone a mat, to five semitones.
- A stack put away swells for a fifth of a second, then its mats lift off
  from the top one by one and fade; a ring in its colour, motes of it
  home to the score, and its points lettered where it stood.
- The second stack of a move: "Double!", stars, a longer run of notes;
  the third: "Triple!" over a sunburst, the longest.
- A level: its number over a sunburst, what it brought in a line under
  it, a lid lifted off its corner turning.
- Two places left: they ring in amber, two slow notes down. The run over:
  the stacks sink one after another, two low knocks, then the card.
- Sounds: eighteen cues from the three kept takes (a button on felt, a
  hollow block, one muffled kalimba note), no new take, 0 flagged by the
  measure. Ticks for what repeats, notes for the moments, nothing above
  five semitones of climb.
- Haptics: a tap as a stack is set down, the echo of each mat's tick, a
  small yes for a stack put away and for a level, the win's knock for a
  chain, a warning for a tight or full tray and a tool that is out.
- Under reduce motion every hop and lift is instant and nothing rings.

## 6. Calls that are mine, the user's to change

1. The name, and that the pieces are felt mats on a wooden tray.
2. One endless run with levels inside it, where the reference ends a
   board at its goal and starts another.
3. Which stack takes the mats (the fewest colours first).
4. Points doubled and tripled for a chain.
5. Lids on the six corners opened by levels, not bought.
6. Two tools, earned a level at a time, and that a full tray with a brush
   held is not the end.
7. Three colours to six; the marks on the mats; the count on a stack.
8. Tap-then-tap as a second way to set a stack down.
9. Two gold boosters (two more brushes, two more fresh hands, 120 gold
   each) and what the Second chance does.
10. **The Arcade tab is paged**: eight cards a page, turned by two
    chevrons in the gold strip. Thirteen cards are seven rows of two and
    do not fit a phone even with the pictures a strip.
11. Every number.
12. No concept tab first (as with Griddle: "do autonomous, no questions").
