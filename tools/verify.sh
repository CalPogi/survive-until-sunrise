#!/usr/bin/env bash
# Runs every check. Each step runs even if an earlier one failed; exits non-zero if any failed.
set -uo pipefail
cd "$(dirname "$0")/.."

failed=()
step() {
	local name="$1"
	shift
	echo "== $name"
	if "$@"; then
		echo "-- $name: ok"
	else
		echo "-- $name: FAILED"
		failed+=("$name")
	fi
}

mkdir -p build
step "stylua" stylua --check src tests tools
step "selene" selene src tests tools
step "rojo build" rojo build default.project.json -o build/place.rbxl
step "rojo sourcemap" rojo sourcemap default.project.json -o sourcemap.json
step "luau-lsp analyze" luau-lsp analyze --platform=roblox --definitions=globalTypes.d.luau \
	--sourcemap=sourcemap.json --base-luaurc=.luaurc src
step "tests" lune run tests/run

echo
if [ ${#failed[@]} -gt 0 ]; then
	echo "VERIFY FAILED: ${failed[*]}"
	exit 1
fi
echo "VERIFY PASSED"
