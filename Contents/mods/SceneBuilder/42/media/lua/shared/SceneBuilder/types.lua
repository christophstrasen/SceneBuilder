---@diagnostic disable: duplicate-doc-field, undefined-doc-name, undefined-global, lowercase-global, missing-fields, redefined-local, luadoc-miss-field-name, luadoc-miss-symbol
---@meta

--------------------------------------------------------------------------------
-- SceneBuilder – unified type annotations for VS Code (LuaLS / Sumneko)
-- Project Zomboid Build 42
-- NOTE: This file is for editor tooling. It contains no runtime logic.
-- Safe to ship with your mod; it won't affect execution.
--------------------------------------------------------------------------------

-- ===== Shared value objects ===================================================

---@class SceneBuilder.PlacePos
---@field x integer
---@field y integer
---@field z integer

---@class SceneBuilder.SpawnCtx
---@field roomDef RoomDef
---@field anchorName string|nil
---@field position SceneBuilder.PlacePos|nil
---@field spec SceneBuilder.PlaceSpec|nil

---@alias SceneBuilder.ProximityFallback
---| '"ignore-proximity-keep-strategy"'
---| '"ignore-proximity-and-strategy"'
---| '"widen-proximity"'
---| '"fail"'

---@class SceneBuilder.PlaceSpec
---@field strategy string
---@field anchor string|nil                     -- anchor name only (string); normalized
---@field retries integer|nil
---@field fallback string[]|nil
---@field room RoomDef|nil
---@field name string|nil
---@field minSurfaceHeight number|nil
---@field limit integer|nil
---@field whitelist string[]|nil
---@field deterministic boolean|nil
---@field maxPlacementSquares number|nil
---@field anchor_proximity integer|nil          -- Chebyshev radius (floored); default 2
---@field respect_strategy boolean|nil          -- default false (proximity over strategy)
---@field proximity_fallback SceneBuilder.ProximityFallback|nil

---@class SceneBuilder.State
---@field anchors table<string, IsoGridSquare>        -- <— anchors are squares

--- Item spec accepted by normType etc.
--- @class SceneBuilder_ItemSpec
--- @field item? string
--- @field type? string
--- @field name? string
--- @field [1]? string

---@class SceneBuilder.PlacerBase
---@field kind 'corpse'|'container'|'scatter'
---@field place SceneBuilder.PlaceSpec|nil
---@field preSpawn fun(ctx:SceneBuilder.SpawnCtx)|nil
---@field postSpawn fun(ctx:SceneBuilder.SpawnCtx, created:table)|nil

---@class SceneBuilder.CorpseSpec : SceneBuilder.PlacerBase
---@field outfit string|nil
---@field onBody (string|{[1]:string,[2]:integer})[]|nil
---@field dropNear (string|{[1]:string,[2]:integer})[]|nil
---@field crawlerChance integer|nil
---@field blood { bruising: integer|nil, floor_splats: integer|nil }|nil

---@class SceneBuilder.ContainerSpec : SceneBuilder.PlacerBase
---@field item string
---@field contains (string|{[1]:string,[2]:integer})[]|nil

---@class SceneBuilder.ScatterSpec : SceneBuilder.PlacerBase
---@field items (string|{[1]:string,[2]:integer})[]|nil
---@field maxItemNum integer|nil

---@class SceneBuilder.ZombiesSpec : SceneBuilder.PlacerBase
---@field count integer|nil
---@field outfit string|nil
---@field femaleChance number|nil

---@alias SceneBuilder.PlacerSpec
---| SceneBuilder.CorpseSpec
---| SceneBuilder.ContainerSpec
---| SceneBuilder.ScatterSpec
---| SceneBuilder.ZombiesSpec

-- ===== Util module ============================================================

---@class SceneBuilder.Util
---@field log fun(tag:string, msg:string)
---@field assertf fun(cond:any, msg?:string):boolean
---@field simpleCache fun():{
---   get: fun(key:any):any,
---   put: fun(key:any, val:any),
---   clear: fun()
---}

-- ===== Lifecycle module =======================================================

---@class SceneBuilder.Lifecycle
---@field tagAndRegister fun(obj:any, tag:string)
---@field despawn fun(tag:string)
---@field getRegistry fun():table

-- ===== Resolvers module =======================================================

---@class SceneBuilder.Resolvers
---@field hasResolver fun(name:string):boolean
---@field normAnchorRef fun(name:any):any
---@field ensurePlace fun(
---   strategyOrOpts:string|SceneBuilder.PlaceSpec, opts2?:table
---):SceneBuilder.PlaceSpec
---@field resolveSquare fun(
---   state:table|nil, roomDef:RoomDef, place:SceneBuilder.PlaceSpec|nil
---):IsoGridSquare|nil

-- ===== Placers module =========================================================

