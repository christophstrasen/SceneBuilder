-- Scans a RoomDef for squares containing furniture surfaces suitable for item placement.
-- Returns { { sq=IsoGridSquare, z=number, obj=IsoObject, texture=string }, ... }
local U = require("SceneBuilder/util") -- for U.log/U.assertf
local LOG_TAG = "SceneBuilder surface_scan"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf

local SurfaceScan = {}
local DEFAULT_WHITELIST = { "counter", "table", "desk", "workbench" }
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
	if not obj or type(obj.getSprite) ~= "function" then
		return nil
	end
	local okSprite, sp = pcall(obj.getSprite, obj)
	if not okSprite or not sp then
		return nil
	end
	if type(sp.getProperties) ~= "function" then
		return nil
	end
	local okProps, props = pcall(sp.getProperties, sp)
	if not okProps or not props then
		return nil
	end
	if type(props.Val) ~= "function" then
		return nil
	end
	local okVal, v = pcall(props.Val, props, "Surface")
	if not okVal then
		return nil
	end
	return v and tonumber(v) or nil
end

-- Diagnostic logging for Surface property discovery (Build 42 changes can affect this).
-- Logs once per spriteRef + stage when we fail to reach properties/Val("Surface"), and once when we succeed.
-- Kept bounded to avoid spamming logs in large rooms.
do
	-- Keep a reference so luacheck doesn't treat the initial definition as dead code.
	local _surfaceZ = surfaceZ
	local SURFACE_Z_LOG_MAX = 256
	local seen = {}
	local order = {}

	local function safeLogValue(v)
		-- Avoid colon to prevent truncation in B42 logs.
		return tostring(v):gsub(":", ";")
	end

	local function logOnce(key, msg, ctx)
		if seen[key] then
			return
		end
		seen[key] = true
		order[#order + 1] = key
		if #order > SURFACE_Z_LOG_MAX then
			local oldKey = table.remove(order, 1)
			if oldKey then
				seen[oldKey] = nil
			end
		end
		U.logCtx(LOG_TAG, msg, ctx)
	end

	local function surfaceZLogged(obj)
		local spriteRef = getSpriteRef(obj) or "<unknown>"

		if not obj or type(obj.getSprite) ~= "function" then
			logOnce("noGetSprite|" .. spriteRef, "surfaceZ missing getSprite", { sprite = spriteRef })
			return nil
		end

		local okSprite, spOrErr = pcall(obj.getSprite, obj)
		if not okSprite then
			logOnce("getSpriteErr|" .. spriteRef, "surfaceZ getSprite failed", {
				sprite = spriteRef,
				err = safeLogValue(spOrErr),
			})
			return nil
		end
		local sp = spOrErr
		if not sp then
			logOnce("noSprite|" .. spriteRef, "surfaceZ getSprite returned nil", { sprite = spriteRef })
			return nil
		end

		if type(sp.getProperties) ~= "function" then
			logOnce("noGetProperties|" .. spriteRef, "surfaceZ missing getProperties", { sprite = spriteRef })
			return nil
		end

		local okProps, propsOrErr = pcall(sp.getProperties, sp)
		if not okProps then
			logOnce("getPropertiesErr|" .. spriteRef, "surfaceZ getProperties failed", {
				sprite = spriteRef,
				err = safeLogValue(propsOrErr),
			})
			return nil
		end
		local props = propsOrErr
		if not props then
			logOnce("noProperties|" .. spriteRef, "surfaceZ getProperties returned nil", { sprite = spriteRef })
			return nil
		end

		if type(props.Val) ~= "function" then
			logOnce("noValFn|" .. spriteRef, "surfaceZ missing properties Val", { sprite = spriteRef })
			return nil
		end

		local okVal, vOrErr = pcall(props.Val, props, "Surface")
		if not okVal then
			logOnce("valErr|" .. spriteRef, "surfaceZ properties Val Surface failed", {
				sprite = spriteRef,
				err = safeLogValue(vOrErr),
			})
			return nil
		end

		if vOrErr == nil then
			logOnce("noSurface|" .. spriteRef, "surfaceZ missing Surface", { sprite = spriteRef })
			return nil
		end

		local n = tonumber(vOrErr)
		if n == nil then
			logOnce("badSurface|" .. spriteRef, "surfaceZ Surface not numeric", {
				sprite = spriteRef,
				surface = safeLogValue(vOrErr),
			})
			return nil
		end

		logOnce("surfaceOk|" .. spriteRef, "surfaceZ got Surface", {
			sprite = spriteRef,
			surface = safeLogValue(vOrErr),
		})
		return n
	end

	surfaceZ = surfaceZLogged
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
		log("Warning whitelist to check texture against is missing or empty")
		return false
	end

	if not tex then
		return false
	end
	local low = tostring(tex):lower()
	for _, pat in ipairs(wl) do
		local needle = tostring(pat):lower()
		if needle ~= "" and low:find(needle, 1, true) then
			return true
		end
	end
	return false
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
					local tex = getSpriteRef(obj) or ""
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
--- @return SurfaceHit|nil
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
			if not obj then
				return nil
			end
			local tex = getSpriteRef(obj)
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
--- @return table<string, any> defaults
---   defaults.whitelist  table<string>
---   defaults.minSurface number
function SurfaceScan.getDefaults()
	return {
		whitelist = DEFAULT_WHITELIST,
		minSurface = DEFAULT_MIN_SURF,
	}
end

function SurfaceScan.clearCache()
	surfaceHitByKey = {}
	surfaceHitKeyOrder = {}
end

return SurfaceScan
