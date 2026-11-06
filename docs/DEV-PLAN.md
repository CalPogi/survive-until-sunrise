# Dev plan

Principle: prove the risky parts first (cross-server play and map data), then build content on top. Free tools only. Each phase ends at a gate. Design work follows `docs/DESIGN-PROCESS.md`.

| # | Phase | What happens | Gate |
|---|---|---|---|
| 0 | Setup | Run `tools/setup.sh` and `tools/verify.sh`. Fill `.env` (Roblox Open Cloud key, Freesound key) | Verify passes |
| 1 | Ghost prototype (done, polish in progress) | Two live servers on a blank map: ghosts and delay measurements, then send-on-change and instant actions | The two-account test feels better than before |
| 2 | World-size test and generator spike | Generate terrain far from the center to find the largest usable world. About 1 km2 of Santiago City from open data, plus a first seeded area. Compare the plugin route with OSM2World in Blender, measure load time and memory | Largest size measured, looks right, runs on phone |
| 3 | Art bible and field survey (parallel) | Fill the art bible. You take photos of the hub, landmarks and typical houses | Style and house types defined |
| 4 | Gameplay slice on one server | Santiago City: the first infected (Heliotrope with day and night behaviour), loot, combat, one vehicle, player data, saved world records, hub, basic groups and bases | Fun with 10 to 20 players, restart keeps the world intact |
| 5 | Fill-first joining and home regions | Start when nearing one server's capacity. Bot load test for players per server | A full server opens a new one, and parties land together |
| 6 | Cells and shared bosses | Start when multiple servers are really happening. Ghosts per cell, owner server for Bloommothers and Hollow Oaks, cross-server hit claims if still wanted | Ghost traffic stays within limits, and a crashed boss owner is taken over |
| 7 | Grow the world | Seeded generation out to the measured edge, infection layer, generated dense-town and mountain stress areas, 50-building accuracy check on the start area | Generation works out to the edge |
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