---@class SceneBuilder.Placers
---@field addItemMulti fun(inv:ItemContainer, t:string|{[1]:string,[2]:integer})
---@field addWorldMulti fun(
---   state:table|nil, sq:IsoGridSquare, typeName:string, qty:integer|nil
---):table                                                # {WorldInventoryItem}
---@field placeCorpse fun(
---   state:table|nil, roomDef:RoomDef, spec:SceneBuilder.CorpseSpec,
---   sqOverride:IsoGridSquare|nil
---):table, IsoGridSquare|nil                             # {IsoDeadBody?}, center
---@field placeContainer fun(
---   state:table|nil, roomDef:RoomDef, spec:SceneBuilder.ContainerSpec,
---   sqOverride:IsoGridSquare|nil
---):table, IsoGridSquare|nil                             # {WorldInventoryItem?}, sq
---@field placeScatter fun(
---   state:table|nil, roomDef:RoomDef, spec:SceneBuilder.ScatterSpec,
---   centerSq:IsoGridSquare|nil
---):table, IsoGridSquare|nil                             # {WorldInventoryItem}, ctr
---@field placeZombies fun(
---   state:table|nil, roomDef:RoomDef, spec:SceneBuilder.ZombiesSpec,
---   sqOverride:IsoGridSquare|nil
---):table, IsoGridSquare|nil                             # {IsoZombie}, center
---@field spawnOne fun(state:table|nil, roomDef:RoomDef, spec:SceneBuilder.PlacerSpec)
---@field normType fun(t:any):string|any
---@field getDefaultCorpseOutfit fun():string

-- ===== Registry module ========================================================

---@alias SceneBuilder.ResolverFn
---| fun(roomDef: RoomDef, place: SceneBuilder.PlaceSpec):
---      IsoGridSquare|IsoGridSquare[]|nil

---@class SceneBuilder.ResolverOptions
---@field overwrite? boolean

---@class SceneBuilder.Registry
---@field registerResolver fun(
---   name: string,
---   fn: SceneBuilder.ResolverFn,
---   opts?: SceneBuilder.ResolverOptions
---): boolean
---@field unregisterResolver fun(name: string)

-- ===== Core / Builder API =====================================================

---@class SceneBuilder.Core
---@field begin fun(roomDef:RoomDef, opts?:{ tag?:string }):SceneBuilder.SceneAPI

-- Sub-builders exposed to user closures

---@class SceneBuilder.CorpseBuilder
---@field place fun(
---   self:SceneBuilder.CorpseBuilder,
---   strategyOrOpts:string|SceneBuilder.PlaceSpec, opts2?:table
---):SceneBuilder.CorpseBuilder
---@field preSpawn fun(
---   self:SceneBuilder.CorpseBuilder, fn:fun(ctx:SceneBuilder.SpawnCtx)
---):SceneBuilder.CorpseBuilder
---@field postSpawn fun(
---   self:SceneBuilder.CorpseBuilder,
---   fn:fun(ctx:SceneBuilder.SpawnCtx, created:table)
---):SceneBuilder.CorpseBuilder
---@field outfit fun(self:SceneBuilder.CorpseBuilder, name:string):
---   SceneBuilder.CorpseBuilder
---@field onBody fun(
---   self:SceneBuilder.CorpseBuilder,
---   ...:string|{[1]:string,[2]:integer}
---):SceneBuilder.CorpseBuilder
---@field dropNear fun(
---   self:SceneBuilder.CorpseBuilder,
---   ...:string|{[1]:string,[2]:integer}
---):SceneBuilder.CorpseBuilder
---@field blood fun(
---   self:SceneBuilder.CorpseBuilder,
---   tbl?:{ bruising?:integer, floor_splats?:integer, trail?:boolean }
---):SceneBuilder.CorpseBuilder

---@class SceneBuilder.ContainerBuilder
---@field place fun(
---   self:SceneBuilder.ContainerBuilder,
---   strategyOrOpts:string|SceneBuilder.PlaceSpec, opts2?:table
---):SceneBuilder.ContainerBuilder
---@field preSpawn fun(
---   self:SceneBuilder.ContainerBuilder, fn:fun(ctx:SceneBuilder.SpawnCtx)
---):SceneBuilder.ContainerBuilder
---@field postSpawn fun(
---   self:SceneBuilder.ContainerBuilder,
---   fn:fun(ctx:SceneBuilder.SpawnCtx, created:table)
---):SceneBuilder.ContainerBuilder
---@field addTo fun(
---   self:SceneBuilder.ContainerBuilder,
---   ...:string|{[1]:string,[2]:integer}
---):SceneBuilder.ContainerBuilder

