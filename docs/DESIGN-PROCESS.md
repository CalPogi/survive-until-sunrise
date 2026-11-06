# Design process

Goal: Survive Until Sunrise looks like one specific place made by people who were there, not like generic generated content. Everything here uses free tools only (see `docs/ASSETS.md`).

## What makes something look like AI slop
- Mixed styles: assets from different sources, scales and texel densities in one scene.
- Default looks: stock Roblox plastic materials, default fonts, glossy blue rounded buttons, gradient glows.
- Generic content with no reference: "a zombie", "a house", "a sign".
- Gibberish text baked into textures (signs, shirts, packaging).
- Repeated identical tiles and props, perfect symmetry, no wear.
- Wrong scale (doors too low, rooms too big) and flat, even lighting.

## Rules
1. **Reference first.** Every asset or screen starts from a reference: your own field photos of Santiago City, or a written description of a real thing. No reference, no asset. Google Maps and Earth are viewed only, never copied (decision #22).
2. **One art bible.** A single page decides the style, palette, shape language, lighting and fonts. All assets are checked against it. Nothing ships that breaks it.
3. **Hand pass on everything.** Generated output (Cube 3D, ComfyUI, Studio generators) is a starting point only. It is normalized to our scale, palette and budgets, and edited before it goes in.
4. **Real text is code, not texture.** Signs, shop names and UI text are drawn with real fonts in Luau (SurfaceGui, TextLabel), in real Filipino and English wording.
5. **Specific over generic.** Local details carry the look: GI sheet roofs, jeepney paint, sari-sari store grilles, tarpaulin banners, tangled wires, monobloc chairs, flood stains, rice fields and Sierra Madre skylines.
6. **Variation by rule.** Colour, wear, signage and props vary per building from a seeded random, so no two houses are twins and results are repeatable.
7. **Lighting and colour grade last, but always.** Atmosphere, time of day, weather and one colour grade do more than any single asset. They are tuned in the real map.

## Art bible (to fill in before any art)
| Item | Decision |
|---|---|
| Style target | Grounded stylized (decided). Details in `docs/ART-BIBLE.md` |
| Palette | 6 to 8 base colours from field photos, plus a wear and grime ramp |
| Shape language | Simple readable forms, realistic proportions, strong silhouettes |
| Scale | 1 stud is about 0.28 to 0.3 m. Door about 7 studs high. Check every asset against an avatar |
| Texture density | One shared texel density. Textures at most 1024 px unless justified |
| Lighting | Time-of-day schedule, humid tropical light, Atmosphere and colour grade presets |
| Fonts | Two only (display and body), from Roblox's built-in font list, chosen to feel like local signage |
| Do not | Glossy gradients, default Roblox blue UI, baked text, unreferenced assets |

## Asset process
Brief, reference, make, normalize, in-game test, approve, upload, log.

| Step | What happens | Who |
|---|---|---|
| Brief | One line: what it is, where it appears, budget | Claude |
| Reference | Photo or description attached to the brief | You (photos), Claude |
| Make | Blender (kit pieces, hero props), Studio generators (quick bases), ComfyUI (painted art), Freesound (audio) | Claude |
| Normalize | Scale vs avatar, tris within budget, palette-matched textures, naming, pivot points | Claude |
| In-game test | Place in the real map under real lighting, at distance and close, desktop and phone | Claude (screenshots) |
| Approve | Side by side with the reference and with neighbouring assets | You |
| Upload and log | `tools/upload`, then a row in `docs/ASSETS.md` | Claude |

Checks every asset passes: silhouette reads at 50 m, scale vs avatar, shares the palette, within budget, no baked text, no visible tiling at normal distance, looks right at night.

## Buildings and terrain
- **Kit-based:** wall, roof, door, window and sign modules in Blender, assembled by the generator from the footprint, height and house type.
- **Hand-built:** hub and landmarks from your photos (accuracy tier 1).
- **Terrain:** heightmap plus land-cover colour map, then hand-painted material passes around the hub and roads.
- **Accuracy check:** 50 sampled buildings against field data before each new region.

## UI process
Mockup, tokens, build, compare, polish, approve.
1. **Mockup** in Claude Design from a one-line brief and the art bible. Output is reference only.
2. **Tokens** (colour, type, spacing, radius, motion) go into `docs/design/TOKENS.md`, then into one shared Luau module. Nothing is hard-coded in screens.
3. **Build** with `/ui <screen>` in code: scale-based layout, 9-slice frames, real fonts. Follow the `roblox-ui` and `game-ui-ux` skills.
4. **Compare** to the mockup at desktop and phone sizes with Studio screenshots, plus touch and gamepad navigation.
5. **Polish** motion with TweenService from the motion tokens. Restraint over juice.
6. **Approve** by you before it counts as done.

UI direction: a survival HUD that feels written and stencilled, not corporate. Minimal always-on HUD, diegetic cues where possible (a worn map, handwritten notes, radio chatter), painted-sign typography, textured panels instead of gradients.

## Audio
Freesound CC0 sounds plus Creator Store audio (free only), layered for variation. Local ambience (roosters, tricycles, radio, rain, insects) carries the place. Use buses and ducking (`audio-design` skill). Quota note: 100 audio uploads per month.

## Characters, animation and VFX
- Zombies: a small set of silhouettes and skins built from local clothing, with wear and variation.
- Animations: Blender rig and keyframes, imported with the Animation Editor. One shared rig and style.
- VFX: Luau emitters with a limited texture set that matches the palette.

## Review gates
- **Look review** at the end of each phase of `docs/DEV-PLAN.md`: screenshots of the real map against the references, one page, you decide go or fix.
- **Cut list:** anything that fails the checks is removed, not patched.
- **Scale test, squint test, silhouette test** before approval.

## Open decisions
- Display and body fonts (proposed in the art bible, to verify in Studio).
- Who makes the first reference photos and when.
