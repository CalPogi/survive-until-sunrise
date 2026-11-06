---
description: Playtest the current feature in Studio
---

Playtest the current spec yourself through the Roblox Studio MCP: make sure `rojo serve` is running and synced, start play (`start_stop_play`), drive the character and input (`character_navigation`, `user_keyboard_input`, `user_mouse_input`), read `get_console_output`, and take `screen_capture`s of anything visual. Try the exploit cases too (spam a remote, wrong types, NaN, huge numbers) with `execute_luau` on the client. Log what passed and what broke in the spec and fix the bugs. Then give me a short checklist of the feel and look things only a human can judge (including phone-emulator checks if there is UI).
