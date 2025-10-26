-- Scans a RoomDef for squares containing furniture surfaces suitable for item placement.
-- Build 42 friendly. ≤100 chars/line. No colons in logs.
-- Returns { { sq=IsoGridSquare, z=number, obj=IsoObject, texture=string }, ... }
local U = require("SceneBuilder/util") -- for U.log/U.assertf
local LOG_TAG = "SceneBuilder surface_scan"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf

local SurfaceScan = {}
-- Global defaults kept in one place.
local DEFAULT_WHITELIST = { "counter", "table", "desk", "workbench" }
local DEFAULT_MIN_SURF = 10

--- @class SurfaceHit
--- @field sq IsoGridSquare
--- @field z number
--- @field obj IsoObject
--- @field texture string

--- @class surfaceHitOpts
--- @field minSurfaceHeight? number
--- @field whitelist? table
--- @field limit? number
--- @field reference? string

-- Extract numeric "Surface" property from the object's sprite.
-- Indicates top-surface height in pixels; nil means not a placable object.
--- @return number|nil
local function surfaceZ(obj)
	local sp = obj and obj:getSprite()
	if not sp then
		return nil
	end
	local props = sp:getProperties()
	if not props then
		return nil
	end
	local v = props:Val("Surface")
	return v and tonumber(v) or nil
end

--- Resolve whitelist and min surface consistently across all functions.
--- @param opts SceneBuilder.SurfaceHitOpts|nil
local function _getWhitelist(opts)
	return (opts and opts.whitelist) or DEFAULT_WHITELIST
end

--- @return number
local function _getMinSurfaceHeight(opts)
	local v = opts and opts.minSurfaceHeight
	v = tonumber(v)
	return v and v or DEFAULT_MIN_SURF
end

-- Simple case-insensitive texture whitelist check.
--- @return boolean
local function _isWhitelisted(tex, wl)
	if not wl or #wl == 0 then
		log("Warning: whitelis to check texture against is missing or empty")
		return false
	end

	if not tex then
		return false
	end
	local low = tostring(tex):lower()
	for _, pat in ipairs(wl) do
		if low:find(pat, 1, true) then
			return true
		end
	end
	return false
end

--- Internal cache of surface hits keyed by IsoGridSquare.
--- Weak keys ensure automatic cleanup when the square is unloaded.
--- @TODO implement cleanup routine as kahlua does not have weak tables and we don't want to memory-leak
--- @type table<IsoGridSquare, (SurfaceHit|nil)>
local surfaceHitBySq = setmetatable({}, { __mode = "k" })

-- local: probe this ONE square for a best surface hit, or nil
--- @param sq IsoGridSquare   The square to probe
--- @param opts SceneBuilder.SurfaceHitOpts
--- @return SurfaceHit|nil
local function _probeSquareForSurface(sq, opts)
	if not sq then
		return nil
	end
	local minZ = _getMinSurfaceHeight(opts)
	local wl = _getWhitelist(opts)
	local objs = sq:getObjects()
	if not objs then
		return nil
	end

	local best, bestZ = nil, -1
	for i = 0, objs:size() - 1 do
		local obj = objs:get(i)
		if obj then
			local z = surfaceZ(obj)
			if z and z >= minZ then
				local tex = obj:getTextureName() or ""
				if _isWhitelisted(tex, wl) and z > bestZ then
					bestZ = z
					best = { sq = sq, z = z, obj = obj, texture = tex }
				elseif z >= minZ then
					log("_probeSquareForSurface reject " .. tostring(tex) .. " z " .. tostring(z))
				end
			elseif z then
				log("_probeSquareForSurface too low z " .. tostring(z))
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
--- @param hit SurfaceHit|nil
--- @return nil
function SurfaceScan.rememberSurfaceHit(sq, hit)
	if not sq or not hit then
		return
	end
	surfaceHitBySq[sq] = hit
end

--- Retrieves a previously remembered surface hit for a given square.
--- Returns nil if no hit is cached or the entry was GC-collected.
---
--- @param sq IsoGridSquare The square to look up.
--- @param opts SceneBuilder.SurfaceHitOpts
--- @return SurfaceHit|nil
function SurfaceScan.getSurfaceHit(sq, opts)
	if not sq then
		return nil
	end
	local hit = surfaceHitBySq[sq]
	if hit ~= nil then
		return hit
	end
	hit = _probeSquareForSurface(sq, opts)
	if hit then
		surfaceHitBySq[sq] = hit
		log("getSurfaceHit cache-hit " .. tostring(hit.texture) .. " z " .. tostring(hit.z))
	end
	return hit
end

---@param room IsoRoom
---@param opts SceneBuilder.SurfaceHitOpts|nil
---@return SurfaceHit[]
function SurfaceScan.scanRoomForSurfaces(room, opts)
	assert(room and room.getSquares, "scanRoomForSurfaces room with getSquares required")

	opts = opts or {}
	local wl = _getWhitelist(opts)
	local minZ = _getMinSurfaceHeight(opts)
	local limit = tonumber(opts.limit)

	local out = {}
	local squares = room:getSquares()
	if not squares or squares:size() == 0 then
		log("scanRoomForSurfaces room has no squares")
		return out
	end

	log(
		"scanRoomForSurfaces scan start wl "
			.. tostring(#wl)
			.. " minZ "
			.. tostring(minZ)
			.. " lim "
			.. tostring(limit or 0)
	)

	-- Decide if an object on a square qualifies as a placable surface.
	local function consider(obj, sq)
		if not obj or not obj.getTextureName then
			return nil
		end
		local tex = obj:getTextureName()
		if not _isWhitelisted(tex, wl) then
			return nil
		end
		local z = surfaceZ(obj)
		if not z or z < minZ then
			return nil
		end
		return { sq = sq, z = z, obj = obj, texture = tex }
	end

	for i = 0, squares:size() - 1 do
		local sq = squares:get(i)
		if sq and sq.getObjects then
			local objs = sq:getObjects()
			if objs and objs:size() > 0 then
				for j = 0, objs:size() - 1 do
					local hit = consider(objs:get(j), sq)
					if hit then
						out[#out + 1] = hit
						-- seed the central cache for this square. Bit of side-channel efficiency helping
						SurfaceScan.rememberSurfaceHit(hit.sq, hit)
						log("SurfScan hit " .. tostring(hit.texture) .. " z " .. tostring(hit.z))
						if limit and #out >= limit then
							return out
						end
						break
					end
				end
			end
		end
	end
	log("scanRoomForSurfaces scan done hits " .. tostring(#out))

	return out
end

--- Returns the current default configuration for surface scanning.
--- Useful for debugging or external introspection.
---
--- @return table<string, any> defaults
---   defaults.whitelist  table<string>
---   defaults.minSurface number
function SurfaceScan.getDefaults()
	return {
		whitelist = DEFAULT_WHITELIST,
		minSurface = DEFAULT_MIN_SURF,
	}
end

return SurfaceScan
