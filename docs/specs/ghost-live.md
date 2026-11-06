# Spec: Live ghosts and the two-server test

## Goal
Two players on different Roblox servers in the same area can see each other move, and we can measure the delay and judge how it feels. This is the gate for the whole "feels like one server" design.

## Behaviour

### Server: `GhostService`
- **Identity.** Each server has one area ID and one server ID. The area is the constant `"test"` with its origin at (0, 0, 0) for now. The server ID is `game.JobId`, or a generated GUID in Studio, where JobId is empty.
- **Registry.** Each server writes itself to a MemoryStore sorted map every 15 s, with a 45 s expiry and its area in the value. It also reads the whole map every 15 s to get the total servers, the other servers in its area, and the pair count for `GhostBudget`.
- **Subscribe.** It subscribes to each peer's topic, `g_<serverId without dashes>` (34 characters, limit 80), and disconnects when a peer leaves the registry. A failed subscribe is retried at the next refresh. A new server's ghosts can take up to 15 s to appear.
- **Send.** At the `GhostBudget` interval, if the server has any peers (timing since replaced, see `ghost-polish.md`):
  - Read each live player's `HumanoidRootPart`: position, yaw, velocity. The server reads these itself, and clients send nothing.
  - Skip players with no root part or no health.
  - Encode with `GhostCodec`, rotating `startIndex` across players on servers above 42.
  - Publish in a `pcall`. A failed publish is counted, not retried, because the next snapshot replaces it.
  - `anim` and `held` are sent as 0 for now.
- **Receive.** Decode each message and drop it if decoding fails, then forward the original text and the current send interval to all clients.
- **Shutdown.** `BindToClose` removes the registry entry, best effort. The 45 s expiry covers crashes.

### Client: `GhostController`
- Decode each snapshot, failing closed, and ignore entries for players on this server.
- Keep one `GhostInterpolator` per user ID, timed with `os.clock()`.
- Give each ghost the larger of the server's send interval and the gap between that ghost's last two samples. Players on full servers update less often, so their ghosts need more render delay.
- Every frame, sample each interpolator and move its ghost model.
- On `gone`, destroy the model and the interpolator.

### Ghost model (test version)
- Client-only, under `Workspace.Ghosts`: a torso block, a head block and a name label. Anchored, with `CanCollide`, `CanTouch` and `CanQuery` all off.
- It slides and turns. `docs/specs/ghost-avatars.md` has since replaced this with real avatars and animations.

### Test tools
These exist so we can measure and test without a crowd. Both are server-only attributes, so clients can't set them.
- **Bots:** `GhostBots = N` adds N fake walkers to this server's snapshots. They walk circles near the origin, with IDs that can't match a real player or another server's bots.
- **Interval override:** `GhostIntervalOverride = seconds` replaces the computed interval, clamped to `GhostBudget.MIN_INTERVAL`, so we can compare 0.5 s, 1 s and 2 s. It's shared through the registry, so setting it on the owner's server also changes the peer within about 15 s. Without this, only one direction would change.
- **Latency probe:** every 5 s a server pings each peer on a separate `gp_<serverId>` topic and the peer echoes it. Round trip / 2 gives transit time without trusting clocks.
- **Report:** every 30 s the server logs to the developer console: interval, servers, peers, pair count, transit p50 and p95, messages in and out, every failure count, the longest message, and the difference between the two servers' `GetServerTimeNow`. Only the owner can read a server's console, so each server also shares its report through the registry, and the owner's server prints its peers' reports too.
- **Studio loopback:** MessagingService is reported not to work across Studio sessions. So in Studio, bot snapshots loop back to the same server after a simulated 200 ms delay with jitter. That lets ghosts be tested and screenshotted in Studio before anything is published.

### Template cleanup
Delete the Ping smoke test (`PingService`, `PingController`, its remote names and the `docs/SETUP.md` steps), as the template says to do with the first real feature.

## Out of scope
- Hit claims, damage and rewind use, soft push-apart, and area ownership leases. Those need this test to pass first, and each gets its own spec.
- Real avatars, animations, held items and name privacy options.
- Infected and vehicles as ghosts.
- Distance culling and rendering limits, multiple areas, and player routing.
- A relay service.

