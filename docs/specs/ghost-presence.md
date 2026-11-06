# Spec: Ghost presence protocol

## Goal
Nothing a player can see yet: this feature delivers the tested logic that later lets players on different servers in the same area see each other move as ghosts. It is the riskiest part of the multiplayer design, so it comes first.

## Behaviour
Each server sends a batch of its players' state to the other servers in its area. A receiving server or client turns those batches into smooth ghost motion. Each server also keeps recent positions of its own players, so a later hit claim can be checked against where the target was.

### Transport budget (the constraint that shapes everything)
Roblox's published MessagingService limits, from its May 2026 announcement (recheck against the live docs before relying on them):

| Limit | Value |
|---|---|
| Message size | 1 kB (forum reports say about 976 bytes in practice) |
| Sent per server | 600 + 240 x players, per minute |
| Received per topic | 40 + 80 x servers, per minute |
| Received per whole game | 400 + 200 x servers, per minute |
| Subscriptions per server | 20 + 8 x players |

The whole-game receive limit is the one that binds, because every subscriber counts as a receive.

**Rules that follow from it:**
- **One topic per sending server, not one per area.** A shared area topic echoes each message back to its sender and hits the per-topic limit quickly. With per-server topics, a sender's message costs one receive per other server in the area.
- **Ghosts get half the whole-game budget.** The other half stays free for hit claims and world events.
- **The send interval is computed, not fixed:** `sends per minute = 0.5 x (400 + 200 x S) / P`, where S is the total servers in the game and P is the sum of `s x (s - 1)` over all areas (s is the servers in that area). Areas with one server cost nothing.

Worst case, with every area the same size, before clamping:

| Total servers | Servers per area | Send interval |
|---|---|---|
| 2 | 2 | 0.3 s |
| 10 | 2 | 0.5 s |
| 100 | 2 | 0.6 s |
| 100 | 3 | 1.2 s |
| 10 | 5 | 2.0 s |
| 100 | 5 | 2.4 s |
| 100 | 10 | 5.3 s |

**Limits this sets:**
- Send interval is clamped to 0.35 s minimum and 2.5 s maximum. The minimum is 0.35 s because two servers would otherwise sit exactly on the per-topic limit.
- Past 2.5 s, routing should stop opening more servers in that area. When every area is that busy, that means about 4 or 5 servers per area, or about 160 to 400 players in one place at 40 to 80 players per server. One busy area among quiet ones can hold more, because single-server areas cost nothing.
- Ghost delay is roughly send interval + transit + a small buffer. Over MessagingService that is about 0.5 to 2 s or more, not the 300 to 600 ms estimated earlier. Transit time is unmeasured. The two-server test measures it.

### Message format
One message type, and no separate roster. Each message is a printable ASCII string using a 64-character alphabet (`A-Z a-z 0-9 - _`), which needs no JSON escaping, so one character is one byte.

Header, 9 characters:
| Field | Chars | Encoding |
|---|---|---|
| Version | 1 | Protocol version |
| Type | 1 | `S` for snapshot |
| Sender time | 7 | Milliseconds on the sender's clock |

Each player entry, 21 characters:
| Field | Chars | Encoding | Range or step |
|---|---|---|---|
| User ID | 7 | Integer, stored with 1024 added so Studio's negative test IDs work | Up to about 4.4 trillion |
| X | 3 | 0.25 stud steps, area-local | -32768 to about 32768 |
| Y | 2 | 0.5 stud steps, area-local | -1024 to about 1024 |
| Z | 3 | 0.25 stud steps, area-local | -32768 to about 32768 |
| Yaw | 1 | 5.625 degree steps | Full circle |
| Velocity X | 1 | 2 stud/s steps | -64 to 62 |
| Velocity Z | 1 | 2 stud/s steps | -64 to 62 |
| Animation | 1 | Index into a shared list | Up to 64 states |
| Held item | 2 | Index into a shared list, 0 is empty | Up to 4096 items |

Encoded size is capped at 900 characters, which fits **42 players per message**. If a server has more, the caller rotates who goes first, so those players update less often.

Out-of-range values are clamped, with two exceptions. A player with a non-finite value or an unusable user ID is skipped, so a bad ID can't turn into someone else. A bad sender time throws, because a clamped clock would freeze every ghost without any error.

