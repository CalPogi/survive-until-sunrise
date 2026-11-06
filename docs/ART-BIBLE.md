# Art bible

Style target: **grounded stylized**. Real places and proportions, simplified into readable shapes, with textured surfaces and honest wear. Free tools only. Process rules are in `docs/DESIGN-PROCESS.md`.

Status: draft. Values marked "provisional" get replaced with colours and measurements taken from the Santiago City field photos.

## Pillars
1. **Specific, not generic.** Every building, sign and prop is recognisably Philippine and recognisably Cagayan Valley.
2. **Lived in.** Wear, repairs, laundry, wires and flood stains tell people's stories before any zombie appears.
3. **Readable first.** Silhouettes and colour separate walkable ground, cover, loot, danger and allies at a glance, on a phone screen.
4. **One world.** Everything shares one palette, one scale and one texel density.

## Shape language
- Simple volumes with believable proportions: boxy concrete houses, pitched GI roofs, flat concrete roofs with rebar, open-sided stores.
- Bevelled edges and slightly exaggerated details (window grilles, roof overhangs, signage) so forms read at distance.
- Hero landmarks (church, city hall, market, gas station, school) have unique silhouettes. Ordinary houses come from kits.
- No perfect symmetry. Offsets, add-ons and patched walls are normal.

## Scale
- 1 stud is about 0.28 to 0.3 m. Door about 7 studs high, ceiling about 9 to 10 studs, road lane about 11 studs wide (provisional, check against photos).
- Every asset is checked next to an avatar before approval.

## Palette (provisional)
| Role | Hex | Notes |
|---|---|---|
| Weathered concrete | #B8B2A6 | Most walls and roads |
| Whitewash | #E6E1D3 | Painted walls, faded |
| GI roof rust | #8C5A3C | Roofs, with a paler zinc variant #A9A7A0 |
| Faded teal paint | #5F9C94 | Local accent for houses and shops |
| Jeepney red | #C23B2E | Accents and signage |
| Jeepney yellow | #E2B93B | Accents, hazard marks |
| Jeepney blue | #2E5E9E | Accents |
| Deep foliage | #3F6B3A | Trees, hedges |
| Rice green | #8FB84E | Fields (seasonal) |
| Wet asphalt | #3A3D40 | Roads |
| Dirt road | #9A7B55 | Barangay roads |
| Humid haze | #A9C3C9 | Sky and distance fog |
| Infection base | #4B5B2E | Dark bark-green, the base of every infected (provisional) |
| Infection accents | per creature | Sunflower gold #E0A82E, rose crimson #8E1B24, spore violet #7B4A9E, thorn glow pink #D14B8C, heart amber #E8A03A, Bloommother pink #C97A8E (provisional, sampled by eye from the concept sheets). Used for danger only |
| Dried blood | #6E1F1A | Rare, never decorative |

Rule: a scene uses mostly the neutral rows, one or two local accents, and the infection colour only where danger is.

## Materials
- A small library of Roblox materials plus our own textures: concrete, painted concrete, GI sheet, wood, rust, asphalt, dirt, grass, mud.
- Wear comes from a grime ramp (dirt at the base, rust streaks under roof edges, sun fade on south faces), applied by rule, not by hand per building.
- No default plastic look. No glossy surfaces except wet ground, glass and fresh paint.

## Lighting and colour
- Time-of-day schedule with a warm, humid tropical morning, a hard midday, a golden late afternoon, and a dark blue-grey night with strong contrast between lit areas and shadow.
- Atmosphere and haze for depth. One colour grade preset per time of day, tuned in the real map.
- Weather states: clear, overcast, rain, typhoon. Weather changes light, haze and sound together.

## Typography (provisional, verify in Studio's font list)
- Display: Oswald (condensed, close to painted and stencilled signage).
- Hand-written accent for notes and maps: PermanentMarker or PatrickHand.
- Body and small text: Roboto or Nunito for legibility on phones.
- Two families at most on any screen. Local signage text is real Filipino and English wording drawn in code, not baked into textures.

## Characters and zombies
- Players use Roblox avatars. The infected are the plant-based roster in `docs/LORE-INFECTED.md`, with concept sheets in `docs/reference/infected/`. Each has its own silhouette and is readable at 40 m.
- Concept sheets are reference only. Models are rebuilt at our budgets, keeping each creature's silhouette and key features.
- Infected overgrow the Philippine setting: local buildings, jeepneys and houses wrapped in vines and blooms, so the world and the enemies read as one place.

## Do not
- Glossy gradients, glow outlines and default Roblox blue UI.
- Text baked into textures.
- Assets with no reference.
- Pure-black or pure-white surfaces.
- Mixing styles or texel densities in one scene.

## Open items
- Replace provisional hex values with colours sampled from field photos.
- Confirm fonts in Studio.
- Pick the 5 to 8 hero landmarks for tier 1 buildings once the survey is done.
