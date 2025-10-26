-- SceneBuilder/registry.lua
local target = nil
local pending = {}

---@class SceneBuilder.Registry
local Registry = {}
function Registry.bind(scene)
	assert(type(scene) == "table" and scene.registerResolver, "registry.bind: valid Scene required")
	target = scene
	for _, r in ipairs(pending) do
		target.registerResolver(r.name, r.fn, r.opts)
	end
	pending = {}
end

function Registry.registerResolver(name, fn, opts)
	assert(type(name) == "string" and name ~= "", "resolver name required")
	assert(type(fn) == "function", "resolver fn required")
	if target then
		return target.registerResolver(name, fn, opts)
	end
	pending[#pending + 1] = { name = name, fn = fn, opts = opts }
end

---@return SceneBuilder.Registry
return Registry
