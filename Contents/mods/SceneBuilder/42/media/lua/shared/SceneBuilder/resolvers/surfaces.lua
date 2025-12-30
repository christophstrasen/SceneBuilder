-- SceneBuilder/resolvers/surfaces.lua
-- "tables_and_counters" via square flags (IsTable). Minimal, opinionated defaults.

local U = require("SceneBuilder/util") -- for U.log/U.assertf
local LOG_TAG = "SceneBuilder resolver/surfaces"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf

local Registry = require("SceneBuilder/registry")

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

	local limit = tonumber(place and place.limit or 16) or 16
	if limit < 0 then
		limit = 0
	end

	local squares = {}
	local list = room:getSquares()
	if not list or list:size() == 0 then
		return nil
	end

	log("resolveTablesAndCounters scan start limit=" .. tostring(limit))

	for i = 0, list:size() - 1 do
		local sq = list:get(i)
		if sq and type(sq.has) == "function" and sq:has("IsTable") then
			squares[#squares + 1] = sq
			if limit > 0 and #squares >= limit then
				break
			end
		end
	end
	if #squares == 0 then
		return nil
	end

	log("resolveTablesAndCounters squares " .. tostring(#squares))
	return squares
end

-- claim your name in the register
Registry.registerResolver("tables_and_counters", resolveTablesAndCounters)

return true
