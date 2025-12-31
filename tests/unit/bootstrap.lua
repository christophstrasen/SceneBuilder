package.path = table.concat({
	"Contents/mods/SceneBuilder/42/media/lua/shared/?.lua",
	"Contents/mods/SceneBuilder/42/media/lua/shared/?/init.lua",
	"../DREAMBase/Contents/mods/DREAMBase/42/media/lua/shared/?.lua",
	"../DREAMBase/Contents/mods/DREAMBase/42/media/lua/shared/?/init.lua",
	"external/DREAMBase/Contents/mods/DREAMBase/42/media/lua/shared/?.lua",
	"external/DREAMBase/Contents/mods/DREAMBase/42/media/lua/shared/?/init.lua",
	package.path,
}, ";")

local TB = require("DREAMBase/test/bootstrap")
if type(TB) == "table" and type(TB.apply) == "function" then
	TB.apply()
end