### Ghost motion
- **Clock independence.** Ghost timing does not assume servers' clocks agree. For each sender, the receiver tracks an offset, the lowest `receive time - sender time` seen, allowed to drift slowly upward. This cancels clock difference and base latency, and a latency spike doesn't disturb it.
- **Render time.** A ghost is shown at `now - offset - renderDelay`, expressed in the sender's clock. `renderDelay` is the send interval + 0.1 s. When the interval changes, it moves at 0.25 s per second, so ghosts never jump backwards.
- **Interpolate** between the two samples around the render time, using the shortest path for yaw.
- **Extrapolate** from the last sample's velocity for up to 0.25 s if no newer sample exists, then hold still.
- **Snap** instead of blending when two samples imply more than 200 studs/s, which covers respawns and teleports.
- **Ignore** samples older than the newest one received, or claiming to be more than 5 s ahead of what the offset expects. Ignored samples don't keep a ghost alive.
- **Remove** a ghost after no sample for 3 send intervals, with an 8 s minimum (5 s until `ghost-polish.md`). The caller discards the interpolator on `gone` and makes a new one if the player returns, which also recovers from a real clock step.

### Rewind buffer
- Holds `maxAge` seconds of positions for each local player, at the server's sampling rate. `maxAge` must cover the longest send interval + 0.1 s + 2 x transit, so about 4 s until transit is measured.
- `at(t)` returns the interpolated position at time t, in the server's own clock.
- Returns nil if t is older than the oldest kept sample or more than `maxAge` before the newest.
- Returns the newest position if t is up to 0.25 s ahead of it, and nil beyond that.

**Why hit claims won't need synchronized clocks:** a ghost's render time is already in the target server's clock, because it comes from that server's own timestamps. A later claim can simply carry that time. This replaces the shared server clock listed in the PRD.

**The cost:** a claim checks where the target was when the shooter saw it, up to about 4 s ago. At slow send intervals, a target can be hit after reaching cover. The hit-claim spec must decide how much of that to allow.

## Out of scope
- `GhostService` and the live MessagingService wiring, the area and server registry, and drawing ghost avatars. These are the next spec.
- Hit claims, damage, and soft push-apart.
- Infected and vehicle mirroring, and area ownership leases.
- A relay service. Only considered if the two-server test shows MessagingService is too slow, and it needs your approval.
- Server-side speed or position sanity checks on outgoing player state.

## Remotes
None in this spec. No client can reach this code.

The next spec will add one server-to-client ghost event. That should be an `UnreliableRemoteEvent` with payloads under 1000 bytes, because each snapshot replaces the last. `Net.clientEvent` only creates a reliable `RemoteEvent` today, so `Net` needs an unreliable option then.

## Server state
None in this spec. These modules hold only the buffers their caller gives them. Position data will come from the server reading each character in the next spec, not from anything a client sends.

## Pure logic (unit tested)
All in `src/shared`, with no Roblox APIs, and clocks and times passed in. Plain numbers, not `Vector3`, so Lune can run them.

**`GhostCodec.luau`**: `encode(senderTime, entries, startIndex)` returns the string and how many input entries it consumed, including skipped ones, so the next start is `startIndex + consumed`. `decode(text)` returns the time and entries, or nil and a reason.
- Round trip stays within half a step on every field.
- 42 entries fit in 900 characters, and the 43rd does not.
- Output uses only the 64-character alphabet.
- Out-of-range values clamp. NaN and infinity are skipped.
- Negative positions, large user IDs and large sender times survive the round trip.
- Decode returns nil, and never errors, on: empty string, wrong version, wrong type, truncated header, a length that isn't a whole number of entries, and characters outside the alphabet.

**`GhostInterpolator.luau`**: `new(sendInterval)`, `setSendInterval(sendInterval)`, `push(senderTime, receiveTime, sample)`, `sample(now)` returns the state, status (`interpolating`, `extrapolating`, `holding`, `gone`), and the render time in the sender's clock.
- Midpoint between two samples gives the midpoint position.
- Yaw going from 350 to 10 degrees passes through 0, not 180.
- A sender clock 500 s off gives the same result as a matching clock.
- A one-off latency spike does not move the offset.
- A late, out-of-order sample is ignored.
- Extrapolation stops at 0.25 s, then holds.
- A jump above 200 studs/s snaps with no blending.
- Status becomes `gone` after the timeout.

