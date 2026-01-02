# SceneBuilder — Logbook

## Day 1 — 2025-12-30

### Progress highlights
- Added `require("SceneBuilder")` convenience facade for downstream mods (exports `core`, `util`, `placers`, etc.).
- Fixed deterministic key-building bug where `nil` varargs could collapse and cause collisions.
- Hardened placement randomness against zero-span ranges and removed colon-containing log messages we touched.
- Improved surface scanning robustness: prefer `getSpriteName()` over `getTextureName()`, and replaced weak-table caching with a bounded cache (Kahlua-safe).
- Made SpriteDimensions polyfill merge resilient to late-loading ItemStories (don’t pin permanently when `SpriteDimensions` is absent).
- Updated demo prefabs to use the shipped logging utility instead of raw `print`.

### Difficulties / blockers
- none

### Learnings
- Build 42 log output truncates on `:` in messages; best practice is to avoid colon characters in log strings.
- Kahlua doesn’t support weak tables reliably, so weak-key caches must be bounded/managed explicitly.

### decisions
- Prefer “graceful degradation” over hard failures in placers when optional engine globals (e.g. corpse spawning helpers) aren’t available (keeps scenes partially spawning instead of crashing).
- Prefer sprite-name-based matching for surface identification to align with how other tooling (and mods like ItemStories) key sprite dimensions.

### Progress highlights (continued)
- Restored Build 42.13 compatibility for surface-aware placement by switching surface detection to engine primitives: `sq:has("IsTable")` + `IsoObject:getSurfaceOffsetNoTable()`.
- Simplified `tables_and_counters` to return `IsTable` squares directly (dropped SurfaceScan-based “scan and rank” for the resolver).
- Removed the temporary multi-path Surface property probing + diagnostic spam once `getSurfaceOffsetNoTable()` proved reliable.
- Updated unit tests to lock in the new contract (IsTable-only surfaces; Z offset derived from `getSurfaceOffsetNoTable()`).

### Difficulties / blockers (continued)
- Build 42.13 no longer exposes `PropertyContainer.Val(...)` to Lua, so the old `Val("Surface")`-based approach silently failed (0 hits) and could also crash when iterating unexpected object types on a square.

### Learnings (continued)
- Vanilla B42’s own placement logic strongly prefers `IsoObject:getSurfaceOffsetNoTable()` over sprite property string access for surface height.
- The `IsoGridSquare` `IsTable` flag is the cleanest filter for “table-like” placement targets (more robust than sprite-name heuristics).

### Major decisions (update)
- Accept only `IsTable` squares for SceneBuilder’s “tables_and_counters” strategy (explicitly not “any object with a surface”).
- Use `getSurfaceOffsetNoTable()` as the single source of truth for table surface height; keep SpriteDimensions only for X/Y safe-box selection and optional `overrideExactOffsetZ` overrides.

## Day 2 — 2026-01-01

### Progress highlights
- Added live zombie spawning via new `:zombies(...)` placer (`:count(n)`, `:outfit(name|nil)`, `:femaleChance(0..100)`), using engine `addZombiesInOutfit(...)`.
- Added resolver strategy `freeOrMidair` (based on `IsoGridSquare:isFreeOrMidair(...)`) to avoid spawning on solid/trees/furniture; prefers strict mode and degrades to non-strict if necessary.
- Added `demo_zombies` prefab and updated README docs to cover `freeOrMidair` and the new placer.
- Added unit coverage for the resolver and list-conversion behavior (engine return value is a Java list-like object, not a Lua table).

### Difficulties / blockers
- None; confirmed `femaleChance` is integer-percent semantics (e.g. `0.5` behaves like `0`) via in-game console probes.

### Decisions
- Keep `:where(...)` required for `:zombies(...)` (consistent with existing placers).
- Name the strategy `freeOrMidair` to match the engine predicate and set expectations (walkable-ish, stairs allowed).

## Day 3 — 2026-01-02

### Progress highlights
- Added resolver strategy `centroid`: computes the centroid of all room squares (works well for L-shaped rooms) and returns squares ordered center-out in concentric rings.
- Added resolver strategy `centroidFreeOrMidair`: same centroid ordering, but filters to walkable-ish squares (via `IsoGridSquare:isFreeOrMidair`), preferring strict mode and degrading to non-strict if necessary.
- Registered both resolvers in `SceneBuilder/resolvers/init.lua` and documented them in the built-in resolver table in `readme.md`.

### Learnings
- A “rotate around center” placement attempt can be modeled cleanly as a deterministic square ordering problem (resolver) rather than placer-level heuristics.
- The centroid computed from actual room squares is a better “room center” than bounding-box center for irregular rooms.

### Next steps
- Explore a “spawn near sprite” resolver family where authors can specify a sprite name/prefix (e.g. `table%`) as a target and SceneBuilder chooses squares near matching objects, still restricted to the same room.
