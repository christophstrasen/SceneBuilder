-- SceneBuilder/resolvers/centroid_free_or_midair.lua
-- "centroidFreeOrMidair" based on room centroid, ordered center-out in rings.

---@class SceneBuilder.PlaceSpec
---@field strategy string|nil
---@field limit number|nil

-- Editor-only type annotations live in this file; safe to load at runtime.
require("SceneBuilder/types")

local U = require("DREAMBase/util")
local LOG_TAG = "SceneBuilder resolver/centroidFreeOrMidair"
local assertf = U.assertf

local Registry = require("SceneBuilder/registry")

local function atan2(y, x)
	if type(math.atan2) == "function" then
		return math.atan2(y, x)
	end
	if x == 0 then
		if y > 0 then
			return math.pi / 2
		end
		if y < 0 then
			return -math.pi / 2
		end
		return 0
	end
	local angle = math.atan(y / x)
	if x < 0 then
		angle = angle + (y >= 0 and math.pi or -math.pi)
	end
	return angle
end

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

---@param entries table
local function sortEntries(entries)
	table.sort(entries, function(a, b)
		if a.r ~= b.r then
			return a.r < b.r
		end
		if a.a ~= b.a then
			return a.a < b.a
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		if a.y ~= b.y then
			return a.y < b.y
		end
		return a.z < b.z
	end)
end

---@param list any
---@param cx number
---@param cy number
---@param strict boolean
---@return table
local function collectEntries(list, cx, cy, strict)
	local entries = {}
	for i = 0, list:size() - 1 do
		local sq = list:get(i)
		if sq and isFreeOrMidair(sq, strict) then
			local x, y, z = sq:getX(), sq:getY(), sq:getZ()
			local dx = x - cx
			local dy = y - cy
			local radius = math.max(math.abs(dx), math.abs(dy))
			local angle = atan2(dy, dx)
			entries[#entries + 1] = {
				sq = sq,
				r = radius,
				a = angle,
				x = x,
				y = y,
				z = z,
			}
		end
	end
	return entries
end

---@param roomDef RoomDef
---@param place SceneBuilder.PlaceSpec|nil
---@return IsoGridSquare[]|nil
local function resolveCentroidFreeOrMidair(roomDef, place)
	U.logCtx(LOG_TAG, "centroidFreeOrMidair entering", {
		strategy = tostring(place and place.strategy),
	})
	assertf(roomDef, "resolveCentroidFreeOrMidair needs RoomDef, got " .. tostring(roomDef))
	assertf(type(roomDef.getIsoRoom) == "function", "resolveCentroidFreeOrMidair no getIsoRoom")

	local room = roomDef:getIsoRoom()
	if not room then
		U.logCtx(LOG_TAG, "resolveCentroidFreeOrMidair live room nil", {})
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

	local sumX, sumY, sumZ = 0, 0, 0
	local count = 0
	for i = 0, list:size() - 1 do
		local sq = list:get(i)
		if sq then
			sumX = sumX + sq:getX()
			sumY = sumY + sq:getY()
			sumZ = sumZ + sq:getZ()
			count = count + 1
		end
	end
	if count == 0 then
		return nil
	end

	local cx = sumX / count
	local cy = sumY / count
	local cz = sumZ / count

	local entries = collectEntries(list, cx, cy, true)
	local strict = true
	if #entries == 0 then
		strict = false
		entries = collectEntries(list, cx, cy, false)
	end
	if #entries == 0 then
		return nil
	end

	sortEntries(entries)

	local pool = {}
	local cap = limit > 0 and math.min(limit, #entries) or #entries
	for i = 1, cap do
		pool[i] = entries[i].sq
	end

	U.logCtx(LOG_TAG, "resolveCentroidFreeOrMidair pool size", {
		size = #pool,
		centerX = cx,
		centerY = cy,
		centerZ = cz,
		strict = strict,
	})
	return pool
end

Registry.registerResolver("centroidFreeOrMidair", resolveCentroidFreeOrMidair)

return true
