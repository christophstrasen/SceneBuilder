-- SceneBuilder/prefabs/demo_zombies.lua
-- Minimal showcase for spawning live zombies via addZombiesInOutfit and freeOrMidair placement.

local U = require("DREAMBase/util")
local LOG_TAG = "SceneBuilder prefab/demo_zombies"
local log = U.makeLogger(LOG_TAG)

local Demo = {}

---@param roomDef any
-- stylua: ignore start
function Demo.makeForRoomDef(roomDef)
	if not roomDef then
		local p = getPlayer()
		local r = p and p:getCurrentSquare() and p:getCurrentSquare():getRoom()
		roomDef = r and r:getRoomDef() or nil
	end

	local S = require("SceneBuilder/core")

	S:begin(roomDef, { tag = "demo_zombies" })
		:zombies(function(z)
		z
			:count(10)
			:outfit("Police")
			:femaleChance(90)
			:postSpawn(function(ctx, created)
				log(("spawned zombies=%d at %s"):format(#(created or {}), tostring(ctx and ctx.position or "?")))
			end)
			:where("freeOrMidair", { fallback = { "any" } })
		end)
		:spawn()

	log("Prefab demo_zombies makeForRoomDef ran for " .. tostring(roomDef and roomDef:getName()))
end
-- stylua: ignore end

return Demo

--[[ console testing
z = require("SceneBuilder/prefabs/demo_zombies")
z.makeForRoomDef(nil)
--]]
