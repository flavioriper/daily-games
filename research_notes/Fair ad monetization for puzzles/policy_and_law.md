# Platform policy and legal constraints on ads and virtual-currency sales (Brazil, US, EU, Spanish-speaking markets) — as of 2026-09

Context evaluated: cozy daily puzzle collection, Android + iOS, AdMob with UMP consent, pt-BR/es/en, no age gate, earned-only gold (nothing random, nothing sold yet). Proposals: (1) interstitial *before starting a game* every 2nd game after a daily ad-free quota; (2) rewarded videos for extra hints / doubled rewards / an item after losing; (3) purchasable premium coin for arcade advantages and hints.

## Google AdMob / Google Publisher policies (interstitial, app open, rewarded)

### Takeaway
AdMob allows interstitials only "at logical breaks" between content (pages, stages, levels), never on app load/exit, never back-to-back, and at most one per two user actions; a rewarded ad needs an explicit opt-in with the action and reward disclosed beforehand, and the reward must be delivered. The "before starting a game" placement is legal on AdMob's own terms only if it sits at a clear break (for example, after tapping a card on the menu, before the board loads, never as a surprise). Google Play's own Ads policy (next section) is stricter.

### Cited Findings
- Disallowed: "Do not place interstitial ads on app load and when exiting apps"; interstitials belong between content pages. — [AdMob: Disallowed interstitial implementations](https://support.google.com/admob/answer/6201362)
- Disallowed: "Placing an interstitial ad after every user action, including but not limited to clicks, swipes, etc." Guidance is "no more than one interstitial ad after every two user actions", and no interstitial "immediately after another interstitial ad was shown." — [AdMob 6201362](https://support.google.com/admob/answer/6201362)
- Disallowed: ads that prevent viewing the app's core content or interfere "with navigating or interacting with the app's core content and functionality." — [AdMob 6201362](https://support.google.com/admob/answer/6201362)
- Disallowed: "Placing interstitial ads so that they suddenly appear when a user is focused on a task at hand." Interstitials should appear only "at logical breaks in between your app's content (e.g. pages, stages, or levels)". Google also recommends preloading interstitials so they never appear unexpectedly. — [AdMob 6201362](https://support.google.com/admob/answer/6201362)
- App open ads: shown only "when the user opens or switches back to an app", over the splash or loading screen. No other ad immediately before or after one. "Apps within Google Play's Designed for Families program can't use app open ads". The close button may be delayed up to 2 s (5 s with high-engagement ads). — [AdMob: App open ads guidance](https://support.google.com/admob/answer/9341964)
- Rewarded ads: "must only be served after a user affirmatively and unambiguously opts in" (rewarded *interstitial* format excepted). Publishers must give "clear, accurate and conspicuous disclosure of the action(s) required and reward(s) offered prior to each instance", and "must deliver the promised reward(s) to the user upon completion." Direct monetary rewards are forbidden. Users must be able to skip without penalty to normal use. — [AdMob rewarded ads policy](https://support.google.com/admob/answer/7313578)

### Inferences
- Hint-for-video and double-reward videos fit the rewarded-ad policy as long as each is a visible, opt-in button that names the reward before the video, and the reward is always granted after completion. An "item after losing" offer is also allowed if it is an optional button on the loss screen, not an auto-playing ad.
- A frequency of "every 2nd game" meets AdMob's one-per-two-actions ceiling. The real risk is the *position* (the start of a game; see Google Play below), not the frequency.
- A forced interstitial on the first app open of the day would be an app-load interstitial, which is disallowed. If a launch ad is ever wanted, the approved format is the app open ad, and that is closed to Designed for Families apps.

### Gaps
- I did not fetch the Better Ads Standards / Coalition for Better Ads mobile list directly. The AdMob pages above are the binding rules for this app.

## Google Play policies (Ads, Families, target audience, virtual currency)

### Takeaway
Google Play's Ads policy explicitly bans full-screen ads "during game play at the beginning of a level or during the beginning of a content segment", and ads that show "unexpectedly". That directly conflicts with an interstitial *before starting a game*. The compliant spot is after a game: the result or win screen, or on returning to the menu. If the game's target audience includes children, the Families rules add more: certified SDKs only, no interest-based ads, no interstitial at launch, rewarded/opt-in ads closeable after 5 s, and a clear coin-versus-money distinction.

### Cited Findings
- "Full screen interstitial ads of all formats (video, GIF, static, etc.) that show unexpectedly, typically when the user has chosen to do something else, are not allowed." — [Google Play Ads policy](https://support.google.com/googleplay/android-developer/answer/9857753)
- "Ads that appear during game play at the beginning of a level or during the beginning of a content segment are not allowed." — [Google Play Ads policy](https://support.google.com/googleplay/android-developer/answer/9857753)
- "Full screen interstitial ads of all formats that are not closeable after 15 seconds are not allowed." Exception: "Opt-in full screen interstitials or full screen interstitials that do not interrupt users in their actions (for example, after the score screen in a game app) may persist more than 15 seconds." — [Google Play Ads policy](https://support.google.com/googleplay/android-developer/answer/9857753)
- Apps may not "force a user to click an ad or submit personal information for advertising purposes before they can fully use an app." Disruptive ads are those "displayed to users in unexpected ways, that may result in inadvertent clicks, or impairing or interfering with the usability of device functions." — [Google Play Ads policy](https://support.google.com/googleplay/android-developer/answer/9857753)
- Families Ads and Monetization, for ads shown to children or to users of unknown age: "Only use Google Play Families Self-Certified Ads SDKs" and "Ensure ads displayed to those users do not involve interest-based advertising" or remarketing. Ad content must be age-appropriate, and children's advertising laws apply. — [Google Play Families Ads & Monetization](https://support.google.com/googleplay/android-developer/answer/9893335)
- Families prohibited formats: ads without "a clear means to dismiss"; "Interstitial monetization and advertising displayed immediately upon app launch"; rewarded/opt-in ads "not closeable after 5 seconds"; "Multiple ad placements on a page"; ads "not clearly distinguishable from your app content"; "Deceptive ads that force the user to click-through". — [Play Families 9893335](https://support.google.com/googleplay/android-developer/answer/9893335)
- Families monetization: failing to provide "a distinction between the use of virtual game coins versus real-life money" is prohibited. — [Play Families 9893335](https://support.google.com/googleplay/android-developer/answer/9893335)

### Inferences
- **Proposal 1 as written ("interstitial before starting a game") is the placement Google Play names as not allowed.** Moving the same frequency (every 2nd game after a daily quota) to *after* a solve/loss, on the win screen's way back to the menu, keeps the business logic and is the placement Google cites as acceptable.
- The game has cute characters, pastel art and simple puzzles, so it plausibly "appeals to children" whatever the declared target audience. If the Play Console target audience includes under-13s, the Families rules apply: AdMob is a self-certified Families SDK, the child-directed/TFUA tags must be set, ads must not be personalised, the ad-free-at-launch rule applies and app open ads are unavailable.

### Gaps
- I did not fetch the full text of Play's Target Audience and Content declaration, Teacher Approved criteria, or the Payments policy (Play Billing required for digital goods; loot-box odds disclosure under "Payments" / "Real-money gambling, games and contests"). The Play Payments policy is well known to require Play Billing for in-app digital currency, but I did not re-verify its 2026 text here.

## Apple App Store Review Guidelines

### Takeaway
Selling coins or boosters must use Apple IAP (3.1.1). Random paid items need disclosed odds. Interrupting ads need visible, large close buttons and must not trick users (2.5.18). Tracking needs ATT consent, and access may not be conditioned on it. Kids Category apps essentially cannot carry third-party ads. Apple's text contains no explicit rule against rewarding ad views, but it does ban artificially inflating impressions.

### Cited Findings
- 3.1.1: "Apps offering 'loot boxes' or other mechanisms that provide randomized virtual items for purchase must disclose the odds of receiving each type of item to customers prior to purchase." Digital goods, including currencies, must be sold through in-app purchase. — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 2.5.18: ads must be "appropriate for the app's age rating", may not use targeted/behavioural ads based on data "from kids (e.g. from apps in the App Store's Kids Category)", and "Interstitial ads or ads that interrupt or block the user experience must clearly indicate that they are an ad, must not manipulate or trick users into tapping into them, and must provide easily accessible and visible close/skip buttons large enough for people to easily dismiss the ad." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 3.2.2(iii), unacceptable: "Artificially increasing the number of impressions or click-throughs of ads, as well as apps that are designed predominantly for the display of ads." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 5.1.2(i): "You must receive explicit permission from users via the App Tracking Transparency APIs to track their activity." Apps "may not require users to enable system functionalities (e.g. ... tracking) in order to access functionality, content, use the app, or receive monetary or other compensation". — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 1.3 Kids Category: "should not include third-party analytics or third-party advertising"; contextual ads only in limited cases, with human review of creatives. 5.1.4(a): apps "intended primarily for kids should not include third-party analytics or third-party advertising." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### Inferences
- Rewarded videos are fine on iOS provided rewards never depend on granting ATT (5.1.2(i)). "Watch an ad for a hint" does not require tracking, so it is compliant.
- Staying out of the Kids Category keeps AdMob viable on iOS. If the app is later positioned for kids, third-party ads essentially go away.

### Gaps
- Apple's guidelines have no clause on "pay-to-win" or on offers at the moment of failure. Those are consumer-law questions (see below).

## Brazil: Lei 15.211/2025 (ECA Digital), CDC and CONANDA Resolução 163

### Takeaway
The ECA Digital has been in force since **17 March 2026**. It applies to any app "directed at or of probable access by" minors, including foreign ones and games. It **bans loot boxes** (paid *random* rewards) in such games, **bans profiling-based advertising to children and adolescents**, and requires reliable age verification (not self-declaration), protective defaults and parental controls, including the ability to restrict purchases. It does not ban the sale of *non-random* currency or boosters, but parental purchase controls and protective defaults apply. The long-standing CDC art. 37 §2 and CONANDA Res. 163 also treat advertising that exploits a child's inexperience as abusive. Penalties reach R$50 million or 10% of revenue.

### Cited Findings
- Art. 20: "São vedadas as caixas de recompensa (loot boxes) oferecidas em jogos eletrônicos direcionados a crianças e a adolescentes ou de acesso provável por eles, nos termos da respectiva classificação indicativa." — [Lei 15.211 cap. VII (Vade Mecum mirror)](https://www.vademecumprevidenciario.com.br/legislacao/nivel/lei_00152112025/capitulo-vii-dos-jogos-eletronicos); official text at [Planalto](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/l15211.htm) (the Planalto page reset the connection twice, so the text was read from the mirror)
- Loot-box definition, as paraphrased by counsel: a feature enabling "pagamento, a aquisição de itens virtuais consumíveis ou vantagens aleatórias sem conhecimento prévio do conteúdo nem garantia de utilidade" — the element is *randomness / unknown content*. — [Assis e Mendes](https://assisemendes.com.br/loot-boxes-eca-digital-e-monetizacao-em-jogos-2836273/)
- Art. 21: games with user-to-user messaging must follow Lei 14.852 art. 16 safeguards and, by default, limit interaction to ensure parental consent (not relevant here: no chat). — [Vade Mecum mirror](https://www.vademecumprevidenciario.com.br/legislacao/nivel/lei_00152112025/capitulo-vii-dos-jogos-eletronicos)
- Advertising: "É vedada a utilização de técnicas de perfilamento para direcionamento de publicidade comercial a crianças e a adolescentes, bem como o emprego de análise emocional, de realidade aumentada, de realidade estendida e de realidade virtual para esse fim." Secondary sources place this in arts. 22–23. — [TechTudo / search summary](https://www.techtudo.com.br/guia/2026/03/eca-digital-entenda-como-a-lei-felca-pode-afetar-os-games-no-brasil-edjogos.ghtml); [Conjur](https://www.conjur.com.br/2026-mar-21/eca-digital-a-resposta-a-nova-infancia-consumidora//?print=1)
- In force since 17 March 2026; scope covers apps, games and app stores "de acesso provável" by minors, including companies based abroad. — [Machado Meyer (listing)](https://www.machadomeyer.com.br/pt/inteligencia-juridica/publicacoes-ij/direito-digital/estatuto-digital-da-crianca-e-do-adolescente-lei-n-15-211-2025-entra-em-vigor-em-17-de-marco-de-2026); [Assis e Mendes](https://assisemendes.com.br/loot-boxes-eca-digital-e-monetizacao-em-jogos-2836273/)
- Per a games-focused firm: art. 9 requires "mecanismos confiáveis de verificação de idade" and forbids mere self-declaration; art. 18 requires Portuguese-language parental tools, including to "restrict purchases and financial transactions" and track usage time; art. 7 requires the most protective settings by default. Penalties go up to R$50 million or 10% of revenue, plus suspension or prohibition. — [Caputo Duarte Advogados](https://caputoduarte.com.br/lei-felca-eca-digital-15-211-2025-novas-obrigacoes-e-impactos-praticos-para-estudios-de-jogos-brasileiros/) (article numbers are the firm's; not verified against the official text)
- Enforcement climate: in June 2026 the TJDFT condemned a Riot Games subsidiary to R$15 million in collective moral damages for offering paid random rewards to children in League of Legends. A party has asked the STF to allow random rewards for minors. — [TJDFT news](https://www.tjdft.jus.br/institucional/imprensa/noticias/2026/junho/justica-condena-empresa-de-jogos-eletronicos-por-pratica-abusiva-com-criancas-e-adolescentes-em-recompensas-pagas); [Gazeta do Povo](https://www.gazetadopovo.com.br/republica/missao-pede-que-stf-autorize-recompensas-aleatorias-a-criancas-e-adolescentes-em-jogos/)
- CDC art. 37 §2 treats as abusive advertising that "se aproveite da deficiência de julgamento e experiência da criança". CONANDA Res. 163/2014 (13 March 2014) declares advertising and marketing communication *directed at* children abusive, in any medium including in-app. — [Jus.com.br on Res. 163](https://jus.com.br/artigos/55833/res-n-163-conanda-e-publicidade-direcionada-ao-infantil); [Res. 163 text (MPBA)](https://mpba.mp.br/sites/default/files/biblioteca/crianca-e-adolescente/publicidade-e-consumo-na-infancia/conanda/resolucao_163_conanda.pdf)

### Inferences
- The current design (earned-only gold, nothing random, every gift shown before it is claimed) is outside the loot-box ban. A **non-random** paid premium coin or booster is not banned by art. 20. However, because a cozy puzzle game is plausibly "de acesso provável" by minors, the game would owe age verification, protective defaults and parental purchase controls. The simplest route is to rely on store-level controls (Play/Apple family purchase approval) and not target children. Whether store controls satisfy art. 18 is not settled.
- Personalised AdMob ads to users who may be minors in Brazil conflict with the profiling ban. With no age gate, the safest reading is to serve non-personalised ads to Brazilian users (or to users of unknown age), or to add an age signal and tag under-18s for non-personalised serving (AdMob's TFUA).
- Any in-game prompt telling a child to buy coins ("buy now to keep going!") risks being "abusive" under CDC art. 37 §2 and Res. 163 as well as the EU principles below.

### Gaps
- The Planalto page could not be fetched (connection reset), so the article numbers for age verification, parental controls, defaults, ads and penalties come from law-firm summaries, not the official text.
- I found no ANPD regulation or decree specifying acceptable age-verification methods for small apps, and no guidance on whether app-store age signals suffice.
- I found no source saying the ECA Digital restricts rewarded ads as such.

## EU (DSA, CPC Key Principles on in-game virtual currencies), UK (ASA/CAP)

### Takeaway
The DSA bans profiling-based ads to users known with reasonable certainty to be minors. The Commission's July 2025 art. 28 guidelines say a terms-of-use disclaimer does not settle whether a service is accessible to minors. The CPC Network's March 2025 Key Principles (non-binding, but based on the UCPD, CRD and UCTD) govern *purchasable* virtual currency. They require a real-money price on every item, no multiple currencies or exchanges, no mismatched bundles, withdrawal-right information, and no exhortation to children. They also recommend real-money spending be **disabled by default** unless the game is adults-only. The principles expressly exclude currency obtainable only through gameplay.

### Cited Findings
- CPC scope: applies to currencies "purchased with real-world monetary value". Excluded: "in-game virtual currencies that can solely be obtained through gameplay and that are therefore not available to purchase with real-world money". Published 21 March 2025. — [CPC Key Principles PDF](https://esportslegal.news/wp-content/uploads/2025/03/Key-principles-on-in-game-virtual-currencies.pdf); [Commission workshop news, 3 June 2025](https://commission.europa.eu/news/european-commission-hosts-stakeholders-talks-application-cpc-networks-key-principles-games-virtual-2025-06-03_en)
- Principle 1: the real-money price of in-game content or services "must be provided ... in a clear and comprehensible manner"; items priced in currency should also show real money, "without applying quantity discounts or other promotional offers". — [CPC PDF](https://esportslegal.news/wp-content/uploads/2025/03/Key-principles-on-in-game-virtual-currencies.pdf)
- Principle 2, practices to avoid: "mixing different in-game virtual currencies in one video game for purchasing" and "Requiring several exchanges of in-game virtual currencies before making any in-game purchase". — [CPC PDF](https://esportslegal.news/wp-content/uploads/2025/03/Key-principles-on-in-game-virtual-currencies.pdf)
- Principle 3, avoid: "Offering in-game virtual currencies only in bundles mismatching the value of purchasable in-game digital content", and denying the choice of specific amounts. "Exploiting cognitive biases in a manner that causes consumers to either overspend ... or to be left with unneeded amounts" is likely unfair. — [CPC PDF](https://esportslegal.news/wp-content/uploads/2025/03/Key-principles-on-in-game-virtual-currencies.pdf)
- Principle 5: respect the 14-day right of withdrawal (CRD arts. 9–16). Principle 6: fair terms, with no unilateral change to currency value. — [CPC PDF](https://esportslegal.news/wp-content/uploads/2025/03/Key-principles-on-in-game-virtual-currencies.pdf); [Baker McKenzie](https://connectontech.bakermckenzie.com/european-consumer-protection-network-issues-new-key-principles-on-in-game-virtual-currencies-impact-for-gaming-and-gambling-entities-in-belgium-the-eu-and-beyond/)
- Principle 7 (UCPD arts. 5–8 and Annex I point 28): "any video game which is not exclusively intended for an adult audience should expect a significant part of its player base to be under the age of 18". "Do not use commercial practices that directly exhort children to buy in-game virtual currencies ... or persuade adults to buy it for them". Ensure "age-appropriate default settings ... such as by default disabling the possibility of spending real-world money in the video game if the video game is not exclusively limited to an adult audience". Age gates "do not limit traders' responsibilities". Business models built on "whales" are judged by a stricter threshold. — [CPC PDF](https://esportslegal.news/wp-content/uploads/2025/03/Key-principles-on-in-game-virtual-currencies.pdf)
- DSA art. 28: platforms accessible to minors must ensure a high level of privacy, safety and security, and "must also not show advertisements based on profiling where they are aware with reasonable certainty that the recipient of the services is a minor". Guidelines finalised 14 July 2025; "a simple disclaimer in the terms of use is no longer sufficient" to establish that a service is not accessible to minors. — [Taylor Wessing](https://www.taylorwessing.com/en/insights-and-events/insights/2025/07/rd-european-commission-guidelines-on-protection-of-minors-under-the-digital-services-act); [Digital Poland](https://digitalpoland.org/en/blog/2025/07/european-commission-publishes-dsa-article-28-guidelines-on-protection-of-minors)
- UK ASA/CAP in-game purchase guidance: make spending easy to understand; say before download whether a game has in-game purchases or loot boxes. Where currency is only bought with real money, the storefront and inducements count as advertising (a "direct proxy" for money), and the cost must be clear. — [ASA guidance PDF](https://www.asa.org.uk/static/4028c436-5861-4035-8d98c148d3c66b7e/Guidance-on-advertising-in-game-purchases.pdf); [Lewis Silkin](https://www.lewissilkin.com/insights/2021/09/23/asa-issues-new-guidance-on-advertising-in-game-purchases-102h772)

### Inferences
- The current earned-only gold is outside the CPC principles entirely. The moment coins are sold, the full list applies: a real-money price shown beside every coin-priced booster or hint, one currency only, packs sized to match item prices (or exact amounts), and withdrawal information. The "disabled by default for a non-adult game" recommendation is the hardest to reconcile with a casual all-ages game.
- A second premium coin next to earned gold would be exactly the "mixing different in-game virtual currencies" practice the principles warn against. If coins are ever sold, selling the *same* gold (and showing its real-money price) is the cleaner design.
- DSA art. 28 obliges "online platforms" (services hosting user content), so a single-player game without UGC is probably not a DSA platform. GDPR consent (UMP) still governs personalised ads in the EU. This is an inference, not a sourced conclusion.

### Gaps
- I found no specific 2025–2026 UK CMA guidance on in-game purchases. The ASA guidance found is from 2021 (updated), and I did not confirm a newer version.
- I did not locate Spanish or Latin American (Mexico, Argentina, Colombia) rules on virtual currency or children's advertising. Spain's draft loot-box law status was not checked.

## US: COPPA and FTC (dark patterns, virtual currency)

### Takeaway
Under COPPA, an app directed at children, or a mixed-audience app, may not use persistent identifiers for behavioural ads to under-13s without verifiable parental consent. The amended COPPA Rule has been in force since 23 June 2025, with compliance required by **22 April 2026**, including new mixed-audience standards. The FTC's $20 million HoYoverse (Genshin Impact) order in January 2025 treats obscured virtual-currency pricing as a deceptive dark pattern and required parental approval for under-16 purchases of random items.

### Cited Findings
- Amended COPPA Rule effective 23 June 2025; compliance date 22 April 2026. Adds expanded personal-information definitions, "new standards for 'mixed audience' services", and stricter retention and security rules. — [BBB National Programs](https://bbbprograms.org/media/insights/blog/coppa-amended); [Loeb & Loeb](https://www.loeb.com/en/insights/publications/2025/05/childrens-online-privacy-in-2025-the-amended-coppa-rule); [Toy Association](https://www.toyassociation.org/ta/PressRoom2/News/2026-News/updated-coppa-rule-requirements-take-effect-april-22.aspx)
- FTC v. HoYoverse: $20 million. The FTC alleged COPPA violations and deception about loot-box costs and odds via a "convoluted virtual currency system". The order requires that under-16s cannot buy loot boxes without parental approval, that loot boxes can be bought directly with real money, and that odds and exchange rates be disclosed. — [FTC business blog](https://ftc.gov/business-guidance/blog/2025/01/level-tips-businesses-ftcs-settlement-genshin-impact-developer-hoyoverse); [PocketGamer.biz](https://www.pocketgamer.biz/hoyoverse-agrees-to-20-million-settlement-with-ftc-over-loot-boxes)

### Inferences
- If the US Play/App Store listing or the art implies child appeal, AdMob requests should be tagged child-directed for under-13 or unknown-age users, which means non-personalised ads only. Adding a neutral age screen, sending under-13s child-directed requests and teens TFUA would satisfy COPPA, the ECA Digital and the DSA with one mechanism.
- FTC reasoning, echoed by the CPC principles, makes real-money price transparency for coins the common denominator across all markets.

### Gaps
- I did not fetch the FTC's 2022 "Bringing Dark Patterns to Light" report or the Epic Games (Fortnite) $245 million order text in this session. Both are relevant precedents on unwanted purchases and button placement but are not cited here.

## Pay-to-win and pressure at the moment of failure

### Takeaway
No platform rule bans an optional "continue / item after losing" offer. Google even names "after the score screen" as the non-interrupting place for full-screen ads. Consumer regulators do, however, target *exploiting vulnerabilities* and *direct exhortation to children* (UCPD Annex I point 28; CPC Principle 7; CDC art. 37 §2; CONANDA 163). A paid continue pushed at the frustration moment to an audience that may include children is the highest-risk variant. A rewarded-video continue (no money) is materially lower risk. A paid one should be neutral in wording and never on a timer.

### Cited Findings
- "Opt-in full screen interstitials or full screen interstitials that do not interrupt users in their actions (for example, after the score screen in a game app) may persist more than 15 seconds." — [Google Play Ads policy](https://support.google.com/googleplay/android-developer/answer/9857753)
- CPC: consumers may be "vulnerable only in context ... in the context of a video game that includes practices that could exploit a specific vulnerability, for example problematic spending behavior". Traders should ensure that "gameplay does not exploit these vulnerabilities or unfairly influence consumers' economic behavior". — [CPC PDF](https://esportslegal.news/wp-content/uploads/2025/03/Key-principles-on-in-game-virtual-currencies.pdf)
- Rewarded ads must be skippable without penalty to normal use and must not use text or icons "to mislead or incentivize users towards a particular choice." — [AdMob rewarded policy](https://support.google.com/admob/answer/7313578)

### Inferences
- An "extra hint for a video" on a daily puzzle whose solve feeds streaks is fair if the video is optional and the hint is also reachable some other way (earned gold). A daily puzzle that becomes much harder without paying would read as pay-to-win on a *daily shared* board, which is a reputational risk rather than a legal one.
- Rewarded videos granting "an item after losing" in arcade games align with the existing Second chance feature. Adding a *paid* coin path there is where UCPD/CDC "exploitation" arguments bite, especially with no age gate.

### Gaps
- I found no regulator text or decision that names "offering a paid continue immediately after a loss" as unlawful per se. The risk here is inferred from the general vulnerability and exhortation rules.