**`RewindBuffer.luau`**: `new(maxAge)`, `push(t, x, y, z)`, `at(t)`.
- An exact sample returns itself, and between two samples it interpolates.
- Older than the oldest, or beyond `maxAge`, returns nil.
- Up to 0.25 s ahead returns the newest, and further ahead returns nil.
- Old samples are pruned so memory stays bounded.
- Out-of-order pushes are ignored.

**`GhostBudget.luau`**: `interval(totalServers, pairCount)` returns the clamped send interval, `rawInterval` the same before clamping, and `canOpenServer(totalServers, pairCount, serversInArea)` says whether another server in an area keeps it within 2.5 s.
- Matches every row of the budget table above.
- Zero pairs returns the 0.35 s minimum.
- Results clamp at both ends.
- Adding a server to a busy area returns false once the interval would pass 2.5 s.

## UI
None.

## Assets
None.

## Exploit audit
Run on 2026-11-06, combined with `/review`, by a separate agent reading the same checklists. The project agents weren't loaded in this session, so it used their definition files. No High findings. No remotes, so a client can't reach this code.

| Severity | Finding | Resolution |
|---|---|---|
| Medium | One sample with a future sender time stopped a ghost updating for minutes, or for good | Fixed: samples more than 5 s ahead are ignored, with a test |
| Medium | A 1 s rewind window can't serve claims at slow send intervals | Fixed in this spec: `maxAge` is now about 4 s until measured |
| Medium | The bad-character test never reached the entry check | Fixed: every entry position is now tested |
| Medium | Raising the send interval discarded history and jumped ghosts backwards | Fixed: 16 samples kept, render delay moves gradually, with tests |
| Low | Sender time rounded down, so the error could reach a full step | Fixed: rounds to nearest, with tests |
| Low | Out-of-range sender time throws, but the spec said clamp | Spec changed: throwing is the better behaviour |
| Low | `gone` reported render time on the wrong clock | Fixed, with a test |
| Low | Two servers sat exactly on the per-topic limit | Fixed: minimum interval is now 0.35 s, with a test |
| Low | Spec and code named things differently | Spec corrected |
| Low | Several behaviours had no test | Tests added. 18 deliberate code breaks were then all caught |
| Low | Recovery from a real latency rise takes about 75 s | Accepted for now: measure in the two-server test |
| Low | Rotated players on full servers get too little render delay | Accepted for now: passed to the next spec |

Still open: anyone with an Open Cloud publish key could send a forged first sample. That ghost goes `gone` and recovers, so the impact is limited.

## What the next spec's test must answer
The two-server test on a published place decides whether this transport is good enough:
- Real transit time and jitter, measured by round-trip echo so clock differences don't matter.
- Whether `GetServerTimeNow` agrees across servers, for logs only.
- Whether the 976-byte figure holds, and whether the limits behave as published.
- Whether ghost delay feels acceptable at 0.5 s, 1 s and 2 s intervals.

The next spec must also:
- Pass each player's real sample spacing to the interpolator, since players on servers above 42 update less often than the send interval.
- Check how quickly ghosts recover after a real latency rise (about 75 s in simulation).
- Put hit claims on their own topics, not on ghost topics.
- Treat decoded `anim` and `held` values beyond the shared lists as unknown.
- Add a sender-side sanity check, since a speed-hacking client's movement passes into snapshots.

If 1 to 2 s of ghost delay feels bad, the options are a paid or limited relay, fewer servers per area, or accepting ghosts as presence only.

## Sources
- [Unifying MessagingService Open Cloud and Engine API rate limits](https://devforum.roblox.com/t/unifying-messagingservice-opencloud-api-and-engine-api-rate-limits/4600993)
- [Messaging Service Limits thread (976-byte report, N x N receive cost)](https://devforum.roblox.com/t/messaging-service-limits/2563657)

## Checklist
- [x] `./tools/verify.sh` passes
- [x] Tests added for pure logic, registered in `tests/run.luau`
- [x] `/audit` run, findings resolved
- [x] `/review` run, findings resolved
- [ ] Playtested: not applicable until the next spec
- [x] `DECISIONS.md` updated (per-server topics, computed interval, no shared clock)
- [ ] One commit
