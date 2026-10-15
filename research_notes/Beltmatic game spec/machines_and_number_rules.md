# Beltmatic: every building, machine and number rule

Research date: 2026-10-15. Game: *Beltmatic*, Notional Games, Steam app 2674590, released 2024-03-29. Latest version as of 2026-10-15: **1.0.10, released 2026-04-18** (Steam news feed via the public ISteamNews API, fetched 2026-10-15). No patch note since release mentions any rate, cost, cap or balance change (full changelog in the "Versions" section), so the mid-2024 figures below are presumed still live; the one caveat is 1.0.10's unitemized "Various minor fixes".

Source quality legend used below:
- **Wiki** = beltmatic.fandom.com (community wiki, 24 pages; the Cloudflare wall blocks plain fetches, read through a browser). Pages carry no edit date on their face; the revision histories read 2026-10-15 show `Upgrades` last edited **2024-10-24**, `Levels` **2024-10-29**, `Extractor` **2024-07-21**. Its own Version History page stops at 1.0.7 (stale).
- **biggieblog** = "Building Number Factories in Beltmatic", biggiemac42, **2025-05-18**, a player's measured write-up; no game version named.
- **Steam guide** = "How to Play" by Supposer, posted 2024-12-25, updated **2025-12-16**. When fetched it showed a notice that it had been removed for violating Community guidelines and is visible only to its uploader, so it may disappear.
- **Dev** = Notional Games posting in a Steam discussion, **2024-08-27**.
- Steam discussions = dated player posts.

Rate semantics, stated once: every "X/s" for an operator means **operations per second = outputs per second**; one operation consumes one number from input A and one from input B (so 2X numbers/s go in), and the Divider emits two numbers per operation. A belt holds one number per tile, so tiles/s = numbers/s. Nothing in any source mentions a placement cost, currency or material for buildings: the only "cost" in the game is the upgrade requirements delivered to the Hub.

---

## Which buildings exist, with inputs, outputs, rate per tier and footprint

### Takeaway
There are exactly nine placeable things: Belt, Bridge, Extractor, Adder, Multiplier, Subtractor, Divider, Exponentiator, Storage, plus the fixed central Hub. There is no splitter, merger, balancer, underground belt, trash or void building: splitting and merging are done by belt junctions, buffering and balancing by Storage, and sinking by the Hub. All operators take exactly two inputs (A, B); only the Divider has two outputs.

### Cited Findings

