# Beltmatic: progression loop, levels, upgrades and economy

Research date: 2026-10-15. Beltmatic (Steam app 2674590) by Notional Games, released 29 Mar 2024, Windows only, sequel to Beltex (8 Jul 2022). All numbers below carry the date of the post they come from; the game's latest confirmed build is Version 1.0.10 (see "Version" under the endgame section). No official wiki exists; r/beltmatic exists but could not be fetched (403, one post seen through a mirror listing), and HowLongToBeat, SteamDB patch notes and speedrun.com all refused the fetch (403). The sources that carried real numbers are two Steam discussion threads with a developer reply, one Steam guide, one long blog post and the Steam achievements page.

Reading note on sources: the Steam guide "How to Play" by Supposer (posted 25 Dec 2024, updated 16 Dec 2025) served its content but the page carries a notice that it was removed for violating community guidelines and is visible only to its owner; it may vanish. The blog post by biggiemac42 (18 May 2025, ~10 h played, all achievements) is the only first-hand walkthrough of the loop with figures.

## How a level works (target N, deliver K to the hub)

### Takeaway
A level is one target number shown on the hub; the player must deliver a required count of that exact number, then the hub picks the next target and the count resets. The only published count is 10 copies of "1" for level 1 to 2; how the required count scales afterwards was not published anywhere found.

