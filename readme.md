# SceneBuilder

_A scene composition framework for Project Zomboid (Build 42), Single Player_

---

[Steam Workshop → SceneBuilder [b42]](https://steamcommunity.com/sharedfiles/filedetails/?id=3594105442)

> Do **not** copy this repo into your mod but use it as a required dependency instead.

---

SceneBuilder lets modders **spawn in-world scenes** in a **declarative** fashion — corpses, containers, clutter, blood, and more — using a Lua DSL.  
Scenes are conceptually similar to **vanilla randomized stories** (e.g. from `RBBasic`) or **ItemStories** ([Steam Workshop → ItemStories B42](https://steamcommunity.com/sharedfiles/filedetails/?id=3569303590)).

Unlike those, SceneBuilder scenes are **not automatically distributed** into the world of Project Zomboid but are **meant to be used by modders** for any purpose.

This framework is low-level in the sense that it does not provide opinions on what should spawn in which environments, rooms types etc.

The shipped DSL can currently be extended with custom resolvers and spawn hooks.

```lua
local Scene = require("SceneBuilder/core")

Scene:begin(roomDef, { tag = "demo_lab" })
  :deterministic(true)
  :anchors(function(a)
    a:name("AnywhereInRoom")
     :where("any")
    a:name("deskLike")
     :where("tables_and_counters")
  end)
  :corpse(function(c)
    c:outfit("Agent")
     :onBody("Bag_ToolBag", "Screwdriver")
     :dropNear("RemoteCraftedV1", "Speaker")
     :blood({ bruising = 4, floor_splats = 20 })
     :where("any", { anchor = "deskLike", anchor_proximity = 2 })
  end)
  :container("Bag_Schoolbag_Travel", function(b)
    b:addTo("MoneyBundle", "Whiskey")
     :where("tables_and_counters", { anchor = "AnywhereInRoom" })
  end)
  :scatter(function(s)
    s:items("Notepad", "Pencil")
     :maxPlacementSquares(3)
     :where("any", { anchor = "AnywhereInRoom" })
  end)
  :spawn()
```

---

## Known Issues & Limitations

* Build 42 only.
* Unfit for Multiplayer.
* Currently only works indoors with a RoomDef given.
* Z-height for placed items may not be visually correct on a number of tiles. For improved accuracy and visual realism, use the **ItemStories B42** mod, which, combined with SceneBuilder’s included SpritesSurfaceDimensions Polyfill, provides good-enough results.

---

## Core Concepts

| Term         | Meaning                                                                               |
| ------------ | ------------------------------------------------------------------------------------- |
| **Scene**    | A one-shot composition combining multiple placers; committed via `:spawn()`.          |
| **Placer**   | Defines *what* to spawn (`corpse`, `container`, or `scatter`) and knows how to do it. |
| **Resolver** | Defines *where* to spawn (`"any"`, `"tables_and_counters"`, …).                       |
| **Anchor**   | A reusable reference point resolved once and used by later placers.                   |

---

## Usage and Lifecycle

SceneBuilder internally tracks which *placer* is currently active and when its
definition is complete.

### 1. Building a Scene

- A new scene begins with `Scene:begin(roomDef, opts)`.
- Each call to a placer (e.g. `:corpse`, `:container`, `:scatter`) activates that
  placer’s builder state until another placer begins or the scene is spawned.

### 2. Working within a Placer

- While a placer is active, you can chain setup calls (`:outfit`, `:items`, `:blood`, …).
- Every placer **must** define a valid `:where` before it can spawn.
- Some placers may require specific setup (e.g. `:items` for `:scatter`).

### 3. Committing and continuing

- Starting a new placer implicitly commits the previous one (but doesn’t spawn it yet).
- You can interrupt scene construction at any time and continue later with the
  same `Scene` object. Just make sure the previous placer has been completed
  with `:where(...)`.

### 4. Spawning

- Use `:spawnNow()` to immediately spawn all placers defined so far.
- Use `:spawn()` at the end of your builder chain to finalize and spawn everything.

> **Tip:** Think of each placer as a “sub-scene.” It becomes part of the active
>   scene once committed, and all are spawned together when `:spawn()` is called.

--- 

## Design choices

### Determinism

Scenes are deterministic by default — same inputs yield the same layout, item selection etc.  
Setting `:deterministic(false)` disables this.    

### Bias to Spawn

> SceneBuilder’s resolvers, placers, and fallbacks are deliberately tuned toward _making placements happen whenever possible._
> The default behavior is to degrade gracefully — relaxing distance limits or falling back to simpler strategies — rather than fail outright.
> Authors who want stricter behavior can override this by registering custom resolvers, setting `fallback = nil` or `proximity_fallback = "fail"` in their placer specs.

---

## Resolvers (where things go)

These are used by placers and anchors to restrict which "pool" of squares they should consider. Whether a placer or anchor works on the entire pool or picks a subset of squares depends on implementation details and sometimes settings. E.g. the "Scatter" placer tries to distribute among the return squares.

### Built-in Resolvers

| Resolver name         | Description                                          |
| --------------------- | ---------------------------------------------------- |
| `any`                 | Free squares inside the room, including surfaces.    |
| `tables_and_counters` | Valid surface squares with table or counter sprites. |

Fallbacks:  

```lua
:where({
  strategy = "tables_and_counters",
  retries  = 4,
  fallback = { "any" }
})
```

If the primary resolver fails, SceneBuilder retries with each fallback in order. 

### Custom Resolvers

Resolvers are designed to be **extensible** — you can define and register your own to determine *which squares* qualify for placing under a given strategy name.

To explore existing examples, review the shipped resolvers in the mod’s `resolvers/` directory.

To add your own resolver, register it from anywhere:

```lua
local Resolvers = require("SceneBuilder/resolvers")

Resolvers.register("my_custom_strategy", function(roomDef, place, state)
  -- Return a list of IsoGridSquares that match your conditions.
  -- For example: all tiles tagged as medical.
  return matchingSquares
end)
```

Once registered, your custom resolver can be used in `:where` or `:anchor` like so:

```lua
:container("Bag_Schoolbag_Travel", function(b)
  b:addTo("Disinfectant", "Bandage")
   :where("my_custom_strategy")
end)
```

> Strategies are global so consider namespacing and watch the log for name conflicts..

---

## Placers (what spawns)

All placers begin with their specific call (current variants `:corpse`, `:container`, `:scatter`).

```lua
:corpse(function(c)
```

They share the same call to a *resolver* under the friendly alias `:where`  which determines the squares that may qualify for the current placer block.

```lua
:where(strategyOrSpec, [opts])
```

- **`strategyOrSpec`**: either a string resolver name (`"any"`, `"tables_and_counters"`, etc.)  
  or a full table spec (`{ strategy="any", retries=4, fallback={...} }`).  
- **`opts`** (optional): may include `anchor`, `anchor_proximity`, and `proximity_fallback`.  

> Resolved items and containers automatically attempt to **drop at the correct surface Z-height** and also adjust to a plausible x,y within the square using the *SpritesSurfaceDimensions* polyfill.

---

### 1) Corpse Placer

A single corpse in random orientation.

```lua
:corpse(function(c)
  c:outfit("Agent")
   :onBody("Bag_ToolBag", "Screwdriver")
   :dropNear("RemoteCraftedV1", "Speaker")
   :blood({ bruising = 4, floor_splats = 20 })
   :where("any", { anchor = "deskLike", anchor_proximity = 2 })
end)
```

**API**  

- `:outfit(name)` – Optional (defaults to "Survivor").
- `:onBody(itemType, ...)` – Optional. Equip extra items on the corpse. Keep in mind "outfit" adds random vanilla items associated with it already. Accepts `"ItemType"` or `{ "ItemType", count }`.
- `:dropNear(itemType, ...)` – Optional. drop items on the floor nearby (currently same square as the body). Accepts `"ItemType"` or `{ "ItemType", count }`.
- `:blood(opts)` – Optional. add blood effects.  
- `:where(strategyOrSpec, [opts])` – **Mandatory**. Choose resolver, anchor, proximity, fallbacks etc.

---

### 2) Container Placer

A single item that must be of type container. 

> Take this — it’s dangerous to go alone.

```lua
:container("Bag_Schoolbag_Travel", function(b)
  b:addTo("MoneyBundle", "Whiskey")
   :where("tables_and_counters", { anchor = "AnywhereInRoom" })
end)
```

**API**  

- `:addTo(itemType, ...)` – Optional. Accepts `"ItemType"` or `{ "ItemType", count }`
- `:where(strategyOrSpec, [opts])` – **Mandatory**. See shared description above.  

---

### 3) Scatter Placer

Drops multiple world inventory items.

```lua
:scatter(function(s)
  s:items(
      { "ElectronicsScrap", 3 },
      { "AluminumFragments", 2 },
      "Notepad",
      "Pencil"
    )
   :maxItemNum(4)
   :maxPlacementSquares(10)
   :where("any", { anchor = "AnywhereInRoom" })
end)
```

**API**  

- `:items(...list)` – **Mandatory**. List of unique items to spawn. Accepts `"ItemType"` or `{ "ItemType", count }`. May include same entries multiple times.
- `:maxItemNum(n)` – Optional. Limit unique entries spawned. Entries in the item-list are treated as "unique" even if they appear multiple times which can be used as a lazy-mans "weighted distribution"
- `:maxPlacementSquares(n)` – Optional. Limit the number of squares eligible for spawning.
- `:where(strategyOrSpec, [opts])` – **Mandatory**. See shared description above.  

> Setting maxItemNum to a value smaller than the number of unique items increases the observed variety.

---

## Anchors

Anchors are named **spatial reference points** that can be resolved once and reused across multiple placers.  
They let scene elements line up spatially — e.g., a corpse *near* a desk, a bag *on* that desk, and notes *around* it.

```lua
:anchors(function(a)
  a:name("deskLike")
   :where("tables_and_counters")
end)

:corpse(function(c)
  c:outfit("Agent")
   :where("any", { anchor = "deskLike", anchor_proximity = 2 })
end)
```

### How Proximity Works

For each placer, SceneBuilder first gathers **all candidate squares** that match the `strategy` passed to `:where` (e.g., all desk or counter surfaces for `"tables_and_counters"`).
If `anchor` and `anchor_proximity` are set, it then keeps only candidates within the given radius ([Chebyshev/Chessboard distance]([Chebyshev distance - Wikipedia](https://en.wikipedia.org/wiki/Chebyshev_distance))) of the anchor’s square.

If **none** survive the proximity filter, a **proximity fallback** (scoped to the current `:where` ) decides what to do.

### Proximity Fallback (per Placer Call)

Configure via `proximity_fallback` in the same `:where` spec:

| Strategy                         | What it does                                                                  | Effect                                                                                 |
| -------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `widen-proximity`                | Deterministically **expand radius** from `r` to `r+1, r+2, …, r+6` (hard cap) | Keeps the **same strategy**; tries bigger radii step-by-step until a candidate exists. |
| `ignore-proximity-keep-strategy` | **Remove the radius constraint** once; keep the same resolver strategy        | Still uses e.g. `"tables_and_counters"`, just without the proximity limit.             |
| `fail`                           | Do **not** relax conditions                                                   | The **current placer** is skipped if no candidates are within proximity.               |

> Planned but missing: **`ignore-strategy-keep-proximity`** and **`ignore-proximity-and-strategy`** (equivalent to `any`”).

**Examples**

```lua
:container("Bag_Schoolbag_Travel", function(b)
  b:addTo("MoneyBundle")
   :where({
     strategy           = "tables_and_counters",
     anchor             = "deskLike",
     anchor_proximity   = 2,
     proximity_fallback = "widen-proximity",
   })
end)
```

**Key points**

- Proximity fallback is a **per placer setting**; it doesn’t affect the anchor or other placers.  
- It runs **after** any resolver chain, including after potential resolver fallback (`fallback = { ... }`) has yielded a pool of squares to choose from.
- Two different fallbacks, for two different use cases!

---

## Hook Functions (`preSpawn` / `postSpawn`)

Hook functions let you execute custom logic immediately before or after a placer spawns its objects. They’re useful for tagging, syncing, or other modifications.

Use them per placer via `:preSpawn(fn)` or `:postSpawn(fn)`:

```lua
:scatter(function(s)
  s:items("Notebook", "Pencil")
   :postSpawn(function(_, created)
     -- Briefly highlight the spawned items
     for _, obj in ipairs(created) do
       obj:setHighlighted(true)
       obj:setHighlightColor(0.8, 0.8, 0.3, 1)
     end
   end)
   :where("tables_and_counters")
end)
```

### Function signature

Each hook gets called with two parameters:

```lua
---@param ctx table    -- scene context (player, anchor, spec, etc.)
---@param created table -- list of spawned IsoWorldInventoryObject or InventoryItem
function myHook(ctx, created)
end
```

| Param     | Description                                                                                         |
| --------- | --------------------------------------------------------------------------------------------------- |
| `ctx`     | Scene context including the active `player`, resolved `anchor`, and the current `spec.place` info.  |
| `created` | All objects produced by the placer; usually a mix of `IsoWorldInventoryObject` and `InventoryItem`. |

> **Tip:** Hooks are just closures — build your own mini hook factories to reuse logic across prefabs.

---

## Prefabs

The mod ships with demo prefabs to showcase and test the builder:  

```lua
require("SceneBuilder/prefabs/demo_full").makeForRoomDef(nil)
```

Included examples:

- `demo_full.lua` – mixed anchor + corpse + container + scatter  
- `demo_corpse.lua` – corpse-focused scene  
- `demo_on_tables.lua` – surface/container placement  
- `demo_scatter.lua` – scatter placement 
- `demo_proximity.lua` – proximity based spawning around an anchor

Scene authors are encouraged to organize and name their own scenes however they prefer.

--- 

## Future Plans

* Caching & async building (though no performance bottlenecks are presently observed).
* Additional inbuilt resolvers e.g. by doors, windows.
* Additional placers for live zombies, possibly vehicles.
* Support passing an IsoGridSquare instead of a named anchor.
* Find a way to supress ItemStories automatic world spawning for those who want to include that mod just for the SpriteSurfaceDimensions.present.
* Support for outdoor scenes.

---

## Contributing

Pull requests are welcome — preferably crafted with a survivor’s sense of caution.
If you have improvements, new resolvers, placement tweaks, automatic tests (one can dream eh), feel free to open a PR.

Please:

* Follow the **StyLua default style** already used (indentation, inline comments, lowercase function names).
* If you can, include a short **comment or example prefab** showing how your addition works.
* Keep debug printouts clear and colon-free (`[SceneBuilder]` prefix recommended).

If you discover bugs or broken behavior, open an **issue** instead of silently suffering.
Suggestions, balance opinions, and weird edge-case reports are all welcome — just keep it constructive.

---

## AI Disclosure

Parts of this project’s code, documentation, and README were drafted or refined with the assistance of AI tools (including OpenAI’s ChatGPT).
All code and text have been **reviewed and edited by a human** before inclusion.

AI assistance was used for:

* Grammar and style editing of documentation
* Formatting and type hinting improvements
* Generating examples or scaffolding code under developer supervision

No game assets, proprietary content, or copyrighted material from *Project Zomboid* or *The Indie Stone* were ever generated, reproduced, or distributed using AI tools.

> *AI may have helped write some lines, but the bloody rags are human-made.*

---

## Disclaimer

SceneBuilder is provided entirely AS-IS —  *still experimental and largely untested* in live worlds. 
There are no guarantees, no stable releases, and not even a notion of versioning at this point.
It may break tomorrow, corrupt your save, or be abandoned without notice.

By using or modifying this code, you accept that:

* You do so at your own risk.
* The authors take no responsibility for any harm, loss, or unintended side effects to your game world, saves, or mods.
* There is no warranty, express or implied, of fitness for survival — much like Knox County itself.
* This project is an independent fan-made modification for Project Zomboid and is not affiliated with, endorsed by, or approved by The Indie Stone Ltd.
* All rights, trademarks, and assets related to Project Zomboid remain the property of The Indie Stone Ltd.
* Licensed under the MIT License (See LICENSE file for details)

> If it breaks, panic quietly, eat some beans, and try again.