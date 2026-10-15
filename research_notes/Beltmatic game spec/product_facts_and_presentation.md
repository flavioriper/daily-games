# Beltmatic: product facts and presentation

Research date: 2026-10-15. Spelling note: the game is "Beltmatic" (one l, with a t); every "Bellmatic"/"Belmatic" hit is a Seiko/Movado wristwatch and was discarded. The Steam news feed, store API, review API, Deck-compatibility endpoint, ProtonDB, iTunes Search API, Google Play search, the GitHub search API and the Steam community forums were queried directly with curl on 2026-10-15; SteamDB, PCGamingWiki, Thinky Games, Steambase (500) and Justia (Cloudflare) refused the fetch. Screenshot and trailer-frame colour values below were sampled with PIL from the files Steam serves (URLs given), and the descriptions are of those files, viewed.

Local copies used for the visual notes (scratchpad, not in the repo): `/private/tmp/claude-501/-Users-flavioriper-dev-daily/a88d1383-229d-4917-8172-de9072837b97/scratchpad/beltmatic/shots/ss_0.jpg` … `ss_5.jpg` (the six 1920x1080 Steam screenshots, in store order) and `/private/tmp/claude-501/-Users-flavioriper-dev-daily/a88d1383-229d-4917-8172-de9072837b97/scratchpad/beltmatic/trailer/f_01.jpg` … `f_11.jpg` (one frame every 8 s of the 87.7 s Steam trailer, 1280x720).

## Developer, publisher, release, price, app id, engine, team, other games

### Takeaway
Beltmatic (Steam app 2674590) is made and published by a one-name studio, Notional Games, released on Steam on 29 March 2024 as a finished 1.0 (no early access), Windows only, at US$6.99; it is a Unity (IL2CPP) build; the studio's only other title is Beltex (2022), the hex-grid predecessor. The person behind Notional Games, their country and team size were not found anywhere.

