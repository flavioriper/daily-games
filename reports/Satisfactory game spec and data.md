# Parse the game, not the wiki: Satisfactory 1.2 end to end

Satisfactory's current stable release is **Update 1.2**. It went live on all platforms on **2026-06-02 as build 491125**, after Experimental opened on 2026-03-17 (build 480321). The update moved the game to **Unreal Engine 5.6.1** and added weather, rebuilt vehicle paths, Fluid Trucks, a Game Modes menu with cost multipliers and world randomization, and the SPWN ([Patch 1.2.0.0](https://satisfactory.wiki.gg/wiki/Patch_1.2.0.0); [Patch 1.2.2.2](https://satisfactory.wiki.gg/wiki/Patch_1.2.2.2)). Almost the whole game can be read by a program, one layer at a time. **Static data** (items, recipes, buildings, schematics) comes from the JSON "Docs" dump that ships in every install. **World data** (nodes, collectibles, crash sites) comes from open community exports of a 1.2 save. **Snapshots** come from the `.sav` format, which is documented and has three maintained parsers that support 1.2. **Live telemetry** comes from the official dedicated-server HTTPS API plus the FICSIT Remote Monitoring mod, which works on 1.2. The main catch is licensing, not technology. Coffee Stain publishes no data licence or fan-content policy. The only ready-parsed 1.2 dataset (the wiki's) is non-commercial. The best open world dataset is GPL-3.0 and partly scraped from a map site that forbids reuse. Most community datasets are still at 1.0 or 1.1. A durable pipeline therefore parses the game's own files from a licensed install and uses the community sets only for validation.

## The game at 1.2: a four-track progression feeding one production graph

Progression has four parts:

