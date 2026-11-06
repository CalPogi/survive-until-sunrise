# Spec: Ghost polish (send-on-change and instant actions)

## Goal
Spend ghost messages where they show. Players standing still cost almost nothing, ghosts turn and stop in the right place, and jumps play as one clean arc where the player made them. This doesn't shorten how far behind a walking ghost is.

## Behaviour

### When a server sends
`GhostService` checks its players every 0.05 s and sends if any of these is true and it has credit:
- **Change:** someone started moving, stopped, turned more than 45 degrees, faced more than 45 degrees away, moved up or down more than 1 stud, or joined.
- **Action:** someone has an action waiting.
- **Due:** someone is moving and one spacing has passed since the last send.
- **Heartbeat:** 2.5 s have passed (or one spacing, if longer), so idle ghosts aren't removed.

A message still carries everyone on the server, because message count is the limit, not message size.

### Credit
Credit refills at 1.1 per spacing and holds at most 3. Each send costs 1. Steady sends use 1 of every 1.1, so the rest is kept for changes and actions. This was 1.25 until the two-account test asked for less delay, which leaves less spare credit for turns.

The average send rate stays at the `GhostBudget` rate, so the spacing is that interval × 1.1:

| Budget interval | Spacing (steady walking) | Delay from spacing, buffer and transit |
|---|---|---|
| 0.35 s | 0.39 s | About 0.69 s |
| 1 s | 1.1 s | About 1.4 s |
| 2.5 s | 2.75 s | About 3.05 s |

Bursts are safe against the per-topic limit. With two servers that limit is 200 messages a minute, and credit allows at most 171 + 3 in any minute.

From the real player to their ghost, Studio measured 0.85 to 0.87 s at the default spacing, including about 0.03 s from the test relay and fake transit of 0.2 to 0.25 s. Before these changes it was 1.03 s.

### Position reports
Physics takes a while to reach the server, so each client reports its own position, facing and velocity, up to 20 times a second while they change, plus once when it stops. The server uses a report for ghosts only if it's at most 0.25 s old and within 15 studs of where the server sees the player. Otherwise it uses physics. A jump hold starts from the same height the samples use, and only applies within 9 studs of both the sample and the server's view.

Reports are for drawing ghosts only. A client can shift its own ghost by up to 15 studs, so nothing that decides a hit, or anything else in gameplay, may read them. The server's view isn't proof of where a player is either, because clients own their character's physics and nothing checks movement yet. On late snapshots, the receiving client can also extrapolate from a sent velocity by up to 16 studs per axis.

**Why ghosts still can't carry combat:** the send interval and MessagingService transit alone are about 0.6 s, against roughly 0.1 to 0.2 s between players on one server. Fights stay on one real server (#35).

`GhostIntervalOverride` sets the spacing directly, but can't go below the budget's spacing, so the test tool can't break the limits either.

A ghost is now removed after 8 s without a sample, up from 5 s, so one lost heartbeat can't remove an idle player. A player who really leaves stays visible for up to 8 s.

### Instant actions
- `GhostService.queueAction(userId, action)` is the way in for later features such as swings and shots.
- The action goes in that player's `anim` field: 0 means none, and other values come from `GhostCodec.Action`. There's no new message type or topic.
- It's kept until a publish that includes the player succeeds, so a lack of credit or a failed publish only delays it. If two arrive between sends, the newer one wins.
- The message goes at once, and the client decides when to show the action. A jump plays at its own time on the ghost's body. A later action such as a swing could play on arrival instead.
- A published message can still be lost, so actions must stay cosmetic.

**Jumping** is the only action so far. The first version detected jumps from physics and flashed the ghost, and the two-account test found it wasn't good. A jump lasts 0.54 s, about one send spacing, so height samples can't carry it:

