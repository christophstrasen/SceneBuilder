-- SceneBuilder/util.lua

---@class SceneBuilder.Util
local U = {}

function U.makeLogger(tag)
	return function(msg)
		if getDebug() then
			U.log(tag, msg)
		end
	end
end

function U.asStringList(value, default_list)
	local out, seen = {}, {}

	local function addOne(s)
		if type(s) ~= "string" then
			return
		end
		-- trim simple leading/trailing spaces
		s = s:match("^%s*(.-)%s*$")
		if s ~= "" and not seen[s] then
			seen[s] = true
			out[#out + 1] = s
		end
	end

	if type(value) == "string" then
		addOne(value)
	elseif type(value) == "table" then
		for i = 1, #value do
			addOne(value[i])
		end
	end

	if #out > 0 then
		return out
	end

	if type(default_list) == "table" and #default_list > 0 then
		for i = 1, #default_list do
			addOne(default_list[i]) -- fills 'out'
		end
		return (#out > 0) and out or nil
	end

	return nil
end

function U.clampInt(n, minv)
	local x = math.floor(tonumber(n) or 0)
	if x < (minv or 0) then
		x = (minv or 0)
	end
	return x
end

--- Chebyshev distance (L∞) in 2D.
function U.cheby(x1, y1, x2, y2)
	local dx = math.abs((x1 or 0) - (x2 or 0))
	local dy = math.abs((y1 or 0) - (y2 or 0))
	return (dx > dy) and dx or dy
end

function U.shallowCopy(t)
	if type(t) ~= "table" then
		return {}
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

function U.logCtx(tag, msg, ctx)
	if not getDebug() then
		return
	end
	local parts = {}
	for k, v in pairs(ctx or {}) do
		parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
	end
	local suffix = (#parts > 0) and (" " .. table.concat(parts, " ")) or ""
	U.log(tag, msg .. suffix)
end

function U.log(tag, msg)
	-- Avoid colon in logs to prevent truncation in B42.
	print("[", tostring(tag or "SB"), "] ", tostring(msg or ""))
end

function U.assertf(cond, msg)
	if not cond then
		error(tostring(msg or "assert failed"), 2)
	end
	return cond
end

-- Simple cache keyed by tostring(key); returns {get, put, clear}
function U.simpleCache()
	local store = {}
	local M = {}
	function M.get(key)
		return store[tostring(key)]
	end
	function M.put(key, val)
		store[tostring(key)] = val
	end
	function M.clear()
		store = {}
	end
	return M
end

--- Neutral selector with optional shuffling.
--- deterministic ~= false => take first `take`, no RNG, no mutation.
--- deterministic == false => Fisher–Yates shuffle then take.
--- @param pool table
--- @param take number|nil
--- @param deterministic boolean
--- @return table|nil
function U.shortlistFromPool(pool, take, deterministic)
	if not pool or #pool == 0 then
		return nil
	end
	local n = #pool
	local k = math.min(n, math.max(1, math.floor(take or 1)))

	-- Deterministic (default): use as-is, no mutation, no RNG
	if deterministic ~= false then
		local out = {}
		for i = 1, k do
			out[i] = pool[i]
		end
		return out
	end

	-- Non-deterministic: Fisher–Yates in-place, then take
	for i = n, 2, -1 do
		local j = ZombRand(i) + 1
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out = {}
	for i = 1, k do
		out[i] = pool[i]
	end
	return out
end

--- Deterministic 32-bit hash (djb2) that works in Lua 5.1.
--- @param s string
--- @return integer
function U.hash32(s)
	local h = 5381
	for i = 1, #s do
		-- shift left 5 bits and add, using arithmetic only (no bitops)
		h = (h * 32 + h + s:byte(i)) % 0x100000000
	end
	-- make positive 32-bit integer
	if h < 0 then
		h = -h
	end
	return h
end

--- Build a compact nil-safe stable key from varargs.
--- @param ... any
--- @return string
function U.buildKey(...)
	-- NOTE: We intentionally avoid `{...}` + `#t` here:
	-- - Lua sequences stop at the first nil; `#t` becomes wrong when any argument is nil.
	-- - SceneBuilder uses this for deterministic keys/hashes; silently dropping segments would break idempotence.
	local n = select("#", ...)
	local t = {}
	for i = 1, n do
		local v = select(i, ...)
		if v == nil then
			t[i] = "∅"
		elseif type(v) == "table" then
			t[i] = tostring(v)
		else
			t[i] = tostring(v)
		end
	end
	return table.concat(t, "|")
end

--- 1..k pick index using stable hash (k<=1 -> 1).
--- @param key string
--- @param k number|nil
--- @return integer
function U.pickIdxHash(key, k)
	if not k or k <= 1 then
		return 1
	end
	local h = U.hash32(key)
	return (h % k) + 1
end

---@return SceneBuilder.Util
return U
