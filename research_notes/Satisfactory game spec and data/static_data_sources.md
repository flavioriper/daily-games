# Satisfactory machine-readable static data sources (verified 2026-09-27)

Context for every section: the game's current stable version is **1.2** (Experimental from 2026-03-17, build 480321; stable for all platforms 2026-06-02, build 491125), which moved the game to **Unreal Engine 5.6.1** and added Fluid Trucks / Fluid Truck Stations, reworked vehicle paths, weather and a Game Modes menu — [Patch 1.2.0.0](https://satisfactory.wiki.gg/wiki/Patch_1.2.0.0); [Patch 1.2.2.2](https://satisfactory.wiki.gg/wiki/Patch_1.2.2.2). So "1.0/1.1" data is already one version behind. Known Steam versions: 1.0.1.4, 1.1.1.3, 1.1.1.4, 1.1.2.2, 1.2.0.0, 1.2.1.0, 1.2.2.0 — [satisfactory-dev/Fetch-Docs.json README](https://github.com/satisfactory-dev/Fetch-Docs.json).

Quick ranking for a tool that wants items/recipes/buildings/generators/schematics/icons:
1. Raw game Docs (`CommunityResources/Docs/en-US.json`) from your own install — authoritative, every version, needs parsing.
2. Wiki's pre-parsed JSON (`Template:DocsItems.json` / `DocsBuildings.json` / `DocsRecipes.json`) — **already 1.2**, clean schema, but CC BY-NC-SA and no schematic table.
3. SatisfactoryTools `data*.json` — best normalized schema (includes schematics, generators, miners, resources), but master is 1.0 (+FICSMAS); dev branch has 1.1; no 1.2.
4. Everything else (KirkMcDonald, satisfactory-docs-parser) is stuck at 1.0 or earlier.

## 1. The game's own Docs export (CommunityResources/Docs)

### Takeaway
Every public build ships localized JSON dumps of class descriptors at `<install>/CommunityResources/Docs/<locale>.json` (e.g. `en-US.json`); UTF-16, an array of `{NativeClass, Classes[]}` groups whose values are almost all strings, including Unreal-serialized struct/array text that needs its own parser. It is not officially redistributed without the game and carries no explicit license, but a raw copy (1.1) is vendored on GitHub.

