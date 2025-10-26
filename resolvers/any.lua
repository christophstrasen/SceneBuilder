-- SceneBuilder/resolvers/any.lua
local U = require("SceneBuilder/util")
local LOG_TAG = "SceneBuilder resolver/any"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf
local Registry = require("SceneBuilder/registry")

---@param roomDef RoomDef
---@param place SceneBuilder.PlaceSpec|nil
---@return IsoGridSquare[]|nil
local function resolveAny(roomDef, place)
	log("any resolver entering for place.strategy=" .. tostring(place and place.strategy))
	assertf(roomDef, "resolveAny needs RoomDef, got " .. tostring(roomDef))
	assertf(type(roomDef.getIsoRoom) == "function", "resolveAny RoomDef has no getIsoRoom method")

	local room = roomDef.getIsoRoom and roomDef:getIsoRoom() or nil
	if not room then
		local name = (roomDef.getName and roomDef:getName()) or "?"
		log("resolveAny live room is nil name=" .. tostring(name))
		return nil
	end

	local squares = room:getSquares()
	local total = (squares and squares.size) and squares:size() or 0
	if total == 0 then
		local rn = (room.getName and room:getName()) or "?"
		log("resolveAny live room has 0 squares name=" .. tostring(rn))
		return nil
	end

	local pool = {}
	local cap = tonumber(place and place.limit) or total
	if cap < 0 then
		cap = 0
	end

	for i = 0, total - 1 do
		local sq = squares:get(i)
		if sq then
			pool[#pool + 1] = sq
			if #pool >= cap then
				break
			end
		end
	end
	if #pool == 0 then
		log("resolveAny pool empty after copy")
		return nil
	end

	log("resolveAny pool size " .. tostring(#pool))
	return pool
end

Registry.registerResolver("any", resolveAny)
return true