## Remotes
| Name | Direction | Args (and checks) | Rate | Server does |
|---|---|---|---|---|
| `GhostSnapshot` | Server to client, `UnreliableRemoteEvent` | Text (up to 900 characters, already decoded once by the server), send interval (seconds) | One per incoming peer message | Forwards to all clients. The client decodes again and ignores anything malformed |

There are no client-to-server remotes. `Net` needs one addition on each side: `Net.unreliableClientEvent(name)` on the server, and `Net.onUnreliableEvent(name, callback)` on the client. Unreliable payloads over 1000 bytes are dropped, so the test also confirms that 900 characters plus the interval fits.

## Server state
- The registry entry, peer list, topic connections, rotation index, bot state and test counters. All are in memory or expire on their own.
- Nothing is saved to DataStore. No health, inventory or other authoritative state changes.

## Pure logic (unit tested)
In `src/shared`, with no Roblox APIs.

**`GhostArea.luau`**: `summarize(registryEntries, myArea, myServerId)` returns total servers, peers in my area, and pair count.
- One server: no peers, zero pairs.
- Two areas of different sizes give the right pair count (for example, sizes 3 and 2 give 8).
- My own server is never listed as a peer.
- Malformed entries are skipped.

**`GhostBots.luau`**: `entries(count, time, idBase)` returns walkers in `GhostCodec.Entry` shape.
- Same inputs give the same output.
- IDs are unique and pass `GhostCodec.encode`.
- Speed stays within walking range, so ghosts blend and never snap.

**`LatencyStats.luau`**: `add(seconds)`, `percentile(p)`, `count()`.
- Known samples give known p50 and p95.
- An empty set returns nil.
- Memory is bounded to the most recent samples.

`GhostService` and `GhostController` touch Roblox APIs, so they're checked by the Studio playtest and the live test.

## UI
None. The name label is part of the test model, and the report goes to the developer console.

## Assets
None.

## Exploit audit
Run on 2026-11-06, combined with `/review`, by a separate agent reading the same checklists. No High findings, and no new client input.

| Severity | Finding | Resolution |
|---|---|---|
| Medium | A failed probe subscribe was never retried or counted, so the test could lose its transit numbers with no explanation | Fixed: retried at each refresh and counted |
| Medium | The second account can't read its server's console or set its override | Fixed: the override and reports are shared through the registry |
| Medium | One error would silently stop a loop for good | Fixed: every loop is protected, and errors are counted in the report |
| Medium | Registry write failures weren't counted | Fixed: separate read and write failure counts |
| Low | Refreshes could overlap, and a hung subscribe could delay re-registering | Fixed: separate write and read loops, each waiting for itself |
| Low | Publish time made the real send rate slower than reported | Fixed: the wait subtracts time already spent |
| Low | A ghost could stand beside a player who just joined this server | Fixed: removed on `PlayerAdded` |
| Low | Pagination used an undocumented string bound | Fixed: uses the documented table form |

Accepted:
- A forged publish with an Open Cloud key can create a fake ghost, which goes away on its own. Malformed text is dropped before reaching clients.
- A hacked client's movement passes into snapshots exactly as it replicates on its own server. The hit-claim spec has to validate it.

## Studio playtest
Run with loopback, so MemoryStore and MessagingService were not exercised:
- 5 bots appeared and moved at about 12 studs/s, with no frame jump above 0.3 studs.
- The local player got no ghost of themselves.
- 50 bots appeared, including those past the 42-per-message cap, and rotated bots stayed smooth at a 1 s interval. An 891-character message got through the unreliable event.
- All ghosts cleared about 6 s after bots stopped, and the report showed zero failures.
- Firing the remote from the client with garbage was discarded by the engine, and bad text fails closed.

Not checked: the phone emulator, and how ghosts feel. Ghosts are test blocks, and there's no real UI.

