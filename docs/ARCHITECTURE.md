# Architecture

| Folder | Becomes in Studio | Holds |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Pure logic (`Validate`, `RateLimiter`), `RemoteNames`, `Types` |
| `src/server` | `ServerScriptService.Server` (Script) | `Net`, `Services/*` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (LocalScript) | `Net`, `Controllers/*` |
| `tests` | not synced | Lune unit tests for pure logic |

## Lifecycle
Each Service/Controller returns `{ Name, Init?, Start? }` (`Types.Lifecycle`). The bootstrap requires all of them, runs every `Init` in order (register remotes, set up state, no yielding), then every `Start` in its own `task.spawn`.

## Networking
- Remotes live in `ReplicatedStorage.Remotes`, created by the server when a Service registers them. Every name is in `RemoteNames`.
- Server: `Net.onEvent(name, { checks, rate?, handler })`, `Net.onFunction(...)`, `Net.onUnreliableEvent(name, ...)` for replaceable client data, `Net.clientEvent(name)`, `Net.unreliableClientEvent(name)` for replaceable data.
- Per call: rate limit per `player.UserId` (default 10 burst, 5/s) -> `Validate.args` (exact arg count) -> `handler(player, args)`. Drops are logged, capped at 5 lines per player per burst.
- Function handler errors are caught so error text never reaches the client.
- Client: `Net.fire`, `Net.fireUnreliable`, `Net.invoke`, `Net.onEvent`, `Net.onUnreliableEvent`.
- `GhostPosition` is the one client-sent position the server uses, and only to draw ghosts (#39). Nothing that decides gameplay may read it.
