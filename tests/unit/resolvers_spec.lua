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

describe("SceneBuilder surfaces resolver", function()
	it("returns only squares flagged IsTable", function()
		local Registry = require("SceneBuilder/registry")
		local captured = {}
		Registry.bind({
			registerResolver = function(name, fn)
				captured[name] = fn
			end,
		})

		require("SceneBuilder/resolvers/surfaces")

		local fn = captured.tables_and_counters
		assert.is_truthy(fn)

		local function makeList(items)
			return {
				_items = items,
				size = function(self)
					return #self._items
				end,
				get = function(self, idx0)
					return self._items[idx0 + 1]
				end,
			}
		end

		local sqNo = { has = function() return false end }
		local sqYes = { has = function(_, flag) return flag == "IsTable" end }
		local room = { getSquares = function() return makeList({ sqNo, sqYes }) end }
		local roomDef = { getIsoRoom = function() return room end }

		local pool = fn(roomDef, { strategy = "tables_and_counters", limit = 16 })
		assert.equals(1, #pool)
		assert.is_true(pool[1] == sqYes)
	end)
end)
