#!/usr/bin/env bash
# Starts the local ComfyUI server on http://127.0.0.1:8188 (AMD GPU via DirectML).
# COMFYUI_DIR defaults to ~/Tools/ComfyUI. Leave it running while generating images.
# COMFYUI_GPU is the DirectML device index (1 = RX 6600 on this PC; 0 is the CPU's built-in graphics).
set -euo pipefail
DIR="${COMFYUI_DIR:-$HOME/Tools/ComfyUI}"
cd "$DIR"
exec .venv/Scripts/python.exe main.py --directml "${COMFYUI_GPU:-1}" --lowvram --listen 127.0.0.1 --port 8188
