# The infected: roster and lore

Source of truth for the game's enemies. A mysterious plant-based infection transforms humans, plants and trees into dangerous creatures. Visual direction: dark fantasy horror in stylized 3D. Concept sheets are in `docs/reference/infected/` and are reference only. In-game models are rebuilt at Roblox budgets (see `docs/ASSETS.md`).

Do not redesign these creatures without an explicit request. Design principles from the owner:
1. Every infected has a unique silhouette, anatomy, movement style and behaviour.
2. Not everything is humanoid. Some look like plants, trees or other organic creatures.
3. Keep the dark, organic, plant-infected identity throughout.
4. Each enemy adds a different challenge, readable from its look alone.
5. The day and night cycle is a core mechanic: many infected hide or go dormant by day and wake at night.
6. Solo developer: favour achievable mechanics and systems.
7. No extra open-world features, complex animation or many variants before the core game works.
8. Keep monetization, performance, replayability and future content updates in mind.

## 1. Heliotrope (Standard Infected)
Basic enemy / patrol. Threat: low to medium. Concept sheet: `01-heliotrope.webp` (variants: Standard, Tattered Suit, Gardener, Corpse Bloom, Construction, Nightshade).
A humanoid infected by a sunflower parasite. Its head is a huge sunflower bloom about twice shoulder width, with a dark centre showing a hollow smiling face and empty eye sockets. Green bark-like skin, human limbs, thick vines, broad leaves.
- **Day:** roots in sunlight, folds its limbs against its stalk and passes as a decorative flower.
- **Night:** unfolds and hunts nearby survivors. The flower centre glows faintly.
- **Traits:** balanced health and speed, detects nearby survivors, camouflages among gardens and vegetation, buds grow on shoulders and arms.

## 2. Thorn-Weaver (Tank Infected)
Tank / area denial. Threat: high. Sheet: `02-thorn-weaver.webp`.
Massive armoured humanoid like a walking rose bush: woody vines, bark armour, huge crimson blooms, razor thorns. A partly open rose surrounds a skull-like face. Long thorned vines extend from the arms like whips.
- **Day:** roots into the ground as an immovable overgrown rose bush.
- **Night:** slowly uproots and attacks.
- **Traits:** extremely high defence and health, slow, long reach, very low sound sensitivity, can block pathways and protect nearby infected.
- **Attacks:** Thorn Lash, Root Slam, Vine Grab.
- **Weakness:** fire burns its woody armour and exposes vulnerable tissue. Explosives also damage the armour.

## 3. Sporecap (Fungal Infected)
Ranged / area control. Threat: medium to high. Sheet: `03-sporecap-creeper.webp` (variants: Standard, Bloated, Fungal Rot, Nightshade, Toxic Leak, Dry Husk).
Bloated fungal humanoid with an oversized layered mushroom cap, swollen purple sacs and glowing spore pockets. Bulky and asymmetrical, clearly fungal and not flower-headed.
- **Behaviour:** prefers dark, damp places, moves slowly, stays behind other infected, releases toxic spores when threatened, contaminates areas.
- **Traits:** medium sound sensitivity, slow, ranged attacks, lingering toxic zones.
- **Attacks:** Spore Burst, Spore Puke.

## 4. Creeper (Wall-Dweller Infected)
Ambush / flanker / stalker. Threat: medium. Sheet: `03-sporecap-creeper.webp` (variants: Ivy Stalk, Stone Moss, Blood Vine, Bark Skin, Shadow Leaf, Thorn Hide).
Thin, elongated, unnaturally flexible, with very long limbs, hooked fingers and vegetation on its body. Its head is hidden under a narrow bark-like leaf mask. Must not share Sporecap's mushroom look or face.
- **Day:** motionless on walls, ceilings and dark corners, blending into vines.
- **Night:** crawls fast over vertical surfaces and ceilings, then drops on isolated survivors.
- **Traits:** extremely fast climbing, clings to walls and ceilings, high sound sensitivity, hard to spot when still, attacks from unexpected angles.
- **Attacks:** Ceiling Drop, Pounce.

## 5. Bramble Stalker (Rapid Infected)
Hit and run / ambush. Threat: medium. Sheet: `04-bramble-stalker.webp` (variants: Rose Thicket, White Briar, Black Bramble, Deadwood, Blood Rose).
Lean, feral predator of tangled brambles, twisted branches and thorny vines. Its head sits in a crown of pointed branches with narrow glowing eyes. Hunched, predatory silhouette, unlike the bulky Thorn-Weaver.
- **Behaviour:** hides in bushes, dead vegetation and overgrown structures, stays still until prey approaches, bursts forward at extreme speed, uses walls and obstacles to close distance.
- **Traits:** extremely fast, high sound sensitivity, lower durability than Thorn-Weaver, thorns cause bleeding.
- **Attacks:** Rush, Leap, Slash, Entangle.
- **Hunting cycle (night):** stalk, spot target, charge, tackle, tear and bleed, disengage.

## 6. Hollow Oak (Ancient Tree Infected)
Mini-boss / area controller. Threat: very high. Sheet: `05-hollow-oak.webp`.
An ancient oak hollowed out and puppeteered by the infection. Enormous humanoid silhouette of thick roots, broken bark, twisted branches and moss. A massive hollow in the chest and trunk holds a glowing amber heart.
- **Day:** looks like a dead hollow tree and stays completely still.
- **Night:** the heart glows, the oak rises, roots spread through the terrain.
- **Traits:** extremely high health, slow heavy movement, reshapes parts of the battlefield, leaves damaging root trails, blocks escape routes, low sound sensitivity, passive aura that raises nearby infected armour and aggression.
- **Attacks:** Root Pillar, Boulder Smash, Root Slam. Attack cycle: harvest, uproot, swing, slam.
- **Weakness:** the glowing heart inside the hollow trunk.

## 7. Bloommother (Matriarch of the Infected)
Main boss / spawner / support. Threat: extreme. Sheet: `06-bloommother.webp` (variants: Petalfade, Mirebloom, Rootbound, Nightbloom, Fungal Bloom, Witherbloom).
A colossal rooted organism that anchors the infection. A huge pale pink blossom with layered petals, pollen sacs and dangling tendrils sits above a mass of twisted roots and a tree-like trunk. A glowing pink heart is protected inside the blossom.
- **Day:** dormant and deeply rooted underground.
- **Night:** awakens, releases pollen, produces lesser infected through underground root pods.
- **Lifecycle:** dormant, emerge, bloom, maturity. Left undisturbed she blooms and spawns endlessly until her heart is destroyed.
- **Traits:** extremely high health, cannot move freely because of her roots, spawns infected, supports and strengthens nearby infected, spreads infection through an area, low sound sensitivity.
- **Attacks:** Pollen Cloud, Root Birth, Nourish.
- **Weakness:** the heart inside the central blossom.

## Implementation notes (for the solo build)
- **Build order:** Heliotrope with day and night behaviour first, then one ambush type (Bramble Stalker), then Thorn-Weaver, Sporecap, Hollow Oak, Bloommother. Creeper last, because wall and ceiling movement is the most complex.
- **Dormant by day** means static entities. They are cheap to simulate and to mirror across servers, and their positions can come from world generation.
- **Shared base AI** with small behaviour modules (dormant, wake, hunt, special attack) instead of one script per creature.
- **Simplify Creeper:** ceiling-drop and pounce from placed anchor points before free wall-crawling.
