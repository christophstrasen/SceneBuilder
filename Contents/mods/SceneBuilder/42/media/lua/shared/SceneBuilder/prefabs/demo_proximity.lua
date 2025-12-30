-- SceneBuilder/prefabs/demo_proximity.lua
-- Minimal showcase for anchor proximity, respect_strategy, and fallback.
-- Stand in a room with a desk/table and run the console snippet at bottom.

local U = require("SceneBuilder/util")
local LOG_TAG = "SceneBuilder prefab/demo_proximity"
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

	S:begin(roomDef, { tag = "demo_proximity" })
		:anchors(function(a)
			-- Two anchors: anywhere and on desk-like (tables_and_counters)
			a
				:name("AnywhereInRoom")
				:where("any")
			a
				:name("deskLike")
				:where("tables_and_counters")
		end)
		-- A) Respect strategy near desk: must land on a table within r=1.
		:container("Bag_DuffelBag", function(b)
		b
			:addTo("Whiskey", "MoneyBundle")
			:where("tables_and_counters", {
				anchor = "deskLike",
				anchor_proximity = 1, -- 3x3 box, center = deskLike
				respect_strategy = true, -- keep tables constraint
				proximity_fallback = "ignore-proximity-keep-strategy",
			})
		end)
		-- B) Prefer proximity over strategy: may end up on the floor near anchor.
		:container(	"Bag_ProtectiveCaseSmall_Electronics",function(b)
		b
			:addTo("Pager", "Calculator")
			:where("tables_and_counters", {
				anchor = "AnywhereInRoom",
				anchor_proximity = 2, -- 5x5 box
				respect_strategy = false, -- near-any beats tables
				proximity_fallback = "ignore-proximity-keep-strategy",
			})
		end)
		-- C) Scatter near anchor, proximity only; strategy = any.
		:scatter(function(s)
		s
			:items("DuctTape", "Pencil", "Notepad", { "ElectronicsScrap", 2 })
			:maxItemNum(4)
			:maxPlacementSquares(6)
			:where("any", {
				anchor = "AnywhereInRoom",
				anchor_proximity = 2, -- 5x5 box
				respect_strategy = false, -- same as default
				proximity_fallback = "ignore-proximity-keep-strategy",
			})
		end)
		:spawn()
	log("[demo_proximity] ran for room " .. tostring(roomDef and roomDef:getName()))
end
-- stylua: ignore end

return Demo

--[[ console testing
prox = require("SceneBuilder/prefabs/demo_proximity")
prox.makeForRoomDef(nil)
--]]