### Cited Findings
- The hub is a large blue box at the map centre showing "the levelling number (large, white), delivered/required (green), current level, and next-level rewards"; it "accepts numbers from up to 20 ingoing belts at once"; reaching a level triggers a transparent white circle across the map and a sound (guide, 25 Dec 2024 / upd. 16 Dec 2025) — [Supposer, How to Play](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- "The hub is a 6×6 blue rounded box in the center of an infinite square grid"; "At the start, you need to make 1. After you ship 10 copies of 1, you reach level 2" (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Hub perimeter is 24 tiles; with base belts at 2 tiles/s "the hub's maximum delivery is 48 numbers per second" (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/); the guide's "up to 20 ingoing belts" (Dec 2024) disagrees with the blog's 24-tile perimeter — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- "I needed to make 335 to upgrade my overall level", and after reaching that level "the requirement changed to 435", making the stock of 335s useless: a target is one number per level, and leftover deliveries of an old target count for nothing (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- The Delivered Numbers window "shows required numbers for the next 12 levels", so upcoming targets are known in advance within a save (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- The Delivered Numbers window lists numbers currently delivered and their speed; yellow entries count toward levelling, upgrade-linked numbers are listed next, the rest are idle; speed units cycle per second / minute / hour (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Official store text: "deliver numbers to the hub to reach the next level and unlock new buildings and upgrade them" — [Steam store page](https://store.steampowered.com/app/2674590/Beltmatic/)
- Achievements for throughput: "Fast Delivery: Deliver 24 numbers per second" (58.7% of players), "Faster Delivery: 48/s" (37.1%), "Fastest Delivery: 96/s" (17.4%) (read 2026-10-15) — [Steam achievements](https://steamcommunity.com/stats/2674590/achievements)

### Inferences
- 96/s as the top delivery achievement is consistent with a 24-tile hub perimeter at a doubled belt speed (24 × 4/s), which weakly favours the blog's 24 over the guide's 20.
- Since the hub displays "delivered/required" as a pair and the window lists 12 future targets, the required count is a per-level value stored with the save, not a running total. Whether it is a constant 10 or grows is unknown (see Gaps).

### Gaps
- Required delivery count per level beyond level 1 (10): not found. No source gives a second data point, so it cannot be said whether K is constant, scales with level, or scales with the target's size.
- Whether a level can ever ask for more than one target number: no source describes one, and the hub UI shows a single levelling number, but nobody states the rule.

## The list of target numbers per level and how targets escalate

### Takeaway
Targets are randomised per save within a range that grows with level, with the first three levels fixed at 1, 2, 3; the only level-indexed table published is levels 70 to 78 (324,571 to 631,448, about +8.7% a level). The hub level cap is 1000 and nine-digit targets never appeared in a run to 1000.

### Cited Findings
- Developer: "Max Hub level: 1000. Max upgrade levels: 128 for belt, 12 for extractor, and 108 for other buildings" (Notional Games, 27 Aug 2024) — [The level limit? thread](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660)
- "Goals are not manually picked. They are random, likely within a set range per level. This applies to both the Hub's level and the upgrade tiers. The same system was used in ... Beltex"; "Goals don't grow exponentially. They appear to at first, but after reaching four digits growth visibly slows while each tier remains a larger increase than the last"; example sequences "3, 14, 65" and "2057, 2803, 3917" (Kyouko Tsukino, 6 Aug 2024) — [The level limit? thread](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660)
- Player-reported target table (Proton, 13 Aug 2024): level 70 → 324,571; 71 → 359,983; 72 → 364,341; 73 → 382,533; 74 → 422,642; 75 → 498,653; 76 → 515,385; 77 → 555,962; 78 → 631,448; "the average is 8.7% per level", "at about 8% the cap [2^31−1] would be reached around level 180" — [The level limit? thread](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660)
- "Targets are randomized. The first levels ask for 1, 2, and 3, and around two-digit numbers the targets vary between playthroughs"; the game "randomizes the map and all of the target values, although they keep the sample range for randomization pretty constrained"; the author's largest target seen was 3,063,744 (after all achievements, so past level 30; 18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Early-game illustrative targets quoted by players: 453 "for an early-level goal" (Kyouko, 11 May 2024); 619 while only 1–4 were extractable (abrid, 13 May 2024); 33,559 with 12 extractors unlocked (destroyer156, 17 May 2024); 90,182 (Matonster, 18 May 2024); goals "appear random, but tend toward primes" (Kyouko, 11 May 2024) — [how to "make" the numbers? thread](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/)
- The next-level target quoted mid-game was 19,553 (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- A player at level 20 on 6 Aug 2024 said goals "seem to grow exponentially" (thebigh) — [The level limit? thread](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660)
- Run to level 1000: "The game never requested nine-digit numbers"; a duplicator design handling values up to about 2,113,882,029 was never needed; "the game didn't request >10^8" (RdB, 1 Feb 2025; IridiumMika, 4 Feb 2025) — [Level 1000 again thread](https://steamcommunity.com/app/2674590/discussions/0/597391520517097420/)
- Integer ceiling: output above the limit is replaced by 2,147,483,647 (2^31−1), negative output bottoms at −2,147,483,648 (first-hand, 18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/); contradicted by an aggregator stating "natural integers with an upper bound of 2^32 − 1" (page updated 2025-07-05) — [VaporLens](https://vaporlens.app/app/2674590/beltmatic.md); and a player who built every power of 2 up to 2^32 said it can "produce any number from 1 to 4294967293" (VinceG, 12 May 2024) — [how to "make" the numbers?](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/). The blog is the only direct observation of the clamp.

### Inferences
- Combining the 1000-level cap with "never nine digits" and ~8.7%/level growth at level 70–78: growth must flatten well below 8%/level after the hundreds, or targets are capped around 10^8; the dev did not say. The three mid-level sequences (3→14→65; 2057→2803→3917; 324k→631k over 8 levels) are consistent with a range per level whose bounds widen roughly geometrically early and sub-geometrically later.
- Because targets are random per save and shown 12 levels ahead, a rebuild that fixes a per-level range (min, max) and draws once at save creation would reproduce the feel; the exact ranges are not public.

### Gaps
- A level-by-level target list for levels 1–30 (or any table beyond 70–78): not found; players post single examples without the level index.
- The exact range function per level, and whether targets are biased toward primes (claimed, not shown).
- Whether targets keep rising after level ~100 or plateau: only the negative statement "no nine-digit target through level 1000".

## What each level unlocks

### Takeaway
Unlocks are a fixed ladder of machines and extractable numbers tied to hub levels: adder, bridge, multiplier, belt priorities, subtractor, divider, exponentiator, storage, and the extractable digits 2–9 then 11, 12. Two player lists exist and differ by exactly +1 at every entry, which is a counting convention (reward granted on completing level N vs. held from level N+1), not a patch.

### Cited Findings
- Guide table (Dec 2024, updated Dec 2025): Belt and Extractor at start; Adder level 1; Bridge level 4; Multiplier level 7; Belt Priorities level 10; Subtractor level 13; Divider level 16; Exponentiator level 19; Storage level 22. Extractable numbers: level 3 → 2, 5 → 3, 6 → 4, 8 → 5, 9 → 6, 11 → 7, 12 → 8, 14 → 9, 15 → 11, 17 → 12. "Starts with only 1 extractable" — [Supposer, How to Play](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Player list (Majibow, 8 May 2025): "1 Extractor, 2 Adder, 5 Bridge, 8 Multiplier, 14 Subtractor, 15 Extract 9's, 16 Extract 11's, 17 Dividor, 20 Exponentiator, 23 Storage" — [my slow but easy solution thread](https://steamcommunity.com/app/2674590/discussions/0/7404569906648161108/)
- "Adder: Unlocked at level 2", belts and extractor available from the start, multiplier/subtractor/divider/exponentiator/storage/bridge "unlocked later" (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- "Digits 1-9 can be extracted directly, but 10 must be built" (aggregator, 2025-07-05) — [VaporLens](https://vaporlens.app/app/2674590/beltmatic.md); Kyouko Tsukino "has never extracted a number above 9" (1 Jun 2024) — [strat for first 30 levels thread](https://steamcommunity.com/app/2674590/discussions/0/4333105245241372162/)
- "The nearest 11 might be about 500 tiles away"; "Later levels unlock new extractable numbers and more components" (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- "Storage buildings unlock later in the game" (aggregator) — [VaporLens](https://vaporlens.app/app/2674590/beltmatic.md)
- Machine shapes: adder 2×2; multiplier 3×1; subtractor L-shaped; divider a square outputting quotient and remainder; exponentiator L-shaped; storage 3×3 holding up to 10,000 values; extractor sits on a 3×3 darkened square around a single value (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Processor rules: each input buffers up to 5 numbers, each output buffers 2 if unconnected; the divider's "both outputs must be taken before new inputs process"; storage "stores up to 10,000 copies of one number, set by the first number it receives while empty" (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619); the blog says components hold up to 4 per input and 2 per output (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Hub "shows ... next-level rewards" (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Beltmatic vs Beltex (developer, 30 Mar 2024): square grid instead of hex; two new operations; values above 9 can be extracted; resources come from a single cell rather than a patch; "lots of smaller upgrade levels after large upgrades"; copy/paste from the start — [pinned dev thread](https://steamcommunity.com/app/2674590/discussions/0/4356743320311032786/)
- A player on 1 Jun 2024 with storage unlocked asked "are there new unlocks, or is the rest just extracting bigger numbers?"; the reply: after unlocking all machines "you level them up until gains shrink or they hit their level cap" (Kyouko, 1 Jun 2024) — [strat for first 30 levels thread](https://steamcommunity.com/app/2674590/discussions/0/4333105245241372162/)

### Inferences
- Majibow's "2 Adder" and the blog's "reach level 2 → adder" match, so Majibow's column is "the level at which you hold the thing" and Supposer's is "the level whose completion grants it"; add 1 to Supposer's table to get the level a player is on when they first use the machine.
- Nothing unlocks after storage (level 22/23); every later level is only a bigger target plus the next extractable number (12 at level 17/18 is the last entry anyone listed). The ladder's content ends by about level 23 while levels run to 1000.
- Belt tiers are not unlocked by level; belt speed is an upgrade track (next section).

### Gaps
- Any unlock after extractable 12 (level 17/18): not found. Whether 13+ ever becomes extractable is unstated; the player who built 33,559 "with 12 extractors unlocked" suggests the count of distinct extractable values reaches 12, not that 12 is the top value, but the two readings cannot be separated.
- Whether the map grows per level (see map section): not found.

## Upgrades: tracks, costs, ranks, effects

### Takeaway
Six upgrade tracks (belt, extractor, adder, multiplier, subtractor+divider shared, exponentiator), each paid by delivering up to three specific randomly chosen numbers per rank; caps are belt 128, extractor 12, others 108; the known end states are belt 20 tiles/s, extractor 12 belts, adder 4/s, others 3/s, with big jumps early (level 7→8 adder ~+50%) and tiny ones later (8→9 ~+1%).

### Cited Findings
- Developer caps (27 Aug 2024): belt 128, extractor 12, "108 for other buildings" — [The level limit? thread](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660)
- Maxed snapshot (neumann.emma12, 21 Sep 2024): Belt level 128 (20/s), Extractor level 12 (12 belts), Adder 108 (4/s), Multiplier 108 (3/s), Sub/Div 108 (3/s), Exponentiator 108 (3/s) — [How many upgrades are there? thread](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245)
- Earlier snapshot (abrid, 27 May 2024): belts 33, extractors 12 ("max"), adders 30, multipliers 26 — [same thread](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245)
- Upgradable machines named: Belt, Extractor, Adder, Multiplier, Sub/Div, Exponentiator (27 May–21 Sep 2024) — [same thread](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245); "The divider shares an upgrade path with the subtractor. The exponentiator has its own" (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Base speeds: belt 2 tiles/s (2 numbers/s on a full belt); extractor "produces as many values per second as fills one belt", measured in "belts"; adder one addition every 4 s at base (0.5 values/s in, so four base adders consume one full base belt); an upgraded belt at 2.5 tiles/s needs a fifth adder; late game multiplier/divider once per second and adder twice per second (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Upgrade window: each row shows "the upgrade name, current level, current speed (or belts served), up to three required numbers, and a build button enabled once those numbers are delivered"; the icon turns green with a sound when buildable; the extractor upgrade "sets speed by how many belts it can serve at full speed" (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- "Each upgradable component has three target values, plus one target for overall level. That makes up to 19 targets at once"; "delivered values can be reused for component upgrades, but only three times each"; upgrades are paid by delivering specific numbers, no currency named (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Effect sizes: "Adder level 7 to 8 gave about a 50% boost. Adder level 8 to 9 gave about 1%. Extractor upgrades are more beneficial past level 8"; one exponentiator upgrade gave +2% speed "but raised the delivery requirement by 1% and the next target by 4%"; "Level 9 requires 5-digit targets, and some 6- and 7-digit targets" (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Upgrade targets are random the same way level targets are (Kyouko, 6 Aug 2024) — [The level limit? thread](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660); "in the early game, you don't need to remove or stop delivering level numbers. In fact, early upgrades need those same numbers" (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Aggregated reviews: "Upgrades are additive, not multiplicative"; upgrades "become unrewarding after around level 8 or level 30" (2025-07-05) — [VaporLens](https://vaporlens.app/app/2674590/beltmatic.md)
- Developer design note: "Lots of smaller upgrade levels after large upgrades" (30 Mar 2024) — [pinned dev thread](https://steamcommunity.com/app/2674590/discussions/0/4356743320311032786/)
- "Upgrading your belt indirectly upgrades your extractors, by increasing the number of extracted values per second. Extractors permit direct upgrades too, increasing the number of belts" (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Achievement "Reasonably Upgraded: Reach level 8 on all upgrades", 6.0% of players; it "can't be earned until all upgradable machines are unlocked" (Kyouko, 27 May 2024) — [achievements](https://steamcommunity.com/stats/2674590/achievements); [How many upgrades? thread](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245)
- The extractor text "speed 8 belts" was found confusing (Supposer, 23 Nov 2024) — [Feature requests/Bugs thread](https://steamcommunity.com/app/2674590/discussions/0/4633736292852632524/)
- A player who upgraded belt speed was "approaching level 100" on it by 26 Aug 2024 (Conardist) — [The level limit? thread](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660)

### Inferences
- Belt: 2 tiles/s at rank 0 to 20/s at rank 128 is +18 over 128 ranks; the lowest upgraded belt speed the blog mentions is 2.5 (rank not named), so the early ranks are not uniform +0.14; the dev's "large upgrades then lots of smaller" and the 50%-then-1% adder observation suggest a front-loaded curve (few big steps to ~rank 8, then ~100 ranks of ~1% each).
- Adder: 0.25/s base to 4/s at 108 (16×); multiplier/sub-div/exponentiator reach 3/s at 108 (base rate unknown).
- "Three times each" reuse plus "up to 19 targets at once" means the economy is a per-number delivery ledger: every delivered number is tallied, and a target is satisfied when its tally reaches the requirement; the same number can be a hub target and an upgrade cost simultaneously.
- Upgrade costs scale with hub level, not with the upgrade's own rank, given "level 9 requires 5–7 digit targets" and the exponentiator rank "raised the next target by 4%": upgrading seems to also bump the number range the game draws from. (Single-source observation; treat as a hypothesis.)

### Gaps
- Per-rank effect tables (belt speed at each rank, adder seconds per op per rank): not found beyond the endpoints and the two anecdotal steps above.
- Per-rank cost tables: not found; costs are random numbers, and no one published the count required per cost number (the hub's K for upgrades) nor the draw ranges.
- Whether each upgrade rank requires exactly three numbers or "up to three" (the guide says up to three; the blog says three).

## Currency, placement costs, refunds, build limits

### Takeaway
There is no money: progress is paid entirely by delivering specific numbers. No source mentions a placement cost, a refund or a build limit, and players describe tearing down and rebuilding freely, so placement is inferred free and unlimited, not confirmed.

### Cited Findings
- Upgrades "are paid by delivering specific numbers"; "The post does not state a currency" (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- The only in-game windows are Delivered Numbers and Upgrades; costs are "the delivered numbers listed per upgrade" (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- "The player can tear down anything they build" (Kyouko, 15 Jul 2024) — [replayability thread](https://steamcommunity.com/app/2674590/discussions/0/4411921803479211926/)
- Editing tools: Copy Ctrl+C, Paste Ctrl+V (R rotates), Cut Ctrl+X, Clear C (numbers only), Demolish X; selection rectangles have a maximum width and height (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619); the selection maximum was raised in Version 1.0.10 — [Steam news](https://steamcommunity.com/app/2674590/allnews/)
- A player ran 24 copies of a seven-path multiplier factory (Proton, 17 Sep 2024) and another built "24 full belts" of every power of 2 up to 2^32 (VinceG, 12 May 2024), neither mentioning any cost — [my slow but easy solution](https://steamcommunity.com/app/2674590/discussions/0/7404569906648161108/); [how to make the numbers?](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/)
- Store tags include "Idler", "Sandbox", "Relaxing" — [Steam store page](https://store.steampowered.com/app/2674590/Beltmatic/)

### Inferences
- Placement is free and unlimited: no source in ~15 threads, one guide and one long blog ever names a build price, and the pinned dev thread lists no economy. Absence of evidence only.
- The scarce resource is throughput and attention, not money: the pacing lever is how many belts of a number a player can route, which is why belt and extractor upgrades are the ones players max first (abrid's May 2024 snapshot has extractor maxed at 12 before any other track passed 33).

### Gaps
- Explicit confirmation that machines cost nothing and that demolish refunds nothing: not found.
- Any cap on building count: not found (the "maximum selection rectangle" is a copy-paste limit, not a build limit).

## The map

### Takeaway
One infinite square grid with the hub at the centre; extractable numbers sit on single dark cells, low digits densest near the hub and higher ones far out (an 11 about 500 tiles away), the layout randomised per save; nothing suggests the map grows or changes per level.

### Cited Findings
- "The hub is a 6×6 blue rounded box in the center of an infinite square grid"; "Extractable 1s and 2s are densest near the hub. The nearest 11 might be about 500 tiles away"; the game "randomizes the map and all of the target values" (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- "Build on a dark grid box to extract the white number shown there"; "Extractable numbers sit on dark boxes; the Hub is central" (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Developer: resources "come from a single cell rather than a patch" (vs Beltex), square grid (30 Mar 2024) — [pinned dev thread](https://steamcommunity.com/app/2674590/discussions/0/4356743320311032786/)
- "The map is described as huge and effectively infinite"; "Full-map loads can cause pauses" (2025-07-05) — [VaporLens](https://vaporlens.app/app/2674590/beltmatic.md)
- "Obstacles in the map prevent designing" (R3C0D3r, 20 Jul 2024) — [replayability thread](https://steamcommunity.com/app/2674590/discussions/0/4411921803479211926/)
- Late game "belt speeds and quantities ... make long distances laughably small" (Kyouko, 15 Jul 2024) — [replayability thread](https://steamcommunity.com/app/2674590/discussions/0/4411921803479211926/)
- A requested-but-absent feature: "challenge maps of about 150x150 with fixed extractor numbers" (zachreid11, 14 Jul 2024) — [replayability thread](https://steamcommunity.com/app/2674590/discussions/0/4411921803479211926/)
- Store feature list: "expand across a large map" — [Steam store page](https://store.steampowered.com/app/2674590/Beltmatic/)
- Hotkeys: H zooms to hub, B places a marker, "it's easy to get lost" (jstwiss, 12 Dec 2024) — [Feature requests/Bugs thread](https://steamcommunity.com/app/2674590/discussions/0/4633736292852632524/)

### Inferences
- "Expansion" is the player walking outward for higher digits, not the map growing; the unlock ladder gates which cells may be extracted ("Starts with only 1 extractable"), so the cells for 2–12 are presumably present from the start but inert until unlocked.
- The level ladder's extractable-number cadence (2 at level 3, 3 at level 5, ... 12 at level 17) together with "11 is 500 tiles away" makes distance the real cost of higher digits.

### Gaps
- Starting map size, whether the playable area is bounded at all, the density function of digits by distance, and the nature of the "obstacles": not found.
- Whether the map is re-rolled on New Game only, or anything changes between levels: not found (no source says anything changes).

## Endgame, play length and pacing

### Takeaway
There is no ending: content stops at storage (level 22/23), the hub counts to a hard cap of level 1000 with nothing at it, upgrades cap at 128/12/108, and there is no infinite mode, prestige or new-game-plus; median play is about 4 hours, a completionist run (all 10 achievements, level 30) is ~10–15 hours, and one player reached level 1000 in 314 hours of mostly idling.

### Cited Findings
- Achievements (10 total, with global unlock rates read 2026-10-15): 10K deliver 10,000 numbers 80.2%; Level 10 69.1%; 100K 59.1%; Fast Delivery 24/s 58.7%; Faster Delivery 48/s 37.1%; 1M 24.6%; Level 20 22.7%; Fastest Delivery 96/s 17.4%; Level 30 7.6%; Reasonably Upgraded (level 8 on all upgrades) 6.0% — [Steam achievements](https://steamcommunity.com/stats/2674590/achievements)
- Level 1000 "reached after 314 hours of game time"; after a couple of million zeros delivered "nothing more" happened; a level-997 save was shared (RdB, 1 and 8 Feb 2025) — [Level 1000 again thread](https://steamcommunity.com/app/2674590/discussions/0/597391520517097420/)
- Level 90 reached then stopped (Proton, 17 Sep 2024); another "someone reached a level 1000 end" — [my slow but easy solution](https://steamcommunity.com/app/2674590/discussions/0/7404569906648161108/)
- Level 20 on 6 Aug 2024 (thebigh); level 78 by 13 Aug 2024 (Proton); belt upgrade "approaching level 100" by 26 Aug 2024 (Conardist) — [The level limit? thread](https://steamcommunity.com/app/2674590/discussions/0/4515506995733927660)
- "lvl 30 like base game" as the base-game goal (zachreid11, 14 Jul 2024); once a 10-digit MAM exists "The game becomes trivial and can be played without building anything more" (Torin, 30 Jul 2024) — [replayability thread](https://steamcommunity.com/app/2674590/discussions/0/4411921803479211926/)
- The game becomes "an idler": inputs changed "about every 10 minutes, which takes about a minute" then idle again (abrid, 27 May 2024) — [How many upgrades? thread](https://steamcommunity.com/app/2674590/discussions/0/4338734234990223245)
- Storage of 10..9000 takes "a couple of days" to fill (Citizen10Bears, 16 Sep 2024) — [my slow but easy solution](https://steamcommunity.com/app/2674590/discussions/0/7404569906648161108/)
- "players report roughly 10-15 hours before exhausting the content"; "No clear ending. Progression is effectively infinite"; "Some players need an external calculator beyond level 15" (2025-07-05) — [VaporLens](https://vaporlens.app/app/2674590/beltmatic.md)
- Nodal: 2,263 reviews, 95% positive; median 4.0 h, mean 9.2 h, 79% play at least 1 h (read 2026-10-15) — [nodal.gg](https://nodal.gg/game/node-math-3648370); Steam store: 94% of 1,549 English reviews (read 2026-10-15) — [Steam store](https://store.steampowered.com/app/2674590/Beltmatic/)
- A 10.5 h reviewer: "Progression can feel slow", becomes copy-paste work once a formula is found (8 Mar 2025) — [Steam review](https://steamcommunity.com/id/BAEuro/recommended/2674590); the blog author got all achievements in ~10 h (18 May 2025) — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Speedrun categories "Level 10" and "Level 20" exist on speedrun.com; rules require starting a new game (LordBalder) and a Level 10 showcase was run at BSG in Feb 2025 (dumbi14); no times were retrievable (403) — [speedrun.com user comments](https://www.speedrun.com/users/LordBalder/comments); [dumbi14](https://www.speedrun.com/users/dumbi14/comments)
- Version history (Steam news, newest first): 1.0.10 (18 Apr, year not shown, sits above the Aug 2024 entry): Alt reverses belt direction, L-shaped placement default, larger selection rectangle; 1.0.9 (29 Aug 2024) graphics performance; 1.0.8 (2 Aug 2024) undo/redo with 1,000-action history; 1.0.7 (14 Jun 2024) auto-bridges on paste; 1.0.6 (8 Jun 2024) faster large-save loads; 1.0.5 (5 Jun 2024); 1.0.4 (31 May 2024) DX10 support; 1.0.3 (27 May 2024) L-shaped belt option; 1.0.2 (23 May 2024) delivery achievement fix; 1.0.1 (11 May 2024). No post changes levels, goals, upgrades or machines — [Steam news](https://steamcommunity.com/app/2674590/allnews/)
- SteamDB: "last record update 23 July 2026", depot 247.20 MiB, tracked since 29 Oct 2023 (metadata, not a build note) — [SteamDB depots](https://steamdb.info/app/2674590/depots/)
- Not open source, no mod API (Notional Games, 13 Jun 2024) — [pinned dev thread](https://steamcommunity.com/app/2674590/discussions/0/4356743320311032786/)

### Inferences
- Pacing from the achievement funnel: of players who pass level 10 (69%), a third reach level 20 (23%) and a ninth reach level 30 (7.6%); the level-30 and all-upgrades-8 badges unlock at about the same rate, so those are the practical "finish line" (~10–15 h).
- Levels 1–10 take under the 4 h median for most players; the forum gives two independent calendar points (one player at level 20 on 6 Aug 2024, a different player at level 78 by 13 Aug 2024), and level 1000 took 314 h, i.e. ~0.3 h a level averaged over the full run, mostly idle time.
- Since the news feed shows no balance patch between 1.0.1 and 1.0.10, every player-reported number above (May 2024 to May 2025) describes the same ruleset; the "latest version as of 2026-10-15" is 1.0.10 as far as public notes go, with the caveat that SteamDB build history was unreadable.

### Gaps
- HowLongToBeat entry: site blocks the crawler; not retrieved.
- Speedrun times for Level 10 / Level 20: not retrieved (403).
- Exact year of 1.0.10 and any build after it: not confirmed.
- Any prestige, new-game-plus, challenge or infinite mode: none mentioned by anyone; the 58-reply replayability thread is players asking for them.

## Save and New Game rules

### Takeaway
The pause menu offers New Game, Load Game and Save Game, saves are plain files in AppData, and Steam Cloud is supported; players share and edit save files freely, but no source states how many slots exist or whether New Game overwrites.

### Cited Findings
- Pause menu (Esc): Resume, New Game, Load Game, Save Game, Options, Exit (Dec 2024) — [Supposer](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Developer: saves are at "C:\Users\<USERNAME>\AppData\Roaming\Beltmatic\Saves" (Notional Games, 24 May 2024) — [Saved games location thread](https://steamcommunity.com/app/2674590/discussions/0/4338733821686881571/)
- Steam features: Single-player, Steam Achievements, Steam Cloud, Family Sharing — [Steam store page](https://store.steampowered.com/app/2674590/Beltmatic/)
- A level-997 save was shared as a zip for others to load (RdB, 8 Feb 2025) — [Level 1000 again thread](https://steamcommunity.com/app/2674590/discussions/0/597391520517097420/); a request to "download other's save files for testing different stuff from the beginning" (joshualandes1, 10 Jul) — [discussions index](https://steamcommunity.com/app/2674590/discussions/)
- A Reddit user claimed "Level 1000 is the maximum level!" from an edited save file (socket2810, r/beltmatic, 18 Jun 2024; page itself returned 403) — [redlib mirror listing](https://redlib.hbubli.cc/user/socket2810/submitted), consistent with the developer's later statement (27 Aug 2024)
- Undo/redo keeps 1,000 actions (Version 1.0.8, 2 Aug 2024) — [Steam news](https://steamcommunity.com/app/2674590/allnews/)
- Speedrun rules require "start a new game for a valid run" (LordBalder) — [speedrun.com](https://www.speedrun.com/users/LordBalder/comments)

### Inferences
- Load Game with a folder of files implies multiple named saves rather than one slot, and New Game re-rolls the map and target list (the blog says both are randomised per playthrough).

### Gaps
- Number of save slots, autosave interval, whether New Game prompts before overwriting: not found.
- Whether achievements or anything else persists across New Game (nothing suggests meta-progression; "in a single game" appears in the delivery achievements' wording).
