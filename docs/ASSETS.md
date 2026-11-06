# Assets

Claude Code makes and uploads assets itself with free tools. The human approves the look.

Budgets (our rules, not platform limits): props <= 2,000 triangles, hero assets <= 10,000, textures <= 1024px unless justified. No SVG uploads; rasterize to PNG.

## How each type is made

| Type | Tool | How Claude does it | Into the game |
|---|---|---|---|
| UI screens | Luau code | Rebuilds the Claude Design handoff (`/ui`) | Code, nothing to upload |
| UI icons, simple vector art | SVG drawn by Claude, rasterized to PNG | Writes SVG, converts it | Studio MCP `upload_image` |
| 2D painted art | ComfyUI + SDXL (local, `tools/image.luau`; about 5-6 min per 1024px image on the RX 6600) | `./tools/comfy.sh`, then `lune run tools/image "<prompt>" assets/<file>.png` | Studio MCP `upload_image` |
| 3D, quick | Studio MCP `generate_mesh`, `generate_procedural_model` | Prompt inside the open place | Already in Studio |
| 3D, precise / low-poly | Blender MCP (Blender 4.5 LTS open, addon running) | Builds the mesh with Python, checks triangle count, exports FBX | `lune run tools/upload <file>.fbx "<name>"` or the Studio 3D Importer |
| Materials / textures | Studio MCP `generate_material` | Prompt inside the open place | Already in Studio |
| Free library assets | Studio MCP `search_asset` / `insert_asset` | Searches the Creator Store, free only | Inserted directly |
| Sound effects | Freesound CC0 (`tools/sound.luau`) or Creator Store audio | `lune run tools/sound search "<words>"`, then `get <id> assets/<file>.mp3` | `lune run tools/upload <file>.mp3 "<name>"` |
| UI motion | TweenService in code | Follows the screen handoff's motion spec | Code |
| Character animation | Blender MCP (rig + keyframes, FBX export) | Unverified end to end; may need one click in Studio to publish | Studio Animation Editor import |
| VFX (particles, trails, beams) | Luau code + generated or library textures | Builds emitters in code, textures via image/upload | Code + uploaded texture |

Generated source files live in `assets/` (git-tracked if small; large binaries stay out of git).

## Keys and limits
- Keys go in `.env` (copy `.env.example`, never commit it): `FREESOUND_API_KEY`, `ROBLOX_API_KEY` (assets read + write), `ROBLOX_USER_ID`.
- Roblox caps uploads: this account has 100 audio uploads/month (checked 2026-11-01). Check `GET https://apis.roblox.com/cloud/v2/users/<id>/asset-quotas` before bulk uploads.
- Only CC0 sounds are fetched, so no attribution is needed. Creator Store assets: free only, and record the asset id below.

## Log

| Name | Type | Source | Tris / Size | Asset id | Used by | Status |
|---|---|---|---|---|---|---|
| Coin Snap | Audio | Freesound 741878 (CC0) | 0.2s / 9.5 KB | 117372389692448 | Workflow test | Reviewing (uploaded 2026-11-01) |
