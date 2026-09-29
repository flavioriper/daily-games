# Rewarded video and hybrid (ads + IAP) monetization in casual puzzle and word games

Scope: rewarded-video design, hybrid models in puzzle/word games, eCPM/ARPDAU benchmarks (US vs Brazil/LatAm), and remove-ads IAP. Evaluated against three proposals for a cozy daily-puzzle collection (AdMob banner + lifetime remove-ads + earned-only gold): (a) rewarded video to double/boost Arcade rewards, (b) rewarded video for one extra hint, (c) rewarded video for a booster/continue only after losing.

Source-quality note: a lot of the "best practice" content online now comes from ad-tech vendor blogs (Applixir, RevenueFlex, AdReact, Audiencelab, etc.) that give neat numbers without methods. They are marked **[vendor blog]** below. Primary data (Unity report via PocketGamer.biz, Appodeal via Mistplay, MonetizeMore network data, Liftoff/Singular) is preferred where it exists.

---

## 1. Best practices for rewarded placements: which work best, engagement, views/DAU, caps, cannibalization, retention

### Takeaway
Rewarded video is the most-watched opt-in format in word and casual games: about 36-38% of DAU watch at least one on a given day (Unity, 2023 data). Placements tied to a need the player feels right then (out of resources, a failed level) get far more takers than generic between-level offers: 38.1% against 23.8%. The better evidence says rewarded ads usually sit alongside IAP rather than taking from it, but the strong "4.5x more likely to buy" figures are old, correlational, and come from ad networks. Proposed caps and cooldowns (a daily cap of 10-20, 2-6 views per DAU) come from vendor blogs, not studies.