### Cited Findings
- Location: `<install>/CommunityResources`, e.g. Steam `C:\Program Files\Steam\steamapps\common\Satisfactory\CommunityResources`; the `Docs` folder holds localized JSON dumps (`en-US.json`, `en-AU.json`, `de.json`, `pt-BR.json` …) covering items, equipment, fluids, buildings, recipes and schematics; "UTF-16 encoded"; the wiki itself generates recipe tables and infoboxes from it — [Community resources (wiki.gg)](https://satisfactory.wiki.gg/wiki/Community_resources)
- Not covered by Docs: creatures, resource node locations, crash sites, collectibles — [Community resources](https://satisfactory.wiki.gg/wiki/Community_resources)
- "The Docs files do not come with any explicit license." — [Community resources](https://satisfactory.wiki.gg/wiki/Community_resources)
- History: single `Docs.json` is the legacy format (first shared 2019-01-20), replaced by per-locale files; now generated automatically at build time — [Community resources](https://satisfactory.wiki.gg/wiki/Community_resources). Fetch-Docs.json's version table records `Docs/Docs.json` for 0.3–0.x builds and `Docs/*.json` for later ones — [Fetch-Docs.json USAGE.md](https://github.com/satisfactory-dev/Fetch-Docs.json/blob/main/USAGE.md)
- Same folder also ships `FactoryGame.usmap` and `CustomVersions.json` (UTF-16 LE), used for asset extraction (section 6) — [SML docs, Extracting Game Files](https://docs.ficsit.app/satisfactory-modding/latest/Development/ExtractGameFiles.html)
- **Verified raw sample (1.1)**: `https://raw.githubusercontent.com/rockfactory/satisfactory-logistics/main/data/docs-en.json` (5,039,030 bytes, last updated by commit "feat: Update data to 1.1 release", 2026-04-12; also `data/docs-it.json`), repo MIT — [rockfactory/satisfactory-logistics](https://github.com/rockfactory/satisfactory-logistics). Note: this copy was re-saved as UTF-8 with CRLF (first bytes `[\r\n\t`), not the original UTF-16. Parsed: a top-level **list of 112 groups**.
- Group key format in 1.x: `"NativeClass": "/Script/CoreUObject.Class'/Script/FactoryGame.FGRecipe'"`; take the text after the last `.` minus the quote. Counts in the 1.1 file: FGRecipe 856, FGSchematic 569, FGBuildingDescriptor 536, FGItemDescriptor 118, FGResourceDescriptor 13, FGItemDescriptorBiomass 16, FGItemDescriptorNuclearFuel 3, FGPowerShardDescriptor 2, FGCustomizationRecipe 106, FGBuildableManufacturer 8, FGBuildableManufacturerVariablePower 3, FGBuildableGeneratorFuel 3, FGBuildableGeneratorNuclear 1, FGBuildableGeneratorGeoThermal 1, FGBuildableResourceExtractor 4, FGBuildableWaterPump 1, FGBuildableFrackingExtractor 1, FGBuildableFrackingActivator 1, FGBuildableConveyorBelt 6, FGBuildableConveyorLift 6, FGBuildablePipeline 4, FGBuildablePipelinePump 3, FGVehicleDescriptor 7, FGEquipmentDescriptor 17, FGConsumableDescriptor 5, plus ~80 other buildable/equipment classes (walls, foundations, trains, drones, portal, elevator, priority power switch, space elevator …) — measured from the file above.
- **FGRecipe fields** (verified on `Recipe_IronPlate_C`): `ClassName`, `FullName`, `mDisplayName`, `mIngredients`, `mProduct`, `mManufacturingMenuPriority`, `mManufactoringDuration` (sic, misspelt; `"6.000000"` seconds), `mManualManufacturingMultiplier`, `mProducedIn`, `mRelevantEvents`, `mVariablePowerConsumptionConstant`, `mVariablePowerConsumptionFactor`. Example `mIngredients`: `((ItemClass="/Script/Engine.BlueprintGeneratedClass'/Game/FactoryGame/Resource/Parts/IronIngot/Desc_IronIngot.Desc_IronIngot_C'",Amount=3))` — raw file above.
- `mProducedIn` is a UE array of object paths, and mixes machines with hand-craft sources: `("/Game/.../Build_ConstructorMk1.Build_ConstructorMk1_C","/Game/.../BP_WorkBenchComponent.BP_WorkBenchComponent_C","/Script/FactoryGame.FGBuildableAutomatedWorkBench")`. Building costs are FGRecipes whose product is a `Desc_*` building descriptor and whose `mProducedIn` is `BP_BuildGun_C` (e.g. `Recipe_ConstructorMk1_C` → 2 Reinforced Iron Plate + 8 Cable) — raw file above.
- **Fluids are in millilitres**: `Recipe_Plastic_C` ingredient `Desc_LiquidOil_C` `Amount=3000`, byproduct `Desc_HeavyOilResidue_C` `Amount=1000` (i.e. 3 m³ / 1 m³); fluid items have `mForm = 'RF_LIQUID'` (or gas) and `mStackSize = 'SS_FLUID'` — raw file above.
- **FGItemDescriptor fields** (verified on `Desc_IronPlate_C`): `mDisplayName`, `mDescription` (CRLF `\r\n`), `mAbbreviatedDisplayName`, `mStackSize` as an enum (`SS_BIG` etc., not a number), `mCanBeDiscarded` (`'True'`/`'False'` strings), `mEnergyValue`, `mRadioactiveDecay`, `mForm` (`RF_SOLID`/`RF_LIQUID`/…), `mGasType`, `mSmallIcon` / `mPersistentBigIcon` (e.g. `Texture2D /Game/FactoryGame/Resource/Parts/IronPlate/UI/IconDesc_IronPlates_256.IconDesc_IronPlates_256`), `mFluidColor` as `(B=255,G=255,R=255,A=0)`, `mResourceSinkPoints` (`'6'`) — raw file above.
- **Building class vs descriptor**: machine stats live on `Build_*_C` (e.g. `Build_ConstructorMk1_C` in FGBuildableManufacturer: `mPowerConsumption '4.000000'`, `mPowerConsumptionExponent '1.321929'`, `mProductionBoostPowerConsumptionExponent '2.000000'`, `mManufacturingSpeed`, `mMinPotential`, `mMaxPotential`, `mProductionShardSlotSize`, `mClearanceData`, ~100 cosmetic/runtime fields); the name/icon/stack info lives on `Desc_*_C` in FGBuildingDescriptor; recipes reference `Build_` in `mProducedIn` and `Desc_` in `mProduct`. Join by stripping the prefix — raw file above.
- Variable-power machines (FGBuildableManufacturerVariablePower, e.g. `Build_QuantumEncoder_C`) carry `mEstimatedMininumPowerConsumption` (sic) / `mEstimatedMaximumPowerConsumption` (0 / 2000); per-recipe power comes from the recipe's `mVariablePowerConsumptionConstant`/`Factor` — raw file above.
- **Generators** (`Build_GeneratorCoal_C`): `mPowerProduction '75.000000'`, `mFuel` is already a real JSON array of objects `{mFuelClass, mSupplementalResourceClass, mByproduct, mByproductAmount}`, `mSupplementalLoadAmount '1000'`, `mSupplementalToPowerRatio '10.000000'`, `mRequiresSupplementalResource 'True'`, `mDefaultFuelClasses` — raw file above.
- **FGSchematic fields** (verified `Schematic_1-1_C`): `mType` (`EST_Milestone`, `EST_MAM`, `EST_Alternate`, `EST_ResourceSink`, `EST_Customization`, `EST_Tutorial`, `EST_HardDrive` …), `mDisplayName`, `mDescription`, `mTechTier` ('1'), `mCost` (same UE item-amount tuple syntax), `mTimeToComplete` ('120.000000'), `mUnlocks` (a real JSON array of `{Class: 'BP_UnlockRecipe_C', mRecipes: '(…paths…)'}` and other unlock kinds), `mSchematicIcon` (a long Slate brush struct string whose `ResourceObject=` holds the texture path), `mSmallSchematicIcon`, `mSchematicDependencies` (JSON array), `mDependenciesBlocksSchematicAccess`, `mHiddenUntilDependenciesMet`, `mRelevantEvents`, `mSubCategories`, `mMenuPriority`, `mIncludeInBuilds` — raw file above. Schematic type breakdown (SatisfactoryTools 1.0 parse): ResourceSink 165, Alternate 109, MAM 96, Milestone 42, Customization 18, Tutorial 6, HardDrive 1 — [SatisfactoryTools data1.0.json](https://raw.githubusercontent.com/greeny/SatisfactoryTools/master/data/data1.0.json)
- **Getting it without owning the game**: old/any versions can be pulled with `steamcmd` `download_depot 526870 526871 <manifest>` (e.g. 1.2.2.0 = `1438688120721473833`, 1.1.2.2 = `1858885725837604498`, 1.0.1.4 = `3007809920758804289`) — but that is the paid client depot (app 526870) and requires a logged-in owning account; the repo says "Until such time as `steamcmd` supports openid auth, this repository will not provide a fully-automated means of fetching Docs.json" — [Fetch-Docs.json](https://github.com/satisfactory-dev/Fetch-Docs.json). Its sibling [satisfactory-dev/Docs.json.ts](https://github.com/satisfactory-dev/Docs.json.ts) (Apache-2.0; npm `@satisfactory-dev/docs.json.ts` 1.6.0, 2026-06-15) has per-version generators/types for Update 3 → 1.2.2.0, but its `data/<version>/Docs/` folders contain only `.gitkeep` — it does **not** redistribute the files.
- Dedicated server: free via `steamcmd +login anonymous +app_update 1690800 validate +quit` (app 1690800, separate from client 526870) — [Dedicated servers (wiki.gg)](https://satisfactory.wiki.gg/wiki/Dedicated_servers)

### Inferences
- Parsing recipe: decode as UTF-16 (strip BOM; be ready for a UTF-8 re-save as in rockfactory's copy); for each group keep the short native class; treat every scalar as a string (`float()`, `'True'` → bool, `SS_*` enums → map to numbers: 1.x stack sizes are 50/100/200/500 per SatisfactoryTools, e.g. Iron Plate SS_BIG → 200); parse `((ItemClass="…'…Desc_X.Desc_X_C'",Amount=N),…)` with a regex like `ItemClass="[^"]*\.(\w+)'?",Amount=([\d.]+)` and path arrays by taking the text after the last `.`; divide fluid amounts by 1000; drop `BP_WorkBenchComponent`/`FGBuildableAutomatedWorkBench`/`BP_BuildGun`/`BP_WorkshopComponent` from `mProducedIn` into "hand/build" flags.
- `Desc_` vs `Build_` naming and the misspellings (`mManufactoringDuration`, `mEstimatedMininumPowerConsumption`) are the most common parser traps.

### Gaps
- **Whether the free dedicated-server depot (1690800) ships `CommunityResources/Docs`** could not be verified: no source found stating it either way, and I did not download the multi-GB depot. Treat as unconfirmed; test with `steamcmd … +app_update 1690800` and check for `CommunityResources/`.
- Byte-level check of an original (UTF-16 LE with BOM?) 1.2 file was not possible without a game install; UTF-16 is per the wiki and SML docs (which say UTF-16 LE for CustomVersions.json).
- No official Coffee Stain Q&A statement on redistribution terms of Docs was found.

## 2. SatisfactoryTools (greeny/SatisfactoryTools)

### Takeaway
The cleanest normalized JSON (items, recipes, schematics, generators, resources, miners, buildings) keyed by class name, MIT code but with a carve-out forbidding reuse of its bundled Coffee Stain images; `master` data is 1.0 (+FICSMAS, Dec 2024), a `dev` branch has a "1.1 update" (Jan 2026), and nothing covers 1.2.

### Cited Findings
- Repo: 535 stars, not archived, last push 2026-03-29 — [GitHub API](https://api.github.com/repos/greeny/SatisfactoryTools)
- `master/data/`: `data.json` (1,553,963 B, pre-1.0), `data1.0.json` (1,728,029 B), `data1.0-ficsmas.json` (1,785,157 B), `debug.json`; last data commits: "Added 1.0" 2024-09-10, "Added ficsmas, fixed icons" / "Fixed ficsmas recipes" 2024-12-07 — [contents](https://github.com/greeny/SatisfactoryTools/tree/master/data)
- Raw URL (verified): `https://raw.githubusercontent.com/greeny/SatisfactoryTools/master/data/data1.0.json`. Top-level keys and counts: items 175, recipes 797, schematics 437, generators 4, resources 13, miners 5, buildings 500 — fetched.
- `dev` branch: `data/data.json` (1,209,494 B) + `aprilData.json`, commit "1.1 update" 2026-01-28; same key set (items 177, recipes 825, schematics 454, buildings 528). Contains 1.1 additions (Priority Merger, Conveyor Wall Hole) but not 1.2's Fluid Truck or Pipeline T-Junction — [dev data.json](https://raw.githubusercontent.com/greeny/SatisfactoryTools/dev/data/data.json) (fetched and diffed)
- Schema samples (verified):
  - item: `{slug, icon, name, description, sinkPoints, className, stackSize (number), energyValue, radioactiveDecay, liquid (bool), fluidColor {r,g,b,a}}`
  - recipe: `{slug, name, className, alternate, time, inHand, forBuilding, inWorkshop, inMachine, manualTimeMultiplier, ingredients[{item, amount}], products[{item, amount}], producedIn[Desc_*], isVariablePower, minPower, maxPower}` — note producedIn uses `Desc_` names, and building recipes have `forBuilding: true`
  - schematic: `{className, type, name, slug, icon, cost[{item,amount}], unlock{recipes[], scannerResources[], inventorySlots, giveItems[]}, requiredSchematics[], tier, time, mam, alternate}`
  - generator: `{className, fuel[], powerProduction, powerProductionExponent, waterToPowerRatio}`
  - miner: `{className, allowedResources[], allowLiquids, allowSolids, itemsPerCycle, extractCycleTime}` (oil pump itemsPerCycle 2000 → mL)
  - building: `{slug, icon, name, description, className, categories, buildMenuPriority, metadata{powerConsumption, powerConsumptionExponent, manufacturingSpeed}, size}`
- Its update pipeline: drop Docs.json in `data/`, `yarn parseDocs` (→ data.json, diff.txt, imageMapping.json); icons extracted with umodel (`-export *_256.uasset -game=ue4.22`) then `yarn generateImages` — [README](https://github.com/greeny/SatisfactoryTools/blob/master/README.md). The umodel instructions are outdated for UE5 (see section 6). Parser source: `bin/parseDocs.ts`, `bin/parsePak.ts`, `bin/generateImages.ts`.
- License: MIT for code, but LICENSE opens with "This repository contains copyrighted material owned by Coffee Stain Studios (www/assets/images/items folder). Permission to use, copy, modify, and distribute this material is granted only for the original repository. Any forks or derivative works are not permitted to use the copyrighted material without explicit permission" — [LICENSE](https://github.com/greeny/SatisfactoryTools/blob/master/LICENSE)

### Inferences
- Good for a quick start at 1.0/1.1 fidelity, and its `parseDocs.ts` is a useful reference implementation to run against a fresh 1.2 Docs file. Do not ship its images.

### Gaps
- Whether the live site (satisfactorytools.com) serves dev's 1.1 data was not confirmed.

## 3. Other GitHub datasets and parsers

### Takeaway
Only the wiki JSON (section 4) and rockfactory's vendored raw Docs are recent; most of the other well-known sources are frozen at 1.0.

### Cited Findings
- **KirkMcDonald/satisfactory-calculator** (Apache-2.0, 81 stars): single hand-curated `data/data.json` (129,006 B) with keys `belts 6, pipes 2, buildings 12, miners 5, items 136, fluids 15, recipes 272, resources 13`; recipe shape `{name, key_name, category, time, ingredients[[key,n]], products[[key,n]]}`; last data commits 2024-09/10 (1.0) → **stuck at 1.0**, no schematics — [repo](https://github.com/KirkMcDonald/satisfactory-calculator), fetched raw.
- **rockfactory/satisfactory-logistics** (MIT, 61 stars, site satisfactory-logistics.xyz): vendors raw `data/docs-en.json` + `docs-it.json` (1.1, 2026-04-12) and parsed `src/recipes/FactoryItems.json`, `FactoryRecipes.json`, `FactoryBuildings.json`, `FactorySchematics.json`, `FactoryMilestoneOnlyUnlocks.json`, plus **`WorldResourceNodes.json` and `WorldCollectibles.json`** (data Docs lacks); parser `scripts/parseDocs.ts`, `scripts/parsers/…` — [repo tree](https://github.com/rockfactory/satisfactory-logistics). At 1.1: missing 1.2's Fluid Truck/Station, SPWN, vehicle paths, Pipeline T-Junction (diffed against wiki 1.2 JSON).
- **lunafoxfire/satisfactory-docs-parser** (MIT): npm `satisfactory-docs-parser` latest 7.0.1 published 2023-01-12 (Update 7 era); repo since rewritten for Deno (`deno run start --docsfile <PATH> --parsed single_file`), pushed 2026-09-10, README: "Don't expect any updates or support" — [GitHub](https://github.com/lunafoxfire/satisfactory-docs-parser), [npm](https://www.npmjs.com/package/satisfactory-docs-parser). npm package is **pre-1.0**.
- **satisfactory-dev/Docs.json.ts** (Apache-2.0): TypeScript types/JSON schemas per version up to 1.2.2.0; npm `@satisfactory-dev/docs.json.ts` 1.6.0 (2026-06-15) — [repo](https://github.com/satisfactory-dev/Docs.json.ts). Brings no data.
- Other active parsers found by GitHub code search for Docs field names: adepierre/ficsit-companion (MIT, pushed 2026-06-14, `scripts/data_extractor.py`), relyen-dev/beltwise-satisfactory (`packages/game-data/src/parseDocs.ts`, pushed 2026-06-15), Scott1903/satisfactory_planner (`Data/read_docs.py`, no license, pushed 2025-06-30), mitaa/production_planner (MPL-2.0, last 2024-10), QuenMBar/satisfactorytools, chwthewke/satisfactory-tools (Scala), satisfactory-dev/Satisfactory-Production-Calculator — [GitHub code search](https://github.com/search?q=%22FGBuildableManufacturerVariablePower%22+%22NativeClass%22&type=code)
- SCIM (satisfactory-calculator.com) exists as a site — [SCIM](https://satisfactory-calculator.com/)

### Inferences
- For 1.2 data from GitHub today, none of the parsed community datasets is current; the practical options are the wiki JSON or parsing a fresh Docs file yourself.

### Gaps
- SCIM exposes no documented public data export/API that I could find; not verified.
- ficsit.app (Satisfactory Mod Repository) was not investigated as a data source; it indexes mods, not base-game data.
- No Python package on PyPI named `satisfactory-docs` (404); I did not do an exhaustive PyPI search.

## 4. satisfactory.wiki.gg (MediaWiki API)

### Takeaway
The official wiki has no Cargo tables, but it keeps three pre-parsed Docs JSON pages that are already **1.2 stable**; fetch them with `action=raw`. Text is CC BY-NC-SA 4.0 (non-commercial); images are Coffee Stain's, hosted under a fair-use claim.

### Cited Findings
- Site: MediaWiki 1.43.6; rights `CC BY-NC-SA 4.0`; extensions include Scribunto; `action=cargotables` returns `{"cargotables":[]}` (no Cargo) — [siteinfo API](https://satisfactory.wiki.gg/api.php?action=query&meta=siteinfo&siprop=rightsinfo|general|extensions&format=json)
- `Module:DocsUtils` loads `mw.loadJsonData('Template:DocsItems.json')`, `'Template:DocsBuildings.json'`, `'Template:DocsRecipes.json'`; its doc says these are "JSON files parsed from the game's Docs.json file, for use in recipe tables and infoboxes" — [Module:DocsUtils](https://satisfactory.wiki.gg/wiki/Module:DocsUtils)
- Raw endpoints (verified, all 200):
  - `https://satisfactory.wiki.gg/index.php?title=Template:DocsItems.json&action=raw` (96,811 B, 196 keys)
  - `https://satisfactory.wiki.gg/index.php?title=Template:DocsBuildings.json&action=raw` (317,718 B, 485 keys)
  - `https://satisfactory.wiki.gg/index.php?title=Template:DocsRecipes.json&action=raw` (703,827 B, 972 keys)
- Revision stamps: DocsItems and DocsBuildings last edited 2026-06-02 with comment "1.2 stable"; DocsRecipes 2026-09-01 "fix Biocoal and Charcoal alts (again)" — [revisions API](https://satisfactory.wiki.gg/api.php?action=query&prop=revisions&titles=Template:DocsRecipes.json|Template:DocsItems.json|Template:DocsBuildings.json&rvprop=timestamp|comment|user&format=json). Content confirms 1.2 (contains `Desc_FluidTruck_C`, `Desc_FluidTruckStation_C`, `Desc_PipelineJunction_T_C`, vehicle paths).
- Schema: each value is an **array** of variants (one per branch) with `stable`/`experimental` booleans.
  - item: `{className, name, description (with <br>), stackSize, energy, radioactive, canBeDiscarded, sinkPoints, abbreviation, form ("solid"…), fluidColor "#ffffff", alienItem, stable, experimental}`
  - building: `{className, name, description, unlockedBy (wikitext), powerUsage, powerGenerated, supplementPerMinute, burnsFuel[], usesMaterials, overclockable, somersloopSlots, isVehicle, stable, experimental}`
  - recipe: `{className, name, unlockedBy (wikitext, e.g. "[[Tier 8]] - Nuclear Power"), duration, ingredients[{item, amount}], products[{item, amount}], producedIn[Desc_*], inCraftBench, inWorkshop, inBuildGun, inCustomizer, manualCraftingMultiplier, alternate, minPower, maxPower, seasons[], stable, experimental}`; includes synthetic generator "burning" recipes (`TempRecipe_NuclearWaste_C`). Fluid amounts look already converted to m³ (nuclear burn: water 1200).
- No schematic/milestone JSON: unlock info is only the `unlockedBy` wikitext string — observed.
- Images: e.g. `File:Iron Plate.png` is 256×256, URL `https://satisfactory.wiki.gg/images/Iron_Plate.png?93d6ef`, in `Category:Item icons`, get via `action=query&prop=imageinfo&iiprop=url` — [imageinfo API](https://satisfactory.wiki.gg/api.php?action=query&titles=File:Iron_Plate.png&prop=imageinfo&iiprop=url|size&format=json). Licence template `{{Copyright game}}` → `License/first-party`: content owned by Coffee Stain; use to illustrate articles "is believed to qualify as fair use" — [Template:License/first-party](https://satisfactory.wiki.gg/wiki/Template:License/first-party)
- Copyrights page: game content is IP of its owners; content the wiki can lawfully license is CC BY-NC-SA 4.0 — [Satisfactory Wiki:Copyrights](https://satisfactory.wiki.gg/wiki/Satisfactory_Wiki:Copyrights)
- `robots.txt` has `Disallow: /api.php` and `Crawl-delay: 1` — [robots.txt](https://satisfactory.wiki.gg/robots.txt)

### Inferences
- The wiki JSON is the fastest route to 1.2 numbers, but it is a derived work under a non-commercial licence; a commercial product (e.g. an ad-supported app) should parse the raw Docs instead, or get permission. Be polite: set a User-Agent, one request per second, and fetch three pages rather than crawling.

### Gaps
- No published numeric API rate limit for wiki.gg was found beyond the crawl-delay in robots.txt.

## 5. Icons and images

### Takeaway
Docs gives every item's icon asset path (`mSmallIcon`/`mPersistentBigIcon`, schematics' `ResourceObject=` inside `mSchematicIcon`), but the pixels have to be extracted from the game's archives with FModel. The ready-made sets (wiki, SatisfactoryTools) are Coffee Stain copyright, on fair-use or restrictive terms.

### Cited Findings
- Icon path example: `Texture2D /Game/FactoryGame/Resource/Parts/IronPlate/UI/IconDesc_IronPlates_256.IconDesc_IronPlates_256` — raw Docs (section 1).
- SatisfactoryTools icons are usable only in the original repository — [LICENSE](https://github.com/greeny/SatisfactoryTools/blob/master/LICENSE)
- Wiki icons are 256 px PNGs under `{{Copyright game}}` (fair use) — section 4 sources.
- Coffee Stain offers a press kit for content creators — [Press - Satisfactory](https://www.satisfactorygame.com/press/)

### Inferences
- Legally safest: extract from your own licensed copy for personal/non-commercial tools, or draw your own icons. No blanket fan-content licence from Coffee Stain was found.

### Gaps
- Could not find an official Coffee Stain fan-content/asset-use policy page; searches returned only the press page.

## 6. Asset extraction (FModel, mappings, AES)

### Takeaway
Use FModel with UE version `GAME_UE5_6` (since 1.2), plus the `FactoryGame.usmap` and `CustomVersions.json` Coffee Stain ships in `CommunityResources`. Assets are in `FactoryGame-Windows.utoc`. The official modding docs describe no AES key step. UModel does not support UE5.

### Cited Findings
- FModel: "Add Undetected Game" → name `Satisfactory`, the install dir, then "select `GAME_UE5_6` for the 'UE Versions' selector"; changed from an earlier value in commit "Update FModel directions to GAME_UE5_6" (2026-06-03) — [ExtractGameFiles.adoc](https://github.com/satisfactorymodding/Documentation/blob/master/modules/ROOT/pages/Development/ExtractGameFiles.adoc), [commits](https://github.com/satisfactorymodding/Documentation/commits/master/modules/ROOT/pages/Development/ExtractGameFiles.adoc)
- "Coffee Stain Studios kindly ships this extra information with the game files": `/CommunityResources/FactoryGame.usmap` (set as FModel "Local Mapping File") and `/CommunityResources/CustomVersions.json` (UTF-16 LE; paste into FModel's custom versions setting) — [SML docs](https://docs.ficsit.app/satisfactory-modding/latest/Development/ExtractGameFiles.html)
- Base game archive `FactoryGame-Windows.utoc`; audio is in the .pak (`FactoryGame/Content/WwiseAudio/…`), not the utoc — same source.
- "UModel does not support Unreal Engine 5" (older instructions targeted 4.26 / ue4.22) — same source; [SatisfactoryTools README](https://github.com/greeny/SatisfactoryTools/blob/master/README.md) still shows umodel `-game=ue4.22`.
- 1.2 upgraded to Unreal Engine 5.6.1 — [Patch 1.2.0.0](https://satisfactory.wiki.gg/wiki/Patch_1.2.0.0)

### Inferences
- The SML guide describes no AES key, and loading works with just the mappings and custom versions, so the archives are very likely unencrypted. That is an inference; I found no explicit statement.
- For 1.0/1.1 installs (UE 5.3-era) a lower `GAME_UE5_x` setting would apply; the guide now documents only 5.6.

### Gaps
- There is no explicit source for "no AES key", and no confirmation of the exact UE version for 1.0/1.1 (commonly cited as 5.3, but not verified here).
- Whether the dedicated server ships the `.usmap` and `CustomVersions.json` is unverified (same gap as Docs).