---@class SceneBuilder.ScatterBuilder
---@field place fun(
---   self:SceneBuilder.ScatterBuilder,
---   strategyOrOpts:string|SceneBuilder.PlaceSpec, opts2?:table
---):SceneBuilder.ScatterBuilder
---@field preSpawn fun(
---   self:SceneBuilder.ScatterBuilder, fn:fun(ctx:SceneBuilder.SpawnCtx)
---):SceneBuilder.ScatterBuilder
---@field postSpawn fun(
---   self:SceneBuilder.ScatterBuilder,
---   fn:fun(ctx:SceneBuilder.SpawnCtx, created:table)
---):SceneBuilder.ScatterBuilder
---@field items fun(
---   self:SceneBuilder.ScatterBuilder,
---   ...:string|{[1]:string,[2]:integer}
---):SceneBuilder.ScatterBuilder
---@field maxItemNum fun(self:SceneBuilder.ScatterBuilder, n:integer):
---   SceneBuilder.ScatterBuilder
---@field maxPlacementSquares fun(self:SceneBuilder.ScatterBuilder, n:integer):
---   SceneBuilder.ScatterBuilder

---@class SceneBuilder.ZombiesBuilder
---@field place fun(
---   self:SceneBuilder.ZombiesBuilder,
---   strategyOrOpts:string|SceneBuilder.PlaceSpec, opts2?:table
---):SceneBuilder.ZombiesBuilder
---@field preSpawn fun(
---   self:SceneBuilder.ZombiesBuilder, fn:fun(ctx:SceneBuilder.SpawnCtx)
---):SceneBuilder.ZombiesBuilder
---@field postSpawn fun(
---   self:SceneBuilder.ZombiesBuilder,
---   fn:fun(ctx:SceneBuilder.SpawnCtx, created:table)
---):SceneBuilder.ZombiesBuilder
---@field count fun(self:SceneBuilder.ZombiesBuilder, n:integer):SceneBuilder.ZombiesBuilder
---@field outfit fun(self:SceneBuilder.ZombiesBuilder, name:string):SceneBuilder.ZombiesBuilder
---@field femaleChance fun(self:SceneBuilder.ZombiesBuilder, pct:number):SceneBuilder.ZombiesBuilder

-- Anchors mini-DSL object used in api:anchors(fn)
---@class SceneBuilder.AnchorsDSL
---@field name fun(self:SceneBuilder.AnchorsDSL, name:string):SceneBuilder.AnchorsDSL
---@field place fun(
---   self:SceneBuilder.AnchorsDSL,
---   strategyOrOpts:string|SceneBuilder.PlaceSpec, opts2?:table
---):SceneBuilder.AnchorsDSL

-- Main Scene API returned by Core.begin(...)
---@class SceneBuilder.SceneAPI
---@field corpse fun(fn:fun(sub:SceneBuilder.CorpseBuilder)):SceneBuilder.SceneAPI
---@field container fun(
---   typeName:string, fn:fun(sub:SceneBuilder.ContainerBuilder)
---):SceneBuilder.SceneAPI
---@field scatter fun(fn:fun(sub:SceneBuilder.ScatterBuilder)):SceneBuilder.SceneAPI
---@field zombies fun(fn:fun(sub:SceneBuilder.ZombiesBuilder)):SceneBuilder.SceneAPI
---@field anchors fun(fn:fun(a:SceneBuilder.AnchorsDSL)):SceneBuilder.SceneAPI
---@field preSpawn fun(
---   fn:fun(ctx:SceneBuilder.SpawnCtx)
---):SceneBuilder.SceneAPI
---@field postSpawn fun(
---   fn:fun(ctx:SceneBuilder.SpawnCtx, created:table)
---):SceneBuilder.SceneAPI
---@field place fun(
---   strategyOrOpts:string|SceneBuilder.PlaceSpec, opts2?:table
---):SceneBuilder.SceneAPI
---@field placeNow fun():SceneBuilder.SceneAPI
---@field spawn fun():SceneBuilder.SceneAPI
---@field getTag fun():string
---@field __state table                                   # optional debug handle

-- Optional unified root (helps some tooling find modules under one umbrella)
---@class SceneBuilder
---@field util SceneBuilder.Util
---@field lifecycle SceneBuilder.Lifecycle
---@field resolvers SceneBuilder.Resolvers
---@field placers SceneBuilder.Placers
---@field registry SceneBuilder.Registry
---@field core SceneBuilder.Core

---@class SceneBuilder.SurfaceHit
---@field sq IsoGridSquare
---@field z number
---@field obj IsoObject
---@field texture string

---@class SceneBuilder.SurfaceHitOpts
---@field minSurfaceHeight? number
---@field whitelist? string[]
---@field limit? number
---@field reference? string
---@field square_padding? number

---@alias SceneBuilder.SurfaceLikeOpts
---| SceneBuilder.SurfaceHitOpts
---| SceneBuilder.PlaceSpec               -- tolerated: superset, unused keys ignored
---| nil

---@class SceneBuilder.SurfaceScan
---@field getSurfaceHit fun(sq:IsoGridSquare, opts:SceneBuilder.SurfaceLikeOpts):SceneBuilder.SurfaceHit|nil
