# Setup (Windows, free tools only)

1. Install **Git** (includes Git Bash, which runs the `tools/*.sh` scripts).
2. Install **Roblox Studio** and **VS Code**.
3. Install **Rokit**: follow https://github.com/rojo-rbx/rokit (download the release for your OS, run `rokit self-install`, restart the terminal).
4. From the repo root in Git Bash: `./tools/setup.sh`
   - First run creates `rokit.toml` and asks you to trust each tool. Commit `rokit.toml`; that pins the versions.
   - Fetches `globalTypes.d.luau` (Roblox types for luau-lsp, untracked).
   - Installs the Rojo Studio plugin.
5. Open the folder in VS Code and install the recommended extensions (luau-lsp, StyLua, Selene).
6. `./tools/verify.sh` should print `VERIFY PASSED`.

## Playtesting
1. `rojo serve` in the repo root (port 34872).
2. In Studio: open a place, Plugins > Rojo > Connect.
3. Press Play. Five grey "Bot" ghosts should walk circles around the spawn, and the server prints a `[Ghost]` report every 30 s. Cross-server messaging doesn't run in Studio, so the bots loop back with a fake delay (`docs/specs/ghost-live.md`).

## Asset tools (one-time)
1. **Roblox Studio MCP:** in Studio, Assistant > ... > Manage MCP Servers > turn on **Enable Studio as MCP server**, with a place open. Claude Code loads `.mcp.json` only when the session starts in this repo folder (not a parent folder), and asks once to approve `Roblox_Studio` and `blender` (`claude mcp list` shows "Pending approval" until then). Working on several games? Register both servers once at user scope so every folder gets them:
   ```bash
   MSYS_NO_PATHCONV=1 claude mcp add --scope user Roblox_Studio -- cmd.exe /c 'cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat'
   MSYS_NO_PATHCONV=1 claude mcp add --scope user blender -e DISABLE_TELEMETRY=true -- uvx mcp-for-blender@2.2.6
   ```
   (`claude mcp add-json` rejects the Studio command, so use `add`.) Studio takes about 15-20 s to attach after the server starts; until then `list_roblox_studios` returns no studios, so retry. `execute_luau` needs `datamodel_type` (`Edit`, `Server` or `Client`).
2. **Blender MCP:** Blender 4.5 LTS (portable, `~/Tools/blender-4.5.15-windows-x64`) with the add-on **MCP for Blender** enabled (Edit > Preferences > Add-ons; installed as `%APPDATA%\Blender Foundation\Blender\4.5\scripts\addons\addon.py`). Open Blender before asking Claude for 3D work; the add-on auto-starts its server on `localhost:9876`. If `get_addon_status` says it can't connect, check `netstat -ano | grep :9876`, then press N in the 3D viewport, open the **MCP for Blender** tab and start the server, or restart Blender. Needs `uv` on PATH.
3. **ComfyUI:** `~/Tools/ComfyUI` pinned to tag `v0.7.0` (newer versions need a PyTorch that DirectML does not support; do not `git pull`), Python 3.12 venv, DirectML on the RX 6600 (device 1) with `models/checkpoints/sd_xl_base_1.0.safetensors`. Start with `./tools/comfy.sh`.
4. **Keys:** copy `.env.example` to `.env` and fill in the Freesound key and the Roblox Open Cloud key (assets read + write) plus your user id.
