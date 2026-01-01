-- SceneBuilder/resolvers/free_or_midair.lua
-- "freeOrMidair" via IsoGridSquare:isFreeOrMidair(bool).
-- Suitable for live zombies (walkable-ish), not items-on-surfaces.

local U = require("DREAMBase/util")
local LOG_TAG = "SceneBuilder resolver/free_or_midair"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf

local Registry = require("SceneBuilder/registry")

---@param sq any
---@param strict boolean
---@return boolean
local function isFreeOrMidair(sq, strict)
	if not (sq and type(sq.isFreeOrMidair) == "function") then
		return false
	end
	local ok, v = pcall(sq.isFreeOrMidair, sq, strict == true)
	return ok and v == true
end

---@param roomDef RoomDef
---@param place SceneBuilder.PlaceSpec|nil
---@return IsoGridSquare[]|nil
local function resolveFreeOrMidair(roomDef, place)
	log("freeOrMidair resolver entering for place.strategy=" .. tostring(place and place.strategy))
	assertf(roomDef, "resolveFreeOrMidair needs RoomDef, got " .. tostring(roomDef))
	assertf(type(roomDef.getIsoRoom) == "function", "resolveFreeOrMidair no getIsoRoom")

	local room = roomDef:getIsoRoom()
	if not room then
		log("resolveFreeOrMidair live room nil")
		return nil
	end

	local list = room:getSquares()
	if not list or list:size() == 0 then
		return nil
	end

	local limit = tonumber(place and place.limit or 0) or 0
	if limit < 0 then
		limit = 0
	end

	local function collect(strict)
		local squares = {}
		for i = 0, list:size() - 1 do
			local sq = list:get(i)
			if sq and isFreeOrMidair(sq, strict) then
				squares[#squares + 1] = sq
				if limit > 0 and #squares >= limit then
					break
				end
			end
		end
		return squares
	end

	-- Prefer "strict" squares (no moving objects) but degrade if that yields none.
	local strictPool = collect(true)
	if #strictPool > 0 then
		log("resolveFreeOrMidair strict pool " .. tostring(#strictPool))
		return strictPool
	end

	local loosePool = collect(false)
	if #loosePool == 0 then
		return nil
	end
	log("resolveFreeOrMidair loose pool " .. tostring(#loosePool))
	return loosePool
end

Registry.registerResolver("freeOrMidair", resolveFreeOrMidair)
return true
