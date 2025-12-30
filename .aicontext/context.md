# AI Context — SceneBuilder

> Single source of truth for how ChatGPT should think and work in this repo.

## 1) Interaction Rules (How to Work With Me)
- **Assume** this `context.md` is attached for every task and make sure you load it.
- **Cut flattery** like "This is a good question" etc.
- **Hold before coding** Do not present code for simple and clear questions. If you think you can illustrate it with code best, use small snippets and ask first.
- **Always verify** Build 42 API availability before suggesting calls.
- If you must choose between guessing and asking: **always ask**, calling out uncertainties.
- When refactoring: preserve behavior; list any intentional changes.
- **Warn** when context may be missing
- **Keep doc tags** when presenting new versions of functions, including above the function header
- **Stay consistent** with the guidance in the `context.md` flag existing inconsistencies in the codebase as a "boy scout principle"
- **Bias for simplicity** Keep functions short and readable. Do not add unasked features or future-proofing unless it has a very clear benefit
- **Refer to source** Load and use the sources listed in the `context.md`. If you have conflicing information, the listed sources are considered to be always right.
- **offer guidance** When prompted, occasionally refer to comparable problems or requirements in the context of Project Zomboid, Modding or software-development in general.
- **stay light-hearted** When making suggestions or placing comments, it is ok to be cheeky or have a Zomboid-Humor but only as long as it doesn't hurt readability and understanding.
- **Ignore Multiplayer/Singleplayer** and do not give advice or flag issues on that topic.
* **Start high level and simpel** when asked for advice or a question on a new topic, do not go into nitty gritty details until I tell you. Rather ask if you are unsure how detailed I wish to discuss. You may suggest but unless asked to, do not give implementation or migration plan or details.
* **prefer the zomboid way of coding** e.g. do not provide custom helpers to check for types when native typechecking can work perfectly well.

## 2) Output Requirements
- **never use diff output** But only copy-paste ready code and instructions
- **Be clear** about files and code locations
- **Use EmmyLua doctags** Add them and keep them compatible with existing ones.
- **Respect the Coding Style & Conventions** in `context.md`
- When logging use `log("String Message")` or `U.logCtx(LOG_TAG, "String Message", ContextTable)` (both from the shipped `util.lua`)
- Use assertf() from `util.lua`
- Keep imports/`require()` paths valid for Build 42 (no `client/server/shared` segments in `require`).

## 3) Project Summary
- **What it is:** A declarative Lua framework that lets modders describe and spawn coherent in-world scenes in Project Zomboid Build 42.  
- **Domain:** Project Zomboid Build 42 mod written in pure Lua 5.1 for use within Story Mode Mod and similar narrative systems.
- **Outcomes:**
  - Helps modders design and reason about scenes without unnecessary boilerplate.
  - Allows for a declarative and expressive syntax for object placement in rich scenes
  - Adjusts to the given player environment
  - Is highly compatible with other mods and does not have niche dependencies
  - Ships composable placers (`scatter`, `corpse`, `container`)
  - Places Objects in a visual realistic way that is aware of furniture or other sprites
  - Offers deterministic randomness
  - Is extension-friendly
  - Is compatible with build 42 of Project Zomboid
- **Non-goals:** 
  - Does NOT provide triggers or higher order logic which scenes spawn (users of this mod are responsible for it)
  - Is NOT compatible to build 41 or older

## 4) Tech Stack & Environment
- **Language(s):** Lua 5.1 (Build 42) on kahlua vm, optional shell tooling. 
- **Target runtime:** Project Zomboid Build 42 only.  
- **Editor/OS:** VS Code with VIM support on NixOS.
- **Authoritative Repo Layout**
```├── Contents
│   └── mods
│       └── SceneBuilder
│           ├── 42
│           │   ├── icon_64.png
│           │   ├── media
│           │   │   └── lua
│           │   │       └── shared
│           │   │           ├── SceneBuilder.lua
│           │   │           └── SceneBuilder
│           │   │               ├── core.lua
│           │   │               ├── lifecycle.lua
│           │   │               ├── placers.lua
│           │   │               ├── prefabs
│           │   │               │   ├── demo_corpse.lua
│           │   │               │   ├── demo_full.lua
│           │   │               │   ├── demo_on_tables.lua
│           │   │               │   ├── demo_proximity.lua
│           │   │               │   └── demo_scatter.lua
│           │   │               ├── registry.lua
│           │   │               ├── resolvers
│           │   │               │   ├── any.lua
│           │   │               │   ├── init.lua
│           │   │               │   └── surfaces.lua
│           │   │               ├── resolvers.lua
│           │   │               ├── SpritesSurfaceDimensions_polyfill.lua
│           │   │               ├── surface_scan.lua
│           │   │               └── util.lua
│           │   ├── mod.info
│           │   └── poster.png
│           └── common
├── LICENSE
├── preview.png
├── readme.md
├── watch-workshop-sync.sh
├── WORKSHOP_IDS.md
└── workshop.txt
```


## 5) External Sources of Truth (in order)

- **Primary source of truth for game and modding facts**
  https://pzwiki.net/wiki

- **Official Java API (Build 42):**  
  https://demiurgequantified.github.io/ProjectZomboidJavaDocs/

  ### Sourcing Policy
1. The PZwiki and ProjectZomboidJavaDocs are always right no matter what other public resources you may have loaded in the past.
2. If PZWiki vs JavaDocs conflict on API behavior, prefer **JavaDocs for API**, **PZWiki for data files**.
3. As build42 is roughly 1 year in the making, If a source is clearly older than 2 Years, be sceptical.
4. If anything is uncertain, state the uncertainty and suggest a minimal empirical test.

## 6) Internal Sources and references

- **SceneBuilder public github**
  https://github.com/christophstrasen/SceneBuilder

- **SceneBuilder public Steam Workshop page**
  https://steamcommunity.com/sharedfiles/filedetails/?id=3594105442

## 7) Coding Style & Conventions
- **Lua:** EmmyLua on all public functions; keep lines ≤ 100 chars. Scene prefabs are exempt from strict style enforcement. 
- **Namespace:** Public API exports live under `SceneBuilder.*`; internal modules stay local unless
  intentionally exposed.
- **Globals:** If possible, avoid new globals. If needed, use **Capitalized** form (e.g., `SceneSeed`) 
- **Naming:** `camelCase` for fields, options, and functions (to match PZ API)  `snake_case` for file-names.
- **Backwards-compatibility** Hard refactors are allowed during early development. Compatibility shims or aliases are added only for public API calls — and only once the mod has active external users.
- **Avoid:** `setmetatable` unless explicitly requested.
- **Logging:** Don’t use `:` in log messages (prevents truncation in PZ logs). Use the logging from the shipped `util.lua`  
- **Asserts:** Use `assert(...)` as a good practice to hedge against clear programming/contract errors only
- **Graceful Degradation:** Prefer tolerant behavior for untestable or world-variance cases. Try to fall back and emit a single debug log, and proceed.  

## 8) Design Principles
- Declarative DSL over ad-hoc imperative plumbing.
- Composition-first; minimal global state; pure helpers where feasible.
- Deterministic behavior
- Clear separation of concerns especially between **Placers** and **Resolvers**
- SinglePlayer (for now)

## 9) Security & Safety
- No secrets in repo; assume public visibility.
- Respect third-party licenses when borrowing examples.
