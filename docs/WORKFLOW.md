# Workflow

One feature per session.

| Step | Who | Command | Output |
|---|---|---|---|
| 1. Spec | Claude chat, then Claude Code | `/spec <feature>` | `docs/specs/<feature>.md` from `_TEMPLATE.md` |
| 2. UI (if any) | Claude Design | `/ui <screen>` | Handoff in `docs/design/screens/<screen>.md` + exported image, rebuilt in Luau |
| 3. Assets (if any) | Claude Code (asset tools), human approves | `/asset <name>` | Asset uploaded, entry in `docs/ASSETS.md` |
| 4. Build | Claude Code | `/build <feature>` | Code + unit tests, `./tools/verify.sh` passing |
| 5. Audit | `exploit-auditor` agent | `/audit` | Findings fixed or accepted in the spec |
| 6. Review | `code-reviewer` agent | `/review` | Findings fixed |
| 7. Playtest | Claude via Studio MCP, then human | `/playtest` | Checklist ticked in the spec, bugs noted |
| 8. Finish | Claude Code | `/finish` | Verify passes, one commit |

Record any decision that changes how we work with `/decision`.

## Roles
| Tool | Owns |
|---|---|
| Claude chat (Project) | Specs, design decisions, balance, planning |
| Claude Design | UI screens + design tokens (reference only, never ships) |
| Claude Code | All implementation and all assets: Luau, tests, 2D/3D/audio via the asset tools, uploads |
| Human | Approves the look and feel, publishes, taste |
