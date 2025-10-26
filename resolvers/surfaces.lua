-- SceneBuilder/resolvers/surfaces.lua
-- "tables_and_counters" via SurfaceScan. Minimal, opinionated defaults.

local U = require("SceneBuilder/util") -- for U.log/U.assertf
local LOG_TAG = "SceneBuilder resolver/surfaces"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf

local Registry = require("SceneBuilder/registry")
local SurfaceScan = require("SceneBuilder/surface_scan")

-- rank hits high-to-low by z (surface height proxy)
local function rankByZ(hits)
	table.sort(hits, function(a, b)
		local az = a.z or 0
		local bz = b.z or 0
		if az ~= bz then
			return az > bz
		end
		return tostring(a.texture or "") < tostring(b.texture or "")
	end)
	return hits
end

---@param roomDef RoomDef
---@param place SceneBuilder.PlaceSpec|nil
---@return IsoGridSquare[]|nil
local function resolveTablesAndCounters(roomDef, place)
	log("resolveTablesAndCounters entering for place.strategy=" .. tostring(place and place.strategy))
	assertf(roomDef, "resolveTablesAndCounters needs RoomDef, got " .. tostring(roomDef))
	assertf(type(roomDef.getIsoRoom) == "function", "resolveTablesAndCounters no getIsoRoom")

	local room = roomDef:getIsoRoom()
	if not room then
		log("resolveTablesAndCounters live room nil")
		return nil
	end

	local minSurfaceHeight = tonumber(place and place.minSurfaceHeight or 10) or 10
	local limit = tonumber(place and place.limit or 16) or 16
	if limit < 0 then
		limit = 0
	end

	local opts = { minSurfaceHeight = minSurfaceHeight, limit = limit }

	log("resolveTablesAndCounters scan start minZ=" .. tostring(minSurfaceHeight) .. " limit=" .. tostring(limit))

	local hits = SurfaceScan.scanRoomForSurfaces(room, opts)
	if not hits or #hits == 0 then
		log("resolveTablesAndCounters no hits")
		return nil
	end

	rankByZ(hits) -- highest z first, stable tie by texture

	local squares = {}
	for i = 1, #hits do
		local h = hits[i]
		if h and h.sq then
			squares[#squares + 1] = h.sq
		end
	end
	if #squares == 0 then
		return nil
	end

	log("resolveTablesAndCounters hits " .. tostring(#hits) .. " squares " .. tostring(#squares))
	return squares
end

-- claim your name in the register
Registry.registerResolver("tables_and_counters", resolveTablesAndCounters)

return true
