--- SceneBuilder uses two resolver shapes:
---   • Pool  : "give me candidate squares" for a strategy (tables, desks, …).
---             Used by placers to shortlist + deterministically choose one.
---             Source of truth: Resolvers.resolvePool(roomDef, place).
---   • Square: "give me one square now" as a *special case* of the above.
---             Used when a placer needs a single, definite start point:
---               - center fallback in scatter when pool/shortlist failed
---               - explicit snap to a named anchor square (author intent)
---             Implemented by collapsing the pool (strategy → fallback list)
---             to its first candidate.
---
---  Notes:
---   • Strategy fallback (place.fallback) is a Resolvers policy.
---   • Proximity fallback is handled elsewhere (_applyProximityPass).

local U = require("SceneBuilder/util")
local LOG_TAG = "SceneBuilder Resolvers"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf
local shallowCopy = U.shallowCopy

---@class SceneBuilder.Resolvers
local Resolvers = {} -- Returns this module later

local _resolvers = {} -- gets filled by resolvers in the resolvers/ folder or from others places via Registry.registerResolver("<name>", func)

--- Register/replace a resolver.
---@param name string
---@param fn SceneBuilder.ResolverFn
---@param opts? SceneBuilder.ResolverOptions
---@return boolean ok
local function registerResolver(name, fn, opts)
	assertf(type(name) == "string" and name ~= "", "resolver name required")
	assertf(type(fn) == "function", "resolver fn must be function")
	if _resolvers[name] and not (opts and opts.overwrite) then
		error("resolver exists " .. name)
	end
	_resolvers[name] = fn
	return true
end

local function unregisterResolver(name)
	_resolvers[name] = nil
end

local function hasResolver(name)
	return _resolvers[name] ~= nil
end

local function _normAnchorRef(name)
	if type(name) ~= "string" then
		return name
	end
	return (name:gsub("^anchor:", ""))
end

--- Normalize the PlaceSpec.
--- @param strategyOrOpts string|table|nil
--- @param opts table|nil
--- @return SceneBuilder.PlaceSpec
local function _ensurePlace(strategyOrOpts, opts)
	if type(strategyOrOpts) == "string" then
		opts = shallowCopy(opts or {})
		opts.strategy = strategyOrOpts
	elseif type(strategyOrOpts) == "table" then
		opts = shallowCopy(strategyOrOpts)
	else
		opts = {}
	end

	local retries = tonumber(opts.retries or 4) or 4
	if retries < 1 then
		retries = 1
	end

	local mps = tonumber(opts.maxPlacementSquares)
	if mps and mps < 1 then
		mps = 1
	end

	local limit = tonumber(opts.limit)
	if limit and limit < 0 then
		limit = 0
	end

	-- making sure fallback is a clean list of strings.
	local fblist = U.asStringList(opts.fallback, { "any" })

	local place = {
		strategy = opts.strategy or "any",
		anchor = opts.anchor and _normAnchorRef(opts.anchor) or nil,
		retries = retries,
		deterministic = (opts.deterministic == nil) and nil or (opts.deterministic ~= false),
		fallback = fblist,
		maxPlacementSquares = mps,
		distribution = opts.distribution or "random",
		minSurfaceHeight = opts.minSurfaceHeight,
		limit = limit,
		whitelist = opts.whitelist,
		room = opts.room,
		name = opts.name,

		-- proximity
		anchor_proximity = U.clampInt(opts.anchor_proximity == nil and 2 or opts.anchor_proximity, 0),
		respect_strategy = (opts.respect_strategy == true),
		proximity_fallback = tostring(opts.proximity_fallback or "ignore-proximity-keep-strategy"),
	}

	if place.anchor_proximity < 0 then
		place.anchor_proximity = 0
		U.logCtx(LOG_TAG, "anchor_proximity clamped to 0", {})
	end

	if type(place.anchor) ~= "string" and place.anchor ~= nil then
		U.logCtx(LOG_TAG, "anchor must be string; ignoring non-string anchor", {})
		place.anchor = nil
	end

	if opts.randomness and not opts.maxPlacementSquares then
		U.logCtx(LOG_TAG, "place.randomness is deprecated use maxPlacementSquares", {})
	end

	return place
end

local function _tryStrategy(roomDef, place, name)
	local fn = _resolvers[name]
	if not fn then
		U.logCtx(LOG_TAG, "resolvePool strategy missing", { name = name })
		return nil
	end
	local ok, pool = pcall(fn, roomDef, place)
	if not ok then
		U.logCtx(LOG_TAG, "resolvePool strategy error", { name = name, err = tostring(pool) })
		return nil
	end
	if not pool or #pool == 0 then
		return nil
	end
	return pool
end

