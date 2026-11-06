# Game Design Document: Survive Until Sunrise

## Pitch
A persistent survival MMO against a plant-based infection. It starts in a real, accurately mapped Santiago City, Isabela and continues into an endless generated world that every player shares.

## Core loop
- 30 seconds: move, scavenge, fight the infected.
- 5 minutes: clear a building, complete a supply run, or reach an outbreak event.
- Session: push a region's infection score down, upgrade gear and base, help hold a frontline.

## Multiplayer model
- A server loads whichever area it is assigned (own local origin), and one Place can host any area. Several servers can run the same area (about 40-80 players each), and players on different servers see each other as ghost avatars, so the world feels like one server.
- Servers share persistent state, chat, player list, events and presence, never shared physics. One owner server per area cell runs zombies, loot and vehicles; others mirror them. Hits across servers use lag-compensated claims.
- Interiors stay inside the area server. Area boundaries are handoffs at natural boundaries such as rivers, ridges and road checkpoints.
- Infection layer: per-area infection, events and supply requests. See `docs/player-pull-spec.md`.

## World and data
- Real start: Santiago City, Isabela in UTM 51N, about 0.28-0.3 m per stud, one constant everywhere.
- Elevation (start area): NAMRIA IfSAR or LiDAR where available, Copernicus GLO-30 fallback.
- Buildings and roads (start area): Overture Maps and OpenStreetMap. Interiors are generated from templates.
- Beyond the start the world is generated without limit from a seed (decision #29). Every server produces the same world, and only player changes are stored, per area. Santiago City is the pipeline test bed, and a generated dense town and mountain area are the stress tests.

## Progression and economy
Undecided. Player data in DataStore (ProfileStore). Regional prices follow supply deliveries.

## Monetization (Roblox-native only)
Undecided.

## Target platforms
Desktop, phone, tablet, console.

## Features
Link each one to its spec in `docs/specs/`.

## Enemies
A plant-based infection turns people, plants and trees into dangerous creatures. Roster, lore and weaknesses are in docs/LORE-INFECTED.md. Many infected are dormant by day and wake at night.
