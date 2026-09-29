# Interstitial ad placement, frequency capping and retention in casual puzzle games

Context being evaluated: "the first 15-20 finished games per day are ad-free; after that, every 2nd game shows an interstitial/video before the game starts." Game: cozy daily-puzzle collection, AdMob anchored banner + lifetime remove-ads today.

Source-quality note for the report writer: the strongest sources here are platform *policy* (Google AdMob, Google Play) and one survey by Deloitte for Google AdMob. Most concrete "cooldown seconds / N levels" numbers come from ad-network marketing blogs (ironSource/Unity, Supersonic) or from 2026 vendor blogs (AdReact, Playio, Airflux) that cite no external data. Those are flagged below. I found no published controlled A/B test with D1/D7/D30 numbers specifically for interstitial frequency in a puzzle game.

## 1. Placement: natural breaks vs before gameplay starts

### Takeaway
Every authoritative source says interstitials go at the *end* of a content unit (after a level/score screen), never at the start of one. Showing a full-screen ad after the player taps "play" and before the game starts is not just bad practice: Google Play's Better Ads Experiences policy names "ads that appear at the beginning of a game level" as a prohibited unexpected interstitial, and AdMob policy forbids interstitials on app load. The proposal's "before the game starts" placement is the one placement the platform explicitly disallows.

