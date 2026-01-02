-- SceneBuilder/resolvers/centroid.lua
-- "centroid" based on the average of all room squares (good for L-shaped rooms).
-- Orders squares from center-outward in concentric rings.

local U = require("DREAMBase/util")
local LOG_TAG = "SceneBuilder resolver/centroid"
local assertf = U.assertf

local Registry = require("SceneBuilder/registry")

local function atan2(y, x)
	if type(math.atan2) == "function" then
		return math.atan2(y, x)
	end
	return math.atan(y, x)
end

---@param roomDef RoomDef
---@param place SceneBuilder.PlaceSpec|nil
---@return IsoGridSquare[]|nil
local function resolveCentroid(roomDef, place)
	U.logCtx(LOG_TAG, "centroid resolver entering", {
		strategy = tostring(place and place.strategy),
	})
	assertf(roomDef, "resolveCentroid needs RoomDef, got " .. tostring(roomDef))
	assertf(type(roomDef.getIsoRoom) == "function", "resolveCentroid no getIsoRoom")

	local room = roomDef:getIsoRoom()
	if not room then
		U.logCtx(LOG_TAG, "resolveCentroid live room nil", {})
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

	local entries = {}
	for i = 0, list:size() - 1 do
		local sq = list:get(i)
		if sq then
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
	if #entries == 0 then
		return nil
	end

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

	local pool = {}
	local cap = limit > 0 and math.min(limit, #entries) or #entries
	for i = 1, cap do
		pool[i] = entries[i].sq
	end

	U.logCtx(LOG_TAG, "resolveCentroid pool size", {
		size = #pool,
		centerX = cx,
		centerY = cy,
		centerZ = cz,
	})
	return pool
end

Registry.registerResolver("centroid", resolveCentroid)

return true
