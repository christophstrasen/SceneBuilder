-- SceneBuilder.lua -- public facade for the SceneBuilder DSL (Build 42).

local SceneBuilder = require("SceneBuilder/core")

-- Convenience exports (mirrors `types.lua` umbrella for tooling/discoverability).
SceneBuilder.lifecycle = require("SceneBuilder/lifecycle")
SceneBuilder.resolvers = require("SceneBuilder/resolvers")
SceneBuilder.placers = require("SceneBuilder/placers")
SceneBuilder.registry = require("SceneBuilder/registry")

return SceneBuilder
