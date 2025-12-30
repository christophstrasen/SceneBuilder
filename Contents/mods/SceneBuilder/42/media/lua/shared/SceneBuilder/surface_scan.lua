-- Scans a RoomDef for squares containing furniture surfaces suitable for item placement.
-- Returns { { sq=IsoGridSquare, z=number, obj=IsoObject, texture=string }, ... }
local U = require("SceneBuilder/util") -- for U.log/U.assertf
local LOG_TAG = "SceneBuilder surface_scan"
local log = U.makeLogger(LOG_TAG)

local SurfaceScan = {}
local DEFAULT_MIN_SURF = 10
local SURFACE_HIT_CACHE_MAX = 512

local function getSpriteRef(obj)
	if not obj then
		return nil
	end
	if type(obj.getSpriteName) == "function" then
		return obj:getSpriteName()
	end
	if type(obj.getTextureName) == "function" then
		return obj:getTextureName()
	end
	return nil
end

--- @class SceneBuilder.SurfaceHit
--- @field sq IsoGridSquare
--- @field z number
--- @field obj IsoObject
--- @field texture string

--- @class SceneBuilder.SurfaceHitOpts
--- @field minSurfaceHeight? number
--- @field limit? number
--- @field reference? string
--- @field square_padding? number

-- Extract surface height in pixels from the object (Build 42).
-- We intentionally rely on the engine-provided method to avoid brittle sprite-property heuristics.
--- @return number|nil
local function surfaceZ(obj)
	if not obj or type(obj.getSurfaceOffsetNoTable) ~= "function" then
		return nil
	end
	local ok, v = pcall(obj.getSurfaceOffsetNoTable, obj)
	local n = ok and tonumber(v) or nil
	return (n and n > 0) and n or nil
end

--- @return number
local function _getMinSurfaceHeight(opts)
	local v = opts and opts.minSurfaceHeight
	v = tonumber(v)
	return v and v or DEFAULT_MIN_SURF
end

-- Internal cache of surface hits keyed by square coordinates.
-- This is intentionally size-bounded because Kahlua does not support weak tables.
local surfaceHitByKey = {}
local surfaceHitKeyOrder = {}

local function sqKey(sq)
	if sq and sq.getX and sq.getY and sq.getZ then
		return tostring(sq:getX()) .. "," .. tostring(sq:getY()) .. "," .. tostring(sq:getZ())
	end
	return tostring(sq)
end

-- local: probe this ONE square for a best surface hit, or nil
--- @param sq IsoGridSquare   The square to probe
--- @param opts SceneBuilder.SurfaceHitOpts
--- @return SceneBuilder.SurfaceHit|nil
local function _probeSquareForSurface(sq, opts)
	if not sq then
		return nil
	end
	-- Option B: accept only squares flagged as tables by the engine.
	-- This avoids brittle sprite-name heuristics and matches vanilla Build 42 usage.
	if type(sq.has) ~= "function" or not sq:has("IsTable") then
		return nil
	end
	local minZ = _getMinSurfaceHeight(opts)
	local objs = sq:getObjects()
	if not objs then
		return nil
	end

	local best, bestZ = nil, -1
	for i = 0, objs:size() - 1 do
		local obj = objs:get(i)
		if obj then
			local z = surfaceZ(obj)
			if z and z >= minZ and z > bestZ then
				bestZ = z
				best = { sq = sq, z = z, obj = obj, texture = getSpriteRef(obj) or "" }
			end
		end
	end
	if best then
		log(
			"_probeSquareForSurface hit "
				.. tostring(best.texture)
				.. " z "
				.. tostring(best.z)
				.. " at sq "
				.. best.sq:getX()
				.. ","
				.. best.sq:getY()
		)
	end
	return best
end

	--- Remembers a surface hit for a given IsoGridSquare.
	--- Safe to call repeatedly; the newest hit overwrites any previous one.
	---
	--- @param sq IsoGridSquare   The square associated with the surface hit.
	--- @param hit SceneBuilder.SurfaceHit|nil
	--- @return nil
	function SurfaceScan.rememberSurfaceHit(sq, hit)
	if not sq or not hit then
		return
	end
	local key = sqKey(sq)
	if surfaceHitByKey[key] == nil then
		surfaceHitKeyOrder[#surfaceHitKeyOrder + 1] = key
		if #surfaceHitKeyOrder > SURFACE_HIT_CACHE_MAX then
			local oldKey = table.remove(surfaceHitKeyOrder, 1)
			if oldKey then
				surfaceHitByKey[oldKey] = nil
			end
		end
	end
	surfaceHitByKey[key] = { texture = hit.texture, z = hit.z, obj = hit.obj }
end

--- Retrieves a previously remembered surface hit for a given square.
--- Returns nil if no hit is cached or the entry was GC-collected.
---
--- @param sq IsoGridSquare The square to look up.
--- @param opts SceneBuilder.SurfaceHitOpts
--- @return SceneBuilder.SurfaceHit|nil
function SurfaceScan.getSurfaceHit(sq, opts)
	if not sq then
		return nil
	end
	local cached = surfaceHitByKey[sqKey(sq)]
	if cached ~= nil then
		return { sq = sq, z = cached.z, obj = cached.obj, texture = cached.texture }
	end

	local hit = _probeSquareForSurface(sq, opts)
	if hit then
		SurfaceScan.rememberSurfaceHit(sq, hit)
		log("getSurfaceHit cache hit " .. tostring(hit.texture) .. " z " .. tostring(hit.z))
	end
	return hit
end

---@param room IsoRoom
---@param opts SceneBuilder.SurfaceHitOpts|nil
---@return SceneBuilder.SurfaceHit[]
function SurfaceScan.scanRoomForSurfaces(room, opts)
	assert(room and room.getSquares, "scanRoomForSurfaces room with getSquares required")

	opts = opts or {}
	local minZ = _getMinSurfaceHeight(opts)
	local limit = tonumber(opts.limit)

	local out = {}
	local squares = room:getSquares()
	if not squares or squares:size() == 0 then
		log("scanRoomForSurfaces room has no squares")
		return out
	end

	log(
		"scanRoomForSurfaces scan start minZ "
			.. tostring(minZ)
			.. " lim "
			.. tostring(limit or 0)
	)

	for i = 0, squares:size() - 1 do
		local sq = squares:get(i)
		if sq then
			local hit = _probeSquareForSurface(sq, opts)
			if hit then
				out[#out + 1] = hit
				SurfaceScan.rememberSurfaceHit(hit.sq, hit)
				log("SurfScan hit " .. tostring(hit.texture) .. " z " .. tostring(hit.z))
				if limit and #out >= limit then
					return out
				end
			end
		end
	end
	log("scanRoomForSurfaces scan done hits " .. tostring(#out))

	return out
end

--- Returns the current default configuration for surface scanning.
--- Useful for debugging or external introspection.
--- @return table<string, any> defaults
---   defaults.whitelist  table<string>
---   defaults.minSurface number
function SurfaceScan.getDefaults()
	return {
		whitelist = nil,
		minSurface = DEFAULT_MIN_SURF,
	}
end

function SurfaceScan.clearCache()
	surfaceHitByKey = {}
	surfaceHitKeyOrder = {}
end

return SurfaceScan
