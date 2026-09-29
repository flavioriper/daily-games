# Satisfactory: live/runtime integration surfaces (official server API, state-exposing mods, modding toolchain)

Researched 2026-09-27. Version context found during research: **the current game is Update 1.2, not 1.1.** Patch 1.2.2.2 (build 491125) shipped 2 June 2026 and upgraded the engine to Unreal 5.6.1 ([wiki: Patch 1.2.2.2](https://satisfactory.wiki.gg/wiki/Patch_1.2.2.2); [XP Gained](https://xpgained.co.uk/patch-notes/satisfactory-1-2-update-patch-notes-2nd-june-2026)). Later patches 1.2.3.0, 1.2.3.1 and 1.2.4.0 are listed on the wiki ([wiki: Patch 1.2.3.1](https://satisfactory.wiki.gg/wiki/Patch_1.2.3.1)). The engine upgrade is what broke some mods (see section 4).

## 1. Official Dedicated Server HTTPS API (added in 1.0)

### Takeaway
Every dedicated server serves an HTTPS JSON RPC API at `https://<host>:7777/api/v1` on the game port. You authenticate with a password login or with a long-lived API token. The API manages the **server**: health, state, options, sessions, saves and console commands. It does **not** return factory contents. For a full factory view, download the save with `DownloadSaveGame` and parse it offline.

### Cited Findings
**Transport**
- Endpoint: `https://<ip>:7777/api/v1`, e.g. `https://127.0.0.1:7777/api/v1`. It is TLS only. The server generates a self-signed certificate when none is provided. — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)
- Every call is a POST. The JSON body is `{"function": "<Name>", "data": {...}}`. Requests and responses use `application/json` in UTF-8. — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)
- Errors return `errorCode` (string), plus optional `errorMessage` and `errorData`. — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)
- Uploads are multipart, with fields `data` (the JSON request), `saveGameFile` (the file) and `_charset_`. — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)

**Authentication**
- Tokens go in an `Authorization: Bearer <token>` header. A token is a Base64 JSON payload, then `.`, then a hex fingerprint. — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)
- There are five privilege levels: NotAuthenticated, Client, Administrator, InitialAdmin (used only to claim an unclaimed server) and APIToken (for applications). — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)
- Ways to get a token:
  - `PasswordLogin` takes `MinimumPrivilegeLevel` and `Password` and returns `AuthenticationToken`.
  - `PasswordlessLogin` takes `MinimumPrivilegeLevel` and works only where no password is set.
  - For third-party tools, an admin runs the server console command `server.GenerateAPIToken`, which issues a persistent token.
  - `server.InvalidateAPITokens` revokes all API tokens.
  — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)

**Functions** (name, privilege, request, response), from [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API):

| Function | Privilege | Request data | Response |
|---|---|---|---|
| HealthCheck | none | ClientCustomData | Health, ServerCustomData |
| VerifyAuthenticationToken | any token | none | none (204-style) |
| PasswordlessLogin | none | MinimumPrivilegeLevel | AuthenticationToken |
| PasswordLogin | none | MinimumPrivilegeLevel, Password | AuthenticationToken |
| QueryServerState | none per wiki table (see Gaps) | none | ServerGameState |
| GetServerOptions | none per wiki table | none | ServerOptions, PendingServerOptions |
| GetAdvancedGameSettings | none per wiki table | none | CreativeModeEnabled, AdvancedGameSettings |
| ApplyAdvancedGameSettings | Admin | AppliedAdvancedGameSettings | none |
| ClaimServer | InitialAdmin | ServerName, AdminPassword | AuthenticationToken |
| RenameServer | Admin | ServerName | none |
| SetClientPassword | Admin | Password | none |
| SetAdminPassword | Admin | Password, AuthenticationToken | none |
| SetAutoLoadSessionName | Admin | SessionName | none |
| RunCommand | Admin | Command | CommandResult, ReturnValue |
| Shutdown | Admin | none | none |
| ApplyServerOptions | Admin | UpdatedServerOptions | none |
| CreateNewGame | Admin | NewGameData | none |
| SaveGame | Admin | SaveName | none |
| DeleteSaveFile | Admin | SaveName | none |
| DeleteSaveSession | Admin | SessionName | none |
| EnumerateSessions | Admin | none | Sessions, CurrentSessionIndex |
| LoadGame | Admin | SaveName, EnableAdvancedGameSettings | none |
| UploadSaveGame | Admin | SaveName, LoadSaveGame, EnableAdvancedGameSettings (multipart) | none |
| DownloadSaveGame | Admin | SaveName | file attachment, not JSON |

