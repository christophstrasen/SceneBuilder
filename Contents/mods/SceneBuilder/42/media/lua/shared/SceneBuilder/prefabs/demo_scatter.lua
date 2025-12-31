-- SceneBuilder/prefabs/demo.lua

--[[ -----------------------------------------------------------
Example prefab (anchors variant), staying close to current demo style
- Keeps chaining API (:corpse / :container / :scatter / :where)
- Introduces named "anchors" resolved once per prefab run
- Shows a per-placement :postSpawn hook on a :corpse command
- Does NOT remove or alter your existing _placeCorpse/_placeContainer/_placeScatter
- Build 42 friendly; no shared/client/server in require paths
------------------------------------------------------------- ]]

local U = require("DREAMBase/util")
local LOG_TAG = "SceneBuilder prefab/demo_scatter"
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
	S:begin(roomDef, { tag = "demo_scatter" })
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
			:maxItemNum(4) -- from the unique items above, ignoring their count
			:maxPlacementSquares(10) -- among the squares that qualify the place (here "any"), scatter on so many squares
			:where("any")
		end)
		:spawn()
	log("Prefab demo_scatter makeForRoomDef ran for " .. tostring(roomDef and roomDef:getName()))
end
-- stylua: ignore end

return Demo

--[[
-- testing and usage via console
scatter = require("SceneBuilder/prefabs/demo_scatter")
scatter.makeForRoomDef(nil)  -- or a specific roomDef. Uses player's current room if nil

]]
--
