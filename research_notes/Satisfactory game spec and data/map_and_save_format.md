# Satisfactory world/map data and save-file format, and the tools that read them

Researched 2026-09-27. The game's current stable branch is **1.2**, not 1.1. Patch 1.2.0.0 reached Experimental on 2026-03-17 (build 480321), and a secondary source puts the stable release at 2026-06-02. Any tool that stops at "1.0/1.1 support" is already one version behind. All GitHub metadata below (license, last push, stars) was read with `gh api` on 2026-09-27.

## Q1. Satisfactory Calculator Interactive Map (SCIM): what data it has, whether it exposes JSON, terms of use

### Takeaway
SCIM is the most complete map and save editor, and it tracks the 1.2 stable branch. It offers no public JSON or API, and its licence forbids reusing its code or data. Treat it as a reference and a way to check results, never as a data source.

### Cited Findings
- The site's branch selector reads "Stable (1.2)". The site handles save upload ("Click/Drop your save game here") and save editing. — [SCIM](https://satisfactory-calculator.com/en/interactive-map)
- The repo README says: "Reuse of the source code and data assets is not permitted in any case, source code is only available for educational purpose. The map is solely intended to be used on the satisfactory-calculator.com domain." It also says the repo "is here for bug reporting and is not intended to be forked or deployed in any means." No SPDX licence is set. Last push 2026-08-28, 214 stars. — [AnthorNet/SC-InteractiveMap](https://github.com/AnthorNet/SC-InteractiveMap)
- SCIM calls itself "a 2D map rendering engine and a full-featured save editor". It can load a dedicated-server save from a remote URL with `?url=SAVE_LINK`, as long as that server sends the file over valid SSL with CORS enabled. — [SC-InteractiveMap README](https://github.com/AnthorNet/SC-InteractiveMap)
- `robots.txt` blocks all bots from `/*/api` and sets `Crawl-delay: 4`. It blocks GPTBot completely. — https://satisfactory-calculator.com/robots.txt (fetched 2026-09-27)
- The map engine's constants are in `src/GameMap.js` (dev branch):
  - `mappingBoundWest = -324698.832031`, `mappingBoundEast = 425301.832031`, `mappingBoundNorth = -375000`, `mappingBoundSouth = 375000`
  - `backgroundSize = 32768`, `extraBackgroundSize = 4096`
  - The tile layers are `L.tileLayer(staticUrl + '/imgMap/gameLayer/' + build + '/{z}/{x}/{y}.png')` and a `realisticLayer` built the same way. They are served from `static.satisfactory-calculator.com`.

  — [SC-InteractiveMap/src/GameMap.js](https://raw.githubusercontent.com/AnthorNet/SC-InteractiveMap/dev/src/GameMap.js)
- The source tree has JSON building models (`src/Models/Buildings/Build_*.json`) and per-building JS classes (Miner, FrackingExtractor, DropPod, ResourceNode, ResourceDeposit, and others). — [SC-InteractiveMap repo tree](https://github.com/AnthorNet/SC-InteractiveMap)
- Secondary sources say SCIM has a "spawn locations" option that circles creature spawners. — [search summary; Creatures wiki](https://satisfactory.wiki.gg/wiki/Creatures)

### Inferences
- The node, collectible and spawner coordinates exist inside SCIM's site bundle and tile server, but the licence forbids taking them. An app should use an openly licensed or self-extracted source (Q2) and use SCIM only to compare against visually.
- SCIM's bounds in centimetres match the wiki's metre figures exactly: −324,698.8 cm ≈ −3,247 m and 425,301.8 cm ≈ 4,253 m. So SCIM's bounds are the canonical Leaflet `CRS.Simple` extents.

### Gaps
- I found no written terms-of-service page for satisfactory-calculator.com beyond the repo README and robots.txt.
- SCIM's data layers could not be listed from a fetch, because the page renders client-side.

## Q2. Open datasets of node and collectible coordinates, map tiles, world size and coordinate units

### Takeaway
The best open, current dataset is GreyHak's `sat_sav_parse/sav_data/*.py` (GPL-3.0). It is exported from a v1.2.0.0 save and covers:
- every resource node, well satellite and geyser, with type, purity and x/y/z in centimetres
- 118 crash sites, 106 Somersloops, about 298 Mercer Spheres, and 596, 389 and 257 blue, yellow and purple power slugs

World coordinates are Unreal centimetres. The map spans roughly x −324,699 to 425,302 and y −375,000 to 375,000.

### Cited Findings
**Coordinate system and world size**
- World size is "47.1 km² (or 7.972 km x 6.8 km)". In-game coordinates run "between -3246, -3750 (North West) and 4253, 3750 (South East)" in metres. Height damage limits are Z −244 m and Z 1997 m. The grid is "exactly 1.024 x 1.024 km (128 x 128 foundations)", numbered from X:0, Y:0 at the south-west corner. There are 21 named biomes. — [World (wiki.gg)](https://satisfactory.wiki.gg/wiki/World)
- In the save, `FTransform` holds a `double[4]` quaternion rotation, a `double[3]` translation ("world position of object (in centimeter)") and a `double[3]` scale. — [moritz-h SATISFACTORY_SAVE.md](https://github.com/moritz-h/satisfactory-3d-map/blob/master/docs/SATISFACTORY_SAVE.md)
- The in-game map zooms from "0.5x to 8x" and shows coordinates in metres. wiki.gg content is licensed CC BY-NC-SA 4.0. — [Map (wiki.gg)](https://satisfactory.wiki.gg/wiki/Map)
- For map tiles, see SCIM's `/imgMap/gameLayer/{build}/{z}/{x}/{y}.png` scheme in Q1 (not reusable). Satisfactory3DMap ships `map/resources/textures/Map/` and marks it "Copyright by Coffee Stain Studios". — [satisfactory-3d-map README](https://github.com/moritz-h/satisfactory-3d-map)

**GreyHak/sat_sav_parse data files (GPL-3.0; last push 2026-08-15; 43 stars)**

Source: https://github.com/GreyHak/sat_sav_parse/tree/main/sav_data. These are Python dicts keyed by level path, for example `"Persistent_Level:PersistentLevel.BP_ResourceNode…"`.
- `resourcePurity.py` has the header comment "Extracted from SCIM for Satisfactory v1.2.0.0". Each entry is `(resource Desc_ class, Purity enum, (x, y, z), [fracking core])`. I counted 607 entries:
  - **458 resource nodes**: iron 127, stone 93, coal 62, copper 55, crude oil 30, SAM 19, bauxite 17, caterite 17, raw quartz 17, sulfur 16, uranium 5
  - **118 resource-well satellites**: water 55, nitrogen 45, oil 18, belonging to 17 `BP_FrackingCore` wells
  - **31 geysers**
  - Purity across all 607: 225 pure, 237 normal, 145 impure

  (My own count of the file.) Note the header: this file came *from SCIM*, which sits awkwardly next to SCIM's no-reuse terms.
- `crashSites.py`: "Exported from Satisfactory v1.2.0.0 (same as v1.1.1.6)". 118 `BP_DropPod` entries, each with an ID, rotation, position, and cost/power data taken from wiki.gg. Access notes use "foundations" / "flight suggested" / "flight recommended". Hazard notes cover gas, radiation, nobelisk and sentry creatures.
- `somersloop.py`: 106 entries. `mercerSphere.py`: about 298 `MERCER_SPHERES` plus a `MERCER_SHRINES` table. `slug.py`: "Num slugs: [596, 389, 257]" (blue, yellow, purple).
- The collectible files were made by "starting a new world and exploring to reveal the entire map without collecting anything" and then parsing that save.

— files read at [sat_sav_parse/sav_data](https://github.com/GreyHak/sat_sav_parse/tree/main/sav_data)

**Other sources**
- The satisfactory.th.gl guides count 106 Somersloops and 298 Mercer Spheres. That site is a third-party interactive map with no stated data licence or API. — [th.gl Somersloop](https://satisfactory.th.gl/guides/Somersloop), [th.gl Mercer Sphere](https://satisfactory.th.gl/guides/Mercer%20Sphere)
- `moritz-h/satisfactory-mapdata` is a mod that exports node type/purity and drop-pod requirements to JSON in `%LOCALAPPDATA%\FactoryGame\MapData-Export`. It exists because "savegames do not store details that are static to the game world, such as resource nodes type and purity". It was last pushed in 2022, so it is **stale (pre-U8)**. — [satisfactory-mapdata](https://github.com/moritz-h/satisfactory-mapdata)
- `Tjark-Kuehl/satisfactorymap` is a Svelte/Leaflet map using a root `resources.json` and "Simple CRS". It has no licence and 1 star, and was last pushed 2025-05-05, which is 1.0/1.1 era. — [satisfactorymap](https://github.com/Tjark-Kuehl/satisfactorymap)
- The Ficsit Remote Monitoring mod serves live node data at `GET http://localhost:8080/getResourceNode`. The response carries `location {x,y,z}`, `Purity` (Impure/Normal/Pure), `EnumPurity`, `ResourceForm`, `NodeType` and `Exploited`, and is GeoJSON-like. — [FRM docs](https://docs.ficsit.app/ficsitremotemonitoring/latest/json/Read/getResourceNode.html)
- Creatures are not persistent. They spawn from fixed spawn points when a player comes into range and respawn after 3 game days if no player is within 150 m. — [Creatures (wiki.gg)](https://satisfactory.wiki.gg/wiki/Creatures)

**1.2 changed the world**
- Patch 1.2.0.0 added World Randomization game modes:
  - Resource Node Randomization: Default, Random, Basic/Advanced Resource Rich, Fossil Fuel Rich
  - Resource Node Purity: Default, All Pure, Mostly Pure, Average, Mostly Impure, All Impure, Random
  - a shareable World Seed

  — [Patch 1.2.0.0 (wiki.gg)](https://satisfactory.wiki.gg/wiki/Patch_1.2.0.0)
- `satisfactory-file-parser` 4.0.1 fixed "ByteProperty wasnt read correctly, when node purities were overwritten from 1.2 game mode". — [CHANGELOG](https://github.com/etothepii4/satisfactory-file-parser/blob/main/CHANGELOG.md)

### Inferences
- In a default world, node type and purity are static game data and not in the save, so an app needs the static table plus the save. In a 1.2 randomized world, the overrides are written into the save, so a static node table is wrong for those worlds unless the save's overrides are applied on top.
- To convert to in-game metres, divide centimetres by 100. For a Leaflet `CRS.Simple` map, use SCIM's bounds as the extents.
- GreyHak's data is the most complete open set, but it is GPL-3.0 and partly derived from SCIM. Its licensing has to be judged before shipping it in a closed app.

### Gaps
- I found no open, permissively licensed dataset of creature spawner coordinates. SCIM and th.gl show them, but neither publishes the data.
- I found no openly licensed map tile set. Extracting the game's own map textures (for example with FModel) is the usual route, but I did not verify a source that documents it.
- I did not check whether wiki.gg has a machine-readable map data page (the `/wiki/Interactive_Map` URL returned 404).

## Q3. Save format: header, compression, levels, objects and properties, the 1.0 to 1.2 changes, and where it is documented

### Takeaway
A `.sav` file is an uncompressed header followed by Unreal zlib chunks of at most 128 KiB each. The body is a map of per-level save data plus persistent data. Each level has a TOC blob (object headers) and a Data blob (tagged property lists). The best document is `docs/SATISFACTORY_SAVE.md` in moritz-h/satisfactory-3d-map, which states "Document Version: Satisfactory 1.2". The wiki.gg Save files page is less current.

### Cited Findings
Source for this section unless marked otherwise: [SATISFACTORY_SAVE.md](https://github.com/moritz-h/satisfactory-3d-map/blob/master/docs/SATISFACTORY_SAVE.md).

**Header**
- Fields in order:
  - `int32 SaveHeaderVersion`, `int32 SaveVersion`, `int32 BuildVersion`
  - `FString SaveName` (header version ≥14), `MapName`, `MapOptions`, `SessionName`, `PlayDurationSeconds`, `FDateTime SaveDateTime`, `SessionVisibility`
  - `EditorObjectVersion` (≥7), `ModMetadata` + `IsModdedSave` (≥8), `SaveIdentifier` (≥10), `IsPartitionedWorld` (≥11), `FMD5Hash SaveDataHash` (≥12), `IsCreativeModeEnabled` (≥13)
- "For Update 8 and 1.0 the header version was 13, for 1.1 it is 14." The struct is `FSaveHeader` in `FGSaveManagerInterface.h`, which ships in the game's `CommunityResources` folder.

**Version numbers from wiki.gg** ([Save files](https://satisfactory.wiki.gg/wiki/Save_files))
- Patch 1.0.0.3 is header 13, save version 46, editor version 40.
- Patch 1.1.1.1 (build 418783) is header 14, save version 52.

**Chunks**
- Each chunk has this header:
  - `PACKAGE_FILE_TAG 0x9E2A83C1`
  - an archive header: `0x00000000` is v1, `0x22222222` is v2, the UE5 form, which has a `uint8 CompressorNum` where `3` means zlib
  - `int64 max chunk size = 131072`
  - the compressed and uncompressed sizes, written twice (summary, then per chunk)
- All chunks except the last are 131072 bytes uncompressed. Concatenate them after inflating.

**Body**
- Layout: `int64` total size; `FSaveObjectVersionData` if SaveVersion ≥53; `FWorldPartitionValidationData`; `TMap<FString, FPerStreamingLevelSaveData> mPerLevelDataMap`; `FPersistentAndRuntimeSaveData`; `FUnresolvedWorldSaveData`. The structs are in `FGSaveSession.h`.
- Each level's `TOCBlob64` holds `numObjects` entries of `bool isActor` followed by `FActorSaveHeader` or `FObjectSaveHeader`, then optionally `DestroyedActors` (or `LevelToDestroyedActorsMap` in the persistent data).
- Each level's `DataBlob64` holds, per object, `int32 SaveVersion`, `bool ShouldMigrateObjectRefsToPersistent`, and `TArray<uint8> Data`. From version 53 each object may also carry per-object version data. The Data size lets a reader skip objects it does not understand.
- Versioning is scoped: an object's version overrides its level's, which overrides the header's. If nothing sets one, the default is `VersionUE5 = 1000`.
- wiki.gg lists five level-grouping grids (MainGrid, LandscapeGrid, ExplorationGrid, FoliageGrid, HLOD0_256m_1023m) and a sublevel count "e.g. 107" plus the persistent level. An actor header has type path, root object, instance name, quaternion rotation, position, scale and flags. A component header has a parent actor name. — [Save files (wiki.gg)](https://satisfactory.wiki.gg/wiki/Save_files)

**Properties**
- The type is `FPropertyTag` / `FPropertyTypeName`. The types covered are Bool, Byte, Enum, Name, Object, SoftObject, Str, Text, Int, Int8, Int64, UInt32, UInt64, Float, Double, Array, Map, Set and Struct, plus game-specific binary structs.
- A property list ends with the name `"None"`.
- `satisfactory-file-parser` 4.0.0 notes that a nested `propertyTagType` "only exists in saves from late 1.1 on". — [CHANGELOG](https://github.com/etothepii4/satisfactory-file-parser/blob/main/CHANGELOG.md)

**Special actors with native (non-property) data**
- `AFGBuildableConveyorBase` (`mItems`)
- `AFGConveyorChainActor`: first/last conveyor, spline segments, and belt items
- `AFGBuildableWire`, `AFGCircuitSubsystem`, `AFGRailroadVehicle`, `AFGDroneVehicle`, `AFGPlayerState`, `AFGGameMode`/`GameState`
- `AFGLightweightBuildableSubsystem` (`/Script/FactoryGame.FGLightweightBuildableSubsystem`). It stores **lightweight buildables** (foundations, walls and similar) as `TMap<class, TArray<FRuntimeBuildableInstanceData>>`, not as actors. Each instance has an `FTransform`, customization (swatch, material, pattern, skin, colours), `BuiltWithRecipe`, `BlueprintProxy`, `TypeSpecificData` (lightweight version ≥2) and `BuiltBy` (≥3). `currentLightweightVersion` exists from SaveVersion ≥48.

**Save locations**
- Windows: `%LOCALAPPDATA%\FactoryGame\Saved\SaveGames\{ID}`, with a `SaveGames_backup` folder beside it. The wiki also gives the Steam Deck path. — [Save files (wiki.gg)](https://satisfactory.wiki.gg/wiki/Save_files)

**Dedicated servers**
- The dedicated server's HTTPS API at `https://host:7777/api/v1` has a `DownloadSaveGame` function that returns the raw save. The API is documented in `CommunityResources/DedicatedServerAPIDocs.md`. — [Dedicated servers/HTTPS API (wiki.gg)](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API), [ficsit.app vanilla API docs](https://docs.ficsit.app/satisfactory-modding/latest/Development/Satisfactory/DedicatedServerAPIDocs.html)

**Blueprints**
- A blueprint is a pair of files, `.sbpcfg` and `.sbp`.
- The `.sbpcfg` holds `ConfigVersion`, description, icon ID, colour, icon library (≥3), and `LastEditedBy`. `LastEditedBy` changed type between 1.1.2.2 (config version 4) and 1.1.3.0 (config version 6), and `FPlayerInfoHandle` changed again in 1.2.0.0.
- The `.sbp` header holds `HeaderVersion` (2), `SaveVersion`, `BuildVersion`, `FIntVector Dimensions`, `Cost`, `RecipeRefs`, and version data (≥53). It is followed by the same compressed chunks, whose body holds `TOCData` and `BlobData`.
- Game versions 1.1.3.0 up to 1.2.0.0 write SaveVersion 53. Version 1.2.0.0 and later write SaveVersion ≥58.

### Inferences
- The known save-version sequence is: 46 (1.0), 52 (1.1.1.1), 53 (1.1.3.0), ≥58 (1.2). A robust reader must branch on version per level and per object, not only on the header.
- The format was redesigned in Update 6 (sublevel saving) and again in U8 (UE5, world partition). Pre-U8 documentation and parsers, including the old wiki v0.6.1.3 layout, will fail on current saves.

### Gaps
- The exact SaveVersion numbers for every 1.2.x patch are not listed in one place. The docs only say "≥58".
- The wiki.gg Save files page stops at 1.1.1.1, so it does not yet cover 1.2.

## Q4. Parsers and editors: 1.0/1.1/1.2 support, licences, maturity, blueprint support

### Takeaway
Three libraries are actively maintained and support 1.2:
- **@etothepii/satisfactory-file-parser** (TypeScript, MIT, reads and writes `.sav`, `.sbp` and `.sbpcfg`)
- **GreyHak/sat_sav_parse** (Python scripts, GPL-3.0, saves plus blueprints)
- **moritz-h satisfactory-3d-map / `satisfactory-save`** (C++ with Python bindings on PyPI, GPL-3.0, the best documentation)

SatisfactorySaveNet (C#, MIT) is active but read-only. Goz3rr's SatisfactorySaveEditor is dead: its own README says U6/U7 are not supported. Rust has no maintained save parser.

### Cited Findings
- **@etothepii/satisfactory-file-parser** — [repo](https://github.com/etothepii4/satisfactory-file-parser), [npm](https://www.npmjs.com/package/@etothepii/satisfactory-file-parser)
  - MIT; last push 2026-09-13; 31 stars; npm `latest` is 4.1.2, published 2026-07-26 (registry query).
  - README: "This parser can read, modify and write: Save Files `.sav`, Blueprint Files `.sbp`, `.sbpcfg`".
  - Support table: ≤U5 ❌, U6 and U7 "mostly compatible", U8, U1.0, U1.1 and U1.2 ✅. It does not migrate between versions. It works in Node and should work in a browser. It has a streaming JSON reader (`ReadableStreamParser`) and was tested against several mods; Ficsit Networks is only partly mapped.
  - Changelog: 4.0.0 (2026-04-18) added "1.2 Support, Breaking Changes". 4.1.0 fixed belt-item offsets, which had been read as int32 instead of float32.
  - It says of itself: "game logic is not known", meaning it gives an editable JSON structure, not semantics.
- **GreyHak/sat_sav_parse** — [repo](https://github.com/GreyHak/sat_sav_parse)
  - GPL-3.0; last push 2026-08-15; 43 stars.
  - Supports v1.2.0.0, 1.2.1.0, 1.2.2.0 and 1.2.2.1. The parser and re-saver also read 1.1.1.6–1.1.3.1. Older games need tagged releases: v1.14 for late 1.1 tooling, v1.6 for 1.0.0.7, v1.5 for 1.0.0.4, v1.1 for 1.0.0.3.
  - Components: `sav_parse.py` (library `readFullSaveFile` / `readSaveFileInfo`), `sav_to_resave.py` (writer), `sav_cli.py` (to/from JSON, find nodes, export/import node types, list vehicle paths, restore Somersloops and Mercer Spheres, and more), `sbp_parse.py` (blueprint parse and re-save), `sav_to_html.py` (map images).
  - It is not on PyPI; the names `satisfactory-save-parser` and `sav-parse` return 404.
- **moritz-h/satisfactory-3d-map** — [repo](https://github.com/moritz-h/satisfactory-3d-map), [libsavepy README](https://github.com/moritz-h/satisfactory-3d-map/blob/master/libsavepy/README.md)
  - GPL-3.0; last push 2026-04-10; 53 stars. A 3D map save editor built on a C++ library with Python bindings.
  - `pip install satisfactory-save`: PyPI version 0.11.0, files uploaded 2026-04-04.
  - API: `s.SaveGame('x.sav')`, `.save()`, `mSaveHeader`, `mPersistentAndRuntimeData.SaveObjects`, `mPerLevelDataMap`.
  - Its format documentation covers 1.2 and blueprints.
- **R3dByt3/SatisfactorySaveNet** (C#, NuGet `SatisfactorySaveNet`) — [repo](https://github.com/R3dByt3/SatisfactorySaveNet)
  - MIT; last push 2026-09-14; 18 stars.
  - A "fully managed C# save file reader (and soon writer)"; "writing capabilities" are only planned.
  - The README does not state 1.2 support explicitly.
- **Goz3rr/SatisfactorySaveEditor** (C#/WPF) — [repo](https://github.com/Goz3rr/SatisfactorySaveEditor)
  - Last push 2024-08-17; no SPDX licence.
  - README: "Update 6/7 is not yet supported!" and it points users to SCIM. **Stuck pre-U6; do not use.**
- **SCIM** is a closed-reuse JS editor; see Q1.
- **Rust**
  - `satisfactory-save-file` on crates.io: 0.2.0, last updated 2021-06-03. **Stale, pre-U6.**
  - `satisfactory-data` (dax-dot-gay, MIT, 2026-05) parses game data files (the recipes/items registry built from `satisfactory-1.1-en-US.zip`), not saves.

  — [crates.io search](https://crates.io/search?q=satisfactory), [dax-dot-gay/satisfactory-data](https://github.com/dax-dot-gay/satisfactory-data)
- **Other names listed on wiki.gg**: a D implementation at GitLab `cybershadow/satisfactory-save-files`, not verified. — [Save files (wiki.gg)](https://satisfactory.wiki.gg/wiki/Save_files)
- **Small or dead projects**
  - `anocweb/SatisfactorySaveTools`: GPL-3.0, last push 2022, "Learning to read…". Stale.
  - `JWalk9000/SatisfactoryFileParser` and `sf-file-parser`: forks of Goz3rr and etothepii.
  - `data-goblin/sat_sav_parse_analysis`: GPL-3.0, 2025-03, 0 stars.
  - `btotharye/satisfactory-ai`: MIT, 2026-03, 1 star; claims to extract buildings, power, resources and rates.

  — gh API
- **Dedicated-server API client**: `DJWoodZ/satisfactory-dedicated-server-https-api-client`, a Node library with zero dependencies (MIT, last push 2024-09). It can fetch saves from a server. — [repo](https://github.com/DJWoodZ/satisfactory-dedicated-server-https-api-client)

### Inferences
- For a JS/TS app, `@etothepii/satisfactory-file-parser` is the only permissive (MIT) choice that is maintained, supports 1.2, and handles saves and blueprints both ways. The Python options are both GPL-3.0.
- "Mostly compatible" U6/U7 support and the ≤U5 cutoff mean very old saves need the game itself to upgrade them.

### Gaps
- I did not test any parser on a real 1.2.2.x save.
- SatisfactorySaveNet's version coverage is unstated.
- I did not verify the D library (GitLab).

## Q5. What a save gives you: enough to rebuild a full factory graph?

### Takeaway
Yes, with one caveat. A save holds every built actor with its transform, plus lightweight buildables with their recipe. Machine state, logistics links, inventories, trains, drones and progression are all stored as properties or native data. Static world facts (default node purity and type) are not in the save and must be joined from a static table, as in Q2.

### Cited Findings
- **Position**: every actor header carries position, rotation (quaternion) and scale. — [Save files (wiki.gg)](https://satisfactory.wiki.gg/wiki/Save_files)
- **Foundations and walls**: lightweight buildables carry the transform, `BuiltWithRecipe`, customization and `BuiltBy`. — [SATISFACTORY_SAVE.md](https://github.com/moritz-h/satisfactory-3d-map/blob/master/docs/SATISFACTORY_SAVE.md)
- **Belts and belt items**: stored natively in `AFGBuildableConveyorBase.mItems` and the `AFGConveyorChainActor` chains. Wires and power circuits are in `AFGBuildableWire` / `AFGCircuitSubsystem`. Train vehicles, drones and the railroad subsystem (`mTrackGraphs`) are covered, and the struct list includes `TimeTableStop`. — [SATISFACTORY_SAVE.md](https://github.com/moritz-h/satisfactory-3d-map/blob/master/docs/SATISFACTORY_SAVE.md)
- **Inventories**: the `InventoryItem` struct and the `RailroadTrackPosition`, `ClientIdentityInfo` and `Box` typed structs are documented. — [Save files (wiki.gg)](https://satisfactory.wiki.gg/wiki/Save_files)
- **Existing tools that build on this data**
  - GreyHak's CLI: player inventories, vehicle paths, free items, and which Somersloops, Mercer Spheres and hard drives are collected. Its `sav_to_html.py` draws power and resource-node maps. — [sat_sav_parse](https://github.com/GreyHak/sat_sav_parse)
  - Savecraft and satisfactory-ai: derive machines, production rates, power grids, storage, trains and progression from saves. — [Savecraft](https://savecraft.gg/satisfactory), [satisfactory-ai](https://github.com/btotharye/satisfactory-ai)
- **Why a static table is needed**: "the savegames do not store details that are static to the game world, such as resources nodes type and purity". — [satisfactory-mapdata](https://github.com/moritz-h/satisfactory-mapdata)
- **1.2 randomized worlds**: purity overrides are written to the save. — [file-parser CHANGELOG](https://github.com/etothepii4/satisfactory-file-parser/blob/main/CHANGELOG.md)

### Inferences
- To build the factory graph:
  1. Take every `Build_*` actor, with its class path and transform.
  2. Read its recipe and clock properties.
  3. Resolve each factory connection component's link to its partner component. These are object references through component headers, whose parent actor name gives the owning building.
  4. Add belts and pipes as edges.
  5. Join extractors to resource-node actors, and those nodes to the static purity table.
- **Unverified property names**: the specific names `mCurrentRecipe`, `mCurrentPotential` (overclock), `mConnectedComponent`, `mPurchasedSchematics` and timetable `mStops` are widely used in the community. I could not confirm them against a primary source in this session, so check them against a parsed 1.2 save before relying on them.

### Gaps
- Confirm the exact property names for recipe, overclock and Somersloop-boost state, and for belt connections, schematics and timetables, by parsing a 1.2 save with one of the libraries above.
- I found no primary documentation listing them.
