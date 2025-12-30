local U = require("SceneBuilder/util")
local LOG_TAG = "SceneBuilder prefab/demo_on_tables"
local log = U.makeLogger(LOG_TAG)

local Demo = {}

--- Public entrypoint: prefab does its work for a given roomDef.
--- If roomDef is nil, defaults to player's current room.
---@param roomDef any
function Demo.makeForRoomDef(roomDef)
	if not roomDef then
		local p = getPlayer()
		local r = p and p:getCurrentSquare() and p:getCurrentSquare():getRoom()
		roomDef = r and r:getRoomDef() or nil
	end

	local S = require("SceneBuilder/core")

	-- Begin scene; define anchors once (formerly "slots")
	-- The engine would resolve these to concrete {x,y,z} positions and cache them
	-- stylua: ignore start
	S:begin(roomDef, { tag = "demo_on_table" })
		:container("Bag_Schoolbag_Travel", function(b)
		b -- Travel bag away from the door, unchanged from demo style
			:addTo("MoneyBundle", "SleepingBag_Camo_Packed", "Whiskey")
			:where("tables_and_counters")
		end)
		:spawn()
	log("Prefab demo_on_tables makeForRoomDef ran for " .. tostring(roomDef and roomDef:getName()))
end

-- stylua: ignore end
return Demo

--[[
-- testing and usage via console
onTables = require("SceneBuilder/prefabs/demo_on_tables")
onTables.makeForRoomDef(nil)  -- or a specific roomDef. Uses player's current room if nil

]]
--