### Cited Findings
- Steam store API (`appdetails`, fetched 2026-10-15): name Beltmatic, `steam_appid` 2674590, developers ["Notional Games"], publishers ["Notional Games"], release date "Mar 29, 2024", `coming_soon: false`, `is_free: false`, `website: None`, `required_age: 0`, `controller_support` absent — [Steam appdetails API](https://store.steampowered.com/api/appdetails?appids=2674590&cc=us)
- Store page text (fetched 2026-10-15): short description "Beltmatic is a casual factory game where you combine numbers using mathematical operations."; About: "Beltmatic is a game where you build mathematical factories." then bullets "Extract numbers from the map / Construct buildings that perform mathematical operations / Lay down an expansive belt network / Deliver numbers to hub to reach the next level / Build new production lines and reuse old ones / Unlock new buildings and upgrade them. / Expand your factory across a huge map" — [Steam store page](https://store.steampowered.com/app/2674590/Beltmatic/)
- Genres Casual, Indie, Simulation, Strategy; user tags Automation, Casual, Base Building, Resource Management, Sandbox, Simulation, Strategy, Crafting, Idler, Education, 2D, Minimalist, Abstract, Building, Family Friendly, Relaxing, Indie, Open World, Singleplayer, Logic — [Steam store page](https://store.steampowered.com/app/2674590/Beltmatic/)
- Prices as served by the store API on 2026-10-15, no discount running: US$6.99; Brazil R$ 23,50; UK £5.89; Germany 6,99 €; Japan ¥800 — [Steam appdetails API, cc=us/br/gb/de/jp](https://store.steampowered.com/api/appdetails?appids=2674590&cc=us)
- Third-party price history (search snippet only; the Steambase page itself returned HTTP 500 on 2026-10-15): base US$6.99 with periodic 35 % sales to US$4.54, e.g. a 6-day sale in May 2026 — [Steambase](https://steambase.io/games/beltmatic/info)
- No "Early Access" string anywhere in the store page HTML (grep, 2026-10-15); the first Steam news post is already "Version 1.0.1 Released" on 2024-05-11 — [Steam store page](https://store.steampowered.com/app/2674590/Beltmatic/); [Steam news API](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2674590&count=100&maxlength=0&format=json)
- The developer's pinned forum post "How is Beltmatic different from Beltex?" is dated 30 Mar 2024, the day after release — [Steam discussion 4356743320311032786](https://steamcommunity.com/app/2674590/discussions/0/4356743320311032786/)
- Engine: a community Ghidra project for the game tells the reader to "Double-click on the GameAssembly.dll file", the IL2CPP output of a Unity build — [JaydenTJD/Beltmatic-Ghidra-Decompilation README](https://github.com/JaydenTJD/Beltmatic-Ghidra-Decompilation); a Steam review of 2024-07-30 says "It crashes on Wine with some Unity error" — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Not open source, no mod API (developer reply, 13 Jun 2024): "It is not open source. There is no mod API." — [Steam discussion 4356743320311032786](https://steamcommunity.com/app/2674590/discussions/0/4356743320311032786/)
- The Steam developer page lists exactly two apps: Beltex (2051420) and Beltmatic (2674590) — [Steam search by developer](https://store.steampowered.com/search/?developer=Notional+Games)
- Beltex: developer/publisher Notional Games, released Jul 8, 2022, Windows only, US$4.99, English only, "a casual factory game played on a hex map. Extract numbers. Combine them using mathematical operations. Deliver them using belts across a huge map." — [Steam appdetails API, 2051420](https://store.steampowered.com/api/appdetails?appids=2051420&cc=us)
- Developer's own list of what changed from Beltex (30 Mar 2024): "Square grid instead of hex / Two new operations / Buildings have different shapes / Numbers larger than 9 can be extracted / Resources are extracted from a single cell instead of a patch / Lots of smaller upgrade levels after large upgrades / Copy/paste available from beginning / Items from copy/paste history can be removed / Direct building-bridge-building connections without belt / Better performance / Multiple buildings can be built in line by dragging (same with paste) / Belts and buildings can be cleared of numbers" — [Steam discussion 4356743320311032786](https://steamcommunity.com/app/2674590/discussions/0/4356743320311032786/)
- The only external link on the store page is a YouTube channel, youtube.com/@notionalgames (the channel's About page returned no description or location to the fetch) — [Steam store page HTML](https://store.steampowered.com/app/2674590/Beltmatic/)
- Reviews on 2026-10-15: 2,274 total, 2,151 positive, 123 negative, "Very Positive" (all languages); English only: 1,588 (1,497 / 91) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=all&num_per_page=100&filter=recent)
- Steam features: Single-player, Steam Achievements (10: Reasonably Upgraded, Fast Delivery, Faster Delivery, Fastest Delivery, 10K, 100K, 1M, Level 10, Level 20, Level 30), Steam Cloud, Family Sharing — [Steam appdetails API](https://store.steampowered.com/api/appdetails?appids=2674590&cc=us)
- Minimum spec: 64-bit Windows 10, 2 GHz CPU, 2 GB RAM, DirectX 11, 300 MB; patch 1.0.4 (2024-05-31) "Added support for DirectX 10 level graphics hardware" — [Steam appdetails API](https://store.steampowered.com/api/appdetails?appids=2674590&cc=us); [Steam news API](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2674590&count=100&maxlength=0&format=json)
- Steam Deck review (2026-07-07) notes the price as "3USD" at the time of writing, i.e. a sale — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)

### Inferences
- Launched straight to 1.0 (no EA phase): no EA flag, the first patch is 1.0.1 six weeks after release, and the developer posted a "differences from Beltex" note the day after launch.
- A solo or near-solo developer: one name, two games with the same design, patch notes of one line each, no website, no Discord (a player asked "DIscord Server for Beltmatic when?" on 30 May 2026 and got no reply). This is an inference; no source states the team size.

### Gaps
- The developer's real name, country and team size: not found (no website, no press interview, the YouTube About page gave nothing to the fetch, itch.io returned 429 for `notionalgames`/`notional-games`).
- Exact price-history table and lowest price: SteamDB and Steambase were unreachable; only the Steambase search snippet (US$4.54, 35 % off) and a review's "3USD" survive.
- A review of 2024-08-27 says "the dev already has like 2 other games that are just 1 to 1 clones of this" — only one (Beltex) is on Steam; a third game was not found.

## Platforms: Windows/Mac/Linux, Steam Deck, mobile, browser, console

### Takeaway
Windows only. The Steam API marks mac and linux false; Deck is "Playable" with text-legibility and keyboard caveats and a ProtonDB gold rating; there is no official mobile, browser or console version (the only "Beltmatic" apps on the App Store and Google Play are third-party calculators), and a Steam Deck reviewer reports that touching the screen sends the camera spinning, so touch was never designed for.

### Cited Findings
- `platforms: {'windows': True, 'mac': False, 'linux': False}` (2026-10-15); mac and linux requirement blocks are empty — [Steam appdetails API](https://store.steampowered.com/api/appdetails?appids=2674590&cc=us). Contradicted by a Steambase search snippet listing "Windows, Mac, Linux, and Steam Deck" — [Steambase](https://steambase.io/games/beltmatic/info); the Steam API is authoritative.
- Mac is the most requested platform: forum threads "MacOS" (6 May 2024, 23 replies of "+1", one "I just bought it, and had to request a refund"), "Migration to Mac" (7 Jul 2026), "Update for Macs?" (29 Apr 2026); no developer reply in any of them — [Steam discussion 4355620941600103254](https://steamcommunity.com/app/2674590/discussions/0/4355620941600103254/), [571542958702207808](https://steamcommunity.com/app/2674590/discussions/0/571542958702207808/), [839500962846547549](https://steamcommunity.com/app/2674590/discussions/0/839500962846547549/)
- Steam Deck compatibility report (2026-10-15): `resolved_category: 2` (Playable). Notes: controller glyphs do not match the Deck; text input does not automatically invoke the keyboard; "interface text is not legible"; default controller configuration fully functional; default configuration performant. SteamOS category also 2 — [Steam Deck compatibility endpoint](https://store.steampowered.com/saleaction/ajaxgetdeckappcompatibilityreport?nAppID=2674590)
- ProtonDB: tier gold, best reported platinum, 20 reports, score 0.64, confidence good — [ProtonDB API](https://www.protondb.com/api/v1/reports/summaries/2674590.json)
- Player experience on Deck is split: "I've also been playing it on the Steam Deck, and it works well" (2026-03-23), "Works well on SteamDeck" (2025-10-14), versus "NOT Steam Deck friendly … Not enough buttons and the camera performs a Holdo maneuver if you swipe the touch screen" (2026-07-07) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- iTunes Search API for "beltmatic" (30 results, 2026-10-15): no game by Notional Games; the only match by name is "Beltmatic Calculator" by Daniel Chernyshev, a companion solver — [App Store, id6748567066](https://apps.apple.com/us/app/beltmatic-calculator/id6748567066)
- Google Play search for "beltmatic" (2026-10-15): the only matching listing is "Beltmatic Calculator" (`com.dilongdann.beltmaticcalculator`), described as "a companion tool designed to help you play smarter. It's not a game"; the rest of the results are shapez (`com.playdigious.shapez`) and maths apps — [Google Play search](https://play.google.com/store/search?q=beltmatic&c=apps)
- Wine: "Please make a version that is compatible with Mac and/or Wine. It crashes on Wine with some Unity error." (review, 2024-07-30) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Browser: searches scoped to crazygames.com, poki.com, github.io and itch.io returned no Beltmatic page; itch.io search for "notional games" lists no game by the studio — [itch.io search](https://itch.io/search?q=notional+games)
- No console: not listed on any store found; the store page's only platform is Windows — [Steam store page](https://store.steampowered.com/app/2674590/Beltmatic/)

### Inferences
- The game is mouse-and-keyboard native with no touch layer: Deck's "text input does not invoke keyboard" and "text not legible" notes, the absent controller flag, and the "swipe the touch screen → camera spins" report all point to raw mouse/keyboard input being read on the Deck.

### Gaps
- No official statement from the developer about mobile, Mac or ports was found anywhere (forum, news, YouTube).

## Version history: current version and changelog

### Takeaway
Current version is 1.0.10 (18 Apr 2026). Ten one-line patches exist, nine of them between May and August 2024, then a 20-month silence until 1.0.10 (belt reversal with Alt, L-shaped belt mode by default, larger selection rectangle). No new machines, maps or balance changes were ever shipped post-launch.

### Cited Findings
All from the Steam news API (feed "Community Announcements", fetched 2026-10-15) — [Steam news API](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2674590&count=100&maxlength=0&format=json):
- 1.0.1 — 2024-05-11 — "Fixed pipette not always working properly"
- 1.0.2 — 2024-05-23 — "Fixed delivery achievements not always unlocking correctly"
- 1.0.3 — 2024-05-27 — "Added option for L-shaped belt placement mode"
- 1.0.4 — 2024-05-31 — "Added support for DirectX 10 level graphics hardware"
- 1.0.5 — 2024-06-05 — "Fixed buildings sometimes stopping production"
- 1.0.6 — 2024-06-08 — "Fixed incorrect placement of the upgrade tutorial message"; "Improved load times for large saves"
- 1.0.7 — 2024-06-14 — "Bridges are now automatically built when pasting belts over existing belts. Hold shift to prevent this behaviour."
- 1.0.8 — 2024-08-02 — "Added undo/redo functionality. The undo history size is 1000 actions."
- 1.0.9 — 2024-08-29 — "Optimized graphics performance"
- 1.0.10 — 2026-04-18 — "Holding alt now reverses the belt direction when building belts"; "When using the L-shaped belt placement mode, the belt will now change its primary direction when it is fully horizontal or vertical"; "L-shaped belt placement mode is now on by default on new installs"; "Increased the max size of the selection rectangle"; "Various minor fixes"
- IsThereAnyDeal confirms "Last update: 18 Apr 2026 (Steam, public branch)" — [IsThereAnyDeal](https://isthereanydeal.com/game/beltmatic/info/)
- Lineage (Beltex patch notes, same developer, for features Beltmatic shipped with): storage building and copy/paste with "Shift+Mouse Wheel to cycle clipboard history" and automatic bridge placement (Beltex 1.0.4, 2022-07-19); Space to pause (1.0.5, 2022-07-24); "Added dark color theme. Controls can now be viewed in Options menu." (1.0.7, 2022-07-31); "Added ability to remap controls" (1.0.13, 2022-12-06); "Delivered Numbers screen" (1.0.14, 2023-02-05); map markers (1.0.15, 2023-02-11) — [Steam news API, Beltex](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2051420&count=50&maxlength=300&format=json)

### Inferences
- Beltmatic shipped on day one with everything Beltex accumulated over eight months (copy/paste, clipboard history, bridges, storage, markers, Delivered Numbers), and then got only input-ergonomics fixes; the player base's requests (blueprint library, sandbox, speed-up, Mac) went unanswered.

### Gaps
- Build-level history (SteamDB depots/builds) was unreachable (HTTP 403); only the ten announced versions are known.
- Whether 1.0.10 changed anything else ("Various minor fixes") is unknown.

## Presentation: visual style, colours, numbers, hub, UI layout, animation, zoom, grid size

### Takeaway
The whole screen is a blueprint: a mid-blue grid of square cells (sampled #1f5b8d with darker lines), belts as near-black strips with small gold chevrons, every number a short white numeral riding inside one cell, machines as flat, lightly gradient, rounded squares in one hue per operation (red extractor, green adder, blue multiplier, magenta subtractor, orange divider, brown exponentiator, teal storage, yellow bridge plates at every belt crossing, a big blue hub), a bottom-centre toolbar of numbered slots and a seven-button cluster top-right; the only chrome colour is a teal-blue (#2888b8).

### Cited Findings
Screenshots are numbered in Steam store order (ss_0 … ss_5); URLs are the ones the store API serves — [Steam appdetails API](https://store.steampowered.com/api/appdetails?appids=2674590&cc=us).

**Grid and background**
- ss_3 ([URL](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2674590/ss_9ee325312751615850eee529d7950a972969a100.1920x1080.jpg)): the empty background is a flat blue, dominant sampled colours #185888 / #205888 (point sample #1f5b8d), ruled by slightly darker lines into squares; the autocorrelation of a background strip gives a 43 px cell period at 1920x1080 in this screenshot (both axes). In ss_0 the period is ~33 px (98 px over three cells): the two screenshots are at different zooms. — measured on the files above.
- Trailer frame f_03 (1280x720): hub 192 px wide, 2x2 adder 58 px, so one cell is ~29 px of a 1280 px frame (2.3 % of the width); in f_07 the period is 43 px (3.4 %). — measured on the trailer frames; trailer URL [Steam HLS master](https://video.akamai.steamstatic.com/store_trailers/2674590/657884/72cac2966c57cd7e6713fcf326dec274f105cd59/1750818298/hls_264_master.m3u8)
- Resource spots: a cell to build an extractor on is a darker square tile (sampled #184878 in ss_2) with the extractable number printed on it in a muted light blue; at mid zoom the tile is drawn 3x3 cells with the number centred (ss_2, "4" at top right; "5", "2" lower). The How to Play guide: "Extractors are built on dark grid boxes and extract the white number shown there." — [ss_2](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2674590/ss_45bc8c416a96f38d919df76ce5190130288f6789.1920x1080.jpg); [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619). Biggieblog: "marked by a darkened 3×3 square around a single value", "The map is randomized" — [Biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- ss_5 ([URL](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2674590/ss_3ba6542ca35bfe07241e8f675548fcf543409cf3.1920x1080.jpg)): the map zoomed far out: the hub is a small blue square at the exact centre reading "640", belts are thin dark lines, machine clusters are dense green/blue/magenta/orange bands, extractors are small red squares with a white digit, and unused resource spots show as lone pale digits (1–6) scattered over the blue. The map fills the frame edge to edge; there is no border and no HUD in this shot.

**Belts and numbers**
- Belts are a dark strip (#080808 / #000000 sampled on ss_3) about three-quarters of a cell wide, running cell-centre to cell-centre, with small gold/brown chevrons along the strip pointing in the flow direction; corners are drawn as right-angle joins of the same strip, and a half-length stub appears where a belt starts or ends (ss_0, ss_1, f_02) — [ss_0](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2674590/9b19409c951ef80c0553d0bb9ae293ec597cda33/ss_9b19409c951ef80c0553d0bb9ae293ec597cda33.1920x1080.jpg), [ss_1](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2674590/ss_2501bd3dfd61242ac99a09ba7633d96e596b879b.1920x1080.jpg)
- Items are plain white numerals (a point sample on a glyph edge over the red extractor gave #f4d5da, i.e. contaminated by the background; the fill reads as plain white) drawn with a thin dark outline, one per occupied cell, moving along the strip; the numeral shrinks to fit a cell, so "408", "2147483647" are all inside one cell width — ss_0; a reviewer: "the numbers stay within a square's width so 21 million is really tiny" (2025-01-20) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Bridge (belt crossing): a yellow rounded plate (#b8a800–#c8c000) the size of a belt width (32 px in ss_3, i.e. ~0.75 cell) with a dark "+" of four arrows, one tile, sitting wherever one belt crosses another: in f_08 the vertical belt dropping from the 8-row carries a plate at each of the 5, 6 and 9 rows it crosses; in f_04 the plate is where the 5-belt drops through the 2-belt to reach the multiplier's A input, while the 2-belt's own turn to B has none; in ss_3 the plates sit in the 10-belt row where the 2-belts cross down to the dividers. The toolbar's "2 Bridge" icon is the same yellow square. "In Beltmatic you just drag a belt across another and it builds a bridge, which is just one tile large: No entry or exit - just crossing two belts." (review 2026-01-19) — ss_0, ss_3, trailer f_04/f_08 (viewed); [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Splits and merges have no marker at all: a belt that forks or joins is a plain T of the dark strip (ss_1, the 62-belt collecting five multiplier outputs; f_09, the 111 outputs merging into the bottom belt). The guide's priority rule ("click a belt leaving a junction") is the only UI a junction has — ss_1, f_09 (viewed); [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Belt priority marker: "shown as a green diamond" on a belt leaving a junction (not visible in the six screenshots) — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619); [Biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)

**Machines: shape, size and colour (sampled dominant quantised colours)**
- Extractor: 3x3 cells, red (#a81020, #901018, #801018 gradient top-light to bottom-dark), big white numeral centred (ss_3: 126 px square at a 43 px cell) — ss_3, ss_0.
- Hub: a 6x6 blue square (biggieblog "6×6 blue"; measured 220–230 px at a 33 px cell, i.e. ~6.6 cells including its border) with a vertical gradient #0078c0 (top) → #0058a8 → #004098 (bottom); content stacked and centred: the target number in large white ("590", ~60 px tall), under it the progress in green "2k/4k" (#38cb63), then "LEVEL 16" in small white caps, then two or three lines of smaller caps "DIVIDER / UNLOCKED / NEXT LEVEL" — ss_0; the guide: "the large blue box at the centre of the map. It accepts up to 20 incoming belts"; biggieblog: "The hub perimeter is 24 tiles" — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619); [Biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Adder: 2x2, green (#208000–#30a000), label "A+B" in the output half and "A", "B" in the two input cells; orientation varies (inputs top, output bottom in f_03; inputs on the right column in ss_3) — ss_3, f_03.
- Multiplier: 3x1, blue (#0050c0–#0820b0), "A | A×B | B" in a row, or a 1x3 column when rotated — ss_1, f_04.
- Subtractor: L-shaped (three cells), magenta/purple (#8820a8, #600878 shadow), "A" top, "A-B" and "B" in the foot — ss_1, f_09.
- Divider: 2x2, burnt orange (#b85818–#803808), top row "A÷B | R" (quotient and remainder outputs), bottom row "A | B" inputs — ss_3.
- Exponentiator: L-shaped, brown/ochre (#704800 in its shadow; tan face), label with a superscript B — trailer f_01; biggieblog "Exponentiator: L-shaped" — [Biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Storage: 3x3, teal (#00a0a0–#00c0c0), stored number large on top ("10") and the count under it ("577") — ss_3.
- Input cells are the darker squares lettered A/B; output cells are the lighter ones with the formula: "Dark squares marked with a letter are inputs. Lighter squares are outputs." — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- All machines have ~4 px rounded corners, a 1 px dark edge and a soft drop shadow; no icons, no texture, no mascots — ss_0–ss_4.

**HUD and panels**
- Bottom toolbar (ss_0, 1920 px wide shot): a bar from x≈490 to x≈1430 (≈940 px, 49 % of the width) and ≈80 px tall, sitting on the bottom edge, colour #2888b8 with darker #185878 separators. Left to right: numbered slots "1 Belt" (black strip icon with gold arrows), "2 Bridge" (yellow square), "3 Extractor" (red square), "4 Adder" (green square), "5 Multiplier" (blue bar), "6 Subtractor" (magenta L); then empty slots (for not-yet-unlocked Divider, Exponentiator, Storage); then a 2x2 block of small text buttons "Ctrl-C Copy / Ctrl-V Paste / Ctrl-X Cut / C Clear"; then a red "X Demolish" slot (#a84040). The slot number and hotkey are printed tiny in the top-left corner of each slot; the name sits under the icon — ss_0. In the trailer's first frames (f_02) the same bar holds only Belt and Extractor, and slots fill in as the game unlocks them (f_03 adds Adder, f_04 Bridge and Multiplier, f_06 Subtractor) — trailer f_02–f_06.
- Top-right cluster (ss_0): seven square buttons of ≈48 px, same #2888b8 fill, in a row flush with the top-right corner: undo, redo, a hollow square (Zoom to Hub), a map pin with "+" (Place Marker), "123" (Delivered Numbers), an up-arrow (Upgrades), a hamburger (Menu). The guide names the same seven — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619). In the trailer at level 1 only the last five are present (undo/redo came with 1.0.8) — f_02.
- Upgrades window (ss_4, [URL](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2674590/ss_57ff60fafebfeac333ba81274d4bf4ce117c05df.1920x1080.jpg)): a centred modal ≈705x870 px (37 % x 81 % of the frame) in a slate blue (#5088b0 face, #486078 edge), title "UPGRADES" top-left in light caps, an "X" close box top-right. Five rows, each a lighter card: header line "BELT LEVEL 4" left and "SPEED 4/s" right; under it three large white required numbers ("16", "54", "794") each with a delivered/required count beneath ("7.5k/5k" in green when met, "2k/2k"), and a square button on the right reading "CLICK TO UPGRADE TO SPEED 5/s" when all three are met or "DELIVER MORE FOR 5 BELTS" otherwise. Rows shown: Belt level 4 (4/s), Extractor level 4 (4 belts), Adder level 4 (0.5/s), Multiplier level 4 (0.5/s), Subtractor level 3 (0.4/s). The factory stays visible, unblurred, around the modal.
- Delivered Numbers window: "lists incoming numbers, with level-up numbers shown in yellow at the top. Speed can be shown per second, minute, or hour. It also lists requirements for the next 12 levels." (not in the screenshots) — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Menu: "Resume, New Game, Load Game, Save Game, Options (with keyboard shortcuts), and Exit" — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- The map fills the whole window; HUD elements float over it with no frame — every screenshot.

**Placement feedback and animation**
- A valid placement ghost is a translucent bright green (#20b058) rectangle the size of the footprint (f_04 placing a multiplier, f_07 placing a belt, f_08 a subtractor); a selection/drag rectangle is a thin pale outline (f_05 while dragging six multipliers in a row) — trailer frames.
- A small two-button rotation widget labelled "Shift-R" and "R" with circular-arrow icons pops up just above the toolbar while a rotatable piece is held — trailer f_05.
- Motion: numbers slide along belts; machines show no moving parts in the stills; a reviewer asks for "a tiny amount of animation when doing zoom in / zoom out" (2024-12-02), i.e. zoom is stepped, not tweened; "When zooming in the text gets pixelated, when zooming out stuff doesn't get bigger and it's hard to read" (2025-07-17) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Title card (f_11): "BELTMATIC" in white, wide serif capitals on a light-blue gridded plate with clipped corners, over a blurred factory — trailer frame.
- Loading screen "shows a 'super cute factory'" — [Biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Beltex, for contrast (its first screenshot): the same palette on a hex grid, hexagonal red extractors on a patch of green "1" hexes, a hexagonal green adder of three hexes, a large stepped-hex blue hub ("2 / 11/30 / LEVEL 2 / EXTRACTION 2 UNLOCKED IN 2 LEVELS"), resource patches as grey "2"s — [Beltex screenshot](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2051420/ss_867a60a2cd45dcd90d6adbf95fa5a2d606edb9ed.1920x1080.jpg)

### Inferences
- Dating the visuals: the six store screenshots and header carry `t=1744824205` (2025-04-16) in their URLs; ss_0 shows the undo/redo buttons, so it was taken on 1.0.8 or later (Aug 2024+), while the trailer frames lack them, so the trailer footage predates 1.0.8. The trailer's own URL stamp is `1750818298` (2025-06-25), a re-encode date, not a capture date.
- Palette for a reimplementation (sampled, quantised to 8-bit steps, so ±8): background #1f5b8d, grid lines a few shades darker, resource tile #184878; belt #080808 with gold chevrons; bridge plate #c0b000; hub #0078c0→#004098; extractor #a81020; adder #28a000; multiplier #0050c0; subtractor #8820a8; divider #b85818; exponentiator tan/#704800; storage #00a8a8; chrome #2888b8 with #185878 dividers; demolish #a84040; done-text green #38cb63; item numerals white.
- Readability relies on a single fact: the item is text. At the zoom of ss_2 (cell ≈ 20 px) three-digit items are still legible; at ss_5 (cell ≈ 4 px) items vanish and only building colours remain, which is how the game's own "zoomed-out" look works.

### Gaps
- The priority diamond, the Delivered Numbers window, the marker/label look, the options screen and the loading screen are not in any screenshot or trailer frame I could obtain.
- Exact font: the UI caps look like a condensed humanist sans (close to Roboto Condensed) and the item numerals like a serif-less slab; not confirmed by any source.

## Sound and music

### Takeaway
Seven licensed Epidemic Sound synthwave/electronic tracks loop as background music (players identified them by name); music is the thing reviewers praise most after the loop, and also call repetitive; nothing documents the machine or UI sounds beyond one "great sound design" and one "audio begins to crackle" report.

### Cited Findings
- Tracklist posted by a player (thread "Soundtrack here", 25 Apr 2026, and the same list in a review created 2025-01-20 and edited later, since it quotes the 2026 thread): 1 "Nothing for Me (Instrumental Version)" – Lupus Nocte, Zorro; 2 "Cold War Games" – Gabriel Lewis; 3 "Polygon" – Ben Elson; 4 "Peacewalker" – ELFL; 5 "Delta" – Ben Elson; 6 "89" – Ben Elson; 7 "Red Driver" – Ben Elson; all on Epidemic Sound, with a YouTube and an Epidemic Sound playlist — [Steam discussion 798968152812807457](https://steamcommunity.com/app/2674590/discussions/0/798968152812807457/); [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Players notice the music elsewhere: "one of the random music tracks sounds a lot like what plays in Balatro" (16 Jul 2025); "I've heard at least two of the tracks played as background music in random youtube shorts" — [Steam discussion 596280581879285989](https://steamcommunity.com/app/2674590/discussions/0/596280581879285989/)
- Review language: "accompanied by synthwave beats" (2025-01-20); "Sounds almost like it came straight from Tron by Daft Punk" (2024-12-22); "The BG music is peak" (2025-11-27); "an absolute banger of a soundtrack" (2025-05-08); "Relaxing music complements the gameplay" (2025-03-08); "The ambient soundtrack is subtle and fitting, though it doesn't evolve much and may wear thin over time" (2025-07-21); "I would give almost anything for there to be more than one track" (2025-07-21); "PLEASE HIRE A MUSICIAN TO ADD TRACKS" (2024-07-30) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Sound effects: "great sound design and very intuiative to play" (2025-08-21); a bug report "After long sprints of gaming, I have noticed that the audio begins to crackle and pop" (2025-07-21) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Out of 1,200 English reviews fetched, 16 mention "music", 8 "sound", 4 "audio" — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- The Steam trailer carries a stereo AAC track (probed with ffprobe, 2026-10-15) — [Steam HLS master](https://video.akamai.steamstatic.com/store_trailers/2674590/657884/72cac2966c57cd7e6713fcf326dec274f105cd59/1750818298/hls_264_master.m3u8)
- The store's language table lists only English (the fetch could not tell which of interface / full audio / subtitles columns were ticked); there is no speech in any frame viewed — [Steam store page](https://store.steampowered.com/app/2674590/Beltmatic/)

### Inferences
- Stock-library music, not an original score; the "familiar from Balatro/shorts" remarks are the signature of Epidemic Sound tracks. A reimplementation cannot reuse these tracks without its own licence.

### Gaps
- No source describes individual effects (placement click, delivery chime, level-up sting) or whether machines hum; the trailer audio was not transcribed.

## Controls on PC

### Takeaway
Belts are laid by click-dragging from one cell to another (straight or, by default since 1.0.10, L-shaped, Alt reversing the direction); machines are picked from the numbered toolbar (1–6), rotated with R / Shift+R, and placed by click or by dragging a line of them; an area tool set (Ctrl+C/V/X copy/paste/cut, C clear numbers, X demolish) works on a dragged box with a size cap, with Shift+wheel cycling the clipboard history, R rotating a paste, Ctrl+Z/Y undoing 1,000 steps, WASD/arrows or right-drag panning, wheel zooming, Space pausing, H jumping to the hub and B placing a marker.

### Cited Findings
All from the Steam guide "How to Play" by Supposer (posted 25 Dec 2024, updated 16 Dec 2025; Steam shows a moderation notice on it, but the text is the only full control list found) — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619):
- Pan: arrow keys or WASD, Shift to move faster, or right-click drag. Zoom: mouse wheel. Pause: Space. Pause menu: Esc. Undo Ctrl+Z, redo Ctrl+Y. Zoom to Hub: H. Place Marker: B.
- Copy Ctrl+C, Paste Ctrl+V, Cut Ctrl+X, Clear C, Demolish X. Each applies to a dragged box with a maximum width and height; the Hub is ignored. Copy and Cut store built objects; Cut also deletes them and any numbers in the area; Clear removes numbers only; Demolish deletes built objects only.
- In Paste, R rotates the preview; Shift+Scroll changes which copied item is previewed.
- Processors rotate clockwise with R, counter-clockwise with Shift+R.
- "Belts are placed by clicking one grid space and dragging to another"; "the start and end spaces get half-belts, and belts are skipped over blocks"; "Connecting a belt to another half-belt creates a corner."
- Priorities (level 10): click a belt leaving a junction to give it priority (green diamond); click again to remove.
- Toolbar (top-right): Undo, Redo, Zoom to Hub, Place Marker, Delivered Numbers, Upgrades, Menu (Esc); Options holds the keyboard shortcuts.
Patch notes — [Steam news API](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2674590&count=100&maxlength=0&format=json):
- L-shaped belt placement mode: optional from 1.0.3 (2024-05-27); default on new installs from 1.0.10 (2026-04-18), which also flips the L's primary direction "when it is fully horizontal or vertical" and made "Holding alt … reverse the belt direction when building belts".
- Pasting belts over existing belts builds bridges automatically; hold Shift to prevent (1.0.7, 2024-06-14).
- Undo/redo with a 1,000-action history (1.0.8, 2024-08-02). Pipette exists (1.0.1 fixes it).
- "Increased the max size of the selection rectangle" (1.0.10).
Developer's own list (30 Mar 2024): "Multiple buildings can be built in line by dragging (same with paste)"; "Belts and buildings can be cleared of numbers"; "Direct building-bridge-building connections without belt" — [Steam discussion 4356743320311032786](https://steamcommunity.com/app/2674590/discussions/0/4356743320311032786/)
Player reports — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent):
- "As long as you don't drag your path along an extractor or along some other path - it will create a bridge automatically … I still would like to be able to just pres R to rotate the it like in shapez. You can drag while pasting - which creates miltiple copies of pasted fragment … You can build when zoomed way out." (2026-03-15)
- "So even if the connection is right it won't connect to the belt in front of it without explicit dragging." (2026-02-22) — no auto-joining of belt ends.
- "great QoL features like CTRL-Z/Y (undo/redo) and SHIFT-rightclick-drag (scroll through clipboard history)" (2025-03-16) — note this names a different gesture from the guide's Shift+Scroll.
- "Design preview showing interactions with existing factory elements before placement" and "Ability to scroll through previously copied items" (2025-03-08).
- "please allow placing paths where if you drag at an angle it just makes 2 sides, rather than having to drag to a corner and then drag again every time" (2024-08-29) — the request 1.0.10's default L-mode answers.
- "Can pause while building, and there is no cost to rebuilding" (2025-03-24); "It needs a pause button" (2024-08-10, before the Space key was widely known).
- "I paste all my blueprints somewhere on the map, and use a label to easily find them ( hotkey B.)" (2024-10-18); "there's no way to teleport to a given label" (2025-04-09); "labels … cannot be copied together with belts" (2025-03-10).
- Hotkey "H" for return-to-hub discovered by a reviewer (2024-11-04).
- Toolbar slots carry their digit hotkey printed in the corner ("1 Belt" … "6 Subtractor"), and the copy/paste block prints "Ctrl-C", "Ctrl-V", "Ctrl-X", "C", "X" — ss_0 (viewed).
- Biggieblog: "Pressing the C hotkey clears all numbers from an area, including storage"; "Some builds require pausing the game to wire parts together" — [Biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Beltex (predecessor) added "ability to remap controls" (1.0.13) and "Controls can now be viewed in Options menu" (1.0.7) — [Steam news API, Beltex](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2051420&count=50&maxlength=300&format=json)

### Inferences
- There is no blueprint library: "blueprints" in reviews means regions of the map the player copies from, plus the clipboard history. The whole editing model is box-select → clipboard, which maps cleanly to touch if a box can be drawn.
- Belt laying is endpoint-to-endpoint with a fixed path (straight or one L), not free-hand painting and not auto-routing around obstacles.

### Gaps
- Whether Beltmatic itself has key remapping (Beltex does) was not confirmed; the guide says only that Options shows the shortcuts.
- The pipette's key and the exact maximum selection box size are not stated anywhere found.
- The two clipboard-history gestures (Shift+Scroll vs Shift+right-drag) could not be reconciled.

## Tutorial and onboarding

### Takeaway
There is no separate tutorial: the hub's own text drives the first minutes ("1 / 0/10 / LEVEL 1 / ADDER UNLOCKED NEXT LEVEL"), the toolbar starts with only Belt and Extractor and grows one slot per unlock, and a one-off "upgrade tutorial message" appears when upgrades become relevant; players report both that it "explains everything step by step" and that they never understood the upgrade box.

### Cited Findings
- Trailer frame f_02 (0:08): a fresh map with one 3x3 red extractor "1", a belt of 1s into the hub, which reads "1 / 0/10 / LEVEL 1 / ADDER UNLOCKED NEXT LEVEL"; the toolbar holds only "1 Belt" and "3 Extractor" plus Copy/Paste/Cut/Clear and Demolish; a faint "2" marks a resource spot — trailer frame (viewed).
- f_03 (0:16): "2 / 0/20 / LEVEL 2 / EXTRACTION 2 UNLOCKED IN 2 LEVELS" with an adder looped off the 1-belt and "4 Adder" now in the toolbar — trailer frame.
- ss_0 at level 16 shows the same slot text: "DIVIDER UNLOCKED NEXT LEVEL" — [ss_0](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2674590/9b19409c951ef80c0553d0bb9ae293ec597cda33/ss_9b19409c951ef80c0553d0bb9ae293ec597cda33.1920x1080.jpg)
- Patch 1.0.6 (2024-06-08): "Fixed incorrect placement of the upgrade tutorial message" — [Steam news API](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2674590&count=100&maxlength=0&format=json)
- Biggieblog: "At the start, the target is 1. Shipping 10 copies of 1 reaches level 2 and unlocks the adder. Early targets are 1, 2, and 3." — [Biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Guide: unlock order "Belt and Extractor (start), Adder, Belt Bridge, Belt Priorities, Subtractor, Divider, Exponentiator, Storage"; Bridges at level 4, Priorities at 10; Multiplier 7, Subtractor 13, Divider 16, Exponentiator 19, Storage 22 — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- "The game eases you right in and explains everything step by step, so don't worry about it." (review 2024-09-11); "I think I skipped whatever tutorial there was, but it took me another few minutes to figure out *how* to upgrade things … the upgrade box seemed so... unimportant" (2026-03-08); "There are sources online that tell you how the upgrade mechanic works … it really should be something explained in game" (2025-07-21) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Forum "Feature requests/Bugs" (23 Nov 2024): "Some areas of the UI needs explanation. I played for a long time not realising how to even upgrade, or what the extra numbers shown in Delivered were saying." — [Steam discussion 4633736292852632524](https://steamcommunity.com/app/2674590/discussions/0/4633736292852632524/)
- Beltex 1.0.2 added a tutorial line "You can use Shift+Right Mouse to copy and Shift+Left Mouse to paste belt priorities", showing the developer's tutorial style is short in-world text — [Steam news API, Beltex](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2051420&count=50&maxlength=300&format=json)

### Inferences
- Onboarding is "the toolbar is the tutorial": the first level can only be solved with the two tools shown, and the hub announces the next unlock. A phone version should keep the hub's three-line text and the growing toolbar.

### Gaps
- The exact wording of the upgrade tutorial message and any other pop-ups was not found.

## Accessibility and localisation

### Takeaway
English only, no colour-blind mode, no controller support, and a Deck test that flags the UI text as not legible; the predecessor had a dark theme, Beltmatic's options are not documented.

### Cited Findings
- `supported_languages: English` (interface, full audio, subtitles) — [Steam appdetails API](https://store.steampowered.com/api/appdetails?appids=2674590&cc=us)
- Steam Deck test: "#SteamDeckVerified_TestResult_InterfaceTextIsNotLegible", "ControllerGlyphsDoNotMatchDeckDevice", "TextInputDoesNotAutomaticallyInvokesKeyboard" — [Steam Deck compatibility endpoint](https://store.steampowered.com/saleaction/ajaxgetdeckappcompatibilityreport?nAppID=2674590)
- Zero of 1,200 English reviews mention colour-blindness; one review mentions the ultrawide/zoom legibility problem ("When zooming in the text gets pixelated, when zooming out stuff doesn't get bigger and it's hard to read", 2025-07-17) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Beltex 1.0.7 (2022-07-31) "Added dark color theme" — [Steam news API, Beltex](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2051420&count=50&maxlength=300&format=json)
- German and other non-English reviews exist (e.g. 2026-08-06 German review calling it "Beltmagic"), so non-English players play the English UI — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=all&num_per_page=100&filter=recent)

### Inferences
- Because every machine type has both a colour and a printed formula ("A+B", "A×B", "A-B", "A÷B/R", "A^B"), the design is colour-blind-safe by construction even without a mode; a reimplementation should keep the label.

### Gaps
- Beltmatic's options menu contents (themes, UI scale, remapping) were not found.

## Legal: trademark, licence, clones and the developer's stance

### Takeaway
No trademark registration for "Beltmatic" was found (the USPTO and EUIPO databases could not be queried directly; a Justia search and three web searches surfaced only "BELT-O-MATIC", "BELTMARK" and an Indian "BELTMATE"); the developer has said only that the game is closed source with no mod API; no statement on clones or fan projects exists, and no playable browser clone was found, only ~47 open-source solver/calculator repos and two companion apps that use the name.

### Cited Findings
- Developer, 13 Jun 2024: "It is not open source. There is no mod API." — [Steam discussion 4356743320311032786](https://steamcommunity.com/app/2674590/discussions/0/4356743320311032786/)
- Trademark search results for "Beltmatic": none; nearest marks BELT-O-MATIC (expired US reg. 0801777, shoe machinery), BELTMARK (US serial 97272310, waist belts), BELTMATE (India, class 9, conveyor monitoring, filed 17/09/2026) — [Justia BELT-O-MATIC](https://trademarks.justia.com/722/14/belt-o-matic-72214535.html); [Justia BELTMARK](https://trademark.justia.com/972/72/beltmark-97272310.html); [RegisterKaro BELTMATE](https://www.registerkaro.in/trademark-search/beltmate-8004110)
- GitHub search "beltmatic": 47 repositories (2026-10-15), e.g. LiamKrenn/beltmatic-calculator (TypeScript, 14 stars, hosted at beltmatic.liamk.dev, "Based on https://info.otypes.de/beltmatic/"), dbrentley/beltmatic-solver (7 stars), KonradowyPL/beltmatic (6 stars), plus BFS/A*/MiniZinc solvers in Python, Rust, C#, Go, Kotlin, Julia; two reverse-engineering repos (Beltmatic-Ghidra-Decompilation, Beltmatic-Save-Dumper, Feb 2026); one repo with `index.html`/`game.js` (zhanbol1/beltmatic, Jul–Aug 2026, no README) whose nature was not verified — [GitHub search API](https://api.github.com/search/repositories?q=beltmatic&per_page=30); [LiamKrenn/beltmatic-calculator](https://github.com/LiamKrenn/beltmatic-calculator)
- Companion apps using the name on mobile stores: "Beltmatic Calculator" by Daniel Chernyshev (iOS) and "Beltmatic Calculator" `com.dilongdann.beltmaticcalculator` (Android, "It's not a game") — [App Store](https://apps.apple.com/us/app/beltmatic-calculator/id6748567066); [Google Play search](https://play.google.com/store/search?q=beltmatic&c=apps)
- A web calculator at info.otypes.de/beltmatic ("Calculated steps", "Extractors") exists, author unnamed — [otypes.de](https://info.otypes.de/beltmatic/)
- Players themselves call Beltmatic "a Shapez clone" repeatedly (8 of 1,200 English reviews use "clone": "A shapez clone to be certain, but it does capture the spirit pretty well", 2026-07-04; "Its a Shapez clone but inferior in all possible ways", 2026-05-26) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- No Beltmatic entry on CrazyGames, Poki, GitHub Pages or itch.io came up in a site-scoped search (2026-10-15) — search result set only; no page to cite.

### Inferences
- The name is unregistered as far as public search goes; the practical constraint on a reimplementation is the distinct trade dress (blueprint grid, these exact machine colours/labels, the "Beltmatic" title card) and the Epidemic Sound music, not a registered mark. (Not legal advice; the registries themselves were not queried.)
- The brief's premise that "known clones on web game sites" exist did not hold up: what exists are solvers/calculators that borrow the name.

### Gaps
- USPTO TESS/TSDR and EUIPO eSearch were not queried (TESS needs a browser session; the Justia mirror sat behind Cloudflare). A direct search by the user would settle it.
- No developer statement on clones, fan games or licensing exists in any source found.

## Similar games in the number-factory niche

### Takeaway
The niche is two Notional Games titles (Beltex on hexes, Beltmatic on squares) in the shadow of shapez/shapez 2, with Builderment and Factorio/Satisfactory as the comparisons players reach for; "Number Factory" on itch is a 2048-style game, not a belt game, and no other belt-and-arithmetic game surfaced.

### Cited Findings
- Beltex (Notional Games, 2022-07-08, hex map, US$4.99) — [Steam appdetails API, 2051420](https://store.steampowered.com/api/appdetails?appids=2051420&cc=us)
- shapez / shapez 2 are the universal reference: "Shapez, with numbers" (2025-03-08); "A bit like a stripped down version of Shapez 2 - but with arithmetic operators" (2026-08-09); "Shapez is missing a few things I really didn't remember missing (undo/redo, panning while building, further zoom, auto-tunnels and general performance)" (2026-01-19) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- "It's an ok mix of 'Builderment' and 'Shapez'" (2026-07-07); Satisfactory and Factorio named as the reviewer's background (2024-07-30) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Google Play's own results for "beltmatic" fill with shapez (`com.playdigious.shapez`), Euclidea, Photomath and cross-math puzzle apps, i.e. the store's nearest neighbours — [Google Play search](https://play.google.com/store/search?q=beltmatic&c=apps)
- Thinky Games' "similar" list for Beltmatic names Beltex, shapez and Block Shop (search snippet; the page returned 403 to the fetch) — [Thinky Games](https://thinkygames.com/games/beltmatic/similar)
- "Number Factory" on itch.io (knobtrifling82) is "2048-inspired", a different design (search snippet) — [itch.io profile](https://knobtrifling82.itch.io)
- Web tools that recreate the arithmetic layer only: beltmatic.liamk.dev, info.otypes.de/beltmatic — [LiamKrenn/beltmatic-calculator](https://github.com/LiamKrenn/beltmatic-calculator); [otypes.de](https://info.otypes.de/beltmatic/)

### Inferences
- Nothing in the niche is on phones: shapez has a mobile port, Beltmatic and Beltex do not, and the companion calculators are the only "Beltmatic" on either store.

### Gaps
- "Calculator The Game" style titles were not researched (out of scope of the belt niche); a nodal.gg "node math" listing appeared in search results but was not opened.

## Rules worth carrying over (mechanics the sources state, for the reimplementation)

### Takeaway
The simulation is small and fully described by two community sources: integer arithmetic with 32-bit overflow, five-item input buffers, even splitting of outputs, a hub that counts deliveries toward a level target and toward three numbers per upgrade row.

### Cited Findings
- Each processor input buffers up to 5 numbers; it runs when every input has at least one; an unconnected output buffers 2; outputs are shared evenly among outgoing belts; the Divider must have both outputs (quotient, remainder) taken before it processes again; Storage holds up to 10,000 copies of one number; the Hub takes up to 20 incoming belts — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Extractor output is split among its outgoing belts; only 1 is extractable at the start; extractor level → max number: L3→2, L5→3, L6→4, L8→5, L9→6, L11→7, L12→8, L14→9, L15→11, L17→12 — [How to Play guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3391840619)
- Belt base speed 2 tiles/s; adder base one addition per 4 s; extractor speed measured in belts; the hub perimeter is 24 tiles; up to 19 targets active (three per upgradable component plus the level target); divider shares an upgrade path with the subtractor, exponentiator has its own; a delivered value can be used for upgrades only three times; overflow shows 2147483647 / -2147483648; division by zero gives quotient 0 and remainder = divisor; "reasonably upgraded" = level 8 on all upgrades (achievement) — [Biggieblog](https://biggieblog.com/building-number-factories-in-beltmatic/)
- Upgrade numbers seen at level 4: belt 4/s → 5/s; extractor 4 belts → 5; adder 0.5/s → 0.667/s; multiplier 0.5/s → 0.667/s; subtractor L3 0.4/s → 0.5/s — [ss_4](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2674590/ss_57ff60fafebfeac333ba81274d4bf4ce117c05df.1920x1080.jpg)
- "once you unlock 8/s per belt and 6 belts per extractor (not even the maximum), the game really levels off" (2024-07-30); "Merging/splitting speed is the same as belt speed; extractor speed upgrades are always relative to belt speed, so an integer amount of belts can be drawn from an extractor" (2025-01-08); "Because nothing has a cost" (2025-11-14) — [Steam reviews API](https://store.steampowered.com/appreviews/2674590?json=1&language=english&num_per_page=100&filter=recent)
- Level progress text in the hub: "0/10" at level 1, "0/20" at level 2 (trailer f_02, f_03), "2k/4k" at level 16 (ss_0) — viewed frames.

### Inferences
- Nothing costs anything: building is free, so the whole economy is throughput and the player's arithmetic; a phone version needs no currency.

### Gaps
- Full per-level target lists, the random map's generation rule and the exact upgrade-speed table beyond level 4 are in the other two research notes' scope and were not re-gathered here.
