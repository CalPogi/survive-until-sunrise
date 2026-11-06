#!/usr/bin/env bash
# One-time machine setup. Needs Rokit installed first: https://github.com/rojo-rbx/rokit
# Versions are pinned in rokit.toml (commit it). Rokit asks you to trust each tool; answer it, never --force.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f rokit.toml ]; then
	rokit init
	rokit add rojo-rbx/rojo
	rokit add Kampfkarren/selene
	rokit add JohnnyMorganz/StyLua stylua
	rokit add lune-org/lune
	rokit add JohnnyMorganz/luau-lsp
fi
rokit install

# Roblox type definitions for luau-lsp analyze (untracked, refetch any time).
curl -fsSL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

# Studio plugin (needs Roblox Studio installed).
rojo plugin install

echo "Setup done. Next: ./tools/verify.sh"
