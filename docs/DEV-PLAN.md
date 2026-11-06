# Dev plan

Principle: prove the risky parts first (cross-server play and map data), then build content on top. Free tools only. Each phase ends at a gate. Design work follows `docs/DESIGN-PROCESS.md`.

| # | Phase | What happens | Gate |
|---|---|---|---|
| 0 | Setup | Run `tools/setup.sh` and `tools/verify.sh`. Fill `.env` (Roblox Open Cloud key, Freesound key) | Verify passes |
| 1 | Multiplayer prototype | Two live servers on a blank map: ghost players, hit claims, area ownership with leases, delay measurements | Delay and message limits acceptable |
| 2 | Pilot tile and generator spike (parallel with 1) | About 1 km2 of Santiago City from open data, plus a first seeded generated area. Compare the plugin route with OSM2World in Blender, measure size and load time | Looks right and runs on phone |
| 3 | Art bible and field survey (parallel) | Fill the art bible. You take photos of the hub, landmarks and typical houses | Style and house types defined |
| 4 | Gameplay slice | One server, pilot area: the first infected (Heliotrope with day and night behaviour), loot, combat, one vehicle, player data, hub, basic tribes and bases | Fun with 10 to 20 players |
| 5 | World state and ghosts on the real map | Persistence, lazy simulation, leases, ghosts in the pilot map | Restart or crash keeps the world intact |
| 6 | Endless world | Seeded generation next to Santiago City, area handoffs, infection layer, 50-building accuracy check on the start area | Generation works at any distance from the start |
| 7 | Scale | Bot load tests, generated dense-town and mountain stress areas, then widen the generated world | Measured capacity |
| 8 | Launch prep | Roblox-native monetization, moderation, polish | Your call |

## Tools by job
- Code: Luau, VS Code, Rojo, Rokit, StyLua, Selene, Lune, Git.
- Map data: OpenStreetMap, Overture, Copernicus elevation; Python, GDAL, DuckDB.
- Buildings and models: OSM2World, Blender, Studio generators.
- Art and audio: Blender, ComfyUI, Freesound CC0.
- Studio work: Studio MCP for building and screenshots; playtests by you.

## Who does what
- Claude Code: code, data pipeline, models, tests, audits, screenshots.
- You: installs and keys, field photos, approving the look, publishing the test place, playtesting.

## First week
1. Run setup and verify; fix what fails.
2. Spec the ghost-presence protocol (batch format, interpolation, rewind buffer) as pure logic with Lune tests.
3. Start the Santiago pilot data downloads.
4. Publish a free test place and prepare a second account for the two-server test.
5. Plan the field-photo day and draft the art bible.

## Needs approval before use
A relay host (free tier only, if needed at all), NAMRIA data, a drone survey, and any paid tool.
