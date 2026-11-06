# Game Design Document: Survive Until Sunrise

## Pitch
A persistent survival MMO against a plant-based infection. It starts in a real, accurately mapped Santiago City, Isabela and continues into a large generated world that every player shares.

## Core loop
- 30 seconds: move, scavenge, fight the infected.
- 5 minutes: clear a building, complete a supply run, or reach an outbreak event.
- Session: push a region's infection score down, upgrade gear and base, help hold a frontline.

## Multiplayer model
- One Place, one continuous map (decision #35). A player joins a server and stays on it for the whole session. There are no separate worlds, loading screens or server switches.
- Servers fill first: a new one opens only when the others are full (working target about 50 players each, until a load test sets the number). Each server spawns its new players around its own home region.
- Players on other servers appear as ghosts, which show presence and smooth movement. Close fights happen between players on the same server, so parties and groups always join together.
- Servers share saved records (bases, loot, destroyed things, infection levels), chat, player list and events, never physics. Bloommothers and Hollow Oaks have one owner server, so everyone fights the same one. Common infected run on each server separately, spawned at the same seeded spots.
- Infection layer: regional infection, events and supply requests. See `docs/player-pull-spec.md`.

## World and data
- Real start: Santiago City, Isabela in UTM 51N, about 0.28-0.3 m per stud, one constant everywhere.
- Elevation (start area): NAMRIA IfSAR or LiDAR where available, Copernicus GLO-30 fallback.
- Buildings and roads (start area): Overture Maps and OpenStreetMap. Interiors are generated from templates.
- Beyond the start the world is generated from a seed. Every server produces the same world, and only player changes are stored, per cell. Santiago City is the pipeline test bed, and a generated dense town and mountain area are the stress tests.
- The world is big, not endless (decision #35): about 10 by 10 km at first, growing until testing shows the limit (roughly 25 to 50 km across, to be measured). Dense infection forms the edge.

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
