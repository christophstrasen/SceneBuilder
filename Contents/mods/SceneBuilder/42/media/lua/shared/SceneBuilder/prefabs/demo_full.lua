-- SceneBuilder/prefabs/demo.lua

--[[ -----------------------------------------------------------
Example prefab (anchors variant), staying close to current demo style
- Keeps chaining API (:corpse / :container / :scatter / :where)
- Introduces named "anchors" resolved once per prefab run
- Shows a per-placement :postSpawn hook on a :corpse command
- Does NOT remove or alter your existing _placeCorpse/_placeContainer/_placeScatter
- Build 42 friendly; no shared/client/server in require paths
------------------------------------------------------------- ]]

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

	-- Use SceneBuilder core (neutral), keep Scene hooks from StoryModeMod.
	local S = require("SceneBuilder/core")
	local Hooks = require("StoryModeMod/scene_hooks")

	-- Begin scene; define anchors once (formerly "slots")
	-- The engine would resolve these to concrete {x,y,z} positions and cache them
	-- stylua: ignore start
	S:begin(roomDef, { tag = "demo_full" })
		:anchors(function(a)
			a:name("AnywhereInRoom")
			a:where("any")
			a:name("deskLike")
			a:where("tables_and_counters")
		end)
		:corpse(function(c)
		c -- Witness corpse near the device anchor; shows per-placement postSpawn hook
			:outfit("Agent")
			:onBody(
				"Bag_ToolBag",
				"Screwdriver",
				"Multitool",
				{ "ElectronicsScrap", 2 },
				"ElectricWire",
				"DuctTape"
			)
			:dropNear("RemoteCraftedV1", "Speaker")
			:blood({ bruising = 4, floor_splats = 30, trail = true })
			:where("any", { anchor = "AnywhereInRoom" })
		end)
		:corpse(function(c)
		c -- Doctor corpse near the board/diagram anchor
			:outfit("Doctor")
			:onBody("Bag_MedicalBag", "PillsAntiDep", "PillsVitamins")
			:dropNear("Notebook", "Journal", "TuningFork")
			:blood({ bruising = 4, floor_splats = 15, trail = true })
			:where("any")
		end)
		:container("Bag_ProtectiveCaseSmall_Electronics", function(b)
		b -- Protective case placed at the board anchor (co-located with board)
			:addTo("Calculator", "WalkieTalkie4", "Pager", "Speaker")
			:where("any")
		end)
		:container("Bag_Schoolbag_Travel", function(b)
		b -- Travel bag away from the door, unchanged from demo style
			:addTo("MoneyBundle", "SleepingBag_Camo_Packed", "Whiskey")
			:where("tables_and_counters")
		end)
		:scatter(function(s)
		s -- Loose items scattered around the primary anchor
			:items(
				{ "ElectronicsScrap", 3 },
				{ "AluminumFragments", 2 },
				"Notepad",
				"Pencil",
				"Paperback_SelfHelp",
				"DuctTape",
				"BandageDirty"
			)
			:maxItemNum(4) -- from the unique items above, not shuffled at the moment
			:maxPlacementSquares(2)
			:where("any")
		end)
		:scatter(function(s)
		s -- Loose items scattered around the primary anchor
			:items("BaseballBat_Broken")
			:maxItemNum(1) -- from the unique items above, not shuffled at the moment
			:maxPlacementSquares(1)
			:postSpawn(Hooks.makeClueTagAndTrack({
				clue_id = "test_id_1",
				preventDrop = true,
				context = "Scatter2",
			}))
			:where("tables_and_counters")
		end)
		:spawn()
	print("Prefab demo_full makeForRoomDef ran for " .. tostring(roomDef and roomDef:getName()))
end
-- stylua: ignore end

return Demo

--[[
-- testing and usage via console
fulldemo = require("SceneBuilder/prefabs/demo_full")
fulldemo.makeForRoomDef(nil)  -- or a specific roomDef. Uses player's current room if nil

]]
--
