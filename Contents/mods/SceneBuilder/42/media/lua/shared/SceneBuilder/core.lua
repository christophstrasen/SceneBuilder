--- SceneBuilder/core.lua
---@diagnostic disable-next-line: undefined-global
local SceneBuilder = SceneBuilder or {} -- gets exported at the bottom
local Scene = SceneBuilder -- alias so the rest of the file stays unchanged

local U = require("DREAMBase/util")
local LOG_TAG = "SceneBuilder Core"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf

local Lifecycle = require("SceneBuilder/lifecycle")
local Resolvers = require("SceneBuilder/resolvers")
local Placers = require("SceneBuilder/placers")
local DEFAULT_OUTFIT = Placers.getDefaultCorpseOutfit()

---Create a scene bound to a room/building.
---Use the returned API to define corpses, containers, scatter that can be placed directly and with the help of anchor squares
function Scene:begin(roomDef, opts)
	assertf(roomDef, "begin(roomDef, opts) requires RoomDef")
	assertf(opts and type(opts.tag) == "string" and opts.tag ~= "", "begin requires opts.tag")
	local state = {
		roomDef = roomDef,
		tag = opts.tag, -- demand a tag (no implicit default)
		queue = {},
		current = nil,
		anchors = {},
		deterministic = true,
		distribution = "random",
		maxPlacementSquares = 4,
		_placeCount = 0,
	}

	local api = {}

	-- internals
	local function enqueueCurrent()
		if state.current then
			table.insert(state.queue, state.current)
			state.current = nil
		end
	end

	local function begin(kind)
		enqueueCurrent()
		if kind == "corpse" then
			state.current = {
				kind = "corpse",
				outfit = "Survivor",
				onBody = {},
				dropNear = {},
				blood = nil,
				place = nil,
				preSpawn = nil,
				postSpawn = nil,
				mayAdjustZ = false, --recommendation. Resolvers handle details or overrides.
			}
		elseif kind == "container" then
			state.current = {
				kind = "container",
				item = nil,
				contains = {},
				place = nil,
				preSpawn = nil,
				postSpawn = nil,
				mayAdjustZ = true, --recommendation. Resolvers handle details or overrides.
			}
		elseif kind == "scatter" then
			state.current = {
				kind = "scatter",
				items = {},
				maxItemNum = 8,
				place = nil,
				preSpawn = nil,
				postSpawn = nil,
				mayAdjustZ = true, --recommendation. Resolvers handle details or overrides.
			}
		else
			error("Unknown builder kind " .. tostring(kind))
		end
	end

	local function requireActive(expectedKind)
		assertf(state.current, "Builder misuse: need active '" .. tostring(expectedKind) .. "'.")
		assertf(
			state.current.kind == expectedKind,
			"Builder misuse expected '" .. tostring(expectedKind) .. "', got '" .. tostring(state.current.kind) .. "'."
		)
	end

	local function mkSub(kind)
		local sub = {}

		function sub:place(strategyOrOpts, opts2)
			api:place(strategyOrOpts, opts2)
			return sub
		end

		--- Sugar alias for readability: "what … where(strategy, opts)".
		--- @param strategyOrOpts string|SceneBuilder.PlaceSpec
		--- @param opts2? SceneBuilder.ResolverOptions
		--- @return SceneBuilder.SceneAPI
		function sub:where(strategyOrOpts, opts2)
			-- Sugar alias for readability: "what … where(strategy, opts)".
			sub:place(strategyOrOpts, opts2)
			return sub
		end

		function sub:preSpawn(fn)
			api:preSpawn(fn)
			return sub
		end
		function sub:postSpawn(fn)
			api:postSpawn(fn)
			return sub
		end

		function sub:deterministic(n)
			api:deterministic(n)
			return sub
		end

		function sub:distribution(n)
			api:distribution(n)
			return sub
		end

		function sub:maxPlacementSquares(n)
			api:maxPlacementSquares(n)
			return sub
		end

		if kind == "corpse" then
			-- in corpse sub:
			---@param name string
			function sub:outfit(name)
				api:outfit(name)
				return sub
			end
			function sub:onBody(...)
				api:onBody(...)
				return sub
			end
			function sub:dropNear(...)
				api:dropNear(...)
				return sub
			end
			function sub:blood(tbl)
				api:blood(tbl)
				return sub
			end
		elseif kind == "container" then
			function sub:addTo(...)
				api:addTo(...)
				return sub
			end
		elseif kind == "scatter" then
			function sub:items(...)
				api:items(...)
				return sub
			end
			function sub:maxItemNum(n)
				api:maxItemNum(n)
				return sub
			end
		end

		return sub
	end

	--- Sugar alias to improve readability in scene specs.
	--- @param strategyOrOpts string|SceneBuilder.PlaceSpec
	--- @param opts2? SceneBuilder.ResolverOptions
	function api:where(strategyOrOpts, opts2)
		return self:place(strategyOrOpts, opts2)
	end

	--- @param strategyOrOpts string|SceneBuilder.PlaceSpec
	--- @param opts2? SceneBuilder.ResolverOptions
	function api:place(strategyOrOpts, opts2)
		assertf(state.current, "place(...) requires active sub-builder. Call :corpse/:container/:scatter first.")
		local p = Resolvers.ensurePlace(strategyOrOpts, opts2)
		if p.deterministic == nil then
			p.deterministic = state.deterministic
		end
		if not p.distribution then
			p.distribution = state.distribution or "random"
		end
		if not p.maxPlacementSquares or p.maxPlacementSquares < 1 then
			p.maxPlacementSquares = state.maxPlacementSquares or 1
		end
		-- (optional) tiny log to confirm effective K
		log(
			"place strategy="
				.. tostring(p.strategy)
				.. " K="
				.. tostring(p.maxPlacementSquares)
				.. " policy="
				.. tostring(p.distribution)
		)

		state.current.place = p
		return api
	end

	---@param mode string
	function api:distribution(mode)
		-- only "random" supported now; future: "roundrobin"
		if mode == nil or mode == "random" then
			state.distribution = "random"
		else
			assertf(false, "unsupported distribution " .. tostring(mode))
		end
		return api
	end

	---@param flag boolean
	function api:deterministic(flag)
		state.deterministic = (flag ~= false)
		return api
	end

	---@param maxSquares number
	function api:maxPlacementSquares(maxSquares)
		if maxSquares < 1 then
			log("maxPlacementSquares must be at least 1")
			maxSquares = 1
		end
		state.maxPlacementSquares = maxSquares
		return api
	end

	---Add a corpse placement block. Configure with :outfit/:onBody/:dropNear/:blood
	---call :place(...). Finish with :spawn() or :spawnNow() for only this placer.
	function api:corpse(fn)
		assertf(type(fn) == "function", "corpse(fn) requires a function.")
		begin("corpse")
		fn(mkSub("corpse"))
		enqueueCurrent()
		return api
	end

	---Add a world container (e.g., bag) and optionally fill it via :addTo(...).
	---call :place(...). Finish with :spawn() or :spawnNow() for only this placer.
	---@param typeName string
	function api:container(typeName, fn)
		assertf(type(typeName) == "string" and #typeName > 0, "container(typeName, fn) typeName string required.")
		assertf(type(fn) == "function", "container(typeName, fn) fn must be a function.")
		begin("container")
		state.current.item = Placers.normType(typeName)
		fn(mkSub("container"))
		enqueueCurrent()
		return api
	end

	---Scatter items around a center square
	---Use :items(...), :maxItemNum(n), :place(...).
	---@param fn fun(sub:SceneBuilder.ScatterBuilder)
	function api:scatter(fn)
		assertf(type(fn) == "function", "scatter(fn) requires a function.")
		begin("scatter")
		fn(mkSub("scatter"))
		enqueueCurrent()
		return api
	end

	function api:anchors(fn)
		assertf(type(fn) == "function", "anchors(fn) requires a function. currently is type " .. type(fn))
		local a = {}

		---@param name string
		function a:name(name)
			a._pendingName = Resolvers.normAnchorRef(name)
			return a
		end

		--- Sugar alias for readability: "what … where(strategy, opts)".
		--- @param strategyOrOpts string|SceneBuilder.PlaceSpec
		--- @param opts2? SceneBuilder.ResolverOptions
		function a:where(strategyOrOpts, opts2)
			return a:place(strategyOrOpts, opts2)
		end

		--- @param strategyOrOpts string|SceneBuilder.PlaceSpec
		--- @param opts2? SceneBuilder.ResolverOptions
		function a:place(strategyOrOpts, opts2)
			local place = Resolvers.ensurePlace(strategyOrOpts, opts2)
			if place.deterministic == nil then
				place.deterministic = state.deterministic
			end
			local name = a._pendingName or place.name or place.anchor
			assertf(
				type(name) == "string" and name ~= "",
				"anchors:place(...) requires anchor name (use a:name() or opts.name)"
			)
			a._pendingName = nil
			local rd = place.room or roomDef
			local sq = Resolvers.resolveSquare(state, rd, place)
			if sq then
				if name then
					if state.anchors[name] then
						log("anchors overwriting existing anchor " .. tostring(name))
					end
					state.anchors[name] = sq
				else
					log("Anchor name is false or nil for strategy " .. tostring(place.strategy))
				end
			else
				log("anchors place failed " .. tostring(name) .. " via " .. tostring(place.strategy))
			end
			return a
		end

		-- You removed :near; keep API minimal for now.

		fn(a)
		return api
	end

	---Hook run to before the particular sub-builder spawns e.g. inside a :corpse block
	---@param fn fun(ctx:{ roomDef:RoomDef, anchorName?:string,
	---  position?:{x:integer,y:integer,z:integer} })
	function api:preSpawn(fn)
		assertf(state.current, "preSpawn() no active sub-builder.")
		state.current.preSpawn = fn
		return api
	end

	---Hook run to after the particular sub-builder spawned e.g. inside a :corpse block
	---@param fn fun(ctx:{ roomDef:RoomDef, anchorName?:string,
	---  position?:{x:integer,y:integer,z:integer} })
	function api:postSpawn(fn)
		assertf(state.current, "postSpawn() no active sub-builder.")
		state.current.postSpawn = fn
		return api
	end

	---Set corpse outfit by name
	---@param name string
	function api:outfit(name)
		requireActive("corpse")
		if type(name) ~= "string" then
			log("outfit(name) expects string; got " .. tostring(name) .. " — using default " .. DEFAULT_OUTFIT)
			state.current.outfit = DEFAULT_OUTFIT
		else
			local trimmed = name:match("^%s*(.-)%s*$")
			if trimmed == "" then
				trimmed = DEFAULT_OUTFIT
			end
			state.current.outfit = trimmed
		end

		return api
	end

	---Add items directly to corpse inventory ("Type" or {"Type", qty}).
	function api:onBody(...)
		requireActive("corpse")
		for _, t in ipairs({ ... }) do
			table.insert(state.current.onBody, t)
		end
		return api
	end

	---Drop items as world items near the corpse square.
	function api:dropNear(...)
		requireActive("corpse")
		for _, t in ipairs({ ... }) do
			table.insert(state.current.dropNear, t)
		end
		return api
	end

	---Configure blood effects.
	---@param tbl? { bruising?:integer, floor_splats?:integer, trail?:boolean }
	function api:blood(tbl)
		requireActive("corpse")
		state.current.blood = {
			bruising = tbl and tbl.bruising or 0,
			floor_splats = tbl and tbl.floor_splats or 0,
			trail = tbl and tbl.trail or false,
		}
		return api
	end

	---Fill the container with items ("Type" or {"Type", qty}).
	function api:addTo(...)
		requireActive("container")
		for _, t in ipairs({ ... }) do
			table.insert(state.current.contains, t)
		end
		return api
	end

	---Define scatter entries. Each arg is "Type" or {"Type", qty}.
	---Entries are atomic; selected entries place whole quantities.
	function api:items(...)
		requireActive("scatter")
		for _, t in ipairs({ ... }) do
			table.insert(state.current.items, t)
		end
		return api
	end

	---Cap number of entries to place (not total pieces).
	---If omitted, all entries are considered.
	---@param n integer
	function api:maxItemNum(n)
		requireActive("scatter")
		state.current.maxItemNum = tonumber(n) or state.current.maxItemNum
		return api
	end

	---Spawn only the most recently defined sub-spec immediately.
	function api:spawnNow()
		enqueueCurrent()
		if #state.queue == 0 then
			log("spawnNow called with empty queue")
			return api
		end
		local last = table.remove(state.queue) -- pop, don't keep
		Placers.spawnOne(state, roomDef, last)
		return api
	end

	---Spawn all queued specs in order.
	function api:spawn()
		enqueueCurrent()
		if #state.queue == 0 then
			log("spawn called with empty queue")
			return api
		end
		for _, spec in ipairs(state.queue) do
			Placers.spawnOne(state, roomDef, spec)
		end
		return api
	end

	---Return the scene tag assigned at begin() time.
	---@return string
	function api:getTag()
		return state.tag
	end
	api.__state = state -- optional debug handle
	return api
end

local Registry = require("SceneBuilder/registry")
-- Bind before loading resolvers so they can register themselves.
Registry.bind(Resolvers)
require("SceneBuilder/resolvers/init")

return Scene