### Cited Findings
- Unity's 2024 Mobile Growth and Monetisation Report (2023 data): the share of DAU who engage with rewarded video is **38.4% in word games**, 37.6% in RPGs, **36% in casual** and 27.3% in sports/trivia. — [PocketGamer.biz](http://www.pocketgamer.biz/unity-global-rewarded-ad-engagement-rose-by-32-in-2023/)
- Same report: **context-sensitive placements (e.g. when the player runs out of resources) got 38.1% engagement; placements between levels got 23.8%.** Games with 15+ ad placements reached engagement "as high as 46%". — [PocketGamer.biz](http://www.pocketgamer.biz/unity-global-rewarded-ad-engagement-rose-by-32-in-2023/)
- Same article: global rewarded-video engagement rose by "3.2%" YoY in 2023. The article URL says "32"; which one is correct is unclear. — [PocketGamer.biz](http://www.pocketgamer.biz/unity-global-rewarded-ad-engagement-rose-by-32-in-2023/)
- Unity's "top 5 rewarded placements for puzzle games": (1) **reward doubling** (2x-20x, single use per offer; e.g. Word Trip), (2) **extra currency** from the shop/home, "typically 1-2 daily attempts" with a countdown timer, (3) **revive** when a player loses mid-level, which does better when levels are longer, (4) **boosters**, "assistance without diminishing achievement", (5) extra lives / mystery rewards (spin wheel), capped daily. Cites Google data that 73% of mobile puzzle players see ads' effect on gameplay as neutral or positive. No per-placement engagement figures. — [Unity blog](https://unity.com/kr/blog/top-5-rewarded-video-placements-to-boost-puzzle-game-revenue)
- Liftoff/Singular 2025 Casual Gaming Apps Report (Feb 2024-Feb 2025 data): rewarded videos watched per user were **Match 42.4, Puzzle 24, Strategy 24.6**. The period the per-user figure covers is not stated in the summary. — [Liftoff 2025 Casual Gaming Apps Report](https://liftoff.ai/?p=34267) (via search summary; the full PDF was not read)
- Opt-in engagement benchmark: 35-65% of ad opportunities shown are started, and under 30% suggests a weak reward-to-effort ratio **[vendor blog]**. — [Applixir](https://www.applixir.com/?p=1792)
- Rewarded impressions/DAU of "2-6" called healthy. An example casual puzzle studio (80k DAU) had a 64% opt-in rate and **2.1 views per DAU** **[vendor blog]**. — [RevenueFlex](https://revenueflex.com/blog/rewarded-video-ads-mobile-game-monetization/), [Applixir playbook](https://www.applixir.com/blog/the-rewarded-video-ad-placement-playbook-retention-monetization/)
- Suggested caps disagree between vendors: "6-10 per session, daily cap 15-20" vs "daily limit 10-15" (anti-bot signal) vs "3-6 per session, 2-3 for sessions under 10 minutes". Cooldowns of "3-5 minutes" vs "60-120 seconds". Target completion rate ≥90% **[vendor blogs, no methods]**. — [RevenueFlex](https://revenueflex.com/blog/rewarded-video-ads-mobile-game-monetization/), [AdReact](https://adreact.com/blog/rewarded-video-ads-mobile-game-monetization/), [Audiencelab](https://audiencelab.ai/blog/rewarded-video-ads-optimization)
- Cannibalization: Tapjoy's study (2016-era) found users who engaged with rewarded ads were **4.5x more likely to make an IAP**, 9x in two apps, and spent over 4x as much. **Old, correlational, and from an ad network.** — [Marketing Dive](https://www.marketingdive.com/news/study-rewarded-ads-45x-more-likely-to-lead-to-in-app-purchases/448301/)
- ironSource's 2022 app monetization report says rewarded ads and IAP "do not cannibalize each other". — [Game Industry Library summary of ironSource 2022](https://gameindustrylibrary.com/documents/ironsource-modern-mobile-consumer-2022-app-monetization-report-2022)
- A counterweight from an industry panel: it is "a myth that advertising always cannibalizes IAP, but ... also a myth that it never cannibalizes". The outcome depends on balancing the economy. — [PocketGamer.biz, 5 common mobile advertising myths](https://www.pocketgamer.biz/5-common-mobile-advertising-myths/)
- Retention: an AdColony-sponsored piece (2017) says one app's D30 retention rose from **5.9% to 6.9% (+17%)** after rewarded video was added, and non-payers were 4x more likely to buy after a rewarded reward. Sponsored and old. — [VentureBeat (presented by AdColony)](https://venturebeat.com/2017/02/07/rewarded-video-isnt-just-for-game-developers)
- The GameAnalytics/SOOMLA study of rewarded video's retention impact across 6 match-3 games exists, but the URL now serves a 2026 guide with no retention figures, so its results could not be verified. — [GameAnalytics](https://www.gameanalytics.com/blog/rewarded-video-retention-impact-match-3-games)
- Block Blast: AdMob reported an **8% retention increase** from its partnership, and InMobi a 5% ARPDAU lift. These are partner case studies. — [Applixir summary](https://www.applixir.com/blog/the-block-blast-playbook-what-127m-in-ad-revenue-actually-bought/), [InMobi case study](https://advertising.inmobi.com/case-study/hungry-studios-block-blast-enjoys-5-arpdau-lift-with-the-inmobi-sdk)

### Inferences
- For this game, **proposal (b), one extra hint for a video, and proposal (c), a continue/booster after losing, are "context-sensitive" placements** of the kind Unity measured at 38.1%. **Proposal (a), doubling Arcade rewards, is Unity's #1 puzzle placement pattern**, but it is offered at level end, which is closer to the 23.8% "between levels" group. Where the offer sits changes the take-up rate.
- The game's gold is earned-only and there is no gold IAP, so rewarded video **cannot cannibalize a currency sale here**. The only IAP it could affect is remove-ads. Standard practice is that remove-ads does not remove opt-in rewarded ads (see §5), so the two do not compete much either.
- Brazil's Lei 15.211/2025 (noted in the project) is about *paid* random items. Rewarded "mystery box / spin wheel" placements are unpaid, but they are a random reward placement in a game minors can reach. Avoiding them is consistent with the project's current "nothing is random" rule.

### Gaps
- No independent, recent (2023-2026) controlled study was found that isolates rewarded video's causal effect on retention or IAP in puzzle/word games. The evidence is correlational and vendor-funded.
- No primary source gives per-placement caps used by named top puzzle games.
- The Liftoff "videos per user" timeframe was not confirmed.

---

## 2. "Rewarded on fail/continue" specifically: performance and player perception

### Takeaway
Revive/continue on fail is one of the most common rewarded placements in puzzle games, and top ad-monetized puzzle games use it as their main or only rewarded slot (Block Blast: one rewarded revive on failure). It sits in the high-engagement "context-sensitive" group. There is little direct perception data beyond general findings that puzzle players rate opt-in ads as neutral or positive.

### Cited Findings
- Revive is Unity's #3 recommended puzzle placement. It is triggered when the player loses mid-level, and **engagement is higher when levels are longer** (more to lose). — [Unity blog](https://unity.com/kr/blog/top-5-rewarded-video-placements-to-boost-puzzle-game-revenue)
- Block Blast's ad setup: persistent bottom banners, interstitials between rounds, and **a single rewarded placement per session, at the failure state**. — [Applixir, Block Blast playbook](https://www.applixir.com/blog/the-block-blast-playbook-what-127m-in-ad-revenue-actually-bought/) **[vendor blog, but specific]**; a similar description ("rewarded ads for revives, interstitials between levels, banners at all times") is in [Udonis](https://www.blog.udonis.co/statistics/block-blast)
- Context-sensitive (out of resources) placements get 38.1% engagement vs 23.8% between levels. — [PocketGamer.biz / Unity](http://www.pocketgamer.biz/unity-global-rewarded-ad-engagement-rose-by-32-in-2023/)
- King's early rewarded-video tests (2016) gave an **extra life** for a watched ad. Rewarded video was "35 percent more liked than pre-roll". Old. — [ExchangeWire](https://www.exchangewire.com/blog/2016/05/27/king-testing-new-reward-video-ad-format-to-monetise-400-million-users/)
- 73% of mobile puzzle players say ads have a neutral or positive effect on gameplay (Google data cited by Unity). — [Unity blog](https://unity.com/kr/blog/top-5-rewarded-video-placements-to-boost-puzzle-game-revenue)

### Inferences
- In this game's Arcade, a run-ending loss is exactly the "failure state" the top ad-funded puzzle game uses. A rewarded continue there is standard and likely the highest-performing single placement. The game already has an earned-gold Second chance. The usual hybrid pattern is to offer the rewarded video **as an alternative** to spending soft currency: "watch to continue" or "spend gold". Capping it at one continue per run keeps the score meaningful. The project already flags a best made with a booster (`best_boosted`), and the same flag could mark ad-continued runs.
- For daily grid puzzles, a loss state mostly does not exist (only Hidden Word can end unsolved). "Rewarded on fail" therefore applies mainly to Arcade, and a hint-for-video is the grid-board equivalent of a context-sensitive offer.

### Gaps
- No quantitative player-sentiment study specific to revive-for-ad (e.g. app-review sentiment or churn after a revive) was found.
- No data on whether an ad-continue devalues a leaderboard or "best" score in players' eyes.

---

## 3. Case studies: how successful puzzle/word games combine ads and IAP

### Takeaway
There is a spectrum. At one end are near-pure ad models (Block Blast: banners + interstitials + one rewarded revive, ~$127M ad revenue Jan-May 2026). In the middle are hybrid word and sudoku games (Wordscapes, Words of Wonders, Sudoku.com) with rewarded hints/coins, remove-ads at **$9.99-$14.99**, and weekly VIP subscriptions (**$3.99-$4.49/week**) that bundle no-ads, daily currency and free hints. At the IAP-heavy end, Royal Match markets itself as having no forced ads while using rewarded video. Hybridcasual puzzle revenue splits around 59% IAP / 41% ads.

### Cited Findings
- **Block Blast (Hungry Studio):** ~**$127M ad revenue Jan-May 2026**, the most of any mobile game. Vita Mahjong $89.8M, Candy Crush Saga $81.1M, Solitaire Associations Journey $73.3M and **Wordscapes $42.6M** in the same window. The puzzle genre takes **53% of mobile-game ad revenue** and blocks 10%. ~70M DAU and ~25,000 A/B tests in 2025. — [Applixir, Block Blast playbook](https://www.applixir.com/blog/the-block-blast-playbook-what-127m-in-ad-revenue-actually-bought/) (cites Sensor Tower/AppMagic-type data; secondary)
- Block Blast's remove-ads offer: sources **conflict**. Udonis says that after the first interstitial the game upsells **Remove Ads $9.99 or a $4.49/week subscription** that removes interstitials and adds daily gems/boosters. — [Udonis](https://www.blog.udonis.co/statistics/block-blast). Applixir says there is "no remove ads purchase". — [Applixir](https://www.applixir.com/blog/the-block-blast-playbook-what-127m-in-ad-revenue-actually-bought/). It may differ by platform or version, or over time.
- Block Blast estimated at **~$584k/day (~$17.5M/month)**. Its revenue is described as mostly in-app advertising. — [Udonis](https://www.blog.udonis.co/statistics/block-blast)
- **Sudoku.com (Easybrain):** says ads keep the game free, with a **"No Ads" IAP at $14.99** (App Store listing). Easybrain runs several ad networks at once so they compete. — [Search summary of App Store / myTarget case study](https://target.vk.ru/publishers/success-stories/easybrain); [App Store listing](https://apps.apple.com/us/app/sudoku-com-number-games/id1193508329?xs=1)
- **Words of Wonders (Fugo):** a **Pro Membership at $3.99/week** (double daily gift, 2 free hints per level, remove ads) and a standalone **Remove Ads ≈ ¥1,500 / ~$9.99**, plus coin packs and a "Golden Wheel". — [App Store (JP) listing via search](https://apps.apple.com/JP/app/id1369521645)
- **Wordscapes (PeopleFun):** coins buy hints and shuffles, and **rewarded videos give hints/gems**. Its revenue rose after moving from a waterfall to AppLovin MAX in-app bidding. ~$5M/month since late 2018 (Naavik, 2022), with no IAP/ad split published. — [Appier](https://www.appier.com/en/blog/what-is-wordscapes-game), [Naavik (2022)](https://naavik.co/f2p-mobile/worldscapes-peoplefun/)
- **Royal Match (Dream Games):** marketed as ad-free with no forced third-party ads. Its ads are almost all rewarded video and **opt-in**. — [App Store BR](https://apps.apple.com/BR/app/id1482155847) (the "54.9% of ads created were rewarded video" search snippet refers to its *UA creatives*, not in-game ads, so it is not used)
- **Candy Crush Saga:** IAP-led ($869M revenue in 2024) with rewarded video as King's main ad format (extra life for an ad). No current ad/IAP split found. — [ExchangeWire 2016](https://www.exchangewire.com/blog/2016/05/27/king-testing-new-reward-video-ad-format-to-monetise-400-million-users/); revenue figure via [Foxdata](https://foxdata.com/en/blogs/how-candy-crush-saga-maintains-its-longstanding-position-at-the-top-of-revenue-charts/)
- Hybridcasual lifestyle/puzzle revenue split **~59% IAP / 41% IAA**. Logic/puzzle titles are often ~30% ads / 70% IAP, with rewarded + banners favoured over interstitials. — [Juego Studio ARPDAU benchmarks](https://www.juegostudio.com/blog/arpdau-benchmarks-by-game-genre) / [GameGrowthAdvisor 2026](https://gamegrowthadvisor.com/blog/2026-06-02-hybrid-monetization-mobile-games-iap-ads-guide-2026/) **[secondary blogs]**
- The top 10 games take 11% of ad revenue but 22% of IAP. Games outside the top 1,000 take 29% of ad revenue but only 9% of IAP, so ads are relatively more important to smaller games. — [Applixir](https://www.applixir.com/blog/the-block-blast-playbook-what-127m-in-ad-revenue-actually-bought/)

### Inferences
- The common pattern in word/sudoku hybrids is: rewarded video for hints/coins, interstitials between levels, banners, a one-off remove-ads at $9.99-$14.99, and a weekly VIP subscription. This game's lifetime remove-ads (US$4.99 / R$19.99 per the project's memory notes) is **priced below category peers**. That is reasonable for a game that has no interstitials to remove.
- No top game found relies on banner-only monetization. Revenue in ad-funded puzzle games comes from interstitials and rewarded video.

### Gaps
- No verified sources were found on NYT Games' ad policy inside puzzles, on Puzzmo, on Microsoft Solitaire's ad/IAP mix, or on Woodoku's ad frequencies, within the call budget.
- No public IAA/IAP revenue split for any named title.

---

## 4. Benchmarks 2024-2026: eCPM by format and region, ARPDAU, revenue per 1,000 DAU

### Takeaway
eCPMs rank **rewarded ≳ interstitial ≫ banner**. In North America, rewarded pays ~$9-14 and banners ~$0.35-0.55. In LatAm, rewarded pays ~$1.90 (Android) to $3.75 (iOS) and banners ~$0.10. **A Brazilian banner impression is worth about 1/5 of a US one, and 1/20-1/40 of a Brazilian rewarded view.** A banner-only game earns very little, especially in LatAm. Adding even one well-placed rewarded slot could plausibly double or triple ad revenue.

### Cited Findings
- Appodeal Q4 2024 (100k+ apps, 70+ networks), via Mistplay:
  - **Rewarded video:** North America Android **$9.20** / iOS **$13.90**; LATAM Android **$1.90** / iOS **$3.75**; US average **$15.15**.
  - **Interstitial:** NA Android $9.70 / iOS $13.60; LATAM Android $1.90 / iOS $3.75; US $12.65.
  - **Banner:** NA Android **$0.55** / iOS **$0.35**; LATAM **$0.10 / $0.10**; US $0.50.
  — [Mistplay (Appodeal Q4 2024)](https://business.mistplay.com/resources/mobile-ads-ecpm/)
  - Note: LATAM rewarded and interstitial show identical figures in this summary, which may be a transcription artifact.
- Appodeal's report says rewarded has the highest eCPM on both platforms, banners are consistently lowest in every region, interstitials are strongest in NA/Europe, and Android does relatively well in LATAM/APAC. — [Appodeal eCPM report 2025 (PDF)](https://appodeal.com/the-mobile-ecpm-report-updated-q4-2024-view)
- MonetizeMore network data (monthly, period labelled 2024 on the page fetched; the page title references 2026):
  - **Interstitial Brazil $2.09-$3.67** (peak Nov-Dec), **US $6.50-$8.57**.
  - **App-open Brazil $0.54-$1.10**, Mexico $1.02-$1.75, US $6.50-$10.51.
  — [MonetizeMore eCPM insights](https://www.monetizemore.com/blog/ecpm-insights/)
  - The search-engine claim that "Brazil rewarded peaked at $1.10 in December 2025" is **wrong**: $1.10 is Brazil's *app-open* eCPM in MonetizeMore's table.
- US Android rewarded eCPM $16.49 (Q4 2024/early 2025). LATAM Android rewarded ~$2.00. — [Maf.ad / Mistplay summary via search](https://business.mistplay.com/resources/mobile-ads-ecpm/)
- Rewarded eCPMs are often 5-20x banner eCPMs. Brazil Android rewarded is ~$1-3 and US iOS rewarded ~$10-25 in 2026 **[secondary blog]**. — [MonetizeMore pt-BR](https://www.monetizemore.com/pt-br/blog/insights-sobre-ecpm-2024-25/)
- Blended ARPDAU: **~$0.15-0.50 for hybridcasual vs $0.03-0.08 for hypercasual** **[secondary blog]**. — [Playio](https://blog.playio.co/arpdau-benchmarks-mobile-games), [Juego Studio](https://www.juegostudio.com/blog/arpdau-benchmarks-by-game-genre)
- Liftoff/Singular 2025: Party and Match genres have the highest ad ARPU ($4.90 and $2.99). Hybrid/hypercasual puzzle revenue rose 240% over 12 months. — [Liftoff 2025 Casual Gaming Apps Report](https://liftoff.ai/?p=34267) (search summary)

### Inferences (rough math, clearly assumption-based)
Per 1,000 DAU per day, revenue = views/DAU × eCPM.

Assumptions:
- Banner: ~15 refreshed impressions/DAU (a ~10-15 minute daily session with 30-60 s refresh).
- Rewarded: 0.3-0.8 views/DAU. Unity's 36-38% of DAU engaging, at ~1-2 views each; this cozy game's more limited placements are the low end.
- Interstitial: 1-2 per DAU.

| Setup | US (eCPM) | US $/day per 1k DAU | LatAm/Brazil (eCPM) | LatAm $/day per 1k DAU |
|---|---|---|---|---|
| Banner only | ~$0.50 | ~$7.50 (ARPDAU ≈ $0.0075) | ~$0.10 | ~$1.50 (≈ $0.0015) |
| + Interstitial | ~$12.65 × 1-2 | +$13-25 | ~$1.90-3.67 × 1-2 | +$2-7 |
| + Rewarded (0.3-0.8/DAU) | ~$15 | +$4.50-12 | ~$1.90-3.75 | +$0.60-3.00 |

Reading the table:
- Banner-only ARPDAU is roughly $0.0075 (US) and $0.0015 (Brazil). That is an order of magnitude below the hybridcasual $0.15-0.50 range, which relies on interstitials and IAP.
- A modest rewarded setup (a hint + a continue + a doubler) could add roughly 60-160% to a US banner-only game's ad revenue and 40-200% in Brazil, without the retention risk of interstitials.
- Both platforms are included: iOS eCPMs run ~1.5-2x Android in NA and LATAM.
- These are order-of-magnitude figures, not forecasts. Actual AdMob fill and eCPM on a new, low-volume app are often below network averages.

### Gaps
- No verified Brazil-specific *rewarded* or *banner* eCPM was found, only LATAM aggregates. Spain and Spanish-speaking LatAm countries are not broken out individually.
- AdMob-specific (as opposed to mediation-network) benchmarks were not found. The Appodeal/MonetizeMore numbers include multi-network bidding, which AdMob-only setups may not match.
- Tenjin's 2026 ad-monetization benchmark (tenjin.com/blog/ad-mon-gaming-2026/) returned 403 and could not be read.

---

## 5. Remove-ads IAP: price, conversion, whether it should remove rewarded, what else it grants

### Takeaway
Remove-ads in top puzzle/word games is priced **$9.99-$14.99** one-off, often beside a weekly VIP ($3.99-$4.49/week) that adds daily currency and free hints. Remove-ads typically removes forced ads (interstitials, banners) and **not** opt-in rewarded ads. The weekly subscriptions in Block Blast and Words of Wonders explicitly bundle perks. No reliable published conversion rate for remove-ads alone was found; overall F2P payer conversion is ~2-5% (one 2024 figure is 1.83%).

### Cited Findings
- Sudoku.com "No Ads" **$14.99**. — [App Store listing](https://apps.apple.com/us/app/sudoku-com-number-games/id1193508329?xs=1)
- Words of Wonders Remove Ads **~$9.99 (¥1,500)**. The Pro Membership at **$3.99/week** bundles remove-ads + double daily gift + 2 free hints per level. — [App Store JP listing](https://apps.apple.com/JP/app/id1369521645)
- Block Blast: Remove Ads **$9.99** or **$4.49/week**. The subscription removes *interstitials* and adds daily gems and boosters, so rewarded stays. Disputed by Applixir, which says there is no remove-ads purchase. — [Udonis](https://www.blog.udonis.co/statistics/block-blast); [Applixir](https://www.applixir.com/blog/the-block-blast-playbook-what-127m-in-ad-revenue-actually-bought/)
- Payer conversion in mobile games is typically 2-5%, with 1.83% of users making an IAP on average (Unity 2024 reporting, via summary). — [Business of Apps](https://www.businessofapps.com/data/mobile-game-conversion-rates/), [Tenjin glossary](https://tenjin.com/glossary/mobile-app-monetization/)
- Remove-ads is a non-consumable, restorable purchase. — [Unity IAP guide](https://unity.com/resources/in-app-purchases-guide)

### Inferences
- If rewarded videos are added, keep them available to remove-ads owners. They are opt-in, and removing them would take away free rewards the buyer might want. Industry practice (Block Blast's sub removes interstitials only) supports this.
- One option is to let owners **skip the video and get the reward directly** for a small, capped set of placements (e.g. the extra hint), as a perk of the purchase. This is how VIP subscriptions add value, and it gives the lifetime purchase a reason to exist beyond hiding a banner. A banner in Brazil earns only ~$0.0015/DAU/day, so the "remove ads" promise alone is weak there.
- At US$4.99 / R$19.99 the price is well below peers ($9.99-14.99). With only a banner to remove, that is defensible. If rewarded perks are added to the purchase, there is room to raise the price.

### Gaps
- No credible published conversion rate specifically for remove-ads purchases in puzzle games was found.
- No A/B data was found on whether exempting remove-ads buyers from rewarded (or granting skip-the-ad rewards) changes their retention or revenue.
