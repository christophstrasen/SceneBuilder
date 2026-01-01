-- SceneBuilder/resolvers/init.lua
-- Loads standard resolvers. Keep this tiny; add new requires as you add files.

require("SceneBuilder/resolvers/any")
require("SceneBuilder/resolvers/free_or_midair")
require("SceneBuilder/resolvers/surfaces")
-- future:
-- require "SceneBuilder/resolvers/beds"
-- require "SceneBuilder/resolvers/shelves"

return true
