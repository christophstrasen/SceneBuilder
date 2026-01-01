describe("SceneBuilder placers helpers", function()
	it("normalizes item type names for Base.* and module-prefixed types", function()
		local Placers = require("SceneBuilder/placers")

		assert.equals("Base.Axe", Placers.normType("Axe"))
		assert.equals("Base.Axe", Placers.normType("  Axe  "))
		assert.equals("Base.Axe", Placers.normType({ "Axe" }))
		assert.equals("Base.Axe", Placers.normType({ item = "Axe" }))
		assert.equals("OtherMod.CustomItem", Placers.normType("OtherMod.CustomItem"))

		assert.is_nil(Placers.normType(""))
		assert.is_nil(Placers.normType("   "))
		assert.is_nil(Placers.normType({}))
	end)
end)

describe("SceneBuilder zombies placer", function()
	it("converts spawned list to Lua array", function()
		local Placers = require("SceneBuilder/placers")

		local calls = {}
		local prev = _G.addZombiesInOutfit
		_G.addZombiesInOutfit = function(x, y, z, total, outfit, femaleChance)
			calls[#calls + 1] = { x = x, y = y, z = z, total = total, outfit = outfit, femaleChance = femaleChance }
			return {
				size = function()
					return 2
				end,
				get = function(_, idx0)
					return { id = idx0 + 1 }
				end,
			}
		end

		local sq = { getX = function() return 10 end, getY = function() return 20 end, getZ = function() return 0 end }

		local created, center = Placers.placeZombies({}, {}, {
			count = 2,
			outfit = "Police",
			femaleChance = 50,
			place = { strategy = "any" },
		}, sq)

		_G.addZombiesInOutfit = prev

		assert.equals(2, #created)
		assert.is_true(center == sq)
		assert.equals(1, #calls)
		assert.equals(2, calls[1].total)
		assert.equals("Police", calls[1].outfit)
		assert.equals(50, calls[1].femaleChance)
	end)
end)
