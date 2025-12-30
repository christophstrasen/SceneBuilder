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