--- Resolve one or more placement strategies into a pool of candidate squares.
---
--- Used by all placers (corpse, container, scatter) as the first step of
--- scene placement. Each strategy’s registered resolver produces a list
--- of IsoGridSquares that match its category (tables, counters, floor, etc.).
---
--- The function will:
---   1. Run the resolver registered for `place.strategy`.
---   2. If that yields no results, iterate through `place.fallback`
---      (a prioritized list, defaulting to {"any"}) and return the first
---      non-empty pool it finds.
---   3. Return both the pool and the name of the strategy that succeeded.
---
--- This function does *not* apply proximity or anchor logic—those are
--- handled later by `_applyProximityPass` inside the placers.
---
--- Fallback behavior is confined to resolver-level strategies; it is
--- separate from proximity fallbacks and should only be triggered when
--- a resolver produces zero results in the entire room.
---
--- @param roomDef RoomDef             -- Target room definition
--- @param place SceneBuilder.PlaceSpec -- Normalized placement spec
--- @param isFallbackAttempt? boolean   -- Internal guard to prevent recursion
--- @return IsoGridSquare[]|nil pool    -- Candidate squares or nil
--- @return string|nil usedStrategy     -- Name of the strategy that succeeded
local function resolvePool(roomDef, place, isFallbackAttempt)
	local primary = place and place.strategy or "any"
	local fbList = (place and place.fallback) or { "any" }

	U.logCtx(LOG_TAG, "resolvePool start", {
		strategy = place and place.strategy or "any",
		isFallbackAttempt = isFallbackAttempt or false,
		fallbackCount = fbList and #fbList or 0,
	})

	-- try primary
	local pool = _tryStrategy(roomDef, place, primary)
	if pool then
		U.logCtx(LOG_TAG, "resolvePool success", {
			strategy = primary,
			size = pool and #pool or 0,
		})
		return pool, primary
	end

	-- bail if we are already inside a fallback attempt
	if isFallbackAttempt then
		U.logCtx(LOG_TAG, "resolvePool empty and not recursing", { strategy = primary })
		return nil, nil
	end

	-- iterate fallback list
	if fbList and #fbList > 0 then
		U.logCtx(LOG_TAG, "resolvePool trying fallbacks", {
			from = primary,
			count = fbList and #fbList or 0,
		})

		for i = 1, #fbList do
			local fb = fbList[i]
			U.logCtx(LOG_TAG, "resolvePool fallback try", {
				name = fbList[i],
				idx = i,
			})
			local fbPool = _tryStrategy(roomDef, place, fb)
			if fbPool then
				U.logCtx(LOG_TAG, "resolvePool fallback success", {
					name = fb,
					size = fbPool and #fbPool or 0,
				})
				return fbPool, fb
			end
		end
	end

	U.logCtx(LOG_TAG, "resolvePool no candidates", {
		strategy = primary,
	})
	return nil, nil
end

--- Try to resolve exactly one IsoGridSquare for a placement spec
---
--- Callers today:
---   • placeScatter: as last-resort center when pool yields no pick.
---   • (Optional in others) when a flow needs a single definite square.
---
--- Resolution order:
---   1) If an explicit anchor resolves to a live square, return it (author win).
---   2) Else use resolvePool(...) to try strategy → fallback list; return first.
--- @param state table|nil     -- SceneBuilder state (anchors live here)
--- @param roomDef RoomDef     -- Target room definition
--- @param place table         -- Normalized PlaceSpec (strategy, fallback, anchor…)
--- @return IsoGridSquare|nil  -- Chosen square or nil if none found
local function resolveSquare(state, roomDef, place)
	assertf(roomDef, "resolveSquare needs RoomDef")
	place = _ensurePlace(place)

	-- If the scene defines an explicit anchor (e.g., "deskCorner") and it already
	-- resolves to a concrete square, honor that first. This is a deliberate
	-- "author intent beats guessing" rule: anchors can dictate a precise start
	-- square before any strategy/pool logic runs.
	local aName = place.anchor and Resolvers.normAnchorRef(place.anchor) or nil
	if aName and state and state.anchors and state.anchors[aName] then
		local sq = state.anchors[aName]
		if sq then
			U.logCtx(LOG_TAG, "resolveSquare anchor-first", { x = sq:getX(), y = sq:getY(), z = sq:getZ() })
			return sq
		end
	end

	-- Use resolvePool to try primary + fallback strategies
	local pool, used = resolvePool(roomDef, place) -- used = name of producing strategy

	if pool and #pool > 0 then
		local sq = pool[1]

		U.logCtx(LOG_TAG, "resolveSquare collapsed first", {
			strategy = used or place.strategy or "any",
			size = #pool,
			x = sq and sq:getX() or nil,
			y = sq and sq:getY() or nil,
			z = sq and sq:getZ() or nil,
		})

		return sq
	end

	U.logCtx(LOG_TAG, "resolveSquare no candidates", {
		strategy = place.strategy or "any",
		fallbackCount = place.fallback and #place.fallback or 0,
	})

	return nil
end

Resolvers.registerResolver = registerResolver
Resolvers.unregisterResolver = unregisterResolver
Resolvers.hasResolver = hasResolver
Resolvers.normAnchorRef = _normAnchorRef
Resolvers.ensurePlace = _ensurePlace
Resolvers.resolvePool = resolvePool
Resolvers.resolveSquare = resolveSquare

---@return SceneBuilder.Resolvers
return Resolvers