| | First version | Now |
|---|---|---|
| Press to message, including the 0.2 to 0.25 s fake transit | 0.72 to 1.07 s | 0.28 to 0.35 s |
| What the ghost shows | A flash, then a rise 0.55 s later | One real arc, about 0.85 s after the real jump |
| Where it plays while running | Not measured | 0.4 to 0.7 studs from the real takeoff spot |
| Peak height (real jump 7.2 studs) | 4.2 to 6.9 studs, depending on send timing | 7.2 studs |
| Sends for a standing jump | 3 or 4 | 1 |

It now works like this:
1. The client fires `GhostJump` when its humanoid enters the Jumping state.
2. The server queues the action and sends the height from that moment for 0.7 s, so samples leave the jump out. A jump during a hold extends it and keeps the first height, because the character may be in the air by then. A hold only applies while the real height is within 9 studs of the held one, so teleports and falls show at once, and a client that keeps signalling can't pull its ghost further off than a normal jump does.
3. The ghost queues the arc of a default jump at the message's sender time, and plays it when its render time reaches that moment. The second version played the arc on arrival, about 0.5 s ahead of the body, and the two-account test found it out of place. So a jump now has the same delay as movement. Jumps queue, so a hop arriving during another doesn't cut it off. One that would start more than 1 stud up in the previous arc is ignored, because it would drop the ghost in one frame.

Physics can't be used for this: on the server, a player's velocity lags their position by about 0.3 s, and the first velocity-based hold pinned the height at about 8.7 studs instead of 4.

Known limits:
- Jumping onto a platform shows the hop back down to the old height, then the ghost rises to the platform about 0.2 s later.
- Hopping up a hill holds the old height until the player is 9 studs off, then the height corrects.
- The arc assumes a default jump. If jump height changes in the game, change `JUMP_SPEED` in `GhostInterpolator` too.

### Client changes
A long gap between samples normally raises a ghost's render delay, so that players on full servers stay smooth. A gap is now ignored unless the samples on both sides of it are moving. Without this, a player who stood still would get about 2.6 s of delay as soon as they started walking. A gap also only counts if it's more than 1.5 times the send interval. Following every gap kept changing the delay, because send-on-change makes gaps irregular, and that changed the ghost's speed.

Correction now measures only the jump a new sample causes, by comparing the ghost's position at the same moment with and without that sample. It used to compare the last frame with the current one, so every sample counted one frame of normal movement as an error. The ghost froze for one frame and caught up, about twice a second. This bug predates send-on-change.

## Out of scope
- Real avatars and walk animations: see `docs/specs/ghost-avatars.md`.
- Sending only some players per message, and putting changed players first on servers above 42.
- Using the saved messages to lower the interval.
- Hit claims and damage.

## Remotes
`GhostSnapshot` is unchanged, and `anim` was already sent as 0.

**`GhostJump`** (client to server, new): no arguments, 2 calls a second with a burst of 2, through `Net.onEvent`. The server ignores it if the player has no living character.

**`GhostPosition`** (client to server, new, `UnreliableRemoteEvent`): x, y, z, yaw, vx and vz, 25 calls a second with a burst of 30, through `Net.onUnreliableEvent`. Each value has a range check, and each report must then pass `GhostReport.isUsable`.

## Server state
Credit, last send time, last sent entries, waiting actions, jump holds and position reports, all in memory. Waiting actions, jump holds and reports are cleared on `PlayerRemoving`. No health, inventory or saved state changes.

## Pure logic (unit tested)
**`GhostPacer.luau`** in `src/shared`: `new()`, `shouldSend(now, spacing, entries)`, `spacingFor(budgetInterval)`.
- First call sends. Idle players then send only at the heartbeat.
- A moving player sends once per spacing.
- Starting, stopping, a sharp turn, facing away, a height change, a new player and an action each send at once.
- Small turns and small speed changes don't.
- Credit runs out under constant changes, and the average rate stays within the budget.
- Leavers don't grow memory.

**`GhostCodec`**: an action value survives encode and decode.

**`GhostReport`**: `isUsable(age, dx, dy, dz)` accepts a fresh, close report, and rejects a stale one, one from the future, and one too far away on any axis or in total.