- `QueryServerState` returns `ServerGameState` with these fields: activeSessionName, numConnectedPlayers, playerLimit, techTier, activeSchematic, gamePhase, isGameRunning, totalGameDuration, isGamePaused, averageTickRate, autoLoadSessionName. The wiki notes the field names start lowercase. — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)
- `DownloadSaveGame` answers with a file attachment instead of JSON. — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)
- Where it is documented: the wiki page "is a copy of the HTTPS API section of the `DedicatedServerAPIDocs.md` document distributed to every player", i.e. shipped with the game and server under CommunityResources. — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)
- The API exists **only on the dedicated server**, not on a listen/hosted game. FRM's docs say so explicitly: "This feature is not available for the base game... This is Coffee Stain Studios' design". — [FRM docs: Dedicated Server API](https://docs.ficsit.app/ficsitremotemonitoring/latest/dedicatedserver.html)

**Lightweight Query API (UDP)**
- It is UDP and therefore unreliable, so a client should poll at intervals instead of waiting for a reply. It runs on the server port (7777 UDP; see the port list in section 2). — [wiki: Lightweight Query API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/Lightweight_Query_API)
- Envelope, all little-endian:
  - uint16 ProtocolMagic `0xF6D5`
  - uint8 MessageType (0 = Poll, 1 = Response)
  - uint8 ProtocolVersion (1)
  - payload
  - uint8 terminator `0x01`
  — [wiki: Lightweight Query API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/Lightweight_Query_API)
- Response fields:
  - ServerState: 0 Offline, 1 Idle, 2 Loading, 3 Playing
  - ServerNetCL: the game changelist, which must match the client's
  - ServerFlags: 8 bits, including "modded" and four custom flags
  - SubStates: counters that change when the game state, options, advanced settings or save list change, so a tool knows when to re-query HTTPS
  - The purpose, per the wiki, is to "allow continuously pulling data from the server and track server state changes" cheaply.
  — [wiki: Lightweight Query API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/Lightweight_Query_API)