- **The HUB.** Six Tier 0 upgrades, then **42 milestones across Tiers 1 to 9** ([Milestones](https://satisfactory.wiki.gg/wiki/Milestones)).
- **The Space Elevator.** Five phases gate the tiers in pairs: phase 1 (50 Smart Plating) opens T3–4, phase 2 opens T5–6, phase 3 opens T7–8, phase 4 opens T9, and phase 5 (1,000 Nuclear Pasta, 1,000 Biochemical Sculptors, 256 AI Expansion Servers and 200 Ballistic Warp Drives) launches Project Assembly and ends the game ([Space Elevator](https://satisfactory.wiki.gg/wiki/Space_Elevator)).
- **The MAM.** About nine research trees for alien and biological resources ([MAM](https://satisfactory.wiki.gg/wiki/MAM)).
- **The AWESOME Shop.** It spends coupons earned by sinking items ([AWESOME Shop](https://satisfactory.wiki.gg/wiki/AWESOME_Shop)).

Alternate recipes come from hard drives. There are **106 alternates** and **118 crash sites**, and after Tier 8 the shop sells unlimited drives at 100 coupons ([Alternate recipes](https://satisfactory.wiki.gg/wiki/Alternate_recipes)).

The production economy runs on a few scalar rules that any model must encode:

- **Node purity** multiplies the base rate by 0.5, 1 or 2. A Mk.1, Mk.2 or Mk.3 miner on a normal node yields 60, 120 or 240 items/min ([Miner](https://satisfactory.wiki.gg/wiki/Miner)).
- **Clock speed** goes up to **250% with three Power Shards**. Machine power scales as clock^**1.321928** (log₂ 2.5), while generator output scales linearly ([Clock speed](https://satisfactory.wiki.gg/wiki/Clock_speed)).
- **Somersloops** add 100%, 50% or 25% of output per slot, depending on whether a machine has 1, 2 or 4 slots. Power then multiplies by (1 + filled/total)² ([Production amplifier](https://satisfactory.wiki.gg/wiki/Production_amplifier)).
- **Belts** Mk.1 to Mk.6 carry 60, 120, 270, 480, 780 and 1,200 items/min ([Conveyor Belts](https://satisfactory.wiki.gg/wiki/Conveyor_Belts)). **Pipes** carry 300 and 600 m³/min ([Pipelines](https://satisfactory.wiki.gg/wiki/Pipelines)).

A Mk.3 miner on a pure node at 250% produces exactly 1,200/min, one Mk.6 belt.

| Layer | Key 1.2 figures | Source |
|---|---|---|
| Raw resources | 10 solid (Iron to SAM), 3 fluid (Water, Crude Oil, Nitrogen) | [Resource node](https://satisfactory.wiki.gg/wiki/Resource_node) |
| Machines (fixed draw) | Smelter/Constructor 4 MW, Packager 10, Assembler 15, Foundry 16, Refinery 30, Manufacturer 55, Blender 75 | [Power](https://satisfactory.wiki.gg/wiki/Power), [Manufacturer](https://satisfactory.wiki.gg/wiki/Manufacturer), [Blender](https://satisfactory.wiki.gg/wiki/Blender) |
| Machines (variable draw) | Particle Accelerator 250–1,500 MW by recipe; Converter 100–400 MW; Quantum Encoder averages 1,000 MW, peaks at 2,000 | [Particle Accelerator](https://satisfactory.wiki.gg/wiki/Particle_Accelerator), [Converter](https://satisfactory.wiki.gg/wiki/Converter), [Quantum Encoder](https://satisfactory.wiki.gg/wiki/Quantum_Encoder) |
| Generators | Biomass 30, Coal 75, Fuel 250, Alien Power Augmenter 500, Nuclear 2,500 MW; Geothermal averages 100/200/400 MW by purity | [Power](https://satisfactory.wiki.gg/wiki/Power), [Nuclear Power Plant](https://satisfactory.wiki.gg/wiki/Nuclear_Power_Plant) |
| Storage and transport | Power Storage holds 100 MWh and charges at up to 100 MW; locomotive draws 25–110 MW and reaches 120 km/h; Drone Port draws 100 MW with 18+18 slots | [Power Storage](https://satisfactory.wiki.gg/wiki/Power_Storage), [Electric Locomotive](https://satisfactory.wiki.gg/wiki/Electric_Locomotive), [Drone Port](https://satisfactory.wiki.gg/wiki/Drone_Port) |
| World | 7.972 × 6.8 km (47.1 km²), 21 biomes, 4 start areas | [World](https://satisfactory.wiki.gg/wiki/World) |

The 1.1 and 1.2 patch notes found so far change logistics, vehicles and quality of life, not recipe rates:

- **1.1** added the Priority Merger, hypertube junctions, the Personnel Elevator and blueprint auto-connect ([Patch 1.1.0.0](https://satisfactory.wiki.gg/wiki/Patch_1.1.0.0)).
- **1.2** added power-line daisy-chaining, the Pipeline T-Junction, 3,200 m³ Fluid Trucks, and Game Modes whose cost multipliers and node randomization alter a world's economics ([Patch 1.2.0.0](https://satisfactory.wiki.gg/wiki/Patch_1.2.0.0)).

That last point matters to the data design. **In 1.2, a world's node table and milestone costs are no longer guaranteed constants.** They are defaults that a save can override.

Three items were not extracted and remain gaps: the full MAM node list with costs, the AWESOME Sink coupon curve, and the creature roster. Patches 1.2.1 through 1.2.4 also exist and were not read line by line.

## Static data lives in the install, and every mirror of it lags or restricts

Every build ships localized class-descriptor dumps at `<install>/CommunityResources/Docs/<locale>.json`. The wiki itself generates its recipe tables from these files ([Community resources](https://satisfactory.wiki.gg/wiki/Community_resources)). They are **UTF-16**, and the top level is an array of `{NativeClass, Classes[]}` groups.

A vendored 1.1 copy parses into **112 groups**, including:

- 856 FGRecipe
- 569 FGSchematic
- 536 FGBuildingDescriptor
- 118 FGItemDescriptor
- 13 FGResourceDescriptor

([rockfactory/satisfactory-logistics docs-en.json](https://raw.githubusercontent.com/rockfactory/satisfactory-logistics/main/data/docs-en.json)).

The file is authoritative, but it takes some work to parse:

- **Nearly every value is a string**, including Unreal-serialized tuples such as `((ItemClass="…Desc_IronIngot_C'",Amount=3))`.
- **Fluid amounts are in millilitres.** Plastic's 3,000 of crude means 3 m³.
- **Two field names are misspelt in the source**: `mManufactoringDuration` and `mEstimatedMininumPowerConsumption`.
- **Machine stats and names live on different classes.** Stats sit on `Build_*_C` classes and names and icons on `Desc_*_C` descriptors, so the two have to be joined.
- **`mProducedIn` mixes machines with the craft bench and build gun.** Building costs are recipes whose producer is `BP_BuildGun_C`.

Schematics carry the whole unlock graph: `mType`, `mTechTier`, `mCost`, `mTimeToComplete`, `mUnlocks` and `mSchematicDependencies` (same source). The Docs do **not** cover creatures, node locations, crash sites or collectibles ([Community resources](https://satisfactory.wiki.gg/wiki/Community_resources)).

Getting the file without buying the game is the hard part. Historical client depots can be fetched with `steamcmd download_depot 526870 526871 <manifest>` (the 1.2.2.0 manifest is `1438688120721473833`), but that requires a logged-in account that owns the game ([Fetch-Docs.json](https://github.com/satisfactory-dev/Fetch-Docs.json)). The dedicated server, by contrast, is a **free anonymous download** (app 1690800) ([Dedicated servers](https://satisfactory.wiki.gg/wiki/Dedicated_servers)). Whether that server depot also ships `CommunityResources/Docs` is **unverified**, and it is the single most valuable open question in this report. If it does, an anonymous CI job can pull fresh static data on every patch.

| Source | Version | Format | License | Verdict |
|---|---|---|---|---|
| Raw Docs `en-US.json` from your install | Any, incl. 1.2.x | UTF-16 JSON, UE string values | **No explicit licence** ([Community resources](https://satisfactory.wiki.gg/wiki/Community_resources)) | Canonical source; parse it yourself |
| Wiki `Template:DocsItems/Buildings/Recipes.json` via `action=raw` | **1.2 stable** (edited 2026-06-02, "1.2 stable") | Clean JSON, stable/experimental variants, fluids in m³ | **CC BY-NC-SA 4.0** ([siteinfo](https://satisfactory.wiki.gg/api.php?action=query&meta=siteinfo&siprop=rightsinfo&format=json)) | Fastest 1.2 numbers; non-commercial; **no schematic table**, only `unlockedBy` wikitext ([Module:DocsUtils](https://satisfactory.wiki.gg/wiki/Module:DocsUtils)) |
| greeny/SatisfactoryTools `data1.0.json` / dev `data.json` | 1.0 on master, 1.1 on dev (2026-01-28), **no 1.2** | Best normalized schema, incl. schematics, generators, miners | MIT code, but bundled images are **forbidden in forks** ([LICENSE](https://github.com/greeny/SatisfactoryTools/blob/master/LICENSE)) | Use `bin/parseDocs.ts` as a reference parser, not as data |
| rockfactory/satisfactory-logistics | 1.1 (2026-04-12) | Raw Docs + parsed JSON + `WorldResourceNodes.json` | MIT repo ([repo](https://github.com/rockfactory/satisfactory-logistics)) | Good 1.1 fixture; missing 1.2 additions |
| KirkMcDonald calculator, lunafoxfire docs-parser | 1.0 / pre-1.0 | Hand-curated or old npm | Apache-2.0 / MIT ([Kirk](https://github.com/KirkMcDonald/satisfactory-calculator), [lunafoxfire](https://github.com/lunafoxfire/satisfactory-docs-parser)) | Stale; skip |
| satisfactory-dev/Docs.json.ts | Types up to 1.2.2.0 | TypeScript types and schemas, **no data** | Apache-2.0 ([repo](https://github.com/satisfactory-dev/Docs.json.ts)) | Useful for validating your own parse |

For **icons and meshes**, Docs gives each asset path (for example `IconDesc_IronPlates_256`), but the pixels have to be extracted from `FactoryGame-Windows.utoc`. The extraction uses FModel set to **`GAME_UE5_6`** plus the `FactoryGame.usmap` mappings file and `CustomVersions.json` that Coffee Stain ships in `CommunityResources`. UModel does not support UE5 ([SML: Extracting Game Files](https://docs.ficsit.app/satisfactory-modding/latest/Development/ExtractGameFiles.html)). The guide describes no AES key step, which suggests the archives are unencrypted, but nothing states it outright. The ready-made icon sets are all Coffee Stain copyright: the wiki's 256 px PNGs are hosted under a fair-use claim ([License/first-party](https://satisfactory.wiki.gg/wiki/Template:License/first-party)), and SatisfactoryTools restricts its images to the original repository.

## World data: centimetre coordinates and a GPL dataset of every node

Unreal stores world positions in **centimetres**. The playable area runs from about x −324,699 to 425,302 and y −375,000 to 375,000. These are SCIM's Leaflet bounds, and they match the wiki's in-game range of −3,246 to 4,253 m by −3,750 to 3,750 m. The wiki also gives a 1.024 km grid (128 × 128 foundations) and height-damage limits of −244 m and 1,997 m ([World](https://satisfactory.wiki.gg/wiki/World); [SC-InteractiveMap GameMap.js](https://raw.githubusercontent.com/AnthorNet/SC-InteractiveMap/dev/src/GameMap.js)).

The most complete open coordinate set is **GreyHak/sat_sav_parse's `sav_data/`**, which is exported from a v1.2.0.0 world ([sav_data](https://github.com/GreyHak/sat_sav_parse/tree/main/sav_data)). It holds 607 extraction points:

- **458 resource nodes**: iron 127, limestone 93, coal 62, copper 55, crude oil 30, SAM 19, bauxite 17, caterium 17, quartz 17, sulfur 16, uranium 5.
- **118 resource-well satellites** on 17 wells.
- **31 geysers**.

Each point carries its type, purity and x/y/z. The same folder has the collectibles: **118 crash sites**, **106 Somersloops**, about **298 Mercer Spheres**, and **596/389/257** blue, yellow and purple power slugs.

The dataset has two licensing problems. It is **GPL-3.0**, and the purity file's header says it was "Extracted from SCIM". SCIM's own README states that "reuse of the source code and data assets is not permitted in any case" ([SC-InteractiveMap](https://github.com/AnthorNet/SC-InteractiveMap)). Treat SCIM itself as a visual cross-check only: it has no public API, and its `robots.txt` blocks `/*/api`.

Two alternatives avoid the problem. **Self-extraction** means walking a fresh "explore everything, collect nothing" save, which is GreyHak's own method for the collectibles. **Live query** means FRM's `getResourceNode` endpoint, which returns location, purity and exploited state from a running game ([FRM getResourceNode](https://docs.ficsit.app/ficsitremotemonitoring/latest/json/Read/getResourceNode.html)). The older moritz-h `satisfactory-mapdata` export mod is stale and predates Update 8 ([repo](https://github.com/moritz-h/satisfactory-mapdata)).

There are three world-data gaps:

- **Creature spawns.** No open dataset exists. Creatures are not persistent anyway: they spawn near players and respawn after three game days ([Creatures](https://satisfactory.wiki.gg/wiki/Creatures)).
- **Map tiles.** No openly licensed tile set exists. Satisfactory3DMap marks its textures "Copyright by Coffee Stain Studios" ([satisfactory-3d-map](https://github.com/moritz-h/satisfactory-3d-map)), so extracting the tiles yourself with FModel is the path.
- **Randomized worlds.** 1.2's node randomization writes purity and type overrides into the save, and satisfactory-file-parser 4.0.1 had to fix exactly that ByteProperty ([CHANGELOG](https://github.com/etothepii4/satisfactory-file-parser/blob/main/CHANGELOG.md)). **A static node table is only a default.** The save's overrides must be applied on top.

## A save file is a complete, versioned factory snapshot

The `.sav` layout is:

1. An uncompressed header (`SaveHeaderVersion`, `SaveVersion`, `BuildVersion`, session name, play time, the modded flag, the Creative Mode flag).
2. Unreal zlib chunks of **131,072 bytes** each, tagged `0x9E2A83C1`, with a v2 `0x22222222` archive header in UE5.
3. A body: a map of per-level `TOCBlob64` (object headers with class path, instance name, quaternion rotation, position and scale) and `DataBlob64` (tagged property lists ending in `"None"`), followed by persistent and runtime data.

Versions are scoped: an object's version overrides its level's, which overrides the header's. The known sequence is **SaveVersion 46 at 1.0, 52 at 1.1.1.1, 53 at 1.1.3.0 and ≥58 at 1.2**. The reference document states "Document Version: Satisfactory 1.2" ([SATISFACTORY_SAVE.md](https://github.com/moritz-h/satisfactory-3d-map/blob/master/docs/SATISFACTORY_SAVE.md); [Save files](https://satisfactory.wiki.gg/wiki/Save_files)). The wiki page stops at 1.1.1.1, so moritz-h's document is the one to follow.

The data is rich enough to rebuild the whole factory graph:

- Every actor carries its transform.
- **Lightweight buildables** (foundations, walls) sit in `FGLightweightBuildableSubsystem` with `BuiltWithRecipe` and customization data.
- Belts and belt items, power wires and circuits, trains with their track graphs, drones and player state all have native serializers.
- Connections resolve as object references from connection components to their parent actors.

The format is documented in the game itself: header and session structs appear in `FGSaveManagerInterface.h` and `FGSaveSession.h`, which ship in `CommunityResources` (same source).

One thing a save does **not** hold is default node purity. That is why the world layer above is needed ([satisfactory-mapdata](https://github.com/moritz-h/satisfactory-mapdata)). The exact property names for recipe, clock, Somersloop state and connections (the community uses `mCurrentRecipe`, `mCurrentPotential` and `mConnectedComponent`) were **not confirmed against a primary source**. Check them against a parsed 1.2 save before building on them.

| Parser | Language | 1.2 | Write | License | Status |
|---|---|---|---|---|---|
| @etothepii/satisfactory-file-parser 4.1.2 | TypeScript (Node/browser, streaming) | ✅ (since 4.0.0, 2026-04-18) | ✅ `.sav`, `.sbp`, `.sbpcfg` | **MIT** | Active, pushed 2026-09-13 ([repo](https://github.com/etothepii4/satisfactory-file-parser)) |
| GreyHak/sat_sav_parse | Python scripts + CLI, map HTML | ✅ 1.2.0.0–1.2.2.1 | ✅ saves and blueprints | GPL-3.0 | Active, not on PyPI ([repo](https://github.com/GreyHak/sat_sav_parse)) |
| moritz-h `satisfactory-save` 0.11.0 | C++ with Python bindings (PyPI) | ✅, best docs | ✅ | GPL-3.0 | Active ([libsavepy](https://github.com/moritz-h/satisfactory-3d-map/blob/master/libsavepy/README.md)) |
| R3dByt3/SatisfactorySaveNet | C# (NuGet) | Not stated | ❌ (planned) | MIT | Active ([repo](https://github.com/R3dByt3/SatisfactorySaveNet)) |
| Goz3rr SatisfactorySaveEditor; Rust `satisfactory-save-file` | C#, Rust | ❌ pre-U6 | — | — | Dead ([Goz3rr](https://github.com/Goz3rr/SatisfactorySaveEditor), [crates.io](https://crates.io/search?q=satisfactory)) |

For a JS/TS product, satisfactory-file-parser is the only maintained, permissive, read/write option that supports 1.2. It gives structure, not meaning: in its own words, "game logic is not known". None of these parsers was tested against a real 1.2.2.x save in this research.

## Live telemetry: an official server API for control, a mod for the factory

Every dedicated server exposes a JSON RPC at **`https://<host>:7777/api/v1`** ([HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)):

- **Transport.** TLS only, with a self-signed certificate by default. Every call is a POST with `{"function", "data"}`.
- **Auth.** A Bearer token from `PasswordLogin`, or a persistent application token issued by the console command `server.GenerateAPIToken`.
- **Functions.** It covers the server, not the factory: `HealthCheck`, `QueryServerState` (tech tier, active schematic, game phase, player count, average tick rate), options, sessions, `RunCommand`, save and load, and **`DownloadSaveGame`**, which returns the raw `.sav`.
- **Docs.** The API is documented in `CommunityResources/DedicatedServerAPIDocs.md`, which ships to every player.

A companion **UDP Lightweight Query API** on port 7777 (magic `0xF6D5`) returns the server state and `SubStates` counters. Those counters tick when the game state, options or save list change, so a client polls UDP cheaply and re-queries HTTPS only when a counter moves ([Lightweight Query API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/Lightweight_Query_API)). Neither API exists on listen-server or single-player games ([FRM: Dedicated Server API](https://docs.ficsit.app/ficsitremotemonitoring/latest/dedicatedserver.html)).

The server itself is free: `steamcmd +login anonymous +app_update 1690800`, on Windows or Linux x64 with 8–16 GB RAM, commonly run as `wolveix/satisfactory-server` in Docker ([Dedicated servers](https://satisfactory.wiki.gg/wiki/Dedicated_servers); [wolveix](https://github.com/wolveix/satisfactory-server)).

For live factory contents, the answer is **FICSIT Remote Monitoring (FRM)**:

- **Status.** Version **1.5.3** was released 2026-08-12. It requires `game_version >=491125` and SML ^3.12.0, and the mod repository marks it "Works" on both branches ([api.ficsit.app GraphQL](https://api.ficsit.app/v2/query)).
- **Transport.** HTTP and WebSocket on port **8080**. It can also be routed through the official 7777 API port on dedicated servers ([Web Server](https://docs.ficsit.app/ficsitremotemonitoring/latest/webserver.html)).
- **Reads.** Dozens of GET endpoints, from `getPower` (per-circuit production, consumption, battery and fuse state) through every machine class, trains, drones, inventories, `getResourceNode` and `getRecipes`. The old `getAll` is **retired** ([FRM index](https://docs.ficsit.app/ficsitremotemonitoring/latest/index.html)).
- **Writes.** A few authenticated endpoints (`setSwitches`, `setEnabled`, `sendChatMessage`) take an `X-FRM-Authorization` token.
- **Push.** A WebSocket client subscribes with `{"action":"subscribe","endpoints":[…]}` ([WebSockets](https://docs.ficsit.app/ficsitremotemonitoring/latest/websockets.html)).
- **Existing stack.** `featheredtoast/satisfactory-monitoring` already wires FRM into Postgres and Grafana ([repo](https://github.com/featheredtoast/satisfactory-monitoring)).

The in-game Lua alternative, FicsIt-Networks' Internet Card, is **"Broken by the update to Unreal Engine 5.6.1"** (same GraphQL source).

The mod ecosystem itself is machine-readable too. The ficsit.app GraphQL endpoint (unauthenticated POST) lists **1,582 mods** with per-branch compatibility. SML 3.12.0 and SMM 3.1.0 both shipped for 1.2 on 2026-06-06 ([SML](https://github.com/satisfactorymodding/SatisfactoryModLoader); [SMM](https://github.com/satisfactorymodding/SatisfactoryModManager)). Building mods requires Coffee Stain's custom UE 5.6.1, obtained through a linked GitHub account ([dependencies](https://docs.ficsit.app/satisfactory-modding/latest/Development/BeginnersGuide/dependencies.html)).

## The recommended pipeline: four layers, each with one owner

| Layer | Primary source | Fallback / validation | Refresh trigger | Licensing caveat |
|---|---|---|---|---|
| **1. Static catalogue** (items, recipes, buildings, generators, schematics/unlock graph) | Parse `CommunityResources/Docs/en-US.json` (and other locales) from a licensed install, or the free server depot if it ships Docs | Diff against the wiki's 1.2 JSON and Docs.json.ts types; borrow SatisfactoryTools' parser logic | New build ID (watch `BuildVersion` / the UDP `ServerNetCL`) | No explicit licence; do not redistribute the raw file; the wiki JSON is NC-only |
| **1b. Assets** (icons, meshes, map texture) | FModel on your own install (`GAME_UE5_6` + shipped `.usmap`) | Wiki icons for internal previews only | New build | Coffee Stain copyright; own-copy extraction for personal use, or draw your own for a product |
| **2. World defaults** (nodes, wells, geysers, crash sites, collectibles, bounds) | Self-extract from a fresh fully-explored 1.2 save with an MIT parser; bounds from the wiki | GreyHak `sav_data` (GPL-3.0); FRM `getResourceNode`; SCIM visually | New build (rarely changes) | GreyHak is GPL and SCIM-derived; SCIM forbids reuse |
| **3. Save snapshot** (every building, recipe, clock, connection, inventory, train, progression, 1.2 node overrides) | `DownloadSaveGame` (or a local `SaveGames` folder) → satisfactory-file-parser → graph builder joined to layers 1 and 2 | sat_sav_parse / satisfactory-save for cross-checks | On each save / autosave; UDP `SubStates` says when | Parser licences (MIT vs GPL); the save is the player's data |
| **4. Live telemetry** (power, machine status, inventories, trains, drones, nodes) | FRM 1.5.3 WebSocket subscriptions → time-series store | Official `QueryServerState` + UDP poll for server health | Continuous (push cycle) | Community mod, tolerated not endorsed; dedicated-server-side only needed |

The join key across all four layers is the **class name**:

- **Recipe to machine.** `Recipe_*_C` maps to `Build_*_C` for machine stats and to `Desc_*_C` for names and icons.
- **Node to purity.** A node's level path (`Persistent_Level:PersistentLevel.BP_ResourceNode…`) joins the save to the world table.
- **Circuit ID.** Live FRM records reference the same circuit IDs and building instances the save uses. This is inferred from FRM's `ID` fields such as `Build_PriorityPowerSwitch_C_2147423102` ([setSwitches](https://docs.ficsit.app/ficsitremotemonitoring/latest/json/Write/setSwitches.html)) and should be checked in practice.

**Version everything by build number.** Save versions, blueprint config versions and FRM's config format all changed between 1.1 and 1.2.

The gaps still worth closing, in order of value:

1. Does the free server depot ship `CommunityResources/Docs` and the `.usmap`? One `steamcmd` run answers it.
2. The exact 1.2 property names for recipe, clock, Somersloop state and connections, confirmed from a parsed save.
3. The per-patch SaveVersion numbers after 58.
4. A full FRM response schema for the factory endpoints.
5. An openly licensed source for map tiles and creature spawns.
6. Any written Coffee Stain policy on fan tools or data use. Its EULA and terms URLs return 404, and none was found ([Q&A patch notes](https://questions.satisfactorygame.com/patchnotes) is the nearest official surface).

## Conclusion

Satisfactory is unusually open for a commercial game. The developer ships the game's own data dump, the mappings needed to read its assets, its save-header source files and its server API documentation inside every install. The data exists; what limits a project is permission. That flips the usual build-versus-scrape calculation. Parsing Docs and saves yourself costs a few hundred lines more than consuming a community dataset, but it is the only route that stays current on patch day and is not bound by a non-commercial, GPL or no-reuse licence. The community sets become test fixtures rather than dependencies.

1.2 also changed what "static" means. Game Modes can reprice milestones and reseed every node, so a world is now described by defaults plus the save's overrides, and any pipeline that treats the wiki's node counts or milestone costs as ground truth will quietly give wrong answers for a randomized world. Designing the snapshot layer as the source of truth, with static and world tables as defaults it overrides, is the choice that will survive 1.3.
