dofile("tests/unit/bootstrap.lua")

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

	it("scans only squares flagged IsTable", function()
		local SurfaceScan = require("SceneBuilder/surface_scan")

		local obj = {
			getSpriteName = function()
				return "Furniture_Tables_High_01_6"
			end,
			-- Build 42 preferred path for surface-aware placement.
			getSurfaceOffsetNoTable = function()
				return 30
			end,
		}

		local squareNoTableFlag = {
			getObjects = function()
				return makeList({ obj })
			end,
			has = function(_, _flag)
				return false
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

		local squareIsTable = {
			getObjects = function()
				return makeList({ obj })
			end,
			has = function(_, flag)
				return flag == "IsTable"
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
				return makeList({ squareNoTableFlag, squareIsTable })
			end,
		}

		local hits = SurfaceScan.scanRoomForSurfaces(room, {
			minSurfaceHeight = 10,
		})

		assert.equals(1, #hits)
		assert.equals("Furniture_Tables_High_01_6", hits[1].texture)
		assert.equals(30, hits[1].z)
	end)
end)