**Inventory and unlock order**
- The unlock order is Belt and Extractor (from the start), then Adder, Belt Bridge, Belt Priorities, Subtractor, Divider, Exponentiator, Storage — [Steam guide, updated 2025-12-16](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619). (The guide's list omits the Multiplier in that sentence; its own processor table puts the Multiplier at level 7.)
- Wiki "Operators" page: operators are Adder (L1), Multiplier (L7), Subtractor (L13), Divider (L16), Exponentiator (L19); machines that "act on numbers but do not change their value" are Hub, Belt, Extractor, Bridge, Storage — [Wiki Operators](https://beltmatic.fandom.com/wiki/Operators).
- "Due to the fact that there are no built-in splitters within Beltmatic, to get an even output that is space efficient, the optimal route is to split the belt into 3 paths. The game will automatically split evenly between them" — [Wiki Adder](https://beltmatic.fandom.com/wiki/Adder).
- "Every arithmetic operation takes exactly two inputs and produces one output" (third-party review digest) — [vaporlens](https://vaporlens.app/app/2674590/beltmatic.md).
- Unlocking "all six buildings adds 18 numbers to track" (three upgrade numbers per building) — [plannedallalong, 2025-08-13](http://plannedallalong.blogspot.com/2025/08/quick-review-beltmatic.html).

**Belt** (unlocked from the start)
- Infobox: base speed 1/s, +1/s per level, level 8 speed 8/s, after level 8 +0.1/s per level — [Wiki Belt](https://beltmatic.fandom.com/wiki/Belt).
- Table: L1 1/s, L2 2/s, L3 3/s, L4 4/s, L5 5/s, L6 6/s, L7 7/s, L8 8/s, L9 8.1/s, L10 8.2/s, L11 8.3/s, L12 8.4/s, L13 8.5/s, L14 8.6/s, L15 8.7/s — [Wiki Upgrades, last edit 2024-10-24](https://beltmatic.fandom.com/wiki/Upgrades).
- Cap: "The max upgrade levels are 128 for belt, 12 for extractor and 108 for other buildings." — [Notional Games (developer), 2024-08-27](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660/).
- At cap: "Belt level 128 speed 20/s" — [neumann.emma12, 2024-09-21](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245).
- biggieblog: "At base level, each belt moves 2 tiles per second", a belt of 2.5 tiles/s is mentioned mid-game, and "A belt can move 8 tiles per second at this level" late — [biggieblog, 2025-05-18](https://biggieblog.com/building-number-factories-in-beltmatic/). Conflicts with the wiki's 1/s at L1; see Inferences (the achievement arithmetic says the wiki is right and biggieblog's "base" is belt level 2).
- Footprint: a belt occupies one tile per segment; numbers occupy one tile each ("Each tile holds one number") — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).

**Bridge** (level 4)
- "Bridges are way to cross two belts past each other without mixing their contents. They match whatever speed the belts are running at and have no direct upgrades." — [Wiki Bridge](https://beltmatic.fandom.com/wiki/Bridge). Its infobox says unlock level 0, but the Levels table and the Steam guide both put it at level 4 — [Wiki Levels](https://beltmatic.fandom.com/wiki/Levels); [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619).
- "Bridges are now automatically built when pasting belts over existing belts. Hold shift to prevent this behaviour." — [Steam news, 1.0.7, 2024-06-14](https://store.steampowered.com/news/app/2674590). "A bridge will not automatically be built if the lower belt intersects at the beginning or end of the belt being built" — [Wiki Bridge](https://beltmatic.fandom.com/wiki/Bridge).

**Extractor** (from the start; 3x3)
- "It has 12 sides, all of which will output the number being extracted. If the number of sides being used exceeds the max belts/s upgrade level, the extracted numbers will be distributed evenly across the total number of belts being used." Base 1 belt, +1 belt per level, level 8 = 8 belts, +1 belt per level after, "Max Level 12"; "all upgrades after the level 12 upgrade are pointless as there are only 12 usable sides" — [Wiki Extractor, last edit 2024-07-21](https://beltmatic.fandom.com/wiki/Extractor). 12 sides on a square = 3x3 (the infobox image is a 3x3 red square; biggieblog: an extractor spot is "a 3×3 darkened square around a single value").
- "the extractor doesn't extract 'X numbers/s', instead it is counted on fully saturated belts, whether those belts are running at 1/s or 10/s" — [Wiki Extractor](https://beltmatic.fandom.com/wiki/Extractor).
- "An extractor stops feeding a belt that is backed up and sends more to other belts"; an extractor at 8 belts yielded 64 values/s of 7s (so belts at 8/s) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).
- At cap: "Extractor level 12 speed 12 belts" — [neumann.emma12, 2024-09-21](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245); earlier "extractors lvl 12 - max" — [abrid, 2024-05-27](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245).
- In-game help text: "Build an EXTRACTOR over a white '1' on the map and connect it to the HUB using BELTS." — [Wiki Extractor](https://beltmatic.fandom.com/wiki/Extractor).

**Adder** (level 1; 2x2)
- Tile map from the wiki infobox image (read 2026-10-15): bottom row `[A][B]`, top row one wide `[A+B]` tile spanning both columns. "The inputs can come from either of the two faces of the 'A' and 'B' tiles, and the sum can be outputted from any of the four faces of the 'A+B' tiles." — [Wiki Adder](https://beltmatic.fandom.com/wiki/Adder). biggieblog: "The adder takes the shape of a 2×2 square" — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).
- Speeds (the only non-linear path): L1 0.25/s, L2 0.333/s, L3 0.4/s, L4 0.5/s, L5 0.667/s, L6 1/s, L7 1.5/s, L8 2/s, L9 2.02/s, then +0.02/s per level — [Wiki Upgrades](https://beltmatic.fandom.com/wiki/Upgrades). (The Adder infobox says ".025/s" base; the table row, biggieblog's "one addition every 4 seconds" at base, and the Steam thread below all say 0.25/s, so the infobox is a typo.)
- At cap: "Adder level 108 speed 4/s" — [neumann.emma12, 2024-09-21](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245).
- "The speed for both is 0.5/s. The adder would upgrade to 0.667/s, but the multiplier would upgrade to 0.6/s." — [thebigh, 2024-08-05](https://steamcommunity.com/app/2674590/discussions/0/4515506834333813461/) (matches the wiki's L4 to L5 rows exactly).
- Help text: "Build an ADDER, connect an EXTRACTOR to the inputs and connect the output to the HUB." — [Wiki Adder](https://beltmatic.fandom.com/wiki/Adder).

**Multiplier** (level 7; 1x3)
- Tile map from the infobox image: a single row `[A][A×B][B]`. "The inputs can come from either of the three faces of the 'A' and 'B' tiles, and the product can be outputted from any of the two faces of the 'AxB' tile." — [Wiki Multiplier](https://beltmatic.fandom.com/wiki/Multiplier). biggieblog: "a 3×1 rectangle" — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).
- Speeds: L1 0.2/s, L2 0.3, L3 0.4, L4 0.5, L5 0.6, L6 0.7, L7 0.8, L8 1/s, L9 1.02/s, then +0.02/s per level — [Wiki Upgrades](https://beltmatic.fandom.com/wiki/Upgrades). At cap "Multiplier level 108 speed 3/s" — [neumann.emma12, 2024-09-21](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245).

**Subtractor** (level 13; L-shape, 3 tiles)
- Tile map from the infobox image: `[A]` on top of `[A-B]`, with `[B]` to the right of `[A-B]`; the output tile is the corner of the L. "The inputs can come from either of the three faces of the 'A' and 'B' tiles, and the difference can be outputted from any of the two faces of the 'A-B' tile." — [Wiki Subtractor](https://beltmatic.fandom.com/wiki/Subtractor). biggieblog: "an L shaped piece".
- Speeds: shared upgrade path with the Divider ("Subtractor / Divider"): L1 0.2/s, +0.1/s per level to L8 1/s, then +0.02/s — [Wiki Upgrades](https://beltmatic.fandom.com/wiki/Upgrades). At cap "Sub/Div level 108 speed 3/s" — [neumann.emma12](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245). "Their upgrades are available initially at Level 13 when the Subtractor is unlocked, and begin affecting the Divider once it is unlocked at Level 16." — [Wiki Upgrades](https://beltmatic.fandom.com/wiki/Upgrades).

**Divider** (level 16; 2x2, two outputs)
- Tile map from the infobox image: top row `[A÷B][R]`, bottom row `[A][B]`. Text: "It takes in two inputs ('A' and 'B'), and outputs the quotient and remainder ('A÷B & R')." The page says A and B have "three faces" each, but in the 2x2 image every tile has two exposed faces; the sentence is copied from the 1x3 Multiplier page, trust the image — [Wiki Divider](https://beltmatic.fandom.com/wiki/Divider). biggieblog: "another square, and does division with remainder".
- "Because Dividers are the only operator with multiple outputs it has the unique property of being able to convert one number to another at a 1-to-1 rate." — [Wiki Divider](https://beltmatic.fandom.com/wiki/Divider).
- Divider output: "A÷B rounded down, plus remainder R (both outputs must be taken)" — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619).
- Speeds: the Subtractor/Divider path above (0.2/s base, 1/s at L8, 3/s at L108).

**Exponentiator** (level 19; L-shape, 3 tiles)
- Tile map from the infobox image: `[A]` top-right, `[B]` bottom-left, `[A^B]` bottom-right corner. "outputs the exponential product ('A^B') ... the order of the inputs matters greatly" ; inputs from "either of the three faces of the 'A' and 'B' tiles", output from "any of the two faces of the 'A^B' tile" — [Wiki Exponentiator](https://beltmatic.fandom.com/wiki/Exponentiator). biggieblog: "another L shaped piece".
- Speeds: own path, L1 0.2/s, +0.1/s to L8 1/s, then +0.02/s — [Wiki Upgrades](https://beltmatic.fandom.com/wiki/Upgrades). At cap "Exponentiator level 108 speed 3/s" — [neumann.emma12](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245).

**Storage** (level 22; 3x3)
- "allows you to store up to 10,000 of a single number. All 12 sides of the Storage can be either input or output, which is solely decided based on the direction of the belt that is connected to that side. There is no cap to the input or output speed. It is only limited by the quantity of stored numbers as well as the speed of the belt. All output belts coming from the Storage exit fully saturated, meaning it can act as a good buffer and belt balancing mechanism." Help text: "The STORAGE BUILDING stores up to 10,000 numbers. Use it as a buffer in your production lines. Numbers can be inserted and removed from any direction." — [Wiki Storage](https://beltmatic.fandom.com/wiki/Storage). biggieblog: "holds up to 10,000 values in a 3×3 box".
- The stored number is "set by the first number received" — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619).
- Storage can be emptied with the C ("Clear") hotkey, which removes numbers in an area including storage — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).

**Hub** (fixed, 6x6)
- "The Hub takes up a 6x6 (36) tile area and contains a total of 24 sides, all of which are inputs that can receive numbers from belts." — [Wiki Hub](https://beltmatic.fandom.com/wiki/Hub). The Steam guide says "up to 20 incoming belts" — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619); 24 is corroborated by biggieblog ("6×6 ... perimeter is 24 tiles ... 48 numbers every second" at 2/s) and by the achievement text below.

### Inferences
- The wiki per-level increments extrapolated to the developer-confirmed caps land exactly on the player-reported capped speeds, three independent sources agreeing: belt 8 + 120×0.1 = 20/s at L128; adder 2 + 100×0.02 = 4/s at L108; multiplier, sub/div and exponentiator 1 + 100×0.02 = 3/s at L108; extractor 12 belts at L12. The upgrade formulas are therefore: belt(L) = L for L ≤ 8, 8 + 0.1(L−8) for 8 < L ≤ 128; extractor(L) = L belts, L ≤ 12; adder(L) = {0.25, 0.333, 0.4, 0.5, 0.667, 1, 1.5, 2} for L = 1..8, then 2 + 0.02(L−8) to L108; the other four operators = 0.1(L+1) for L ≤ 7 (0.2 .. 0.8), then a +0.2 step to 1.0/s at L8, then 1 + 0.02(L−8) to L108. The infoboxes' "+0.1/s per level" with "Level 8 speed 1/s" is self-inconsistent (0.2 + 7×0.1 = 0.9); the Upgrades tables (L7 0.8/s → L8 1/s for Multiplier, Sub/Div and Exponentiator) are what the capped 3/s figure confirms, so the tables win.
- The belt L1 conflict resolves in the wiki's favour: the Achievements page says "Fast Delivery, Deliver 24 numbers per second: The earliest this can be achieved is at the start by having fully saturated Level 1 Belts on every side of the main hub" (24 sides × 1/s), and 48/s at level 2, 96/s at level 3 — [Wiki Achievements](https://beltmatic.fandom.com/wiki/Achievements). biggieblog's "base 2 tiles/s" and "48 numbers every second" is belt level 2, which costs only 200 ones and is reached within minutes.
- 12 sides on the Extractor and Storage and 24 on the Hub are the face counts of a 3x3 and a 6x6 square (4 × side length), which is why "20 incoming belts" in the Steam guide looks like a count of perimeter tiles (20) rather than faces (24).
- An operator's footprint is the number of tiles in its diagram: Adder 4, Multiplier 3, Subtractor 3, Divider 4, Exponentiator 3, Extractor 9, Storage 9, Hub 36. Each input tile accepts a belt on any of its free faces, and the output tile(s) emit on any free face, so a machine can be fed from several sides.

### Gaps
- No source states a placement cost or build limit for any building; "Upgrades cost no currency, only large quantities of up to three different numbers" is the closest statement — [plannedallalong](http://plannedallalong.blogspot.com/2025/08/quick-review-beltmatic.html). Treat buildings as free: not found explicitly.
- Whether buildings can be rotated into all four orientations is implied by the copy/paste/rotate tools ("Whole machine setups can be copied, pasted, and rotated" — [vaporlens](https://vaporlens.app/app/2674590/beltmatic.md)) but no page states the rotation rule for single machines.

---

## How each arithmetic machine combines its inputs, operand order, division, negatives, zero, overflow

### Takeaway
Each operation pops one number from A and one from B and emits A+B, A×B, A−B, floor(A÷B) with R = A mod B on a second output, or A^B (A is the base). Order matters for −, ÷ and ^; negatives are allowed and behave normally; a zero remainder is not emitted; values are 32-bit signed integers and an oversized result is replaced by 2,147,483,647.

### Cited Findings
- Adder: "outputs the sum ('A+B') ... the order of the inputs doesn't matter." — [Wiki Adder](https://beltmatic.fandom.com/wiki/Adder).
- Multiplier: "outputs the product ('AxB'). Due to the commutative property of multiplication, the order of the inputs does not matter." — [Wiki Multiplier](https://beltmatic.fandom.com/wiki/Multiplier).
- Subtractor: "outputs the difference ('A-B') ... the order of the inputs matters and negative numbers can result, although negative numbers are never required. They act just as normal negative numbers would in any mathematical operation." — [Wiki Subtractor](https://beltmatic.fandom.com/wiki/Subtractor).
- Divider: "outputs the quotient and remainder ('A÷B & R'). Due to the fact that it is a quotient, the order of the inputs matters." — [Wiki Divider](https://beltmatic.fandom.com/wiki/Divider); "A÷B rounded down, plus remainder R (both outputs must be taken)" — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619); "5÷2=2, with remainder of 1" — [plannedallalong](http://plannedallalong.blogspot.com/2025/08/quick-review-beltmatic.html).
- Zero remainder: "If the division has no remainder, it won't bother to make a 0 (even with space for it)." — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/). Corroborated: "if you are breaking the number down by dividing by 2 you'd get the expected 25353 r0 ... this division will not output the remainder of 0." — [Yugo2Slow, "Zero!", 2024-08-23](https://steamcommunity.com/app/2674590/discussions/0/4427688336540633246/).
- Division by zero: "Division by 0 is apparently fine and dandy, and will output 0 as the quotient and the dividing number as the remainder" — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/) ("the dividing number" is ambiguous between dividend and divisor on its own). Two player observations pin it to the dividend: "If you divide 0 by 50706 you will get 0 r 50706, very useable" in a post about halving 50706 (50706 ÷ 2 = 25353 r 0, the zero remainder not emitted) — [Yugo2Slow, 2024-08-23](https://steamcommunity.com/app/2674590/discussions/0/4427688336540633246/): the operands are {50706, 0} and the outputs (0, 50706), which is exactly A ÷ 0 → quotient 0, remainder A for A = 50706 (the sentence's word order reads as 0 ÷ 50706, but under ordinary modulus that would give R = 0, which the game never emits, so the player is describing 50706 with a zero divisor). And "I used dividers and their behavior of dividing by zero. In that case, I get 2 outputs: one that is counted and eventually blocked, a second that continues to trigger divisions, whose value conveniently is also zero" — [Lord Balder, 2024-11-05](https://steamcommunity.com/app/2674590/discussions/0/4548155824440414415/): 0 ÷ 0 → (0, 0), again R = A. Rule: **A ÷ 0 emits quotient 0 and remainder A** (both emitted, even when A = 0).
- Exponentiator: "outputs the product of number 'A' raised to the power of number 'B'" — [Wiki Operators](https://beltmatic.fandom.com/wiki/Operators); "A^B" — [plannedallalong](http://plannedallalong.blogspot.com/2025/08/quick-review-beltmatic.html). A is the tile at the top of the L, B the one at the left (infobox image, [Wiki Exponentiator](https://beltmatic.fandom.com/wiki/Exponentiator)).
- Caps: "Their maximum value is 2,147,483,647 and their minimum is -2,147,483,648, since they are internally stored with a 32-bit integer limit." — [Wiki Number](https://beltmatic.fandom.com/wiki/Number). "Any sufficiently large output is replaced by 2147483647, which is 2^31 – 1." and "In the negative direction, you get -2147483648" — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/). "Eventually the goal hits 2147483647, the limit of numbers in the game" — [thebigh, 2024-08-06](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660/).
- The Duplicator trick depends on the cap: multiply N by (X+1) then divide by X with X > N gives quotient N and remainder N; "a basic duplicator can only duplicate numbers less than the square root of 2^31 - 1 (<46340)" — [Wiki Duplicator](https://beltmatic.fandom.com/wiki/Duplicator). A level-1000 player used divmod by 45927 (9^4×7) and ×(6^6+1)/6^6 — [RdB, 2025-02-01](https://steamcommunity.com/app/2674590/discussions/0/597391520517097420/).
- Making zeros: "The easiest way is subtracting X-X" — [gotan, 2024-06-22](https://steamcommunity.com/app/2674590/discussions/0/4348869643731572205/).
- The Hub "deletes" numbers: numbers "can be created using extractors, stored using storage, and deleted by the hub" — [Wiki Number](https://beltmatic.fandom.com/wiki/Number).

### Inferences
- The integer model is signed 32-bit with saturation at the top (biggieblog says "replaced by", not wrapped). Multiplication and exponentiation past 2^31−1 therefore clamp.
- Division is integer with quotient and remainder as separate items; both outputs are produced in one operation, so the Divider's throughput is "X/s" operations but up to 2X numbers/s out. The zero-remainder rule means a divisible pair produces one item, not two.
- Hidden operator semantics (A is always the tile labelled A, B the tile labelled B) are fixed by the machine's shape, so operand order is a placement/rotation decision, not a timing one.

### Gaps
- Exponent edge cases are not found anywhere: 0^0, A^0, 0^B, negative base, negative exponent, and whether exponent overflow clamps like multiplication. biggieblog explicitly says "I also never played around with 0, negative numbers".
- Division with a negative operand: floor vs truncation toward zero, and the sign of R, not found.
- Whether the low end saturates or wraps: not found (biggieblog only reports reaching −2147483648).
- The divide-by-zero rule rests on one blog sentence and two player anecdotes read against their own arithmetic; no developer statement found. If Yugo2Slow's sentence is read literally (0 ÷ 50706), it would instead mean R = B whenever A = 0, which no other source supports.

---

## Extractors: which numbers, where numbers sit on the map, map layout

### Takeaway
The map is a seeded, effectively infinite square grid with the 6x6 Hub at the centre; number deposits ("spots", 3x3 marked squares) surround it, 1s nearest and larger values farther out, every integer 1..999 except 10. Which value an extractor may extract is gated by Hub level ("Extraction N" rewards), not by distance.

### Cited Findings
- "The Map, or the playing area, is a seemingly infinite spanning grid with the Hub located at the center. Surrounding it and moving outwards are various numbers that can be extracted. The numbers start out at 1 and progressively get larger the farther away from the hub. All numbers that can be extracted will not exceed 999. There will also be no number 10's as those would make the game much easier. The map uses a seed to randomly generate the numbers and their locations" — [Wiki Map](https://beltmatic.fandom.com/wiki/Map).
- "The map is an infinite square grid ... Extractors work only on specific spots, marked by a darkened 3×3 square around a single value. The densest extractable 1s and 2s are near the hub. The nearest 11 may be about 500 tiles away." — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).
- Extractable set: "[1-9][11-999], or all positive integers between 1 and 999, excluding 10"; "By the time you reach Level 30 (the end of meaningful progression), you are able to extract 23s" — [Wiki Extractor](https://beltmatic.fandom.com/wiki/Extractor).
- Steam guide's level-to-max-number table: level 3 → 2, 5 → 3, 6 → 4, 8 → 5, 9 → 6, 11 → 7, 12 → 8, 14 → 9, 15 → 11, 17 → 12 — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619). Matches the wiki Levels table (below).
- Wiki Levels rewards: L3 Extraction 2, L5 3, L6 4, L8 5, L9 6, L11 7, L12 8, L14 9, L15 11, L17 12, L18 13, L20 14, L21 15, L23 16, L24 17, L25 18, L26 19, L27 20, L28 21, L29 22, L30 23, L31 24, L32 25, L33 26, L34 27, L35 28, L36 29, L37 31, L38 32, L39 33, L40 34; "Starting at Level 23, the reward can be calculated as Extraction (Level # - 7) ... the theoretical max level that has a reward is Level 1006, where you would unlock Extraction 999." — [Wiki Levels, last edit 2024-10-29](https://beltmatic.fandom.com/wiki/Levels).
- Earlier versions of the game used a hex grid: "The grid changed from hexagonal to square" (sequel to the dev's earlier Beltex) — [vaporlens digest](https://vaporlens.app/app/2674590/beltmatic.md).
- "Numbers 1–9 can be extracted directly. 10 is not available and must be built." — [vaporlens digest](https://vaporlens.app/app/2674590/beltmatic.md).
- Extractors can be copied and re-targeted: "Configurable number generators can be copied and adjusted to output different values" — [vaporlens digest](https://vaporlens.app/app/2674590/beltmatic.md) (a review paraphrase, low confidence).

### Inferences
- Extraction unlocks are per value, by Hub level: at any level the set of extractable values is {1..N} minus 10 where N is the latest "Extraction N" reward; the deposits exist on the map before they are unlocked (the help text says to build over a "white 1"; unused spots can have belts laid over them).
- Because value 10 is never a deposit, the first "10" must be built (e.g. 5+5 or 2×5), which is the game's deliberate wrinkle for decimal-digit machines.

### Gaps
- Deposit density, spacing, cluster size and the radial function mapping value to distance are not published anywhere found; only biggieblog's single anecdote ("nearest 11 ~500 tiles away").
- The Levels table skips Extraction 30 (L36 → 29, L37 → 31) while the Extractor page says every integer 11..999 is extractable; whether 30 is also absent from the map or the table has a typo is unresolved.
- The developer's "max hub level is 1000" (2024-08-27) contradicts the wiki's "theoretical max level 1006"; the developer statement is primary.

---

## Belt mechanics: throughput, queueing, blocking, merging, splitting, corners, crossings, priorities

### Takeaway
A belt tile carries one number; speed is the belt upgrade level in tiles/s (1/s at L1, 8/s at L8, 20/s at L128). Junctions merge round-robin and split evenly; a priority flag on one arm of a junction makes it win and others fill the gaps; a belt crossing another becomes a Bridge unless Shift is held, in which case it is a mixing cross. Belts back up when the downstream is full and extractors skip backed-up belts.

### Cited Findings
- "When two or more belts intersect ..., each belt at an intersection will cycle through which belt is feeding the main belt (assuming all belts have numbers waiting to move). This means that all belts have an equal distribution onto the main belt." — [Wiki Belt](https://beltmatic.fandom.com/wiki/Belt).
- "Multiple inputs to a space alternate, and so do multiple outputs." — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619).
- Junction types (wiki): Corner (front end of a new belt joins the back end of another: one continuous turning belt); T (a belt runs past the back end of another: "can either join two belts together, or split their contents evenly between all belts depending on the direction of the belts"); a cross made while holding Shift ("can either join three belts together, or split their contents evenly between all belts"); two opposed aligned belts meeting on a perpendicular belt ("will mix the contents of two belts evenly between the two"); crossing without Shift makes a Bridge ("no real intersection is made") — [Wiki Belt](https://beltmatic.fandom.com/wiki/Belt). (The page's "Split Intersection" and "Plus (+) Intersection" paragraphs are swapped relative to their headings; the behaviours are as quoted.)
- Priorities (level 10): "At any intersection, you can change the priority of the belt by left clicking on that intersection, which will apply a small green diamond. When toggling on a belt as the highest priority, any numbers flowing across it will be prioritized and any gaps in that belt will be filled by other available belts. Only one belt in an intersection can be marked as priority." In-game text: "Set input/output PRIORITIES for belt intersections by clicking the belt direction. Click again to remove the priority." — [Wiki Belt](https://beltmatic.fandom.com/wiki/Belt). "Priorities unlock at level 10 and send numbers preferentially down one exit of a junction." — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619).
- Blocking: an operator "refuses to act if an input is over capacity, and a clogged output stalls it"; "An extractor stops feeding a belt that is backed up and sends more to other belts" — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).
- Machine buffers: "Each input buffers up to 5 numbers ... an unconnected output holds 2 numbers" — [Steam guide, updated 2025-12-16](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619); "A component can only hold 4 values in each input, and 2 values in each output." — [biggieblog, 2025-05-18](https://biggieblog.com/building-number-factories-in-beltmatic/); "Each operator has a storage of 4 for each inputs and 2 for the output." — [Lord Balder, 2024-11-05](https://steamcommunity.com/app/2674590/discussions/0/4548155824440414415/). Two in-game observers say 4, the guide says 5.
- Output distribution: "Outputs split evenly across outgoing belts" — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619).
- Building belts: drag between grid spaces; L-shaped placement mode (added 1.0.3, default since 1.0.10); "Holding alt now reverses the belt direction when building belts" (1.0.10) — [Steam news feed](https://store.steampowered.com/news/app/2674590); [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619).
- Throughput measured by players: a whole-factory belt "100% saturated" after 8 minutes for a slow design vs 75 s for a fast one (2024-07-12) and "a full belt is now reached after like 5 numbers" (2024-11-05) — [Lord Balder](https://steamcommunity.com/app/2674590/discussions/0/4548155824440414415/); a 1024× duplicator "at 20/s" and hub intake "at 480/s" (24 belts × 20/s) — [RdB, 2025-02-01/08](https://steamcommunity.com/app/2674590/discussions/0/597391520517097420/).
- Four base adders consume one level-2 belt exactly (an L1 adder at 0.25 ops/s eats 0.5 numbers/s in total, 0.25 from each side; four of them = 2/s = one 2/s belt: "one addition every 4 seconds") — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).

### Inferences
- A simulation model consistent with every source: belts are FIFO lanes of one item per tile advancing at `speed` tiles/s; an item advances only if the next tile is free; a junction tile with k feeding belts takes from them round-robin among those that have an item ready (priority arm first if flagged, others fill gaps); a tile with k outgoing belts hands items out round-robin among those with room. Operators have an input queue per side (4, possibly 5) and an output queue of 2 per output tile; an operation starts when both inputs are non-empty and the output queue has room, takes 1/speed seconds, and pushes the result(s); outputs drain round-robin onto connected belts. Extractors emit on each connected face at belt speed up to `level` belts' worth, skipping full belts. The Hub consumes instantly.
- The hub cap is 24 × belt speed: 24/s at L1, 48/s at L2, 96/s at L3, 192/s at L8, 480/s at L128.

### Gaps
- Exact in-engine tick model (continuous vs. discrete tile steps) and whether belt speed is uniform at corners: not found.
- Whether the input buffer is 4 or 5 in version 1.0.10: unresolved (4 from two in-game testers in 2024-11 and 2025-05; 5 from a guide last edited 2025-12).
- Input-buffer behaviour of the Hub (instant sink is inferred, not stated).

---

## Machine rates per tier and exact upgrade multipliers, plus upgrade requirements

### Takeaway
Upgrades are additive, not multiplicative: belts +1/s per level to 8 then +0.1/s to 128 (20/s); extractors +1 belt per level to 12; adder a hand-tuned curve to 2/s at L8 then +0.02/s to 108 (4/s); multiplier, subtractor/divider (one shared path) and exponentiator +0.1/s to 1/s at L8 then +0.02/s to 108 (3/s). Each level costs up to three distinct target numbers delivered to the Hub in stated counts; the numbers are randomised per save, the counts are not; surplus carries over.

### Cited Findings
- "Upgrades ... require a specific quantity of 1, 2, or 3 unique numbers ... Level 1: One unique number. Level 2: Two unique numbers, the unique number from Level 1 is the same, but requires more quantity. Level 3: Three unique number ... Levels 4+: A new number is added in the far right column and all numbers are 'shifted' to the left, meaning the oldest number is removed. As each number is shifted leftwards, the quantity required increases." "There are an unlimited number of upgrades, but only the first 8 are tied to progression or achievements." "Any amount of numbers stored in the hub that go over the required amount for a specific upgrade are carried over to the next upgrade stage ... E.g. If you store 6k 75s on Adder Level 3 when only 3k were needed, once you progress to the next level, you will be 'credited' the extra 3k." "The actual number that is required ... is randomized within a small range ... your number may differ slightly, but the count will be the same." — [Wiki Upgrades, last edit 2024-10-24](https://beltmatic.fandom.com/wiki/Upgrades).
- "Upgrades add flat increases to speed and efficiency rather than multiplying them." — [vaporlens digest](https://vaporlens.app/app/2674590/beltmatic.md). "Some upgrades keep going seemingly forever, but with extremely diminished returns after their eighth upgrade level" and "+0.025/s per level pretty early into their tiers" — [Kyouko Tsukino, 2024-08-05](https://steamcommunity.com/app/2674590/discussions/0/4515506834333813461/). "Level 8→9 on the adder gave about 1%" and one exponentiator tier "about 2%" — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/) (2.02/2 = 1%, 1.02/1 = 2%: exact matches to the wiki table).
- Caps: belt 128, extractor 12, others 108; hub level 1000 — [Notional Games, 2024-08-27](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660/).
- Requirement tables, one save, counts exact, the specific numbers randomised (format: level → speed; req1 number×count, req2, req3; next speed) — [Wiki Upgrades](https://beltmatic.fandom.com/wiki/Upgrades):
  - Belt: L1 1/s; 1×200 → 2/s. L2; 1×1k, 16×500 → 3/s. L3; 1×4k, 16×3k, 22×1.5k → 4/s. L4; 34×9k, 121×7k, 839×6k → 5/s. L5; 94×9k, 247×7k, 562×6k → 6/s. L6; counts 11k, 9k, 8k → 7/s. L7; 854×15k, 1526×12k, 7891×10k → 8/s. L8; 1526×20k, 7891×16k, 4294×12k → 8.1/s. L9; 8966×20.5k, 1697×16.5k, 9240×12.5k → 8.2/s. L10; 21k, 17k, 13k → 8.3/s. L11; 21.5k, 17.5k, 13.5k → 8.4/s. L12; 1862×22k, 2263×18k, 4519×14k → 8.5/s. L13; 2263×22.5k, 4519×18.5k, 2378×14.5k → 8.6/s. L14; 23k, 19k, 15k → 8.7/s.
  - Extractor: L1 1 belt; 2×300 → 2. L2; 2×2k, 18×1k → 3. L3; 2×5k, 18×2k, 23×1k → 4. L4; 16×8k, 22×3k, 438×2k → 5. L5; 89×10k, 378×4k, 787×3k → 6. L6; 291×12k, 791×8k, 2319×4k → 7. L7; 791×15k, 2319×12k, 7774×6k → 8. L8; 2319×20k, 7774×17k, ?×20k → 9 belts.
  - Adder: L1 0.25/s; 3×450 → 0.333. L2; 3×3k, 11×1.5k → 0.4. L3; 3×5k, 11×4k, 75×3k → 0.5. L4; 11×7k, 91×5k, 193×4k → 0.667. L5; 91×12k, 193×10k, 625×5k → 1. L6; 193×15k, 625×12k, 3447×8k → 1.5. L7; 625×20k, 3447×17k, 9423×10k → 2. L8; 3447×30k, 9423×20k, 44031×16k → 2.02/s.
  - Multiplier: L1 0.2/s; 15×500 → 0.3. L2; 15×5k, 20×2.5k → 0.4. L3; 15×10k, 20×7k, 257×4k → 0.5. L4; 20×11k, 257×6k, 690×5k → 0.6. L5; 257×17k, 690×13k, 3644×6k → 0.7. L6; 690×22k, 3644×17k, 6433×10k → 0.8. L7; 3644×35k, 6433×25k, 49514×17k → 1. L8; 6433×37k, 49514×30k, 97001×20k → 1.02/s.
  - Subtractor/Divider (shared): L1 0.2 → 0.3 → 0.4 → 0.5 (L1–L3 requirements blank on the wiki). L4; 147×13k, 640×8k, 3103×6k → 0.6. L5; 640×24k, 3103×16k, 8118×8k → 0.7. L6; 3103×32k, 8118×21k, 30870×13k → 0.8. L7; 8118×43k, 30870×33k, 61589×26k → 1. L8; 30870×50k, 61589×40k, 227887×30k → 1.02/s.
  - Exponentiator: L1 0.2/s; 64×800 → 0.3. L2; 64×7k, 187×4k → 0.4. L3; 64×10k, 187×6k, 983×4k → 0.5. L4; 187×15k, 983×9k, 4563×7k → 0.6. L5; 983×29k, 4563×18k, 5684×9k → 0.7. L6; 4563×37k, 5684×25k, 6605×15k → 0.8. L7; 5684×40k, 11067×35k, 92927×26k → 1. L8; 11067×60k, 92927×50k, 8312675×40k → 1.02/s.
- The Upgrades window "lists each upgrade with up to three required numbers. Its build button activates once those numbers are delivered." — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619).
- "At most 19 targets can be active: 3 per upgradable component and 1 for overall level" and "Values are reusable for component upgrades only three times each" — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).
- Player-observed late-game levels: "belts lvl 33, extractors lvl 12 - max, adders lvl 30, multipliers lvl 26" — [abrid, 2024-05-27](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245).

### Inferences
- The required-number sequence per upgrade path is a sliding window of three over one growing list of numbers (each level introduces one new, larger number on the right), which is why the same numbers recur in three consecutive levels and why biggieblog says each value is useful "three times".
- Upgrade requirement numbers grow roughly geometrically within a path (Exponentiator L8 asks for 8,312,675 × 40k), which is the content that keeps high-level play going past level 30.

### Gaps
- The randomisation band for requirement numbers is "a small range" with no stated width.
- Requirements beyond level 9 for operators and level 15 for belts are not published (wiki stops; "unlimited" upgrades).
- The first three Subtractor/Divider levels' requirements are missing from the wiki.

---

## The Hub: targets, counts, wrong numbers, level progression

### Takeaway
The Hub is a 6x6 sink with 24 input faces. Each level names one target number and a count; delivering that count levels up and grants a reward (a building, Belt Priorities, Storage, or a new extractable value). Targets after the first few are random within a band that grows roughly 5–95 % (average ~8.7 %) per level; the hub counts every number delivered, for level targets and for the up-to-18 upgrade targets at once.

### Cited Findings
- "All sides of the Hub are inputs and all numbers that are added to it contribute progressing in levels and upgrades ... the current number required, the current/total quantity required, as well as the next level unlocks are shown on the Hub." Help text: "The objective is [to] deliver numbers to the HUB to reach [the] next level." — [Wiki Hub](https://beltmatic.fandom.com/wiki/Hub).
- Level table (target ~number, count, reward): L1 1×10 Adder; L2 2×20; L3 3×35 Extraction 2; L4 5×40 Bridge; L5 10×50 Extraction 3; L6 19×100 Extraction 4; L7 27×150 Multiplier; L8 36×300 Extraction 5; L9 47×450 Extraction 6; L10 50×500 Belt Priorities; L11 82×600 Extraction 7; L12 174×800 Extraction 8; L13 248×1k Subtractor; L14 324×2k Extraction 9; L15 466×3k Extraction 11; L16 594×4k Divider; L17 631×5k Extraction 12; L18 727×6k Extraction 13; L19 891×7k Exponentiator; L20 928×8k Extraction 14; L21 1779×9k Extraction 15; L22 2805×10k Storage; L23 3366×10.5k Extraction 16; L24 4860×11k; L25 5445×11.5k; L26 6667×12k; L27 7512×12.5k; L28 8133×13k; L29 9646×13.5k; L30 10904×14k Extraction 23; L31 12675×14.5k; L32–L40 count 14.5k each with targets 14772, 18962, 20158, 23431, 24755, 27432, 29296, 32550, 35541. "The actual number ... is randomized within a small range. The difference from one level to the next, starting by about Level 10, is between 5% more and 95% more from the previous number." "you can click on the Levels icon and see the next 15 required numbers (but not their count)" — [Wiki Levels, last edit 2024-10-29](https://beltmatic.fandom.com/wiki/Levels). The Steam guide says the Delivered Numbers window shows "the requirements for the next 12 levels" — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619).
- "Target values are randomized. Levels 1–3 always ask for 1, 2, and 3. Two-digit targets vary between playthroughs. Level 2 requires shipping 10 copies of 1 and unlocks the adder" (biggieblog's count for level 1/2 differs from the wiki's 10/20; see Gaps) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).
- "They are randomly picked, most likely within a set range per level" — [Kyouko Tsukino, 2024-08-06](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660/); "average for these is 8.7% increase per level" — [Proton, 2024-08-13](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660/); "The max hub level is 1000" — [Notional Games, 2024-08-27](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660/).
- Each level "asks for a specific number, usually prime or one or two operations away from one" — [plannedallalong](http://plannedallalong.blogspot.com/2025/08/quick-review-beltmatic.html).
- Late game: "the game never requested more than 10^8" and a level-1000 run delivering "10 target numbers per level" with a 24-belt intake at 480/s — [IridiumMika, 2025-02-04; RdB, 2025-02-01](https://steamcommunity.com/app/2674590/discussions/0/597391520517097420/). (Counts stay at 14.5k per the wiki; "10 target numbers per level" there refers to the player's own batching, not a requirement.)
- The Delivered Numbers window shows delivery rates per second, minute or hour; "The delivery screen lists current hub values and their purposes"; "A value can become useless when the overall level requirement changes." — [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619); [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/).
- Achievements (Steam, 10 total): deliver 10K / 100K / 1M numbers lifetime per save; reach level 10 / 20 / 30; deliver 24 / 48 / 96 numbers per second; "Reasonably Upgraded: Reach level 8 on all upgrades" — [Wiki Achievements](https://beltmatic.fandom.com/wiki/Achievements).

### Inferences
- A wrong (non-target) number delivered to the Hub is simply consumed: the Number page says numbers are "deleted by the hub", and the Delivered Numbers screen lists "current hub values and their purposes", so the Hub keeps a tally per value and any value not currently needed is counted but useless (biggieblog's "a value can become useless"). No source says it is refused or penalised.
- Level targets are chosen from a band that grows geometrically (~1.05–1.95× per level, 1.087× mean) from a seed, with fixed counts per level that plateau at 14.5k from level 31; 1000 levels of ~8.7 % growth would overrun 2^31 near level 180 (Proton's estimate), yet the level-1000 player saw targets no larger than 10^8, so the generator must cap or slow its growth; the rule is not published.

### Gaps
- Whether the Hub rejects, discards or stores non-target numbers is never stated outright (inference above).
- Level 1 count: wiki says 1×10, biggieblog says level 2 needs "10 copies of 1" and unlocks the adder; wiki says the Adder is the Level 1 reward (and the Steam guide agrees Adder is unlocked at level 1). biggieblog's off-by-one is probably reading "Level 1" as the level you are on while delivering; unresolved.
- The target-selection formula past level 40 (band, cap, prime bias) is not found.

---

## Versions, dates and what changed since release

### Takeaway
Ten patches since 2024-03-29, none touching rates, caps or numbers; the latest is 1.0.10 (2026-04-18).

### Cited Findings
- Full changelog from the Steam news feed (ISteamNews API, fetched 2026-10-15) — [Steam news hub](https://store.steampowered.com/news/app/2674590):
  - 1.0.10, 2026-04-18: holding Alt reverses belt direction when building; L-shaped mode changes primary direction when fully horizontal/vertical; L-shaped placement on by default on new installs; "Increased the max size of the selection rectangle"; "Various minor fixes" — [post](https://store.steampowered.com/news/app/2674590/view/755057297411015160).
  - 1.0.9, 2024-08-29: "Optimized graphics performance" — [post](https://steamcommunity.com/games/2674590/announcements/detail/6240387642454426737).
  - 1.0.8, 2024-08-02: undo/redo, history 1000 actions — [post](https://steamcommunity.com/games/2674590/announcements/detail/5963413728339330304).
  - 1.0.7, 2024-06-14: automatic bridges when pasting belts over belts (Shift to prevent) — [post](https://steamcommunity.com/games/2674590/announcements/detail/6890025005352536761).
  - 1.0.6, 2024-06-08: upgrade tutorial message placement fix; faster loads for large saves.
  - 1.0.5, 2024-06-05: "Fixed buildings sometimes stopping production".
  - 1.0.4, 2024-05-31: DirectX 10 level hardware support.
  - 1.0.3, 2024-05-27: option for L-shaped belt placement mode.
  - 1.0.2, 2024-05-23: delivery achievements fix.
  - 1.0.1, 2024-05-11: pipette fix.
- SteamDB records the public branch last updated 2026-04-18 — [SteamDB depots](https://steamdb.info/app/2674590/depots/).
- The wiki's Version History ends at 1.0.7 — [Wiki Version History](https://beltmatic.fandom.com/wiki/Version_History).

### Inferences
- Every numeric figure above that was recorded between 2024-05 and 2025-12 applies to 1.0.10 unless "Various minor fixes" changed something silently.

### Gaps
- No itemisation of 1.0.10's "minor fixes".
