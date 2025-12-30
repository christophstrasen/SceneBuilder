package.path = table.concat({
	"Contents/mods/SceneBuilder/42/media/lua/shared/?.lua",
	"Contents/mods/SceneBuilder/42/media/lua/shared/?/init.lua",
	package.path,
}, ";")

_G.getDebug = function()
	return false
end

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