**`GhostInterpolator`**: a steady walker moves the same distance every frame as samples arrive. `playJump(senderTime)` waits for the body to reach its time, follows a default jump's arc and lands. A new sample mid-jump doesn't change it, a jump arriving during another plays after it, and a jump that would start high in the previous arc, or is older than the newest, is ignored.

## UI
None.

## Assets
None.

## Exploit audit
Run on 2026-11-06 by a separate agent, combined with `/review`, and again after `GhostJump` was added. No critical or high security findings. `GhostJump` takes no arguments and uses the sender's own `UserId`, so a client can only affect its own ghost, and only cosmetically for now. Hit claims must not trust a ghost's height, since it can be up to 9 studs off. A client that moves or signals constantly can keep credit low, but sends stay within the limits, and everyone on the server is in every message.

| Severity | Finding | Resolution |
|---|---|---|
| High | One lost heartbeat could remove an idle player's ghost, because 5 s was too close to 2 × 2.5 s | Fixed: removal is now after 8 s |
| Medium | The rotation index went stale when a player joined, so a message could leave out other players | Fixed: rotation only applies above 42 entries |
| Medium | A signalling client, or a player hopping up a hill, could hold a ghost's height without limit | Fixed: a hold only applies within 9 studs of the real height |
| Medium | A jump hold plus a report could put a ghost's height 24 studs from the server's view, past the 15-stud limit | Fixed: a hold also has to be within 9 studs of the server's view |
| Medium | Holds started from physics height while samples came from reports, so a ghost could float after a fall or a quick re-jump | Fixed: holds start from the same height as samples |
| Medium | Stops reached the pacer up to 0.25 s late, because the last report still carried speed | Fixed: the client reports once when it stops |
| Medium | A jump could be missed while the send loop waited on a publish | No longer applies: jumps come from the client signal |
| Medium | The interval override could break limits at 3 or more servers | Fixed: it can't go below the budget's spacing |
| Medium | A lost stop message counted the next heartbeat as a long gap, adding delay | Fixed: gaps count only between two moving samples |
| Low | An action queued during a publish could be cleared unsent | Fixed: actions are cleared before publishing and restored if it fails |
| Low | A jump arriving mid-arc dropped the ghost up to 7 studs in one frame | Fixed: jumps queue, and one that would start above 1 stud is ignored |
| Low | A queued jump could play long after, when a peer appeared or the player respawned | Fixed: actions are dropped when there are no peers or the player isn't alive |
| Low | The 0.1 s check made real gaps longer than the spacing | Fixed: the check is now 0.05 s, and 2.25 messages/s were measured against 2.29 expected |

The stutter and hop-timing fixes change only client drawing code and add no input, so the audit wasn't repeated for them. `GhostPosition` got its own audit, with no critical or high findings. A client flipping its facing on every report can force sends at the budget rate, which is the same ceiling as before but cheaper to reach. That's accepted, because everyone is still in every message. The audit also suggested adding this cosmetic exception to `CLAUDE.md`, which is left for the owner to decide. `ARCHITECTURE.md` records it.

Accepted:
- If a publish fails, the pacer still treats it as sent, so a lost stop is corrected by the next heartbeat. A message lost in transit behaves the same way, and neither can be fully prevented.
- `queueAction` doesn't check its own input. `GhostJump` checks for a living character first, and later callers should too.

## Studio playtest
Run with loopback (one server, fake 0.2 to 0.25 s transit), so MessagingService and real players weren't exercised:

