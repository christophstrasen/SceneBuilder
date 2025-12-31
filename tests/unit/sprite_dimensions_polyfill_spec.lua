dofile("tests/unit/bootstrap.lua")

local function reload(moduleName)
	package.loaded[moduleName] = nil
	return require(moduleName)
end

describe("SpriteDimensions polyfill", function()
	local savedSpriteDimensions

	before_each(function()
		savedSpriteDimensions = rawget(_G, "SpriteDimensions")
		_G.SpriteDimensions = nil
		_G.SpriteDimensionsPolyfill = nil
		package.loaded["SceneBuilder/SpritesSurfaceDimensions_polyfill"] = nil
	end)

	after_each(function()
		_G.SpriteDimensions = savedSpriteDimensions
		package.loaded["SceneBuilder/SpritesSurfaceDimensions_polyfill"] = nil
	end)

	it("merges when SpriteDimensions appears after initial access", function()
		reload("SceneBuilder/SpritesSurfaceDimensions_polyfill")
		local SD = _G.SpriteDimensionsPolyfill
		assert.is_table(SD)

		-- Initial access without SpriteDimensions present.
		assert.is_nil(SD.get("example_sprite_01_0", false))

		-- Late load (e.g. ItemStories): polyfill should still merge on next access.
		_G.SpriteDimensions = {
			default = { minOffsetX = 1, maxOffsetX = 2, minOffsetY = 3, maxOffsetY = 4 },
			defaultOnFloor = { minOffsetX = 10, maxOffsetX = 20, minOffsetY = 30, maxOffsetY = 40 },
			list = {
				example_sprite_01_0 = { minOffsetX = 7, maxOffsetX = 8, minOffsetY = 9, maxOffsetY = 10 },
			},
		}

		local entry = SD.get("example_sprite_01_0", false)
		assert.is_table(entry)
		assert.equals(7, entry.minOffsetX)

		local def = SD.getDefaultRaised()
		-- Polyfill defaults take precedence over real defaults per-field.
		assert.equals(35, def.minOffsetX)
	end)
end)
