-- SceneBuilder/lifecycle.lua
local U = require("SceneBuilder/util")
local LOG_TAG = "SceneBuilder Lifecycle"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf

-- Keep registry private to this module.
local _registry = {}

---@class SceneBuilder.Lifecycle
local Lifecycle = {}

-- PASTE EXACTLY FROM core.lua:
local function tagAndRegister(obj, tag)
	if not obj or not tag then
		return
	end
	_registry[tag] = _registry[tag] or {}
	table.insert(_registry[tag], obj)
end

-- PASTE EXACTLY FROM core.lua:
--   function Scene.despawn(tag) ... end
-- Change the head to 'local function despawn(tag)' and
-- replace 'Scene._registry' with '_registry' inside.
-- BEGIN_PASTE
local function despawn(tag)
	local list = _registry[tag]
	if not list then
		return
	end
	for _, obj in ipairs(list) do
		if obj then
			local sq = obj.getSquare and obj:getSquare() or nil
			if sq and sq:containsItem(obj) then -- This will likely fail on e.g. inventory items
				sq:transmitRemoveItemFromSquare(obj)
			elseif obj.Remove and obj.getCell then
				obj:Remove()
			end
		end
	end
	_registry[tag] = nil
	log("despawned tag " .. tostring(tag))
end
-- END_PASTE

Lifecycle.tagAndRegister = tagAndRegister
Lifecycle.despawn = despawn
Lifecycle.getRegistry = function()
	return _registry
end

---@return SceneBuilder.Lifecycle
return Lifecycle
