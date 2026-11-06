# CLAUDE.md

Roblox game. Rojo + VS Code + Git, strict Luau. Studio is only for playtesting and publishing.
Read `docs/WORKFLOW.md` for the loop and `docs/ARCHITECTURE.md` for the layout. Decisions live in `DECISIONS.md`.

## Commands
- `./tools/verify.sh`: format check, lint, build, type-check, tests. Must pass before a feature is done.
- `stylua src tests`: format.
- `lune run tests/run`: unit tests. Register new spec files in `tests/run.luau`.

## Security (the client is hostile)
- Every client-to-server call goes through `Net.onEvent` / `Net.onFunction` (`src/server/Net.luau`). Feature code never touches raw remotes. New remote names go in `src/shared/RemoteNames.luau`.
- The server owns all state: currency, inventory, health, damage. Never trust client-sent ids, times, damage or positions.
- Validate type, range, length, finiteness (NaN/inf) and enum membership with `Validate`. No optional remote args.
- Never `InvokeClient` from the server. No `loadstring`. No requiring asset-id modules without human approval.
- Pure-logic modules (Validate, RateLimiter, economy math) must not touch Roblox APIs, so they stay testable under Lune.

## Luau rules
- `--!strict` at the top of every file.
- `task.wait/spawn/delay`, never `wait()`/`spawn()`/`delay()`. No `_G` or `shared`.
- Set `Parent` last. Disconnect per-player connections on `PlayerRemoving`.
- Require shared modules as `ReplicatedStorage.Shared.X` so luau-lsp can type them.

## UI and assets
- UI is built in code from the Claude Design handoff (`docs/design/`): scale-based layout, UICorner/UIStroke/UIGradient, 9-slice frames. Match the exported image at desktop and phone sizes.
- Roblox does not accept SVG uploads: rasterize to PNG or avoid.
- Make assets with the tools in `docs/ASSETS.md`. Show the result and get approval before uploading. Keys live in `.env`, never in code or chat.
- Budgets (our rules): props <= 2,000 tris, hero assets <= 10,000, textures <= 1024px unless justified.

## Definition of done
`./tools/verify.sh` passes, tests added for pure logic, `/audit` run, spec checklist updated, `DECISIONS.md` updated if needed, one commit per feature.

## Skills
Project skills live in `.claude/skills` (Roblox, game UI/audio/assets, Blender). They are reference: when one conflicts with this file or the Net layer, this file wins. Update them with `npx skills update -p` and review the diff before committing.

## Never
- Add a paid tool or plugin without asking.
- Guess tool versions: use `rokit add`.
