package.path = table.concat({
	"Contents/mods/SceneBuilder/42/media/lua/shared/?.lua",
	"Contents/mods/SceneBuilder/42/media/lua/shared/?/init.lua",
	package.path,
}, ";")

_G.getDebug = function()
	return false
end

describe("SceneBuilder resolvers normalization", function()
	it("ensurePlace normalizes defaults and fallbacks", function()
		local Resolvers = require("SceneBuilder/resolvers")

		local p = Resolvers.ensurePlace(nil, nil)
		assert.equals("any", p.strategy)
		assert.are.same({ "any" }, p.fallback)
	end)

	it("ensurePlace normalizes anchor references and clamps proximity", function()
		local Resolvers = require("SceneBuilder/resolvers")

		local p = Resolvers.ensurePlace("any", {
			anchor = "anchor:deskLike",
			anchor_proximity = -10,
			fallback = { " any ", "tables_and_counters", "any" },
			respect_strategy = true,
		})

		assert.equals("deskLike", p.anchor)
		assert.equals(0, p.anchor_proximity)
		assert.are.same({ "any", "tables_and_counters" }, p.fallback)
		assert.is_true(p.respect_strategy)
	end)
end)
