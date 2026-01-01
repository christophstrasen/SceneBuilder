-- SceneBuilder/placers.lua — scaffold
local U = require("DREAMBase/util")
local LOG_TAG = "SceneBuilder Placers"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf
local Resolvers = require("SceneBuilder/resolvers")
local Lifecycle = require("SceneBuilder/lifecycle")
local SurfaceScan = require("SceneBuilder/surface_scan")

-- luacheck: globals addZombiesInOutfit

require("SceneBuilder/SpritesSurfaceDimensions_polyfill")
local SD = SpriteDimensionsPolyfill

---@class SceneBuilder.Placers
local Placers = {} -- Returns this module later

-- === Proximity pass (Chebyshev) =============================================

--- Find anchor square by name in state.
--- @return IsoGridSquare|nil, string|nil  -- sq, anchorName
local function _getAnchorSq(state, place)
	if not (state and state.anchors) then
		return nil, nil
	end
	if type(place and place.anchor) ~= "string" then
		return nil, nil
	end
	local name = place.anchor
	local sq = state.anchors[name]
	return sq, name
end

--- Build a "near-any" set inside room using Chebyshev radius around anchor sq.
--- Room clamp is implicit by iterating room squares only.
--- @return table<IsoGridSquare>
local function _buildNearAnySet(roomDef, anchorSq, radius)
	local out = {}
	local room = roomDef and roomDef.getIsoRoom and roomDef:getIsoRoom() or nil
	if not (room and room.getSquares) then
		return out
	end
	local ax, ay = anchorSq:getX(), anchorSq:getY()
	local squares = room:getSquares()
	if not squares or squares:size() == 0 then
		return out
	end
	for i = 0, squares:size() - 1 do
		local sq = squares:get(i)
		if sq then
			local d = U.cheby(sq:getX(), sq:getY(), ax, ay)
			if d <= radius then
				out[#out + 1] = sq
			end
		end
	end
	return out
end

--- Intersect an existing resolver pool with "near" constraint (Chebyshev).
--- @return IsoGridSquare[]|nil
local function _filterPoolByProximity(pool, anchorSq, radius)
	if not (pool and #pool > 0 and anchorSq and radius) then
		return pool
	end
	local ax, ay = anchorSq:getX(), anchorSq:getY()
	local out = {}
	for i = 1, #pool do
		local sq = pool[i]
		if sq and U.cheby(sq:getX(), sq:getY(), ax, ay) <= radius then
			out[#out + 1] = sq
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

--- Proximity pass according to PlaceSpec (Chebyshev).
--- Returns a candidate list to shortlist from, honoring:
---  - respect_strategy (pool vs near-any)
---  - proximity_fallback ("ignore-proximity-keep-strategy" | ... )
---  - anchor_proximity (default 2)
--- Deterministic concerns are handled by higher-level shortlist/picking, not here.
--- @return IsoGridSquare[]|nil, string|nil  -- candidatePool, anchorName
local function _applyProximityPass(state, roomDef, place, pool)
	local function finish(outPool, name)
		U.logCtx(LOG_TAG, "proximity result", {
			poolOut = outPool and #outPool or 0,
		})
		return outPool, name
	end

	-- quick exits
	local anchorSq, anchorName = _getAnchorSq(state, place)
	if not anchorSq or not place then
		return finish(pool, anchorName)
	end

	U.logCtx(LOG_TAG, "proximity start", {
		anchor = anchorName or place.anchor or "",
		radius = place.anchor_proximity or 2,
		respect = place.respect_strategy ~= false,
		mode = place.proximity_fallback or "default",
		poolIn = pool and #pool or 0,
	})

	local r = U.clampInt(place.anchor_proximity == nil and 2 or place.anchor_proximity, 0)
	local keepStrategy = (place.respect_strategy == true)
	local fb = tostring(place.proximity_fallback or "ignore-proximity-keep-strategy")

	-- case A: keep strategy; try pool ∩ near
	if keepStrategy then
		local nearPool = _filterPoolByProximity(pool, anchorSq, r)
		if nearPool and #nearPool > 0 then
			return finish(nearPool, anchorName)
		end
		if fb == "widen-proximity" then
			-- expand r deterministically: r+1..r+6 (hard cap)
			for rr = r + 1, r + 6 do
				local widened = _filterPoolByProximity(pool, anchorSq, rr)
				if widened and #widened > 0 then
					return finish(widened, anchorName)
				end
			end
			-- then fall through to ignore-proximity-keep-strategy
			fb = "ignore-proximity-keep-strategy"
		end
		if fb == "ignore-proximity-keep-strategy" then
			return finish(pool, anchorName)
		elseif fb == "ignore-proximity-and-strategy" then
			local nearAny = _buildNearAnySet(roomDef, anchorSq, r)
			if nearAny and #nearAny > 0 then
				return finish(nearAny, anchorName)
			end
			return finish(pool, anchorName)
		elseif fb == "fail" then
			return finish(nil, anchorName)
		end
		return finish(pool, anchorName)
	end

	-- case B: do not keep strategy; prefer near-any first
	local nearAny = _buildNearAnySet(roomDef, anchorSq, r)
	if nearAny and #nearAny > 0 then
		return finish(nearAny, anchorName)
	end
	if fb == "widen-proximity" then
		for rr = r + 1, r + 6 do
			local widenedAny = _buildNearAnySet(roomDef, anchorSq, rr)
			if widenedAny and #widenedAny > 0 then
				return finish(widenedAny, anchorName)
			end
		end
		-- fall through
	end
	if fb == "ignore-proximity-keep-strategy" then
		return finish(pool, anchorName)
	elseif fb == "ignore-proximity-and-strategy" then
		-- already tried near-any; nothing; fall back to pool
		return finish(pool, anchorName)
	elseif fb == "fail" then
		return finish(nil, anchorName) -- was 'pool'
	end

	return finish(pool, anchorName)
end

local function getDefaultCorpseOutfit()
	return "Survivor"
end

--- Determine whether placement should be deterministic.
--- @param place SceneBuilder.PlaceSpec|nil  -- placement spec, may omit deterministic
--- @param state table|nil                    -- current SceneBuilder state (may contain .deterministic)
--- @return boolean                           -- true if deterministic, false otherwise
local function isDeterministic(place, state)
	local v = place and place.deterministic
	if v == nil and state then
		v = state.deterministic
	end
	if v == nil then
		v = true
	end
	return v
end

--- @param x string|SceneBuilder_ItemSpec|nil
--- @return string|nil
local function normType(x)
	local s = x
	if type(s) == "table" then
		s = s.item or s.type or s.name or s[1]
	end
	if type(s) ~= "string" then
		return nil
	end
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	if s == "" then
		return nil
	end
	-- IMPORTANT: with plain=true, use "." (not "%.") to detect a literal dot
	if s:find(".", 1, true) then
		return s
	end
	return "Base." .. s
end

--- Create an InventoryItem from a string or item-spec table.
--- @param t string|table
--- @return InventoryItem|nil
local function mkItem(t)
	local typeName = normType(t)
	if not typeName then
		log("mkItem no script name from " .. tostring(t))
		return nil
	end
	if type(instanceItem) ~= "function" then
		log("mkItem instanceItem missing")
		return nil
	end
	log("mkItem Creating item " .. tostring(typeName))
	local it = instanceItem(typeName)
	if not it then
		log("mkItem failed " .. tostring(typeName))
	end
	return it
end

-- Compute a point inside a SpriteDimensions box (returns 0..1, 0..1).
-- 'box' is expected to carry minOffsetX/Y, maxOffsetX/Y in percent (0..100).
-- 'pad' is extra padding in percent points (e.g., 18), optional.
-- Never shifts around center; respects bounds strictly.
-- defBox is the fallback to fill missing fields in box (raised or floor)
local function _pickXYInBox(box, pad, defBox)
	pad = pad or 0
	local def = defBox or box
	local minXp = math.max(0, (box.minOffsetX or def.minOffsetX) + pad)
	local maxXp = math.min(100, (box.maxOffsetX or def.maxOffsetX) - pad)
	local minYp = math.max(0, (box.minOffsetY or def.minOffsetY) + pad)
	local maxYp = math.min(100, (box.maxOffsetY or def.maxOffsetY) - pad)

	-- guard inversions (padding could cause it)
	if maxXp < minXp then
		minXp, maxXp = maxXp, minXp
	end
	if maxYp < minYp then
		minYp, maxYp = maxYp, minYp
	end

	-- convert to normalized 0..1
	local minX = minXp / 100.0
	local maxX = maxXp / 100.0
	local minY = minYp / 100.0
	local maxY = maxYp / 100.0

	-- pick random in [min,max] (guard 0-span to avoid ZombRand(0))
	local function randRange(a, b)
		if not (b and a) or b <= a then
			return a or 0
		end
		if ZombRandFloat then
			return ZombRandFloat(a, b)
		end
		if type(ZombRand) ~= "function" then
			return a
		end
		local span = b - a
		local steps = math.floor(span * 10000)
		if steps < 1 then
			return a
		end
		return (ZombRand(steps) / 10000.0) + a
	end
	local rx = randRange(minX, maxX)
	local ry = randRange(minY, maxY)

	-- paranoia clamp
	if rx < minX then
		rx = minX
	elseif rx > maxX then
		rx = maxX
	end
	if ry < minY then
		ry = minY
	elseif ry > maxY then
		ry = maxY
	end

	return rx, ry, minXp, maxXp, minYp, maxYp
end

--- Compute spawn offsets for a given square, respecting mayAdjustZ.
--- @param sq IsoGridSquare
--- @param mayAdjustZ boolean|nil
--- @param opts SceneBuilder.SurfaceHitOpts
--- @return number, number, number  -- x[0..1], y[0..1], z[tiles]
local function computeOffsets(sq, mayAdjustZ, opts)
	assertf(sq and sq.getX and sq.getY and sq.getZ, "computeOffsets bad square")
	local ref = (opts and opts.reference) or ""
	local pad = opts and opts.square_padding or 0

	local floorBox = SD.getDefaultFloor()
	local raisedBox = SD.getDefaultRaised()
	if not floorBox or not raisedBox then
		U.logCtx(LOG_TAG, "computeOffsets defaults missing so returning 0 0 0", { ref = ref })
		return 0, 0, 0
	end

	-- DRY finish helper: pick XY in given box and compute z tiles
	local function finish(box, zPix)
		local defForBox = (zPix and zPix > 0) and raisedBox or floorBox
		local x, y = _pickXYInBox(box, pad, defForBox)
		local zPad, TILE_PX = 0.01, 96.0
		local z = (zPix or 0) / TILE_PX + zPad
		if z > 1.5 then
			z = 1.5
		end
		if z < 0 then
			z = 0
		end
		return x, y, z
	end

	-- No Z adjustment wanted → floor placement and z 0
	if not mayAdjustZ then
		U.logCtx(LOG_TAG, "no adjust z using floor", { ref = ref })
		return finish(floorBox, 0)
	end

	-- Find surface sprite on this square
	local hit = SurfaceScan.getSurfaceHit(sq, opts)
	if not hit or not hit.texture then
		U.logCtx(LOG_TAG, "no surface hit, so using floorbox", { ref = ref })
		return finish(floorBox, 0)
	end

	-- Exact or pattern entry without default fallback
	local entry = SD.get(hit.texture, false) -- nil means not listed or pattern mismatch
	local zPix = (entry and entry.overrideExactOffsetZ) or hit.z or 0 --take override, the hit reported z or 0

	-- Choose box: floor for flat sprites, else entry if present, else raised default
	local function isBox(t)
		return type(t) == "table"
			and type(t.minOffsetX) == "number"
			and type(t.maxOffsetX) == "number"
			and type(t.minOffsetY) == "number"
			and type(t.maxOffsetY) == "number"
	end

	-- Choose box: floor for flat sprites, else entry if good, else raised default
	local box = (zPix <= 0) and floorBox or (isBox(entry) and entry or raisedBox)

	-- Done
	local xOff, yOff, zOff = finish(box, zPix)
	U.logCtx(LOG_TAG, "computed offsets", {
		ref = ref,
		tex = hit.texture,
		zPix = zPix,
		listed = entry ~= nil,
	})
	return xOff, yOff, zOff
end

--- Narrow pool to shortlist and pick one square by hashed distribution.
--- @param state table
--- @param place SceneBuilder.PlaceSpec
--- @param shortlist IsoGridSquare[]|nil
--- @param ctx table|nil  -- { kind?:string, type?:string, occurrence?:integer,
---                       --   anchorName?:string, poolStrategy?:string }
--- @return IsoGridSquare|nil
local function chooseSquareFromShortlist(state, place, shortlist, ctx)
	if not shortlist or #shortlist == 0 then
		return nil
	end
	assertf(type(place) == "table", "chooseSquareFromShortlist bad place spec")

	state._placeCount = (state._placeCount or 0) + 1

	local key = U.buildKey(
		(ctx and ctx.poolStrategy) or (place.strategy or "any"),
		ctx and ctx.anchorName or "",
		ctx and ctx.kind or "",
		ctx and ctx.type or "",
		tostring(ctx and ctx.occurrence or state._placeCount),
		tostring(#shortlist),
		tostring(place.anchor_proximity or 2),
		tostring(place.respect_strategy and 1 or 0),
		tostring(place.proximity_fallback or "ignore-proximity-keep-strategy")
	)

	local idx = U.pickIdxHash(key, #shortlist)
	return shortlist[idx]
end

local function addItemMulti(inv, typeOrPair)
	if type(typeOrPair) == "table" then
		local typeName, qty = typeOrPair[1], typeOrPair[2] or 1
		for _ = 1, qty do
			local it = mkItem(typeName)
			if it then
				inv:AddItem(it)
			else
				log("addItemMulti mkItem failed for " .. tostring(typeName))
			end
		end
	else
		local it = mkItem(typeOrPair)
		if it then
			inv:AddItem(it)
		else
			log("addItemMulti mkItem failed for " .. tostring(typeOrPair))
		end
	end
end

local function addWorldMulti(state, sq, typeName, qty, opts)
	assertf(sq and sq.AddWorldInventoryItem, "addWorldMulti bad square " .. tostring(sq))
	local created = {}
	local n = math.max(1, tonumber(qty) or 1)
	opts = opts or {}

	local function placeOne()
		local item = mkItem(typeName)
		if not item then
			log("addWorldMulti mkItem failed " .. tostring(typeName))
			return
		end
		local baseRef = opts.reference or ""
		local ref = (baseRef == "" and "" or (baseRef .. " ")) .. "addWorldMulti " .. typeName
		local mayAdjustZ = (opts.mayAdjustZ ~= false)
		local xOff, yOff, zOff = computeOffsets(sq, mayAdjustZ, opts)
		log(
			"Placement offsets x="
				.. tostring(xOff)
				.. " y="
				.. tostring(yOff)
				.. " z="
				.. tostring(zOff)
				.. " mayAdjustZ="
				.. tostring(mayAdjustZ)
		)
		local wi = sq:AddWorldInventoryItem(item, xOff, yOff, zOff)
		if not wi then
			log("addWorldMulti AddWorldInventoryItem failed " .. tostring(typeName))
			return
		end
		if state and state.tag then
			Lifecycle.tagAndRegister(wi, state.tag)
		end
		created[#created + 1] = wi
	end

	for _ = 1, n do
		placeOne()
	end

	return created
end

---@param list any
---@return table
local function toLuaList(list)
	if list == nil then
		return {}
	end
	if type(list) == "table" and #list > 0 then
		return list
	end
	local sizeFn = list and list.size
	local getFn = list and list.get
	if type(sizeFn) == "function" and type(getFn) == "function" then
		local okSize, size = pcall(sizeFn, list)
		if not okSize or type(size) ~= "number" then
			return {}
		end
		local out = {}
		for i = 0, size - 1 do
			local okGet, v = pcall(getFn, list, i)
			if okGet and v ~= nil then
				out[#out + 1] = v
			end
		end
		return out
	end
	return {}
end

-- Once-per-spec: normalize place, resolve pool, apply proximity, log.
local function _gatherPoolCtx(state, roomDef, spec)
	local place = Resolvers.ensurePlace(spec.place)
	local det = isDeterministic(place, state)

	local rawPool, poolStrategy = Resolvers.resolvePool(roomDef, place)
	local pool, anchorName = _applyProximityPass(state, roomDef, place, rawPool)

	U.logCtx(LOG_TAG, "placer pool after proximity", {
		pool = pool and #pool or 0,
		from = poolStrategy or place.strategy,
		anchor = anchorName or place.anchor or "",
	})

	return {
		place = place,
		det = det,
		pool = pool,
		poolStrategy = poolStrategy,
		anchorName = anchorName,
	}
end

-- Build shortlist from pool with K and determinism; log.
local function _makeShortlist(ctx, state)
	local place, pool, det = ctx.place, ctx.pool, ctx.det
	local K = place.maxPlacementSquares or (state and state.maxPlacementSquares) or 1
	local sl = pool and U.shortlistFromPool(pool, K, det) or nil

	U.logCtx(LOG_TAG, "shortlist ready", {
		size = sl and #sl or 0,
		det = det,
		K = K,
	})
	return sl
end

--- @param state table
--- @param roomDef RoomDef
--- @param spec table
--- @param sqOverride IsoGridSquare|nil
--- @return table, IsoGridSquare|nil
local function placeCorpse(state, roomDef, spec, sqOverride)
	-- Gather once: place, det, pool(+proximity), anchor, poolStrategy
	local ctx = _gatherPoolCtx(state, roomDef, spec)
	local place, anchorName, poolStrategy = ctx.place, ctx.anchorName, ctx.poolStrategy

	-- Narrow pool to shortlist (K, deterministic)
	local shortlist = _makeShortlist(ctx, state)

	-- Decide square: prefer shortlist, else explicit override, else nil
	local sq = sqOverride
	if not sq and shortlist and #shortlist > 0 then
		sq = chooseSquareFromShortlist(state, place, shortlist, {
			kind = "corpse",
			type = spec.outfit or spec.item,
			anchorName = anchorName,
			poolStrategy = poolStrategy,
		})
	end

	if sq then
		U.logCtx(LOG_TAG, "shortlist picked", { x = sq:getX(), y = sq:getY(), z = sq:getZ() })
	else
		U.logCtx(LOG_TAG, "shortlist picked none", {})
	end

	if not sq then
		log("PlaceCorpse corpse skip")
		return {}, nil
	end

	-- corpse creation + loot
	local bruising = (spec.blood and spec.blood.bruising) or 5
	local floor_splats = (spec.blood and spec.blood.floor_splats) or 0
	local crawlerChance = spec.crawlerChance or 0
	local outfit = getDefaultCorpseOutfit()
	if type(spec.outfit) == "string" then
		outfit = spec.outfit:match("^%s*(.-)%s*$")
	elseif spec.outfit ~= nil then
		log("PlaceCorpse invalid outfit non-string using default " .. getDefaultCorpseOutfit())
	end

	if not (RandomizedWorldBase and type(RandomizedWorldBase.createRandomDeadBody) == "function") then
		log("placeCorpse missing RandomizedWorldBase.createRandomDeadBody so skipping corpse")
		return {}, sq
	end

	local dir = IsoDirections and IsoDirections.getRandom and IsoDirections.getRandom() or nil
	if not dir and IsoDirections and IsoDirections.N then
		dir = IsoDirections.N
	end

	local corpse = RandomizedWorldBase.createRandomDeadBody(sq, dir, bruising, crawlerChance, outfit)
	if type(addBloodSplat) == "function" then
		addBloodSplat(sq, floor_splats)
	end

	if corpse and corpse.getContainer then
		Lifecycle.tagAndRegister(corpse, state.tag)
		local inv = corpse:getContainer()
		if inv then
			for _, t in ipairs(spec.onBody or {}) do
				addItemMulti(inv, t)
			end
		end
	end
	for _, t in ipairs(spec.dropNear or {}) do
		addWorldMulti(state, sq, t, nil, {
			mayAdjustZ = false,
			reference = " place corpse " .. outfit,
		})
	end

	local list = {}
	if corpse then
		list[#list + 1] = corpse
	end
	return list, sq
end

--- @param state table
--- @param roomDef RoomDef
--- @param spec table
--- @param sqOverride IsoGridSquare|nil
--- @return table, IsoGridSquare|nil
local function placeContainer(state, roomDef, spec, sqOverride)
	-- Gather once: place, det, pool(+proximity), anchor, poolStrategy
	local ctx = _gatherPoolCtx(state, roomDef, spec)
	local place, anchorName, poolStrategy = ctx.place, ctx.anchorName, ctx.poolStrategy

	-- Narrow pool to shortlist (K, deterministic)
	local shortlist = _makeShortlist(ctx, state)

	-- Decide square: prefer shortlist, else explicit override, else nil
	local sq = sqOverride
	if not sq and shortlist and #shortlist > 0 then
		sq = chooseSquareFromShortlist(state, place, shortlist, {
			kind = "container",
			type = spec.item,
			anchorName = anchorName,
			poolStrategy = poolStrategy,
		})
	end

	if sq then
		U.logCtx(LOG_TAG, "shortlist picked", { x = sq:getX(), y = sq:getY(), z = sq:getZ() })
	else
		U.logCtx(LOG_TAG, "shortlist picked none", {})
	end

	if not sq then
		log("placeContainer container skip")
		return {}, nil
	end

	-- create the container item and fill contents
	local tn = normType(spec.item)
	if not tn then
		log("placeContainer cannot resolve spec.item to string " .. tostring(spec.item))
		return {}, sq
	end

	local bag = mkItem(tn)
	if not bag then
		log("placeContainer mkItem failed for container " .. tostring(spec.item))
		return {}, sq
	end

	if not bag:IsInventoryContainer() and #(spec.contains or {}) > 0 then
		log("placeContainer item not a container addTo ignored " .. tostring(spec.item))
	end
	if bag:IsInventoryContainer() then
		---@cast bag InventoryContainer
		local inv = bag:getInventory()
		for _, t in ipairs(spec.contains or {}) do
			addItemMulti(inv, t)
		end
	end

	local mayAdjustZ = (spec.mayAdjustZ ~= false)
	local xOff, yOff, zOff = computeOffsets(sq, mayAdjustZ, {
		reference = " placeContainer place.strategy=" .. tostring(place.strategy) .. " item=" .. tostring(spec.item),
	})

	local wi = sq:AddWorldInventoryItem(bag, xOff, yOff, zOff)
	if not wi then
		log("placeContainer AddWorldInventoryItem failed for item=" .. tostring(tn))
		return {}, sq
	end
	if state and state.tag then
		Lifecycle.tagAndRegister(wi, state.tag)
	end

	return { wi }, sq
end

--- Scatter items across viable squares using pool + hashed distribution.
--- @param state table
--- @param roomDef RoomDef
--- @param spec table
--- @param sqOverride IsoGridSquare|nil
--- @return table, nil
local function placeScatter(state, roomDef, spec, sqOverride)
	assertf(roomDef, "placeScatter needs RoomDef")
	assertf(type(spec) == "table", "placeScatter spec table required")

	-- Gather once: place, det, pool(+proximity), anchor, poolStrategy
	local ctx = _gatherPoolCtx(state, roomDef, spec)
	local place, det = ctx.place, ctx.det
	local anchorName, poolStrategy = ctx.anchorName, ctx.poolStrategy
	local pool = ctx.pool

	-- center fallback used when shortlist pick fails
	local centerSq = sqOverride
	if not centerSq then
		centerSq = Resolvers.resolveSquare(state, roomDef, place)
	end

	-- Normalize item list (unchanged)
	local rawItems = spec.items
	if not (rawItems and #rawItems > 0) then
		if spec.item ~= nil then
			rawItems = { spec.item }
		else
			log("[Scatter] nothing to place (spec.items/spec.item missing)")
			return {}, nil
		end
	end

	local entries = {}
	for _, t in ipairs(rawItems) do
		local tn
		local q = 1
		if type(t) == "table" then
			tn = normType(t[1] or t.item or t.type or t.name)
			q = tonumber(t[2]) or tonumber(t.qty) or 1
		else
			tn = normType(t)
		end
		if tn and q and q > 0 then
			entries[#entries + 1] = { tn, q }
		else
			log("[Scatter] skipping bad item spec " .. tostring(t))
		end
	end
	if #entries == 0 then
		log("[Scatter] no valid entries after normalization")
		return {}, nil
	end

	local maxEntries = tonumber(spec.maxItemNum) or #entries
	if maxEntries < 1 then
		maxEntries = 1
	end
	if maxEntries > #entries then
		maxEntries = #entries
	end

	local count = tonumber(spec.count or 1) or 1
	if count < 1 then
		count = 1
	end

	-- explicit K determination (unchanged)
	local k = tonumber(place.maxPlacementSquares)
	if not k or k < 1 then
		k = tonumber(state and state.maxPlacementSquares) or 1
	end

	log(
		("[Scatter] Begin K=%d  pool=%s  entries=%d  count=%d"):format(
			k,
			tostring(pool and #pool or 0),
			#entries,
			count
		)
	)

	local results = {}

	for i = 1, count do
		local shortlist = nil
		if pool and #pool > 0 then
			shortlist = U.shortlistFromPool(pool, k, det)
			U.logCtx(LOG_TAG, "shortlist ready", {
				size = shortlist and #shortlist or 0,
				det = isDeterministic(place, state),
				K = place.maxPlacementSquares or (state and state.maxPlacementSquares) or 1,
			})
		else
			log("[Scatter] no pool, using center fallback")
		end

		for eIdx, pair in ipairs(U.shortlistFromPool(entries, maxEntries, det) or {}) do
			local tn, qty = pair[1], pair[2]

			local sq = nil
			if shortlist and #shortlist > 0 then
				sq = chooseSquareFromShortlist(state, place, shortlist, {
					kind = "scatter",
					type = tn,
					occurrence = (i * 1000) + eIdx,
					anchorName = anchorName or (type(place.anchor) == "string" and place.anchor or ""),
					poolStrategy = poolStrategy,
				})

				if sq then
					log(
						("[Scatter] picked square #%d of %d for item=%s  coords=(%d,%d,%d)"):format(
							eIdx,
							#shortlist,
							tn,
							sq:getX(),
							sq:getY(),
							sq:getZ()
						)
					)
				else
					log(("[Scatter] chooseSquareFromShortlist returned nil for item=%s"):format(tn))
				end
			end

			if not sq then
				sq = centerSq
			end
			if not sq then
				log("[Scatter] no square (pool empty, no center)")
				break
			end

			local mayAdjustZ = (spec.mayAdjustZ ~= false)
			local ref = " scatter place.strategy=" .. tostring(place.strategy)
			local created = addWorldMulti(state, sq, tn, qty, {
				mayAdjustZ = mayAdjustZ,
				reference = ref,
			})
			if created and created[1] then
				for _, wi in ipairs(created) do
					results[#results + 1] = wi
				end
			end
		end
	end

	log(("[Scatter] Finished spawned %d world items"):format(#results))
	return results, nil
end

--- Spawn live zombies centered around a chosen square.
--- Uses addZombiesInOutfit(x, y, z, totalZombies, outfit, femaleChance).
--- @param state table
--- @param roomDef RoomDef
--- @param spec table
--- @param sqOverride IsoGridSquare|nil
--- @return table, IsoGridSquare|nil
local function placeZombies(state, roomDef, spec, sqOverride)
	assertf(roomDef, "placeZombies needs RoomDef")
	assertf(type(spec) == "table", "placeZombies spec table required")

	if type(addZombiesInOutfit) ~= "function" then
		log("placeZombies missing addZombiesInOutfit so skipping zombies")
		return {}, nil
	end

	-- Gather once: place, det, pool(+proximity), anchor, poolStrategy
	local ctx = _gatherPoolCtx(state, roomDef, spec)
	local place, anchorName, poolStrategy = ctx.place, ctx.anchorName, ctx.poolStrategy

	-- Narrow pool to shortlist (K, deterministic)
	local shortlist = _makeShortlist(ctx, state)

	-- Decide square: prefer shortlist, else explicit override, else last-resort resolveSquare
	local sq = sqOverride
	if not sq and shortlist and #shortlist > 0 then
		sq = chooseSquareFromShortlist(state, place, shortlist, {
			kind = "zombies",
			type = spec.outfit or "",
			anchorName = anchorName,
			poolStrategy = poolStrategy,
		})
	end
	if not sq then
		sq = Resolvers.resolveSquare(state, roomDef, place)
	end

	if not sq then
		log("placeZombies no square so skipping zombies")
		return {}, nil
	end

	local count = tonumber(spec.count) or 1
	if count < 1 then
		count = 1
	end
	count = math.floor(count)

	local femaleChance = tonumber(spec.femaleChance)
	if femaleChance == nil then
		femaleChance = 50
	end
	if femaleChance < 0 then
		femaleChance = 0
	elseif femaleChance > 100 then
		femaleChance = 100
	end

	local x, y, z = sq:getX(), sq:getY(), sq:getZ()
	local ok, result = pcall(addZombiesInOutfit, x, y, z, count, spec.outfit, femaleChance)
	if not ok then
		U.logCtx(LOG_TAG, "placeZombies addZombiesInOutfit error", { err = tostring(result) })
		return {}, sq
	end

	local created = toLuaList(result)
	U.logCtx(LOG_TAG, "placeZombies spawned", {
		countRequested = count,
		countCreated = #created,
		x = x,
		y = y,
		z = z,
	})
	return created, sq
end

local function spawnOne(state, roomDef, spec)
	local valid = spec and (spec.kind == "corpse" or spec.kind == "container" or spec.kind == "scatter" or spec.kind == "zombies")
	assertf(valid, "spawnOne invalid spec.kind " .. tostring(spec and spec.kind))
	spec.place = Resolvers.ensurePlace(spec.place)

	-- We resolve a center square only for scatter (fallback center).
	-- For corpse/container we let placers use the resolver pool first.
	local centerSq = nil
	if spec.kind == "scatter" then
		centerSq = Resolvers.resolveSquare(state, roomDef, spec.place)
	end

	local anchorName = spec.place and Resolvers.normAnchorRef(spec.place.anchor) or nil
	local pos = nil
	if centerSq then
		pos = { x = centerSq:getX(), y = centerSq:getY(), z = centerSq:getZ() }
	end

	local ctx = {
		roomDef = roomDef,
		anchorName = anchorName,
		position = pos, -- may be nil for corpse/container (pool decides)
		spec = spec.place,
	}

	if type(spec.preSpawn) == "function" then
		pcall(spec.preSpawn, ctx)
	end

	local createdList = {}
	if spec.kind == "corpse" then
		createdList = ({ placeCorpse(state, roomDef, spec, nil) })[1] or {}
	elseif spec.kind == "container" then
		createdList = ({ placeContainer(state, roomDef, spec, nil) })[1] or {}
	elseif spec.kind == "scatter" then
		createdList = ({ placeScatter(state, roomDef, spec, centerSq) })[1] or {}
	elseif spec.kind == "zombies" then
		local created, sq = placeZombies(state, roomDef, spec, nil)
		createdList = created or {}
		if sq then
			ctx.position = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
		end
	end

	if type(spec.postSpawn) == "function" then
		pcall(spec.postSpawn, ctx, createdList)
	end
end

-- public API
Placers.addItemMulti = addItemMulti
Placers.addWorldMulti = addWorldMulti
Placers.placeCorpse = placeCorpse
Placers.placeContainer = placeContainer
Placers.placeScatter = placeScatter
Placers.placeZombies = placeZombies
Placers.spawnOne = spawnOne
Placers.getDefaultCorpseOutfit = getDefaultCorpseOutfit
Placers.normType = normType

---@return SceneBuilder.Placers
return Placers
