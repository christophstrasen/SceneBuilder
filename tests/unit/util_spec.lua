package.path = table.concat({
	"Contents/mods/SceneBuilder/42/media/lua/shared/?.lua",
	"Contents/mods/SceneBuilder/42/media/lua/shared/?/init.lua",
	package.path,
}, ";")

_G.getDebug = function()
	return false
end

describe("SceneBuilder util", function()
	it("buildKey includes nil segments (does not collapse after nil)", function()
		local U = require("SceneBuilder/util")
		assert.equals("a|∅|b", U.buildKey("a", nil, "b"))
		assert.equals("a|∅", U.buildKey("a", nil))
	end)

	it("shortlistFromPool deterministic default does not mutate input pool", function()
		local U = require("SceneBuilder/util")

		local pool = { 1, 2, 3, 4 }
		local before = table.concat(pool, ",")
		local sl = U.shortlistFromPool(pool, 2, true)
		local after = table.concat(pool, ",")

		assert.are.same({ 1, 2 }, sl)
		assert.equals(before, after)
	end)

	it("shortlistFromPool non-deterministic shuffles in place (mutates pool)", function()
		local U = require("SceneBuilder/util")

		local saved = _G.ZombRand
		_G.ZombRand = function()
			return 0 -- forces repeated swaps with index 1
		end

		local pool = { 1, 2, 3, 4 }
		local before = table.concat(pool, ",")
		local sl = U.shortlistFromPool(pool, 2, false)
		local after = table.concat(pool, ",")

		_G.ZombRand = saved

		assert.is_table(sl)
		assert.equals(2, #sl)
		assert.is_not.equals(before, after)
	end)
end)
