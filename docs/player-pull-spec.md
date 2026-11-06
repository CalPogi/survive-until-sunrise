# Survive Until Sunrise: Player Pull and Regional State

Goal: across a Luzon-sized world, players keep meeting each other and share goals.
Tuning metric: pairs of players within 100 m of each other per hour. Log it from day one.

## First-release pillars

| # | Pillar | Rule | Tunables |
|---|---|---|---|
| 1 | Hub per region | One fortified settlement per region: market, stash, respawn, safe zone. New players spawn only at active hubs. | `hub_chunk_id`, safe-zone radius |
| 2 | Supply runs | Hubs post requests (medicine, fuel, ammo) with a deadline. The best source is a dangerous building, so players group up. | request count, quantity, reward, deadline |
| 3 | Outbreak events | A timed horde or boss spawns at a named landmark and shows on the regional map for 20-30 min. | spawn interval, duration, density |
| 4 | Infection score | Each region has a 0-100 score. Clearing zombies and restoring power lowers it. It spreads along the region graph. Everyone sees it on the map. | spread rate, decay, loot and zombie modifiers by band |
| 5 | Friend and party join | One click to land in a friend's region and channel. Parties are routed to the same channel. | channel cap, party size |

## Pacing rules
- Activate a region's Level 1 content only when current regions are healthy
  (average channel fill above a threshold). Never on a calendar.
- Best loot lives near hubs, events and frontlines. Never in empty corners.
- Sparse regions get cheap content: wandering NPC survivors, abandoned camps, radio signals.

## Later (not in first release)
Convoys, faction control, guild bases, scheduled blackout nights, radio chat.

## Write rules (important for correctness)
- Regional counters are updated with **commutative deltas** applied in the database
  (`infection = clamp(infection + delta)`). Never overwrite with an absolute value.
  Several channels of one region can then contribute at once with no lease.
- Only the **spread tick** needs a single writer. One server holds a short lease
  on the `spread_tick` row, so the tick runs once per interval.
- Batch deltas on the server and flush every 15-30 s. Do not send one request per kill.
- Deltas carry an idempotency key (`channel_id:seq`) so a retry cannot double-apply.

## Schema (Postgres; the same shapes work as DataStore records)

```sql
create table regions (
  region_id         text primary key,            -- 'marilao'
  place_id          bigint,                      -- Roblox place for this region
  neighbors         jsonb not null default '[]', -- [{"region":"meycauayan","exit":"nlex_south"}]
  hub_chunk_id      text,
  activated         boolean not null default false,
  infection         real not null default 50 check (infection between 0 and 100),
  controlling_faction text,
  version           bigint not null default 0,
  updated_at        timestamptz not null default now()
);

create table region_events (
  event_id    uuid primary key default gen_random_uuid(),
  region_id   text not null references regions,
  kind        text not null,                    -- 'horde' | 'boss' | 'blackout'
  landmark_id text,
  starts_at   timestamptz not null,
  ends_at     timestamptz not null,
  progress    int not null default 0,
  status      text not null default 'scheduled' -- scheduled | active | done | expired
);
create index on region_events (region_id, status, ends_at);

create table supply_requests (
  request_id  uuid primary key default gen_random_uuid(),
  region_id   text not null references regions,
  item        text not null,
  qty_needed  int not null check (qty_needed > 0),
  qty_given   int not null default 0 check (qty_given >= 0),
  reward      jsonb not null,
  deadline    timestamptz not null,
  status      text not null default 'open'      -- open | filled | expired
);
create index on supply_requests (region_id, status, deadline);

create table applied_deltas (                   -- idempotency
  key text primary key,
  applied_at timestamptz not null default now()
);

create function apply_region_delta(p_region text, p_delta real, p_key text)
returns real language plpgsql as $$
declare v real;
begin
  insert into applied_deltas(key) values (p_key) on conflict do nothing;
  if not found then
    return (select infection from regions where region_id = p_region);
  end if;
  update regions
     set infection = greatest(0, least(100, infection + p_delta)),
         version = version + 1, updated_at = now()
   where region_id = p_region
   returning infection into v;
  return v;
end $$;

alter table regions enable row level security;          -- no policies: server role only
alter table region_events enable row level security;
alter table supply_requests enable row level security;
alter table applied_deltas enable row level security;
```

Supply fills use the same pattern: `update supply_requests set qty_given = least(qty_needed, qty_given + $n)`
inside one statement, so two channels cannot over-fill a request.

## Open decisions
- Start on DataStore (one record per region, `UpdateAsync` for deltas) or on Supabase from day one?
  The shapes above work for both. Choose when step 2 of the roadmap starts.
- Infection spread formula and band thresholds need playtest data. Do not tune them on paper.