| Check | Result |
|---|---|
| 5 moving bots | 2.25 messages/s (expected about 2.29), 60 fps, largest frame step 0.34 studs |
| One idle player, no bots | 0.33 messages/s, down from 2.86 before this change |
| Bots removed | Ghosts gone within 7 s (measured at the old 5 s timeout) |
| Jump to message, 20 real jumps (standing, walking and holding Space) | 0.28 to 0.35 s, including the fake transit |
| Height samples during those jumps | Flat: 4.0 standing and holding Space, 3.0 walking |
| Messages per jump when standing or holding Space | 1 |
| A real player's own ghost, by relaying their snapshots under a fake id: 4 hops | Peak 7.2 studs, 0.53 s in the air, no extra bumps, 0.88 to 0.93 s after the real jump, 0.1 studs from takeoff when standing and 1.8 to 2.7 when running |
| Same ghost, frame by frame while running and turning | No one-frame freezes in the first run |
| Same ghost, two later runs on straight lines, one with running jumps | 1 of 557 frames reached 22 studs/s (true speed 16) in the run measured against the real ghost, and the render delay stayed at 0.54 s |
| Ghost delay behind the real player, before position reports and shorter spacing | p50 1.03 s, p10 1.02 s, p90 1.07 s, including about 0.03 s from the test relay |
| The same, after them | p50 0.85 and 0.87 s across two runs, with p10 0.83 s and p90 0.87 to 0.88 s, also with the relay. On straight lines, 23 of 306 and 45 of 338 frames were off by more than 3 studs/s, including speeding up and slowing down, and none froze |
| Hops after them, including re-jumps 0.75 s apart | Peak 7.0 to 7.2 studs, 0.4 to 0.7 studs from takeoff when running, and height samples flat |
| Player stops to a zero-speed message reaching the client, 4 stops | 0.32 to 0.35 s, including the fake transit |
| Client reporting a false position | 10 studs off: used, ghost moved 9.9. 1,000 studs off: ignored. NaN, infinity, wrong type, missing value and a speed of 9999: dropped, and snapshots continued |
| Audit's case: hold at the ground, server's view 24 studs up, report 9 up | Sent 9.1 above the ground, then 24.1 once the report went stale, and never the held height |
| Client signalling at a legal rate while the server moved it | Up 5 studs: height stays held. Up 25 studs: corrects at once. Falling: follows once past 9 studs |
| 53 rapid `GhostJump` calls | 1 action, and 5 log lines |

Where the first version's jump time went, from 2 jumps in Studio: about 0.02 s from press to the client's jump, 0.37 to 0.43 s for the server to see it in velocity, and 0.28 to 0.37 s to the client including fake transit. The other 4 test jumps in that run never started.

Velocity also lags on walking, but less: 0 to 0.25 s late when starting, and not late when stopping. The rendered delay doesn't depend on it, so it's unchanged.

A simulation of the same code with live-like timing, before and after the stutter fixes: on straight runs, frames fell as low as 0 studs/s before and stayed between 15.4 and 17.4 after. On zigzags, frames off by more than 3 studs/s went from about 25% to 1.2%.

Unexplained: one earlier run of the relayed ghost showed single frames of up to 193 studs/s. They didn't return in the two later runs, and the cause wasn't found. That run's logger and the later ones measured differently, so it may be a measuring error, but that isn't confirmed.

Not tested: dropping actions with no peers or on death, and restoring them after a failed publish, because Studio has no peers or real publishes and no one died in the test. The long-gap rule for full servers, and live servers in general. The 8 s timeout was retested only by the runs above.

## Two-account test
Run on 2026-11-06:
- **First version:** movement was good but delayed, and the jump wasn't good. Corners at `GhostIntervalOverride = 1` and the idle check weren't reported separately.
- **Second version (hop on arrival):** jerky or stuttering, and the jump was out of place.

- **Third version (stutter and hop fixes):** movement was still too delayed for combat.

**Needs from you for the fourth version:** republish, then join with both accounts. Run, turn and jump. Is it smooth, are corners still acceptable with less spare credit, and is the delay better?

## Checklist
- [x] `./tools/verify.sh` passes
- [x] Tests added for pure logic
- [x] `/audit` run, findings resolved
- [x] `/review` run, findings resolved
- [x] Playtested in Studio with bots (desktop only)
- [ ] Two-account test of the new jump run and results recorded here
- [x] `DECISIONS.md` updated
- [ ] One commit
