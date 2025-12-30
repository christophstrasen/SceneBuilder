package.path = table.concat({
	"Contents/mods/SceneBuilder/42/media/lua/shared/?.lua",
	"Contents/mods/SceneBuilder/42/media/lua/shared/?/init.lua",
	package.path,
}, ";")

_G.getDebug = function()
	return false
end

describe("SceneBuilder surface scan", function()
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

	it("prefers getSpriteName and matches whitelist case-insensitively", function()
		local SurfaceScan = require("SceneBuilder/surface_scan")

		-- Regression coverage:
		-- some IsoObject-like instances returned by sq:getObjects() in newer B42 builds
		-- appear to not implement getSprite(), which previously crashed surfaceZ().
		local weirdObjWithoutSprite = {
			getSpriteName = function()
				return "Weird_Object_NoSprite"
			end,
		}

		local obj = {
			getSpriteName = function()
				return "Furniture_Tables_High_01_6"
			end,
			getTextureName = function()
				error("getTextureName should not be used when getSpriteName exists")
			end,
			getSprite = function()
				return {
					getProperties = function()
						return {
							Val = function(_, key)
								if key == "Surface" then
									return "20"
								end
								return nil
							end,
						}
					end,
				}
			end,
		}

		local square = {
			getObjects = function()
				return makeList({ weirdObjWithoutSprite, obj })
			end,
			getX = function()
				return 10
			end,
			getY = function()
				return 20
			end,
			getZ = function()
				return 0
			end,
		}

		local room = {
			getSquares = function()
				return makeList({ square })
			end,
		}

		local hits = SurfaceScan.scanRoomForSurfaces(room, {
			whitelist = { "TABLE" },
			minSurfaceHeight = 10,
		})

		assert.equals(1, #hits)
		assert.equals("Furniture_Tables_High_01_6", hits[1].texture)
		assert.equals(20, hits[1].z)
	end)
end)
