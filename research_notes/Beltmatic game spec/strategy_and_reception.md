# Beltmatic: player strategy and reception

Research date: 2026-10-15. The game: Beltmatic, Steam app 2674590, developer and publisher Notional Games, released 29 March 2024, US$6.99, Windows only ([Steam store](https://store.steampowered.com/app/2674590/Beltmatic/); [SteamSpy](https://www.steamspy.com/app/2674590)). Every "belmatic"/Bellmatic watch result was excluded; only the video game is covered below.

On quotes: text in quotation marks from Steam reviews, Steam threads and blogs is as rendered by the fetch tool, which summarises pages; it is close to verbatim but not guaranteed so. Quoted text on Vaporlens and TapTap lines is the aggregator's own summary wording, not a player's. Vaporlens and SteamSpy figures were fetched 2026-10-15 and neither page states a data date.

Two sources are flagged throughout: the Steam guides by makki ("How to make any number without brain damage") and Supposer ("How to Play") both returned pages saying the item "has been removed from the community" / is visible only to the owner, though the text still rendered at fetch time. Cite with that caveat.

## How players reach a target number

### Takeaway
Players converge on four methods, in rough order of popularity: (1) prime-factorise the target and build it from extractor numbers, with a small ± adjustment when the target is prime; (2) "nearest round number plus a remainder" using 10^n and memorised squares; (3) place-value machines (digit × 10^k, summed), which make any number at the cost of size; (4) binary (powers of 2 summed) machines. Solvers that search for the fewest operations are widely shared. The integer cap is 2^31 − 1.

### Cited Findings
- The game's loop as stated by the dev: "extract numbers from the map, build machines for math operations, lay belt networks, deliver numbers to a hub to advance, unlock and upgrade buildings." — [Steam store](https://store.steampowered.com/app/2674590/Beltmatic/)
- Machines and unlock levels (How to Play guide, posted 25 Dec 2024, updated 16 Dec 2025): Adder (A+B) level 1; Multiplier (A×B) level 7; Subtractor (A−B) level 13; Divider (A÷B rounded down, plus remainder) level 16, "both outputs must be taken before new inputs process"; Exponentiator (A^B) level 19; Storage level 22, holds 10,000 of one number. Bridges unlock at level 4, belt priorities at level 10. — [Steam guide: How to Play](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619) (flagged: page says removed from community)
- Extractor tiers: only 1 at the start; up to 2 at level 3, 3 at L5, 4 at L6, 5 at L8, 6 at L9, 7 at L11, 8 at L12, 9 at L14, 11 at L15, 12 at L17. — [Steam guide: How to Play](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- First target is 1; shipping 10 copies of 1 reaches Level 2 and unlocks the adder. Early levels ask for 1, 2, 3; "around two-digit numbers, targets vary between playthroughs." — [biggieblog, 18 May 2025](https://biggieblog.com/building-number-factories-in-beltmatic/)
- "All 'goal' and 'upgrade' numbers outside the first few are randomly generated, with a lean toward primes." — player in [Steam discussion "how to make the numbers?"](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/) (May 2024)
- Values cap at 2147483647 (2^31 − 1); negative limit −2147483648. Division by 0 outputs 0 as quotient and the divisor as remainder. — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Method, squares and round numbers (Kyouko Tsukino, 11 May 2024): "10^X is your best friend once you get to that tier"; 19 = (4×4)+3; 41 = (4×9)+5; 453 = 9×50 + 3 where 50 = (5×5)+(5×5). — [Steam discussion "how to make the numbers?"](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/)
- Same player (1 Jun 2024): has "never extracted any number bigger than 9"; arrays of 10s and powers of 10 leave a result at most nine away from the target. — [Steam discussion "strat for first 30 levels"](https://steamcommunity.com/app/2674590/discussions/0/4333105245241372162/)
- Method, place value (Quazimodem, 17 May 2024): separate 10^n machines combined digit by digit, 67583 = 10^4×6 + 10^3×7 + 10^2×5 + 10×8 + 3, "so one setup can make any five-digit number." ravage_mk2 (18 May 2024) used 0–9 digit sets plus 1/10/100/1000 feeds, example 4731. — [Steam discussion "how to make the numbers?"](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/)
- Method, powers of 2 (VinceG, 12 May 2024): built every power of 2 from 2^1 to 2^32, "covers numbers up to 4,294,967,293" [sic; above the 2^31−1 cap documented elsewhere]. — [Steam discussion](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/)
- Method, primes (destroyer156, 17 May 2024): keep a set of primes, factor the target: 33559 = 907 × 37; for a prime like 619 build 61, then 61 × 10 × ... + 1. — [Steam discussion](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/)
- Method, exponents and roots (Matonster, 18 May 2024): graph the nth root of the target and look for integer crossings; 90182 = 18^4 − 11^4 − (14×11−1). Fat Rooster (20–21 May 2024): 31×41 = 36^2 − 5^2 (difference of squares); 90182 = 2^6×(2^6×22+1)+6; or 2^13×11 + 5×14 "needs only four operations." — [Steam discussion](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/)
- Method, factorisation ± small integer (cilibrar, 1 Jun 2024): "factor the target and look for easy combinations within about ±1-5 to use exponentiators and multipliers"; estimates "about 6 operations for a 4-digit number"; tried decimal and octal but "wound up" using factorisation. — [Steam discussion "strat for first 30 levels"](https://steamcommunity.com/app/2674590/discussions/0/4333105245241372162/)
- Method, single base N (biggieblog): write the target in base N (3 to 7 is the sweet spot: "Base 2 grows too slowly; larger bases need many additions"), balanced digits allowed. 19553 = (((7×7+7)×7+7)×7×7×7+7+7)÷7 using 11 copies of 7; 4851 = ((7+7)×7×7+7)×7; 8227 from 19 in 11 copies. If the target is prime, "pick N near the target, build N×X, then divide." — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Solver example (Fraket, 15 May 2024): a BFS Python script for minimum operations: 3660 = (3^6+3)×5 with numbers 1–13. — [Steam discussion](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/)
- Reviewer advice: "Pay close attention to operand order for subtraction and division, since A−B and B−A differ"; "Keep a calculator open, and perhaps a factors calculator too." — [Planned All Along, 13 Aug 2025](http://plannedallalong.blogspot.com/2025/08/quick-review-beltmatic.html)
- Number deletion tricks players use: the C hotkey clears numbers; 1^N = 1 loops; feeding an adder with itself until 2147483647 + N = 2147483647 ("a little more degenerate than 1^N = 1"). — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)

### Inferences
- No source worked the number 454. Applying the methods above (my derivation, not a player's): 454 = 2 × 227 and 227 is prime, beyond every extractor, so pure factorisation fails; the "nearest easy number ± small" method gives 454 = 7×(8×8) + 6 (7×64 = 448, +6), three machines (exponentiator or multiplier for 64, multiplier, adder), or 454 = 9×50 + 4 in Kyouko's style. This is exactly the case the ± adjustment exists for.
- The early game is a "make 10, then make powers of 10" game (Kyouko, makki's guide); the mid game is factorisation with adjustments; the late game, where targets are five to seven digits, is a MAM (make-anything-machine) or a solver script. One player (Kyouko Tsukino) reports playing through on extractors 1–9 alone.

### Gaps
- No Steam guide or thread works a number in the 400s step by step; 454 is inferred only.
- The exact random target generator (range per level, prime bias) is player observation only; no dev statement found.

## Common layout patterns

### Takeaway
Players build one module once and copy-paste it to fill a belt; chains of adders in series, parallel chains off one extractor, and "MAM" place-value or binary machines with belt priorities as the switch. Throughput is reasoned in "belts": a base belt moves 2 tiles/s, an adder at base speed consumes 0.5 values/s, so four adders drink one belt.

### Cited Findings
- Base belts move 2 tiles per second; the hub perimeter is 24 tiles so the theoretical base maximum delivery is 48 numbers/s. — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/). The How to Play guide says the hub accepts numbers "from up to 20 incoming belts" — [Steam guide: How to Play](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619). The two figures are reported as found, not reconciled.
- Machine footprints: adder 2×2 (base one operation per 4 s), multiplier 3×1, subtractor L-shaped (shares an upgrade path with the divider), divider square, exponentiator L-shaped with its own path, storage 3×3. — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Internal buffers: components hold 4 values per input and 2 per output (biggieblog, Lord Balder); the How to Play guide says 5 per input, 2 per output. — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/); [Compact MAM Designs](https://steamcommunity.com/app/2674590/discussions/0/4548155824440414415/); [How to Play](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Saturation arithmetic: "At base speed, four adders consume a full base belt (0.5 values/s each). Upgrading to 2.5 tiles/s requires a fifth adder. Upgrading the extractor to two belts and copying the setup doubles throughput." Extractors "skip backed-up belts, so other belts receive a larger share." The author "prefers filling belts to 100%, even at the cost of extractor efficiency." — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Series and parallel: chained adders make 1+1+1+1+1+1+1 = 7; the author moved from "knight-move triangles" to a linear layout "because it copy-pastes without mirroring"; multiple chains share one extractor, a third belt fully used it. — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- The copy-paste module (cilibrar, 1 Jun 2024): "pack 8-15 adders/subtractors/dividers/multipliers/exponentiators into a 15x15 square area" with 2 input belts and 1–2 output belts, then copy-paste. Shau (25 May 2024): build a working multiplier/adder layout once, "copy it 6–8 times across the 3s to fill a belt." — [strat thread](https://steamcommunity.com/app/2674590/discussions/0/4333105245241372162/); [numbers thread](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/)
- Place-value MAM (makki, 19 Jun 2024; 31 ratings, 34 favourites, 3,915 unique visitors): ten storages hold digits 0–9 (0 from a subtractor subtracting a digit from itself); 10 is made as 5+5, an exponentiator turns it into 100, 1000...; "use the priority feature to select one digit from 0–9. A single sorter handles 2 digits, and 10 sorters are combined. The input must flow without gaps, or lower-priority digits can leak through"; blocks are joined by adders in stages (1+10, 100+1000, 10k+100k, then 11+1100, then 1111+110k); an 8-digit version followed. — [Steam guide: makki](https://steamcommunity.com/sharedfiles/filedetails/?id=3270810062) (flagged: page says removed)
- Binary MAM (Lord Balder, 12 Jul 2024, edited 5 Nov 2024): v1 binary adder switched by belt priorities needing 48 supply lines; v2 shift register (×2, +1 per set bit) compact but "about 2 minutes for the first new number and 8 minutes to saturate the belt"; v3.1 adders in pairs as a binary tree, switched by adding/removing bridges, "about 30 s for the first number and about 75 s to fill the belt"; v3.3 fixed a priority flaw ("numbers exiting a bridge always had lower priority than numbers from a belt"); v4 adds 2 bits and shifts by 2 per stage, halving the area. Switching waste fell from ~10k numbers to ~3k by replacing empty belts with zeros and adding buffer storage. — [Compact MAM Designs](https://steamcommunity.com/app/2674590/discussions/0/4548155824440414415/)
- A duplicator trick: a divider used as a replicator (multiply by 7, divide by 6); logic gates with 4 and 2 as binary 0 and 1; a pseudorandom generator built from them. — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Other guides on the Steam guides page (10 total, fetched 2026-10-15): "Simple MAM with any number as input" (Surround), "Beltomatic Calculator" (cilibrar, 4 stars), "5 digit generator" (Suncrow), "Super Dense Calculator" (ClientCoin, updating Davidus Rex's), "Multi-digit number duplication" to 8 digits (Yugo2Slow), "How to make a 10 digit mam" (SnakeyKing34), "Lisp-like calculation pipeline" (FlameRat), "Minimum steps to make any number from a blank page" (davidus rex). — [Steam guides list](https://steamcommunity.com/app/2674590/guides/)
- Storage "prevents clogging" and the divider's remainder "can be reused for other numbers"; a menu tracks which numbers feed the dock "making it easier to trim unneeded branches." — [Planned All Along](http://plannedallalong.blogspot.com/2025/08/quick-review-beltmatic.html)
- Belt mechanics players praise: "automatic crossing, splitting, merging, and priority settings" (praise weight 0.03 in the aggregate). — [Vaporlens summary](https://vaporlens.app/app/2674590/beltmatic.md)

### Inferences
- The game has no balancer building; "balancing" is done with belt priorities at junctions and by counting machines per belt. Starvation is avoided by sizing the machine count to the belt (4 adders per base belt) rather than by splitter trees.
- Copy-paste with multi-paste drag is the game's blueprint substitute, which is why linear, mirror-free modules are preferred (mirroring is not in the game; see requests below).

### Gaps
- No throughput table per machine per upgrade level was found beyond the adder's base 4 s cycle.
- No guide quantifies "doubling chain" layouts specifically; VinceG's 2^1..2^32 build is the only power-of-two chain described, without geometry.

## Progression order of upgrades

### Takeaway
No guide prescribes an order (belt first vs extractor first). The only guidance found: level everything until gains shrink, and returns past level 8 are tiny except for extractors.

### Cited Findings
- "After unlocking all machines, all you do is level them up until gains become small or they hit their level cap. Then use the improvements to deliver each new main goal." — Kyouko Tsukino, 1 Jun 2024, [strat thread](https://steamcommunity.com/app/2674590/discussions/0/4333105245241372162/)
- Up to 19 target values can be active at once: three per upgradable component plus one for the level; values used for component upgrades can be reused only three times; targets change after use. — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Diminishing returns: "Upgrades past Level 8 give small returns, except for extractors. Adder Level 9 added about 1%, versus about 50% from Level 7 to 8." Achievements include 96 numbers/s delivered, one million numbers total, Level 30, and Level 8 on all upgrades. — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Reviewer who finished: reached Level 30 and upgraded all buildings to Level 8; "Leveling buildings requires large quantities of up to three numbers, which can turn into 'a waiting game.'" — [Planned All Along](http://plannedallalong.blogspot.com/2025/08/quick-review-beltmatic.html)
- How to Play guide: "Don't stop level-number deliveries early, since early upgrades need them"; build one processing pair at a time. — [How to Play](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Aggregate complaint: upgrades "become minimal after roughly level 8 or 30" (weight 0.05); the upgrade system is "confusing at first and then unrewarding after a certain level." — [Vaporlens](https://vaporlens.app/app/2674590/beltmatic.md)

### Inferences
- Since extractor upgrades (more belts out of one extractor) scale the whole module by copy-paste, extractors are the lever players keep pulling after level 8; belt speed forces re-counting machines per belt (4 → 5 adders). This is consistent with the sources but not stated as an order by any.

### Gaps
- Not found: any guide saying "belt speed first" or "extractor speed first". Record as not found.

## Exploits, degenerate strategies, dev patches

### Takeaway
No patched exploit was found. Player-documented quirks: the 2^31−1 saturation, 1^N and ÷0 behaviours used for deletion and sequencing, and a divider-as-duplicator. Patch notes are QoL and bug fixes.

### Cited Findings
- Patch history (Steam news, fetched 2026-10-15): 1.0.1 (11 May 2024) pipette fix; 1.0.2 (23 May 2024) delivery achievements unlock correctly; 1.0.3 (27 May 2024) L-shaped belt placement option; 1.0.4 (31 May 2024) DirectX 10 hardware support; 1.0.5 (5 Jun 2024) "buildings sometimes stopped producing" fixed; 1.0.6 (8 Jun 2024) large saves load faster; 1.0.7 (14 Jun 2024) bridges auto-built when pasting belts over belts, Shift to disable; 1.0.8 (2 Aug 2024) undo/redo with 1,000-action history; 1.0.9 (29 Aug 2024) graphics performance; 1.0.10 ("18 Apr", year not shown on the page, after 1.0.9) Alt reverses belt direction, L-shaped placement on by default, larger selection rectangle. — [Steam news list](https://steamcommunity.com/app/2674590/allnews/)
- Divider by zero "produce a counted output and a zero output that can trigger indefinitely, releasing 30 bits per trigger" used as a sequencer. — [Compact MAM Designs](https://steamcommunity.com/app/2674590/discussions/0/4548155824440414415/)
- Divider as replicator (×7 then ÷6), "4s feedback loops get stuck making 4s forever". — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- "There is no benefit to overproducing previous numbers." — Yilmas, 15 Jun 2024, [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)

### Inferences
- The "degenerate" strategy players name is the idle one: build once, leave it running; this is a complaint, not an exploit (see reception).

### Gaps
- No dev post naming an exploit; no SteamDB changelog could be read (SteamDB returned HTTP 402 twice). The "adder glitch" thread named in a sidebar was not fetched.

## Community tools

### Takeaway
Several solvers exist (web, Python, iOS app); there is no blueprint sharing, no Workshop and no mod support, and no planner beyond in-game copy-paste.

### Cited Findings
- Beltomatic Calculator (cilibrar, Steam guide rated 4 stars; GitHub repo rudi-cilibrasi/beltomatic-calculator). — [Steam guides](https://steamcommunity.com/app/2674590/guides/); [strat thread](https://steamcommunity.com/app/2674590/discussions/0/4333105245241372162/)
- Web solver at dbrentley.github.io/beltmatic-solver: inputs "Max Number (the highest number you have unlocked)" and "Target"; no algorithm description on the page. — [beltmatic-solver](https://dbrentley.github.io/beltmatic-solver)
- Python BFS scripts by Fraket (May 2024) and Abomination Reanimation (Jun 2024, GitHub Gist). — [numbers thread](https://steamcommunity.com/app/2674590/discussions/0/4364628453800871481/); [strat thread](https://steamcommunity.com/app/2674590/discussions/0/4333105245241372162/)
- iOS "Beltmatic Calculator" (third party): shortest routes to a target with chosen operations (+, −, ×, ÷, ^), free with ads, US$1.99 to remove, version 0.9.6 released 2 Jun 2026. — [App Store](https://apps.apple.com/us/app/-/id6748567066)
- "The game lacks shareable blueprints or templates... The best way to create a template is to build it once and then copy and paste it off to the side." — [Beltmatic Fandom wiki, via search](https://beltmatic.fandom.com/wiki/Version_History)
- Requests for mod support and a Workshop (weight 0.09) and a built-in calculator with log history (0.02). — [Vaporlens](https://vaporlens.app/app/2674590/beltmatic.md)

### Gaps
- Fandom wiki pages returned HTTP 402 at fetch; contents known only through search snippets.
- No mods found anywhere.

## Reception: scores and counts

### Takeaway
Steam "Very Positive", 94–95% over ~2,170–2,270 reviews in 2026; Metacritic user 8.5 from 16 ratings, no Metascore found; no mainstream press review found.

### Cited Findings
- Steam store page, fetched 2026-10-15: "English Reviews: Very Positive (1,549)", 94% positive; recent "Very Positive (30)", 96% in the last 30 days. (English-language filter, not all languages.) — [Steam store](https://store.steampowered.com/app/2674590/Beltmatic/)
- All languages: 95% "Very positive" from 2,273 reviews, data as of 2026-10-15. — [Raijin](https://raijin.gg/app/2674590/Beltmatic). An earlier snapshot: 94% across 2,172 reviews, 22 Jul 2026. — [Raijin via search](https://raijin.gg/app/2674590/Beltmatic)
- Metacritic PC user score 8.5 "Generally Favorable", 16 ratings (12 positive, 3 mixed, 1 negative); no Metascore shown. — [Metacritic](https://www.metacritic.com/game/beltmatic/user-reviews/)
- Kotaku's page is a database entry: no article, no score, misfiled 2009 news item in its "news" box. — [Kotaku](https://kotaku.com/games/beltmatic)
- Thinky Games lists the game in its database and recommends it to fans of Beltex and Block Shop; no editorial review found (page fetch returned 403). — [Thinky Games similar list](https://thinkygames.com/games/beltmatic/similar)
- TapTap listing: 5.8/10 from 17 ratings, 0 downloads, purchase link only to Steam; "some user reviews say the game was described as free on mobile and that it's expensive." Not an official mobile release. — [TapTap](https://www.taptap.io/app/33648744)

### Inferences
- The English-only 1,549 vs all-language 2,273 gap means ~30% of reviews are non-English, a signal that a Chinese-language request (below) comes from a real audience.

### Gaps
- Rock Paper Shotgun, PC Gamer, Kotaku, Polygon reviews: none found (search 2026-10-15). OpenCritic: not found. Thinky Games write-up: not found.

## Reception: praise and complaints

### Takeaway
Praise: the number-factory idea, addictiveness, value at $6.99, accessibility next to Factorio/shapez, light hardware needs. Complaints: it becomes "same-y" once every machine is unlocked, turns into an idle game, upgrades go flat, the divider is nearly useless, no mirror/flip, no decimals or negatives.

### Cited Findings
- Aggregate praise themes with weights: engaging math-puzzle gameplay 1.00 ("worth every cent"); minimalist factory automation 0.26 ("accessible entry point, often compared favorably to Factorio and Shapez"); value 0.20 ("a no-brainer for its price"); educational 0.13; intuitive UI 0.09; QoL "copy-paste and undo/redo" 0.06; performance on low specs incl. Linux 0.06; art 0.04; belt mechanics 0.03. — [Vaporlens](https://vaporlens.app/app/2674590/beltmatic.md)
- Aggregate complaint themes: repetitive and shallow 0.46 ("becomes idle or repetitive, with weak endgame content"); limited replayability 0.12 ("designed as a single playthrough"); missing QoL 0.11 (speed-up option, shortcuts); inferior to shapez/Factorio 0.09; unrewarding upgrades 0.05; useless divider 0.03; "pump and dump" 0.01. Emotional tone: satisfaction 0.33, disappointment 0.10. Reviewers mention "about 10-15 hours of content." — [Vaporlens](https://vaporlens.app/app/2674590/beltmatic.md)
- "Good game. Worth the money. Very addictive. Devs Please add the ability to mirror copied selection not just rotate" — Haphazodus, 12.2 h, 20 Jun 2024, 137 helpful. — [Steam reviews, top rated](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)
- "this is a godsend to the autistic community (me)" — dinky, 414 h, 21 Jun 2024, 194 helpful; "I have autism. I like this game." — finalcyan, 13 Apr 2024, 69 helpful. — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)
- "once you unlock all the combinators it starts to feel very same-y" — Poodlepalooza, 7.7 h, 23 Jun 2024, Not Recommended, 160 helpful; wants negatives, fractions, complex numbers. — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)
- "It very quickly turns into an idle game that you leave running in the background"; slow unlocks; "you cannot mirror/flip designs"; no real blueprint system — nifela, 22.6 h, 19 Jul 2024, Not Recommended, 56 helpful. — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)
- "A bit like Sudoku meets Factorio sorta thing"; "there is no benefit to overproducing previous numbers" — Yilmas, 9 h, 15 Jun 2024. — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)
- "shapez is better", play it first — Larithen, 4.4 h, 7 May 2024. BlueMagma (11.1 h, 23 May 2024): lacks shapez's "flow gates and logic control", division and subtraction arrive too late, wants non-integers, wants finished numbers shown green, music "uninteresting", "the game ran smoothly", "alright for the price I paid." — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)
- Vermilisix (30 Mar 2024, 83 helpful): praises belt priorities and the square (not hex) grid, start "isn't as painfully slow" as Beltex; wants decimals for square-root or pi factories. — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)
- Mcweezle (3 Nov 2024): gets lost on a big map, asks for a hub hotkey; a reply says it is H. — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)
- Blog verdict: "a fun one", "every factory-building game reduced to the simplest expression"; early game slow ("getting numbers near 10 takes a lot of work"), leveling is "a waiting game", "may not appeal to fans of more traditional factory-building games." — [Planned All Along, 13 Aug 2025](http://plannedallalong.blogspot.com/2025/08/quick-review-beltmatic.html)
- biggieblog: enjoys over-engineering, compares the optimisation to Opus Magnum cycle-golf; "replay value is limited"; "deleted the factory after finishing achievements"; played ~10 hours. — [biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Search-level summary: complaints include no macOS and no Chinese language. — [Vaporlens app page via search](https://vaporlens.app/app/2674590/beltmatic)

### Inferences
- Performance with large factories is not a visible complaint; 1.0.6 (large saves) and 1.0.9 (graphics) addressed it early. Belt placement complaints are about tedium and lack of mirroring, not bugs.
- Price (US$6.99) is almost uniformly judged fair; "lack of content" is the dominant negative and is framed as a single 10–15 h playthrough.

### Gaps
- Review counts per complaint are weights from one aggregator (Vaporlens, fetched 2026-10-15, page states no snapshot date); raw counts not found.
- No negative review cites performance; absence of evidence only.
- Playtime: "median 3.9 h / mean 8.9 h" appeared in a search summary attributed to "one tracker"; the tracker was not identified, Vaporlens' page has no playtime metrics and SteamSpy's are Patreon-gated. Not verified.

## Requested features and what the dev delivered

### Takeaway
Undo/redo was requested and shipped (1.0.8, 2 Aug 2024). Mirror/flip, blueprints, sandbox, bigger maps, speed-up, non-integer numbers, logic gates, macOS, Chinese, mobile: requested, none found delivered as of 2026-10-15.

### Cited Findings
- Requested (aggregate weights): more content/modes/DLC/sequel incl. sandbox 0.11; logic gates, switches, wires 0.10; mod support/Workshop 0.09; macOS and Wine 0.09; Chinese language; built-in calculator 0.02; slower number scaling as a difficulty option 0.02; diagonal drag, easier cleanup, mirroring, more visual/music variety 0.05; pause during building 0.01. — [Vaporlens](https://vaporlens.app/app/2674590/beltmatic.md)
- Delivered: undo/redo 1,000 actions (1.0.8, 2 Aug 2024); auto-bridges on paste (1.0.7, 14 Jun 2024); L-shaped belt placement (1.0.3, 27 May 2024; default in 1.0.10); Alt to reverse belt direction (1.0.10). — [Steam news](https://steamcommunity.com/app/2674590/allnews/)
- Copy/paste/cut with rotate (R) and drag-to-paste multiple copies, Shift+Scroll to step through earlier copies, C clears numbers, X demolishes, pause on Space. — [How to Play](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Mirror requested 20 Jun 2024 and 19 Jul 2024 (reviews above); no patch note delivers it. — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated); [Steam news](https://steamcommunity.com/app/2674590/allnews/)
- Mac: the store lists Windows 10 64-bit only, no macOS. — [Steam store](https://store.steampowered.com/app/2674590/Beltmatic/)
- Mobile: no official port found; the TapTap "APK" listing links only to Steam. — [TapTap](https://www.taptap.io/app/33648744)
- Languages: English only (interface, audio, subtitles). — [Steam store](https://store.steampowered.com/app/2674590/Beltmatic/)

### Inferences
- The last update on the news feed is 1.0.10 ("18 Apr", after Aug 2024); if the year is 2025 the game has had no update for ~18 months, which matches the "pump and dump" minority complaint and the "single playthrough" framing.

### Gaps
- Year of 1.0.10 not shown on the page; SteamDB (402) would confirm.
- No dev roadmap or statement on blueprints, sandbox, or a sequel found.

## Comparisons: shapez, shapez 2, Factorio, Mindustry, Beltex

### Takeaway
shapez is the comparison players make most; Beltmatic is judged simpler and shallower but more accessible; Factorio is the "deeper" reference; Beltex (same dev, 2022) is the predecessor it improves on. Mindustry: not mentioned by any source found.

### Cited Findings
- "Shapez: Most frequently compared. Some reviewers suggest playing it first for a different complexity level (0.07). Factorio: compared as a more complex, deeper game. This game is seen as simpler and more accessible (0.08 for factory fans). Satisfactory: mentioned. Beltex: this game is a sequel with better controls and additional operators." — [Vaporlens](https://vaporlens.app/app/2674590/beltmatic.md)
- Beltex: Notional Games, Steam, released 8 Jul 2022, US$4.99. — [Notional Games publisher page via search](https://store.steampowered.com/publisher/NotionalGames); [Beltex store](https://store.steampowered.com/app/2051420/Beltex/)
- Vermilisix (30 Mar 2024): Beltmatic improves on Beltex (square grid, priorities, faster start). — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated)
- Steam tags by count: Automation 136, Casual 129, Base-Building 126, Sandbox 123, Resource Management 120, Simulation 110, Strategy 108, Crafting 107, Idler 101, Education 96, 2D 92, Minimalist 91, Abstract 88. — [SteamSpy](https://www.steamspy.com/app/2674590)
- What is its own: the resource is the number itself and the recipe is arithmetic; "Sudoku meets Factorio" (Yilmas). What is borrowed: belts, bridges, priorities, hub delivery for levels, copy-paste (the shapez loop). — [Steam reviews](https://steamcommunity.com/app/2674590/reviews?browsefilter=toprated); [Steam store](https://store.steampowered.com/app/2674590/Beltmatic/)

### Inferences
- The "Idler" tag at 101 and the idle-game complaint point the same way: once a module is built, progress is waiting. shapez 2 was not named in any fetched source; comparisons are to the first shapez.

### Gaps
- No source compares to Mindustry or shapez 2 by name.

## Popularity signals

### Takeaway
A slow-burn launch: 12 peak players in April 2024, 227 in May, 819 in June, 852 all-time peak in July 2024, then a long tail of ~50–60 average players through 2026. Estimated ~50k copies, ~US$280k gross.

### Cited Findings
- Steam Charts (fetched 2026-10-15): April 2024 avg 5.41 / peak 12; May 93.87 / 227; June 260.90 / 819; July 378.26 / 852 (all-time peak); Aug 176.40 / 338. Recent: May 2026 56.91 / 102; Jun 48.77 / 98; Jul 59.70 / 115; Aug 61.93 / 104; Sep 56.84 / 109; last 30 days 54.78 / 103; now 44, 24 h peak 67. — [Steam Charts](https://steamcharts.com/app/2674590)
- Raijin (2026-10-15): all-time peak 446 (conflicts with Steam Charts' 852), 2,273 reviews at 95%, estimated 50,706 copies, US$283.5k gross (medium confidence), 4,257 followers, ~34k wishlists; monthly estimated revenue rising ~US$4–8k a month May–Oct 2026. — [Raijin](https://raijin.gg/app/2674590/Beltmatic)
- Tracker.gg and SteamBase (search snippets only, not fetched): all-time peak 846 and 852 on 10 Jul 2024 respectively. — [Tracker.gg](https://tracker.gg/population/steam/2674590); [SteamBase](https://steambase.io/apps/beltmatic)
- SteamSpy (fetched 2026-10-15, page states no data date): owners 50,000–100,000; 3,594 followers; "peak concurrent players yesterday: 74." — [SteamSpy](https://www.steamspy.com/app/2674590)
- YouTube coverage exists from smaller channels with titles like "Factiorio but with Numbers - Beltmatic", "They turned MATH into a factory game...", "When you FULLY AUTOMATE mathematics...", "NEW Minimalist Automation Game!! - Beltmatic"; a "Beltmatic Season 1" playlist. Upload dates and view counts not captured. — [YouTube search results](https://www.youtube.com/watch?v=maMOec5tZL4); [YouTube](https://www.youtube.com/watch?v=s5GTnqOxe8k)

### Inferences
- Raijin's 446 peak is probably a shorter tracking window than Steam Charts' (which has data from April 2024); Steam Charts' 852 is taken as the figure.
- The May–July 2024 climb two to three months after release, with no patch adding content, is the shape of word-of-mouth or short-clip spread; the figures do not identify the channel.
- Gamalytic/VG Insights not reachable; Raijin's ~50k copies agrees with SteamSpy's 50–100k owners floor.

### Gaps
- Real Civil Engineer, Nilaus: no Beltmatic video found. TikTok: no clips found by search (TikTok search returned only unrelated RCE pages). Reddit: no thread surfaced (the index did not honour `site:reddit.com`; two phrasings tried). Gamalytic and VG Insights: not found. SteamDB: HTTP 402 on every fetch.
