# Spec: <feature>

## Goal
One sentence: what the player can do after this ships.

## Behaviour
- ...

## Out of scope
- ...

## Remotes
| Name | Direction | Args (and checks) | Rate | Server does |
|---|---|---|---|---|

## Server state
What the server owns and how it changes. Never trust the client for any of it.

## Pure logic (unit tested)
Modules in `src/shared` and their test cases.

## UI
Link to `docs/design/screens/<screen>.md`, or "none".

## Assets
Link to `docs/ASSETS.md` rows, or "none".

## Exploit audit
Findings from `/audit` and how each was fixed or why it is accepted.

## Checklist
- [ ] `./tools/verify.sh` passes
- [ ] Tests added for pure logic
- [ ] `/audit` run, findings resolved
- [ ] `/review` run, findings resolved
- [ ] Playtested (desktop + phone emulator)
- [ ] `DECISIONS.md` updated if needed
- [ ] One commit