### Cited Findings
- Google Play Better Ads Experiences policy: unexpected full-screen interstitials are not allowed; "Unexpected usually means that users are in the middle of doing something or that users clicked on a button expecting to start their user journey, rather than see an ad." Listed examples of unexpected ads: ads that appear "at the beginning of a game level" and "at the beginning of a content segment." Permitted: end of a game level, end of a content section, after score screens, after splash screens have fully loaded. Rewarded ads that the user explicitly opts into are exempt. — [Google Play Console Help, Better Ads Experiences](https://support.google.com/googleplay/android-developer/answer/12271244)
- AdMob disallowed interstitial implementations: "Do not place interstitial ads on app load and when exiting apps as interstitials should only be placed in between pages of app content"; no interstitial "after every user action" (max one per two user actions); no interstitial immediately after another was closed; ads must not launch unexpectedly while users are gaming, only "at logical breaks in between your app's content (e.g. pages, stages, or levels)"; must not interfere with navigating the app's core content. — [AdMob Help: Disallowed interstitial implementations](https://support.google.com/admob/answer/6201362)
- AdMob guidance: interstitials "are best placed at natural app transition points"; ask "Will the user be surprised by the interstitial ad?"; best suited to apps with linear experiences with clear start/stop points. Close-button delay: up to 5 s for standard, up to 12 s for high-engagement video, up to 30 s for third-party sourced ads. — [AdMob Help: Interstitial ad guidance](https://support.google.com/admob/answer/6066980)
- ironSource/Unity (March 2021, older): "Showing the ad after the end-level screen is the most common practice in the hyper-casual space"; showing it *before* the end-level/rewarded-offer screen "is often better for the user experience, helping increase ARPDAU while minimizing any potential effect on retention." Mid-level placements only for levels over 45 s. — [Unity/ironSource blog](https://unity.com/blog/best-practices-for-maximizing-revenue-from-interstitial-ads-in-your-app)
- Supersonic (Feb 2022, older): A/B tests of "serving an interstitial before vs. after the end of the level" produced a 5.5% average ARPU uplift (ARPU only; no retention figures published). — [Supersonic blog](https://supersonic.com/learn/blog/5-a-b-tests-you-should-be-running-to-improve-your-hyper-casual-game/)
- GameBiz Consulting (Oct 2025): moving interstitials to before the rewards screen instead of after raised interstitial revenue 24% and ad ARPDAU 23%, "no retention decline reported." — [PocketGamer.biz](https://www.pocketgamer.biz/what-five-in-game-ad-experiments-taught-us-about-player-behaviour-and-revenue/)
- Deloitte + Google AdMob study (early 2025): "quitting rates triple" when disruptive ads appear on end-cards or reward screens — i.e. even the end-of-level slot is sensitive if the ad interrupts a reward moment. — [PR Newswire, Deloitte/AdMob](https://www.prnewswire.com/news-releases/growth-in-mobile-gaming-new-global-study-from-deloitte-and-google-admob-reveals-the-link-between-mobile-ad-engagement-and-gamer-retention-302477095.html)

### Inferences
- "Before the game starts" fails on three counts: it is a Play policy violation (enforcement risk on the Android listing), it violates AdMob's "unexpected" principle (the player tapped a card expecting to play), and it lands at the moment of highest intent. The equivalent revenue can be taken at the *end* of a game (after the win screen, or between the win screen and returning to the grid), which all sources endorse.
- In this game the natural break is "solved -> win screen -> back to menu". The cleanest slot is when the player dismisses the win screen / returns to the grid, not over the win celebration itself (the Deloitte "end-card" finding suggests not covering the reward moment).

### Gaps
- No source quantified the retention difference between "before level start" and "after level end" placements; the argument rests on policy and UX principle, not a published A/B.
- Apple has no equivalent written interstitial policy that I found; the iOS side is governed by AdMob policy only.

## 2. Frequency caps, cooldowns and grace periods (concrete numbers)

### Takeaway
Typical published ranges: a time cooldown of roughly 30-90 s between interstitials in hyper-casual (up to 2-3 min in more casual/cozy contexts), first interstitial after level 3-8 rather than level 1, casual/midcore titles often waiting days to weeks for new users, and a per-session cap of ~4-6. Best practice is a dual cap (seconds since last ad AND levels since last ad) plus reset after a rewarded view, all remote-configured. A per-day *free quota* is not a standard lever in any source found.

### Cited Findings
- AdMob policy floor: at most one interstitial per two user actions; never back-to-back. — [AdMob Help](https://support.google.com/admob/answer/6201362)
- Meta Instant Games enforces a platform minimum of 30 s between interstitials (call fails otherwise). — [Meta for Developers, Instant Games interstitials](https://developers.facebook.com/documentation/games/monetize/in-app-ads/interstitial-ads)
- ironSource/Unity (2021): hyper-casual shows interstitials from Day 1; show the first at level 3-8 rather than level 1 "to improve retention"; for casual/midcore/hardcore "wait at least two weeks before showing interstitial ads"; do not serve interstitials to paying users. A/B test ~2 weeks; reduce frequency if D1 drops without proportional ARPU gain. — [Unity/ironSource blog](https://unity.com/blog/best-practices-for-maximizing-revenue-from-interstitial-ads-in-your-app)
- Supersonic (2022): cooldown tests at 20/30/40 s between ads gave a 5% average ARPU uplift; "which level to begin showing ads" (level 1, 2, 7...) tests gave 4% ARPU uplift. Hyper-casual numbers; retention not reported. — [Supersonic](https://supersonic.com/learn/blog/5-a-b-tests-you-should-be-running-to-improve-your-hyper-casual-game/)
- Felix Braberg (June 2026): trigger on the level break, not a timer; protect new users until a set number of levels, sessions or time since install; use dual caps ("minimum seconds since the last ad and the minimum levels since the last ad"); differentiate win vs loss; reset timers after a rewarded ad and do not stack an interstitial after one (rewarded eCPM 1.5-2x); keep cooldowns, level gates, session caps in remote config. No numbers given. — [Mobile Ad Revenue newsletter](https://felixbraberg.substack.com/p/7-best-practices-for-interstitial)
- Real puzzle titles (June 2025 teardown): Words of Wonder starts interstitials after level 8, then after every level and on app return; Vita Mahjong shows them "after nearly every level", banners from level 11; Happy Color at transitions (opening an image, completing, app returns). — [Felix Braberg newsletter #26](https://felixbraberg.substack.com/p/the-top-6-android-games-making-a)
- Vendor blogs (2026, no external citations — treat as opinion): delay first ad of a session 60-90 s, 2-3 min between ads, cap 4-6 impressions/session; claims first-ad delay improved D1 5-8% "with no meaningful revenue loss" based on unnamed implementations. — [AdReact (May 2026)](https://adreact.com/blog/interstitial-ad-best-practices-mobile-games/); repeated in [Playio blog (Sept 2026)](https://blog.playio.co/interstitial-ads-mobile-games). A search snippet attributed to Airflux recommends 60-90 s for casual and 180 s+ for levels 1-10 with no interstitial in the first 5 minutes; I could not load the page to verify (404). — [Airflux (unverified)](https://airflux.ai/blog/progression-based-game-monetization)
- Unsourced aggregator claim: "every level" interstitials in casual puzzle might see 15-25% abandon in the first session; recommends every 3-4 levels plus rewarded for hints/skips. No data source given. — [Udonis blog](https://www.blog.udonis.co/mobile-marketing/mobile-games/interstitial-ads)

### Inferences
- "Every 2nd game" is on the aggressive-but-common end for puzzle games (shipped hits do every level after level 8), but those hits are level-grinders played for many short levels; a cozy daily game's player base and positioning are closer to "casual" where ironSource advises long grace periods.
- A time cooldown matters more than a game count here: some boards take 20 s, others several minutes. "Every 2nd game" with no seconds floor could fire two ads a minute on fast boards; a dual cap (e.g. >= 2 games AND >= N minutes since last) is the standard pattern.

### Gaps
- No primary source gives a controlled, published cooldown-vs-retention curve for puzzle games.
- No source gives a per-day grace quota; all grace periods are per-install (levels, sessions, days since install) or per-session (first N seconds).

## 3. Measured effects on retention, session length, uninstalls

### Takeaway
Hard evidence is thin and mixed. A 2016 observational study across 21 games found only a weak, insignificant effect of ad count on retention (game quality dominated). The only large recent study (Deloitte for Google AdMob, 2025, a survey, not a telemetry experiment) says *disruptive* ads, not ads per se, drive churn: one exposure +6-7% churn, repeated exposure makes 52% quit. Vendor A/B claims report revenue uplifts with "no retention decline", but publish only ARPU.

### Cited Findings
- Burns, Roseboom (deltaDNA), Ross, "The Sensitivity of Retention to In-Game Advertisements: An Exploratory Analysis", AIIDE Player Analytics workshop, AAAI WS-16-23 (2016, older): user-level data from 21 F2P mobile games; "in-game advertisements have a weak, insignificant effect on each measure of retention"; "game-specific effects dominate all advertising effects." Observational, authors note limitations. — [AAAI paper PDF](https://cdn.aaai.org/ojs/12906/12906-52-16423-1-2-20201228.pdf)
- Deloitte + Google AdMob "Quality drives value" (early 2025; 7,000-gamer survey in DE, JP, UK, US, VN plus a 50-person diary study; commissioned by Google): single exposure to disruptive ad features raises churn 6-7%; quit rates triple when disruptive ads hit end-cards or reward screens; casual gamers 30-50% more likely to churn after disruptive features; repeated exposure pushes 52% to quit; 1 in 5 abandon a game over low-quality ad experiences; 72% exposed to high-quality ads keep playing. — [PR Newswire](https://www.prnewswire.com/news-releases/growth-in-mobile-gaming-new-global-study-from-deloitte-and-google-admob-reveals-the-link-between-mobile-ad-engagement-and-gamer-retention-302477095.html)
- A small study of a Google Play game ("Between Beats", 51 participants) found adding rewarded ads alongside existing interstitials reduced perceived intrusiveness and increased ads viewed. Surfaced via search snippet only; sample tiny. — (search result; primary not fetched — treat as gap-level)
- Industry experiments report revenue without retention loss: interstitial reorder +24% interstitial revenue, +23% ad ARPDAU, no retention decline (unnamed client, 2025). — [PocketGamer.biz](https://www.pocketgamer.biz/what-five-in-game-ad-experiments-taught-us-about-player-behaviour-and-revenue/)
- Vendor claim, unsourced: pushing first ad out 60-90 s raised D1 5-8%. — [AdReact](https://adreact.com/blog/interstitial-ad-best-practices-mobile-games/)

### Inferences
- The defensible reading: frequency matters less than *disruptiveness* (surprise, blocking intent, covering rewards). That argues directly against "before the game starts" and in favour of end-of-game placement with a cooldown.
- Because this game's retention hook is a daily streak (three boards/day keep it), an interstitial wedged between "tap card" and "play" is on the streak path every day; that is the moment the Deloitte findings describe as highest churn risk.

### Gaps
- No published D7/D30 A/B results for interstitial frequency or grace-period length in a puzzle game found; uninstall rates specifically not found.

## 4. "Ad-free for first N plays per day" schemes and whether 15-20 is sensible

### Takeaway
I found no shipped game or published case using a per-day ad-free quota; the industry's grace mechanisms are per install (first levels/days) and per session (first 60-90 s). Engagement data suggest a 15-20 free plays/day threshold would mean almost nobody ever sees an interstitial: median sessions are 3-5/day at ~4.5 min, and even NYT Games' highly engaged audience plays a handful of puzzles.

### Cited Findings
- GameAnalytics Q1 2024 benchmarks (10,000+ games, ~1.67B MAU): typical 3-5 sessions per day; global median session length 4.45 min; puzzle/word peak ~10 sessions/day in the Middle East. — [GameAnalytics via gameindustrylibrary](https://gameindustrylibrary.com/documents/q1-mobile-games-benchmarks-2024/read)
- NYT Games (2025, Fast Company): two-thirds of weekly visitors play two or more games and half play four or more (per week, per snippet). Another snippet said "over half of weekly users play more than one puzzle every day, and over a quarter play four or more" — the two phrasings conflict on per-day vs per-week; neither primary page was loadable. — [Fast Company](https://www.fastcompany.com/91386818/pips-new-game-nyt-the-next-wordle); [Creative Review (403, snippet only)](https://www.creativereview.co.uk/new-york-times-games-wordle-crossplay-design-jonathan-knight/)
- Industry grace mechanisms are per-install: level 3-8 first ad (hyper-casual), two weeks (casual/midcore) — [Unity/ironSource](https://unity.com/blog/best-practices-for-maximizing-revenue-from-interstitial-ads-in-your-app); levels / session count / time since install — [Felix Braberg](https://felixbraberg.substack.com/p/7-best-practices-for-interstitial); Words of Wonder level 8 — [Felix Braberg #26](https://felixbraberg.substack.com/p/the-top-6-android-games-making-a)

### Inferences
- At 15-20 free games/day, interstitials would reach only a small tail of heavy players, and exactly the most engaged ones (the players most likely to buy remove-ads or stay long-term). Revenue from it would be small; the players who do hit it are the most valuable to annoy least. Either lower the threshold substantially (e.g. after the day's daily set or a few games) with end-of-game placement and a time cooldown, or treat the high threshold as a deliberate "heavy-user nudge toward remove-ads" rather than a revenue line.
- A daily count also resets each day, so a heavy player gets the same pattern daily; a per-install grace (first days/first N games ever) protects new-user D1/D7, which is where published advice concentrates.
- The game's own "games" include Arcade runs and Versus matches of very different lengths; a count-based threshold treats a 20 s board and a 10-minute snooker frame the same.

### Gaps
- No data on puzzles per day for a multi-puzzle cozy collection; the game's own Firebase analytics (puzzle_complete per user per day) would answer this better than any public benchmark.
- No published results for any per-day-quota scheme.

## 5. Revenue share: interstitial vs banner vs rewarded in puzzle games

### Takeaway
Where interstitials are used in ad-monetised puzzle games, they are typically the largest ad revenue line (~70%+ in the examples found); banners are a minor share and rewarded depends on how many valuable opt-in placements exist. A banner-only puzzle game leaves most of the ad-revenue potential unrealised, which is the business case for the proposal.

### Cited Findings
- Vita Mahjong (June 2025, estimates): interstitials ~70% of ad revenue (~$85-95k of $135-143k/day Android); Words of Wonder: interstitials "the majority" of ad revenue. — [Felix Braberg newsletter #26](https://felixbraberg.substack.com/p/the-top-6-android-games-making-a)
- 2019 data (older, source aggregation): interstitials 74% of revenue / 75% of impressions vs rewarded 26% / 25% in puzzle. Surfaced via search snippet; primary not verified. — (search result referencing [Unity: top 5 rewarded placements for puzzle](https://unity.com/ja/blog/top-5-rewarded-video-placements-to-boost-puzzle-game-revenue))
- CrazyGames (web portal): puzzle games average 8.9 ad impressions per play, ~4.2 rewarded and ~4 midgame. — [CrazyGames docs](https://docs.crazygames.com/resources/monetizing-puzzle/)
- Counter-example: after optimisation in one casual hybrid game, interstitials were 17% of ad revenue (rewarded-heavy design). — [PocketGamer.biz](https://www.pocketgamer.biz/what-five-in-game-ad-experiments-taught-us-about-player-behaviour-and-revenue/)
- Rewarded eCPM typically 1.5-2x interstitial. — [Felix Braberg](https://felixbraberg.substack.com/p/7-best-practices-for-interstitial)

### Inferences
- The game already has natural rewarded slots (Hint, Second chance, boosters) — the rewarded-first route recommended for puzzle games may recover much of the interstitial revenue with less retention risk, and Google Play policy exempts opt-in rewarded ads from the unexpected-interstitial rule.

### Gaps
- No verified 2023-2026 genre-wide breakdown (e.g. AppLovin/Unity puzzle benchmark) of banner/interstitial/rewarded share was found.

## 6. Player reactions: most-hated patterns

### Takeaway
Players' complaints centre on ads after every level, ads that appear when they expected to play, long unskippable video, and ads that cover rewards; paid remove-ads is widely expected as an escape hatch. Survey data (Deloitte/AdMob) confirms disruptive, repeated ads are the churn driver.

### Cited Findings
- App-review/press complaints: ads after every level "greatly diminish playability"; players close and reopen apps to escape; commenters suggest every other level / every 3 levels / 20-40% of the time instead; paid remove-ads is expected. — [search-surfaced app reviews via Sensor Tower pages](https://app.sensortower.com/api/ios/apps/1461045706?country=US); [Android Central, "Interstitial ads are terrible"](https://androidcentral.com/interstitial-ads-suck-and-they-need-to-die-slowly-and-painfully)
- Load-delay bug: interstitials that load slowly and then pop up during gameplay are a known cause of complaints (preload/cached ads avoid it). — [Solar2D forum](https://forums.solar2d.com/t/interstitial-showing-during-gameplay-due-to-load-delay/321066); caching advice — [Felix Braberg](https://felixbraberg.substack.com/p/7-best-practices-for-interstitial)
- AdMob allows close-button delays up to 5 s (standard), 12 s (video) and 30 s (third-party); long unskippable video is permitted but is what players experience as "30 s ads". — [AdMob Help](https://support.google.com/admob/answer/6066980)
- 1 in 5 gamers abandon a game over low-quality ad experiences; repeated disruptive exposure makes 52% quit. — [Deloitte/AdMob](https://www.prnewswire.com/news-releases/growth-in-mobile-gaming-new-global-study-from-deloitte-and-google-admob-reveals-the-link-between-mobile-ad-engagement-and-gamer-retention-302477095.html)

### Inferences
- For a "cozy" brand, video interstitials with long unskippable windows are the most brand-dissonant option; AdMob lets publishers restrict to static/skippable formats or cap video, which is worth weighing.

### Gaps
- I did not systematically mine Reddit threads (search returned app-review pages instead); quantitative sentiment on specific patterns (fake close buttons, 30 s video) not found beyond the Deloitte survey.