**Parsing a downloaded save for a full factory view**
- `@etothepii/satisfactory-file-parser` (TypeScript, npm; latest **4.1.2** on the npm registry as of 2026-09-27):
  - It reads, modifies and writes `.sav` and blueprint files (`.sbp`, `.sbpcfg`) to and from JSON.
  - Its README lists U1.0, U1.1 and U1.2 as compatible and Update 5 and below as not supported.
  - It does not migrate saves between versions, and its mod support is marked "<= 1.1".
  — [GitHub README](https://github.com/etothepii4/satisfactory-file-parser); [npm](https://www.npmjs.com/package/@etothepii/satisfactory-file-parser)
- There is also a Python parser, GreyHak/sat_sav_parse. — [GitHub](https://github.com/GreyHak/sat_sav_parse)

### Inferences
- A no-mod pipeline for full factory state works: generate an API token, call `SaveGame` (or use autosaves), call `EnumerateSessions`, call `DownloadSaveGame`, then parse with satisfactory-file-parser. The result is a snapshot, not a live view. Freshness is limited by how often you save, and a late-game save can be large, though no size figure was found.
- Read-only monitoring that needs no admin rights (HealthCheck, QueryServerState) is cheap. The UDP query's SubStates tell you when an HTTPS re-query is worth making.
- `RunCommand` is the only "write into the running world" path in the official API, and it is limited to console commands.

### Gaps
- The wiki table marks QueryServerState, GetServerOptions and GetAdvancedGameSettings as "None". The upstream DedicatedServerAPIDocs.md may say these need at least a Client token; this was not verified against the shipped file.
- Whether 1.2 added or changed any functions: the patch-note summaries fetched did not mention API changes, and the wiki page carries no version stamp.
- The exact byte layout of the Poll and Response payloads (cookie, field order, server name) was only partly captured. See the wiki page.
- The self-signed certificate means clients must skip verification or pin the certificate. Wiki guidance on installing a custom certificate was not extracted.

## 2. The dedicated server itself

### Takeaway
The server is free through SteamCMD as app **1690800** with anonymous login, and it also installs as a Steam tool or a free Epic add-on. It runs on 64-bit Windows and Linux only; there is no console server. Docker is well established; wolveix/satisfactory-server (about 2.1k stars) is the standard image.

### Cited Findings
- Install command: `steamcmd +force_install_dir <path> +login anonymous +app_update 1690800 validate +quit`. — [wiki: Dedicated servers](https://satisfactory.wiki.gg/wiki/Dedicated_servers)
- It runs on 64-bit Windows and Linux. "Dedicated servers are not available for the console release, without any plan to introduce the support later." — [wiki: Dedicated servers](https://satisfactory.wiki.gg/wiki/Dedicated_servers)
- Ports (as of 1.0+):
  - **7777 TCP/UDP** carries game traffic and the HTTPS API.
  - **8888 TCP** carries reliable messaging.
  - The external and internal port must match, because port redirection is not supported.
  — [wiki: Dedicated servers](https://satisfactory.wiki.gg/wiki/Dedicated_servers)
- Requirements: x86-64 CPU (i5-3570 / Ryzen 5 3600 or better; single-thread speed matters), 8 GB RAM minimum and 16 GB recommended, 12.4 GB of disk on Windows or 8 GB on Linux. — [wiki: Dedicated servers](https://satisfactory.wiki.gg/wiki/Dedicated_servers)
- Deployment options listed: SteamCMD, the Steam GUI, the Epic free add-on, Docker, and hosts or panels such as Pterodactyl and LinuxGSM. — [wiki: Dedicated servers](https://satisfactory.wiki.gg/wiki/Dedicated_servers)
- Docker image `wolveix/satisfactory-server:latest`:
  - Exposes 7777/tcp, 7777/udp and 8888/tcp.
  - Environment variables: `MAXPLAYERS` (4), `STEAMBETA` (experimental branch), `AUTOSAVENUM` (5), `MAXTICKRATE` (30), `SKIPUPDATE`, `PUID`/`PGID`.
  - Ships a `healthcheck.sh`. Mods "do now work" but are "a little rough around the edges".
  - About 2.1k stars and 187 forks.
  — [GitHub wolveix/satisfactory-server](https://github.com/wolveix/satisfactory-server)

### Inferences
- **Update 8 and earlier:** before 1.0 the server used separate query and beacon ports and had no HTTPS API. This is my recollection (UDP 15777 query and 15000 beacon); it was not re-verified this session. Treat any guide that mentions 15777 or 15000 as pre-1.0.

### Gaps
- The Docker image's latest tag date and its 1.2 support were not checked explicitly. The repo was reachable but no release date was captured.

## 3. FICSIT Remote Monitoring (FRM) and other state-exposing mods

### Takeaway
FRM is the main live-state API. It serves HTTP and WebSocket JSON on port **8080** by default, with dozens of `get*` read endpoints and a few authenticated write endpoints. It works on 1.2: v1.5.3 was released 2026-08-12, and SMR marks it "Works". It runs on Windows client, WindowsServer and LinuxServer. It can also route its endpoints through the official dedicated-server API port. FicsIt-Networks, which gives in-game Lua computers an Internet Card for HTTP, is currently **Broken** on 1.2.

### Cited Findings
**FRM status and targets**
- SMR's GraphQL API, queried live on 2026-09-27, reports:
  - Latest version **1.5.3**, created 2026-08-12. Earlier versions: 1.5.2 (2026-06-22) and 1.5.1 (2026-06-18).
  - `game_version >=491125`, i.e. 1.2, with dependency SML `^3.12.0`.
  - Targets: Windows, WindowsServer, LinuxServer. `required_on_remote: false`.
  - Compatibility EA "Works", EXP "Works". About 55.6k downloads.
  — [api.ficsit.app/v2/query](https://api.ficsit.app/v2/query) (POST GraphQL; `getModByReference(modReference:"FicsitRemoteMonitoring")`)
- The GitHub repo porisius/FicsitRemoteMonitoring had 84 stars and was last pushed 2026-09-17. — [GitHub API](https://github.com/porisius/FicsitRemoteMonitoring)
- The README says the icon system does not work on dedicated servers. — [GitHub](https://github.com/porisius/FicsitRemoteMonitoring)

**Serving and authentication**
- It is an HTTP and WebSocket server on a configurable port, **default 8080**. It is off until the chat command `/frm http start` is sent, unless `Web_Autostart` is set to true.
  - Endpoints hang off the root, e.g. `http://localhost:8080/getPower`, and `/` redirects to `/index.html`, the bundled web UI in `FactoryGame\Mods\FicsitRemoteMonitoring\www`.
  - It is configurable from the dedicated server's Server Manager or from the main-menu options.
  — [FRM docs: Web Server](https://docs.ficsit.app/ficsitremotemonitoring/latest/webserver.html)
- Auth:
  - A token is auto-generated in `Configs/FicsitRemoteMonitoring/WebServer.cfg` under `Authentication_Token`, and you can set your own.
  - Send it as the header `X-FRM-Authorization: <token>`.
  - Only write endpoints require it.
  — [FRM docs: Authentication](https://docs.ficsit.app/ficsitremotemonitoring/latest/json/authentication.html); [setSwitches](https://docs.ficsit.app/ficsitremotemonitoring/latest/json/Write/setSwitches.html)
- The docs split config into current and "Legacy Configurations (Satisfactory 1.1 and before)", so the config format changed for 1.2. — [FRM docs nav](https://docs.ficsit.app/ficsitremotemonitoring/latest/index.html)

**Read endpoints** (all GET), from [FRM docs index](https://docs.ficsit.app/ficsitremotemonitoring/latest/index.html):
- Chat: getChatMessages
- Factory: getAssembler, getBelts, getBlender, getCables, getConstructor, getConverter, getEncoder, getElevators, getExtractor, getFactory, getFrackingActivator, getFoundry, getHUBTerminal, getHyperEntrance, getHypertube, getManufacturer, getPackager, getParticle, getPipes, getPipeJunctions, getPortal, getPump, getRadarTower, getRefinery, getResourceSinkBuilding, getSmelter, getSpaceElevator, getSplitterMerger, getSwitches, getSPWN, getTradingPost, getTrainRails
- Generators: getBiomassGenerator, getCoalGenerator, getFuelGenerator, getGenerators, getGeothermalGenerator, getNuclearGenerator
- Inventory: getCloudInv, getCrateInv, getStorageInv, getWorldInv
- Power: getPower, getPowerUsage (the page also lists getPowerSlug)
- Vehicles, stations, resources and world: getTrains, getDrone, getVehicles, getTrainStation, getResourceNode, getRecipes, getPlayer and others
- **getAll is marked "Retired"**, so older dashboards that call it will break.

**Example response**
- `getPower` returns an array of circuit groups with CircuitGroupID, PowerProduction, PowerConsumed, PowerCapacity, PowerMaxConsumed, BatteryInput, BatteryOutput, BatteryDifferential, BatteryPercent, BatteryCapacity, BatteryTimeEmpty/Full ("HH:MM:SS"), AssociatedCircuits and FuseTriggered. — [FRM docs: getPower](https://docs.ficsit.app/ficsitremotemonitoring/latest/json/Read/getPower.html)

**Write endpoints** (authenticated POST)
- sendChatMessage, setEnabled, setSwitches (name, priority 0-8, on/off), createPing and setModSetting. — [FRM docs index](https://docs.ficsit.app/ficsitremotemonitoring/latest/index.html)
- Example: `setSwitches` takes a body with `ID` (for example `Build_PriorityPowerSwitch_C_2147423102`) and any of `name`, `priority`, `status`, and accepts an array of such objects. — [FRM docs: setSwitches](https://docs.ficsit.app/ficsitremotemonitoring/latest/json/Write/setSwitches.html)

**WebSocket, webhooks, serial and the official port**
- WebSocket: `ws://<ip>:8080/` (no wss). Send `{"action":"subscribe","endpoints":["getPlayer","getPower"]}` and the server pushes each endpoint as its own message every `WebSocketPushCycle`. Unsubscribe the same way. — [FRM docs: WebSockets](https://docs.ficsit.app/ficsitremotemonitoring/latest/websockets.html)
- Webhooks: customizable JSON templates for Discord, Slack and similar services, e.g. a battery or backup-power notice with `{CircuitID}`, `{TimeEmpty}` and `{BattPercent}`. There is also serial (RS232) output and a DiscIT config section. — [FRM docs: Webhook](https://docs.ficsit.app/ficsitremotemonitoring/latest/webhook.html)
- Through the official API port: "as of 1.1", FRM can serve its endpoints through `https://<ServerIP>:7777/api/v1/` on dedicated servers only, as a fallback when port 8080 cannot be reached.
  - Every FRM endpoint then runs on the game thread, where the standalone web server uses a separate thread for most requests.
  - Calls go through as NotAuthenticated, with FRM's own token required for protected endpoints.
  — [FRM docs: Dedicated Server API](https://docs.ficsit.app/ficsitremotemonitoring/latest/dedicatedserver.html)

**Dashboards and exporters built on FRM**
- The FRM README lists the FRM Companion App, Satisfactory Efficiency Terminal, the FRM Companion Bundle and the FRM Dashboard. — [GitHub FRM](https://github.com/porisius/FicsitRemoteMonitoring)
- featheredtoast/satisfactory-monitoring is a Docker stack in which an FRM cache writes to Postgres, which feeds Grafana. — [GitHub](https://github.com/featheredtoast/satisfactory-monitoring); [supercraft.host guide](https://supercraft.host/wiki/satisfactory/satisfactory_remote_monitoring_dashboard/)

**FicsIt-Networks (Lua computers)**
- The Internet Card makes HTTP requests from in-game Lua: `local card = computer.getPCIDevices(classes.FINInternetCard)[1]`, then `card:request(url, method, body, headerPairs...)` and `:await()`. — [FIN docs: Internet Card](https://docs.ficsit.app/ficsit-networks/latest/buildings/ComputerCase/InternetCard.html); [Lua example](https://docs.ficsit.app/ficsit-networks/latest/lua/examples/InternetCard.html)
- SMR, queried live, shows latest v1.2.0 (2025-09-09), SML `^3.11.1`, and about 209k downloads. Its compatibility is EA **"Broken"** and EXP **"Broken"**, with the note "Broken by the update to Unreal Engine 5.6.1". — [api.ficsit.app GraphQL](https://api.ficsit.app/v2/query)

### Inferences
- For live state on 1.2 today, FRM is the only mature option, and it is actively maintained (releases in June and August 2026, pushes in September 2026).
- FIN's push-to-HTTP pattern (Lua computers POSTing factory data to an external service) is unavailable on 1.2 until FIN is rebuilt for UE 5.6.1.
- FRM is not required on remote clients, so a dedicated server can run it alone and players can join unmodded. This is an inference from `required_on_remote: false` and was not tested.

### Gaps
- A complete JSON schema for `getFactory` and `getProdStats`/`getWorldInv` was not captured, and `getProdStats` did not appear in the fetched index. It may be renamed or folded into other endpoints; check the docs site.
- Whether the Companion App and the Grafana stack are updated for FRM 1.5.x (1.2 config, retired getAll) is unknown.
- Discord bots: FRM's webhooks and DiscIT cover this. No standalone, maintained Discord-bot project for 1.2 was verified.
- Other companion-app mods were not surveyed exhaustively.

## 4. Modding toolchain: SML, SMM, ficsit.app, Starter Project, engine

### Takeaway
Mods load through the community Satisfactory Mod Loader (SML **3.12.0**, released 2026-06-06 for build 491125, i.e. 1.2) and are installed with Satisfactory Mod Manager (SMM **v3.1.0**, 2026-06-06) from the ficsit.app repository. The repository has a public, unauthenticated GraphQL API. Building mods requires Coffee Stain's custom **Unreal Engine 5.6.1**, obtained through the satisfactorymodding UnrealEngine GitHub releases after linking your GitHub account, plus Wwise 2023.1.14.8770 and Visual Studio 2022.

### Cited Findings
- SML latest is v3.12.0, published 2026-06-06 (GitHub releases API). SMR lists it with `satisfactory_version: 491125` and targets Windows, WindowsServer and LinuxServer. The previous version was 3.11.3 (2025-08-09) for build 416835.
  - SMR's `engine_version` field still reads "5.2" for every entry, which contradicts the docs' 5.6.1 and looks stale.
  — [GitHub SML](https://github.com/satisfactorymodding/SatisfactoryModLoader); [api.ficsit.app GraphQL](https://api.ficsit.app/v2/query)
- SMM latest is v3.1.0, published 2026-06-06. — [GitHub SMM](https://github.com/satisfactorymodding/SatisfactoryModManager)
- The ficsit.app GraphQL endpoint is `https://api.ficsit.app/v2/query`. POST `{"query": ...}` with no auth works for reads (a GET returns 422).
  - Useful queries: `getModByReference(modReference:)` returns versions, targets, dependencies, `compatibility{EA{state note} EXP{state note}}` and downloads; `getSMLVersions`; `getMods(filter:{search, limit})`.
  - `getMods.count` returned 1582 mods.
  — [api.ficsit.app](https://api.ficsit.app/v2/query) (verified by live queries this session)
- The docs site describes "over 1200 mods released". Mods can be written in Unreal Blueprint or C++, or as JSON through ContentLib. SMR tests uploads for malware before approval. — [docs.ficsit.app](https://docs.ficsit.app/satisfactory-modding/latest/index.html)
- Required software:
  - "Unreal Engine 5.6.1 with custom changes provided by Coffee Stain Studios", from `https://github.com/satisfactorymodding/UnrealEngine/releases/latest`, after linking a GitHub account at `https://linker.ficsit.app/link`.
  - Wwise `2023.1.14.8770`.
  - Visual Studio 2022, not 2026. Needs 30+ GB of disk.
  - The Starter Project is referenced under "Obtain Starter Project"; the repo is presumably satisfactorymodding/SatisfactoryModLoader (see Gaps).
  - A community setup helper, SMEH by SirDigby, exists.
  — [docs.ficsit.app: dependencies](https://docs.ficsit.app/satisfactory-modding/latest/Development/BeginnersGuide/dependencies.html)
- Game side: 1.2.2.2 "upgraded our Unreal Engine version to 5.6.1". — [wiki: Patch 1.2.2.2](https://satisfactory.wiki.gg/wiki/Patch_1.2.2.2)
- Engine upgrades break mods historically: "Incompatible mods can cause the game to become unplayable". — [wiki: Modding](https://satisfactory.wiki.gg/wiki/Modding)
- Dedicated servers support mods through SMM, and "Modding support for the console release is not planned in any capacity." — [wiki: Modding](https://satisfactory.wiki.gg/wiki/Modding)
- **Update 8 and earlier:** the pre-1.0 toolchain was UE 5.2-CSS, and SML 3.x before 3.8 targeted Update 8. Only the stale SMR `engine_version: 5.2` field was observed this session; the 1.0/1.1 engine (commonly cited as 5.3.2-CSS) was not re-verified.

### Inferences
- A mod built for 1.0 or 1.1 (SML 3.11.x, UE 5.3) needs a rebuild against UE 5.6.1 and SML 3.12 to run on 1.2. FicsIt-Networks' "Broken" status is the concrete case. Before relying on any mod, check its `compatibility` through the GraphQL API.

### Gaps
- The exact Starter Project repository URL was not extracted from the "Obtain Starter Project" page.
- The UE version for 1.0 and 1.1 (5.3.x-CSS) was not verified this session.

## 5. Coffee Stain's stance, EULA and official public resources

### Takeaway
Coffee Stain tolerates and supports modding on PC but gives no formal official support. The official public data surfaces are the dedicated-server API and its shipped docs. No official data export, public Q&A API or fan-content policy page was found.

### Cited Findings
- The official wiki says Coffee Stain "designed Satisfactory to allow it to be modded if played on a PC", supports the community without full official support, and plans official support in the future. It contains no EULA text on modding. — [wiki: Modding](https://satisfactory.wiki.gg/wiki/Modding)
- The fandom wiki says the devs "made changes in the game to make it easier for mods to integrate" but prioritise the game over mod compatibility. This is older text that predates 1.0. — [Satisfactory fandom: Coffee Stain Studios](https://satisfactory.fandom.com/wiki/Coffee_Stain_Studios)
- The official Q&A site (questions.satisfactorygame.com) hosts bug reports, suggestions and patch notes at `/patchnotes`. Its `/api` path returns the single-page-app HTML shell rather than a documented API. — [Q&A patch notes](https://questions.satisfactorygame.com/patchnotes) (checked with curl, 2026-09-27)
- The API documentation "distributed to every player" (DedicatedServerAPIDocs.md) is the official developer-facing data interface. — [wiki: HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)

### Inferences
- A tool that reads a server through the official API, or a save through a parser, is on the safest footing. Mod-based reading (FRM) is community-tolerated.
- The Q&A site's JSON backend could be reverse-engineered, but it is undocumented and not an endorsed API.

### Gaps
- No EULA or fan-content policy text was found:
  - `satisfactorygame.com/eula`, `/terms` and `coffeestainstudios.com/eula` return 404.
  - `coffeestainstudios.com/legal` redirects to the corporate homepage.
  - The Steam store's EULA was not checked.
- No developer statement specifically about fan tools or data use (calculators, map sites) was found in this session.
- No official static data export (recipes, items) was found. The community uses the game's `Docs.json` / `en-US.json` from CommunityResources, but this was not verified this session.