## The two-server test
**Needs from you**
1. Publish the place to a new free experience, separate from anything else.
2. Have a second account on a second device, such as a phone or a friend's computer.
3. Put the two accounts on different servers. The simplest way is setting the server size to 1 in the experience settings. I haven't confirmed Roblox allows a size of 1. If it doesn't, each account can start its own free private server.
4. Make sure the second account can join. I haven't confirmed what access a private experience needs here, so check its visibility first.

**Steps**
1. I test ghosts in Studio with bots and show you screenshots.
2. You publish, and both accounts join. Each should see the other as a ghost within about 15 s.
3. Walk around together at 0.5 s, 1 s and 2 s intervals, and judge how each feels. Set the override from the owner's developer console. It reaches the other server within about 15 s, so wait before judging.
4. Add bots to test a full message, and watch for limit errors.
5. Copy the reports from the owner's developer console for me. They include the other server's report.

**What it answers**
| Question | How |
|---|---|
| How long does a message take between servers? | Probe, p50 and p95 |
| How far behind are ghosts in practice? | Interval + transit + buffer, plus your judgment |
| Do published limits hold? | Publish failures and Output warnings |
| Do 900 characters get through both transports? | Longest message with 42 bots |
| Do server clocks agree? | Report, for information only |

**Decision after the test**
- **Feels fine at the interval a realistic crowd allows (about 1 to 2 s):** keep MessagingService and move on to hit claims.
- **Only feels fine when faster:** choose between a relay (hosting may cost money and needs your approval), fewer servers per area, or using ghosts only to show presence and keeping fights on one server.
- **Transit itself is bad, or limits are hit early:** the design needs rethinking before more is built.

**First live results (2026-11-06, partial)**
Two real servers, one player each, server size 1, public experience.

| Measure | Server A | Server B |
|---|---|---|
| Transit p50 | 0.214 s | 0.177 s |
| Transit p95 | 0.217 s | 0.222 s |
| Probes so far | 9 | 5 |
| Clock difference | -0.026 s | 0.005 s |
| All failure counts | 0 | 0 |

- **It works live:** servers found each other through the registry, and each player saw the other as a named ghost.
- **Transit is about 0.2 s,** so most of the ghost's delay comes from the send interval and buffer, not the network. Ghost delay is about interval + 0.3 s.
- **Feel:** at the default (0.35 s, about 0.65 s behind) the owner reported under a second of delay. At 1 s (about 1.3 s behind) the other player could be followed but felt delayed, and the owner wouldn't trust it to fight alongside them.
- **Clocks** agreed within about 30 ms in this sample, though nothing depends on that.

Not yet tested: the 0.5 s and 2 s intervals, a full message with 42 bots on live servers, and more than two servers. The probe sample is small, and it came from one pair of servers.

**Prediction: tried and rejected**
Because 1 s felt too delayed, ghosts were changed to show almost at the newest sample and move ahead on their last known velocity. A simulation with bots on steady curves looked good (15.5 down to 4.4 studs from the real position at 1 s). On live servers with real players it felt worse, "like the player is teleporting": at 1 s a running player can overshoot by up to about 16 studs, which then has to be pulled back. Prediction was removed. The short blend that removes jumps when a sample arrives was kept.

**Decision:** ghosts show presence and smooth movement. Close fights happen on one real server, through routing. See `DECISIONS.md` #33.

## Sources
- [Messaging usage guide (80-character topic limit, 1 KiB messages)](https://create.roblox.com/docs/cloud/guides/usage-messaging)
- [Memory stores (quota, costs)](https://create.roblox.com/docs/cloud-services/memory-stores)
- [MemoryStoreSortedMap (200 items per range read)](https://create.roblox.com/docs/reference/engine/classes/MemoryStoreSortedMap)
- [MessagingService for Studio (community report that it doesn't work in Studio)](https://devforum.roblox.com/t/messagingservice-for-studio/3315802)

## Checklist
- [x] `./tools/verify.sh` passes
- [x] Tests added for pure logic
- [x] `/audit` run, findings resolved
- [x] `/review` run, findings resolved
- [x] Playtested in Studio with bots (desktop only)
- [ ] Two-server test run and results recorded here
- [ ] `DECISIONS.md` updated with the result
- [ ] One commit
