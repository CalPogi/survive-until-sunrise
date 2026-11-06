# Spec: Ghost avatars

## Goal
Players on other servers look like real players: their own Roblox avatar, with idle, walk, run, jump and fall animations.

## Behaviour
- A new ghost appears as the grey stand-in, then swaps to its avatar once that loads. Up to 3 load at once, and the rest wait their turn.
- At most 40 ghosts have avatars, which is the most tested so far. Others stay stand-ins until a slot frees, first come, first served, so a nearby ghost can be a stand-in while a far one has an avatar.
- If an avatar can't load, the ghost stays a stand-in and the client warns once. It doesn't retry unless the ghost leaves and returns.
- Avatars are built on the client, so they exist only there. They can't be touched, collided with or targeted.
- Everyone is shown as R15 with Roblox's default animations. Custom animation packs aren't used.
- The name shows through the Humanoid, like a real player's, but as the username rather than the display name.
- Bots use the default avatar.

### Poses
Chosen each frame from how the ghost is really moving on screen, so they match what the player sees:

| Pose | When |
|---|---|
| Jump | The ghost's jump arc is playing |
| Fall | Dropping faster than 25 studs/s |
| Idle | Slower than 0.75 studs/s, and it starts moving again above 1.5 |
| Walk | Below 11 studs/s when starting to run, and it stays running down to 9 |
| Run | Default walking speed (16 studs/s) uses this one |

Walk and run play faster or slower to match speed, between half and double, so feet don't slide. A move faster than 200 studs/s is a teleport or respawn, so it doesn't count as movement.

## Out of scope
- Display names, custom animation packs, R6 and held items.
- Lower detail for far ghosts, unless the test below needs it.
- Tools and swing animations, which arrive with combat.

## Remotes
None.

## Server state
None.

## Pure logic (unit tested)
**`GhostPose.luau`** in `src/shared`: `next(current, speed, verticalSpeed, jumping)`, `playbackSpeed(pose, speed)`, `isTeleport(distance, dt)`, `smooth(current, target, dt)`.
- A jump across the map is a teleport, while a jump's arc and running at a low frame rate aren't.
- Jumping beats everything, then falling.
- Moving thresholds have a gap, so a speed near a limit doesn't flicker between poses.
- Playback speed follows ground speed within its limits. Other poses play at normal speed.
- Smoothing moves toward the target and doesn't overshoot on a long frame.

**`GhostInterpolator`**: the state says whether a jump arc is playing.

## UI
None.

## Assets
None. Avatars come from Roblox, and the animations are Roblox's defaults.

## Exploit audit
Run on 2026-11-06 by a separate agent, combined with `/review`. No remotes or server code changed, so there are no security findings. A client can't set a ghost's user id, because ids come from the server. No critical or high findings.

| Severity | Finding | Resolution |
|---|---|---|
| Medium | An error after the swap could lose a load slot for good, and 3 of those would leave every later ghost grey | Fixed: the whole load is protected, and the stand-in stays until the avatar's animations are ready |
| Medium | Every ghost got a full avatar, with no limit | Fixed: at most 40. Phones and real outfits still need measuring |
| Low | A teleport or respawn played the wrong pose for up to about a second | Fixed: it doesn't count as movement |
| Low | Name lookups for stand-ins weren't limited, and repeated the avatar's lookup | Fixed: one lookup, inside the load limit |

Accepted:
- **An idle ghost can reload after one lost message:** this needs a server above 42 players at the slowest send rate, where a player updates only about every 5.5 s. One lost message then passes the 8 s timeout, so the avatar goes grey and reloads. That isn't reachable yet, and raising the timeout makes every ghost linger longer after its player leaves. Revisit with fill-first joining.
- **A web call that never returns holds its load slot:** nothing times these out. Whether Roblox guarantees they return isn't known.

## Studio playtest
Run with loopback and a real character's snapshots relayed back under the second account's user id, so a real ghost could be watched next to the player. The avatar calls were also checked from a real `LocalScript`, in case the test tool's higher permissions hid a restriction.

| Check | Result |
|---|---|
| Avatar | The second account's own avatar and username appear, replacing the stand-in |
| Poses over a run, jump, stop and reverse | idle, walk, run, jump, run, walk, idle, jump, idle, with run playing at about 0.97 to 1 times normal speed |
| Height | Ghost 4.00, player 3.93 on the same spot |
| Untouchable | 0 of the parts with collision, touch or query on, after fixing the torso collision that came back on parenting |
| 40 bots | All loaded within about 0.5 s, 60 fps after a first window of 51, 3.0 to 3.9 ms of render CPU |
| Moving 40 ghosts each frame | 0.5 ms by setting the root, against 1.7 ms with `PivotTo` |
| 50 bots, plus the relayed ghost and one that can't load | 40 avatars and 12 stand-ins, with 0 touchable parts |
| Down to 25 bots | After the rest timed out, 26 avatars and only the unloadable stand-in, so waiting ghosts took the freed slots |
| A user id that doesn't exist | Stays a stand-in labelled "Ghost", with one warning |
| Moving the player 400 studs while standing | The ghost's pose stayed idle |
| Collision after running and jumping | 0 touchable parts on the real ghost |

Limits of these results:
- Bots use the plain default body, so real avatars with clothes and accessories will cost more than the 40-bot figure.
- Avatar load time was measured with bots, which skip the web calls for the avatar. One real avatar took about 0.5 to 0.9 s.
- Studio throttles to 15 fps when its window isn't focused, so only the first seconds after Play gave valid frame rates. GPU cost wasn't measured separately.
- Phones weren't tested, and they're where avatars will cost most.
- Not tested: a ghost leaving during a load, and animations failing to load.

## Two-account test
Run on 2026-11-06: the owner reported that the live game "looks right". Whether this included a phone wasn't reported, so phones are still untested.

## Checklist
- [x] `./tools/verify.sh` passes
- [x] Tests added for pure logic
- [x] `/audit` run, findings resolved
- [x] `/review` run, findings resolved
- [x] Playtested in Studio
- [x] Two-account test run and results recorded here
- [x] `DECISIONS.md` updated if needed
- [ ] One commit
