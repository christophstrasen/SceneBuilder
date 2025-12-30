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
