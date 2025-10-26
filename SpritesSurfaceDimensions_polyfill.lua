-- ============================================================================
-- 1) SpritesSurfaceDimensions Polyfill (Build 42)
-- ============================================================================
-- Intent
--   Lightweight, self-contained fallback for a sprite’s usable surface box
--   in X/Y/Z “pixel” space of an IsoSquare. Inspired by Champy’s ItemStories
--   (https://steamcommunity.com/sharedfiles/filedetails/?id=3569303590).
--
-- Purpose
--   • Prevent floating or clipping items when accurate surface data is missing.
--   • Provide consistent offsets for placement logic across mods.
--   • Merge automatically with a global SpriteDimensions table if present.
--     If Champy’s “ItemStories” mod is installed, its dataset will be used and
--     extended automatically—recommended for more accurate presets.
--
-- Core idea
--   Each sprite has a “placement box”: a 0–100% rectangle of safe spawn area.
--   If a sprite is unknown, two global presets apply:
--     • defaultRaised  → for tables, counters, shelves
--     • defaultFloor   → for ground level
--   Entries may include `overrideExactOffsetZ` to force an explicit pixel offset.
--
-- API summary
--   SD.get(name, returnDefaults?)       → entry, pattern-matched, or floor default
--   SD.getDefaultRaised() / getDefaultFloor()  → explicit defaults
--   SD.set(names, fields)               → define or override sprite boxes
--
-- Behavior
--   • Lazily merges once with SpriteDimensions if that global exists and is valid.
--   • Polyfill fields always take precedence per key.
--
-- Usage
--   local box = SD.get(spriteName, false) or SD.getDefaultRaised()
--
-- ============================================================================

---@class SpriteDimensionsEntry
---@field minOffsetX integer  -- usable X-range minimum (0–100)
---@field maxOffsetX integer  -- usable X-range maximum (0–100)
---@field minOffsetY integer  -- usable Y-range minimum (0–100)
---@field maxOffsetY integer  -- usable Y-range maximum (0–100)
---@field overrideExactOffsetZ number|nil  -- Z offset in pixels; nil = use sprite surface

---@class SpriteDimensionsAPI
---@field default SpriteDimensionsEntry
---@field defaultOnFloor SpriteDimensionsEntry
---@field list table<string, SpriteDimensionsEntry>
---@field set fun(names: string[], fields: table)
---@field get fun(name: string, returnDefaults: boolean|nil): SpriteDimensionsEntry|nil
---@field getDefaultFloor fun(): SpriteDimensionsEntry|nil
---@field getDefaultRaised fun(): SpriteDimensionsEntry|nil

SpriteDimensionsPolyfill = SpriteDimensionsPolyfill or {} ---@type SpriteDimensionsAPI

-- ============================================================================
-- Internal state (lazy merge + pin)
-- ============================================================================
local U = require("SceneBuilder/util")
local LOG_TAG = "SpriteDimensionsPolyfill"
local log = U.makeLogger(LOG_TAG)
local assertf = U.assertf
local _pinned = false
local _merged_handle = nil -- merged copy or Polyfill itself
local _notifiedPatternMatch = {} -- file-scope (top-level) small set

log("SpritesSurfaceDimensions_polyfill.lua starting")

-- ============================================================================
-- 1) Core defaults (polyfill-owned baseline)
-- ============================================================================

-- Default for raised surfaces (tables, counters, shelves).
SpriteDimensionsPolyfill.default = SpriteDimensionsPolyfill.default
	or {
		minOffsetX = 35,
		maxOffsetX = 65,
		minOffsetY = 35,
		maxOffsetY = 65,
		overrideExactOffsetZ = nil, -- nil = rely on sprite's Surface property
	}

-- Default for floor-level placement (ground contact).
SpriteDimensionsPolyfill.defaultOnFloor = SpriteDimensionsPolyfill.defaultOnFloor
	or {
		minOffsetX = 18,
		maxOffsetX = 82,
		minOffsetY = 18,
		maxOffsetY = 82,
		overrideExactOffsetZ = 0, -- exact floor contact
	}

-- Explicit sprite entries defined by the polyfill or callers via .set.
SpriteDimensionsPolyfill.list = SpriteDimensionsPolyfill.list or {}

-- ============================================================================
-- 2) Helpers: clone, validate, and merge
-- ============================================================================

-- Add near helpers section
local _ALLOWED = {
	minOffsetX = true,
	maxOffsetX = true,
	minOffsetY = true,
	maxOffsetY = true,
	overrideExactOffsetZ = true,
}

local function _assertEntryFields(f, label)
	if f == nil then
		return
	end
	assertf(type(f) == "table", "fields for must be table for label=" .. tostring(label))
	for k, _ in pairs(f) do
		assertf(_ALLOWED[k], "unknown field=" .. tostring(k) .. " for label=" .. tostring(label))
	end
	local function chk(a, b, nameA, nameB)
		if a ~= nil then
			assertf(type(a) == "number", "must be number nameA=" .. nameA)
			assertf(a >= 0 and a <= 100, "out of range 0..100 nameA=" .. nameA)
		end
		if b ~= nil then
			assertf(type(b) == "number", "must be number nameB=" .. nameB)
			assertf(b >= 0 and b <= 100, "out of range 0..100 nameB=" .. nameB)
		end
		if a and b then
			assertf(a <= b, "a must be ≤= b nameA=" .. nameA .. " nameB=" .. nameB)
		end
	end
	chk(f.minOffsetX, f.maxOffsetX, "minOffsetX", "maxOffsetX")
	chk(f.minOffsetY, f.maxOffsetY, "minOffsetY", "maxOffsetY")
	if f.overrideExactOffsetZ ~= nil then
		assertf(type(f.overrideExactOffsetZ) == "number", "overrideExactOffsetZ must be number")
	end
end

---@param base SpriteDimensionsEntry|nil
---@param overrides table|nil
---@return SpriteDimensionsEntry
local function cloneEntry(base, overrides)
	local src = base or SpriteDimensionsPolyfill.default
	local out = {
		minOffsetX = src.minOffsetX,
		maxOffsetX = src.maxOffsetX,
		minOffsetY = src.minOffsetY,
		maxOffsetY = src.maxOffsetY,
		overrideExactOffsetZ = src.overrideExactOffsetZ,
	}
	if overrides then
		for k, v in pairs(overrides) do
			out[k] = v
		end
	end
	return out
end

---@param n any
---@return boolean
local function isNumber(n)
	return type(n) == "number"
end

---@param sd any
---@return boolean
local function validateSpriteDimensions(sd)
	if type(sd) ~= "table" then
		return false
	end
	local def = sd.default
	if type(def) ~= "table" then
		return false
	end
	return isNumber(def.minOffsetX)
		and isNumber(def.maxOffsetX)
		and isNumber(def.minOffsetY)
		and isNumber(def.maxOffsetY)
end

---@param real any
---@return table res, table stats
local function makeMerged(real)
	local stats = { real = 0, real_kept = 0, poly_over = 0, poly_only = 0 }
	-- Start from a deep-ish copy of the polyfill table
	local res = {
		default = cloneEntry(SpriteDimensionsPolyfill.default),
		defaultOnFloor = cloneEntry(SpriteDimensionsPolyfill.defaultOnFloor),
		list = {},
	}

	-- Bring over all real.list entries
	if type(real.list) == "table" then
		for k, v in pairs(real.list) do
			if type(v) == "table" then
				res.list[k] = cloneEntry(v)
				stats.real = stats.real + 1
				stats.real_kept = stats.real_kept + 1
			end
		end
	end

	-- Merge defaults with poly taking precedence per field
	do
		local rdef = real.default
		if type(rdef) == "table" then
			res.default = cloneEntry(rdef)
		end
		for k, v in pairs(SpriteDimensionsPolyfill.default) do
			res.default[k] = v
		end

		local rflo = real.defaultOnFloor
		if type(rflo) == "table" then
			res.defaultOnFloor = cloneEntry(rflo)
		end
		for k, v in pairs(SpriteDimensionsPolyfill.defaultOnFloor) do
			res.defaultOnFloor[k] = v
		end
	end

	-- Merge per-entry: if poly has an entry, its fields override real
	for k, pEntry in pairs(SpriteDimensionsPolyfill.list) do
		local base = res.list[k]
		if base then
			for fk, fv in pairs(pEntry) do
				-- count only if actually overriding a present key
				if base[fk] ~= nil and base[fk] ~= fv then
					stats.poly_over = stats.poly_over + 1
				end
				base[fk] = fv
			end
		else
			res.list[k] = cloneEntry(SpriteDimensionsPolyfill.default, pEntry)
			stats.poly_only = stats.poly_only + 1
		end
	end

	return res, stats
end

local function ensureMerged()
	if _pinned then
		return
	end

	local real = _G and _G.SpriteDimensions or rawget(_G or {}, "SpriteDimensions")
	if validateSpriteDimensions(real) then
		local merged, stats = makeMerged(real)
		_merged_handle = merged
		_pinned = true
		U.logCtx(LOG_TAG, "merge complete", stats or {})
		return
	end

	if real ~= nil then
		U.logCtx(LOG_TAG, "invalid SpriteDimensions", { type = type(real) })
	end
	_merged_handle = SpriteDimensionsPolyfill
	_pinned = true
end

local function resolved()
	ensureMerged()
	return _merged_handle or SpriteDimensionsPolyfill
end

-- ============================================================================
-- 3) Public API (set / single getter)
-- ============================================================================

--- Define or replace explicit sprite entries.
---@param names string[]
---@param fields table  -- partial or complete SpriteDimensionsEntry
function SpriteDimensionsPolyfill.set(names, fields)
	assertf(type(names) == "table", "names must be table")
	_assertEntryFields(fields, "set")
	local f = type(fields) == "table" and fields or nil

	for _, name in ipairs(names) do
		assertf(type(name) == "string" and name ~= "", "name must be non-empty string")
		SpriteDimensionsPolyfill.list[name] = cloneEntry(SpriteDimensionsPolyfill.default, f)
	end

	-- If we already merged, update the merged copy per precedence rule
	if not (_pinned and _merged_handle and _merged_handle ~= SpriteDimensionsPolyfill) then
		return
	end

	local mh = _merged_handle
	if type(mh.list) ~= "table" then
		mh.list = {}
	end
	if type(mh.default) ~= "table" then
		mh.default = SpriteDimensionsPolyfill.default
	end

	for _, name in ipairs(names) do
		local base = type(mh.list[name]) == "table" and mh.list[name] or nil
		if base then
			if f then
				for k, v in pairs(f) do
					base[k] = v
				end
			end
		else
			mh.list[name] = cloneEntry(mh.default, f)
		end
	end
end

--- Single accessor.
--- name: sprite name to look up
--- returnDefaults: when true/nil → fallback to defaultOnFloor; false → return nil
---@param name string
---@param returnDefaults boolean|nil
---@return SpriteDimensionsEntry|nil
function SpriteDimensionsPolyfill.get(name, returnDefaults)
	local h = resolved()
	local lst = type(h.list) == "table" and h.list or nil
	local hit = lst and rawget(lst, name) or nil
	if hit then
		return hit
	end

	-- Pattern fallback: strip trailing _NNN segments, then choose best prefix match
	local function findByPattern(nm)
		if not lst then
			return nil
		end
		local base = tostring(nm or "")
		while true do
			if lst[base] then
				return lst[base]
			end
			local nb = base:gsub("_[0-9]+$", "")
			if nb == base or #nb == 0 then
				break
			end
			base = nb
		end
		local best, bestLen = nil, 0
		for k, v in pairs(lst) do
			if type(k) == "string" and base:sub(1, #k) == k and #k > bestLen then
				best, bestLen = v, #k
			end
		end
		return best
	end

	local patt = findByPattern(name)
	if patt then
		if not _notifiedPatternMatch[name] then
			U.logCtx(LOG_TAG, "pattern match", { name = name })
			_notifiedPatternMatch[name] = true
		end
		return patt
	end

	if returnDefaults == false then
		return nil
	end

	local flo = type(h.defaultOnFloor) == "table" and h.defaultOnFloor or SpriteDimensionsPolyfill.defaultOnFloor
	return flo
end

--- Get the raised-surface default box.
---@return SpriteDimensionsEntry
function SpriteDimensionsPolyfill.getDefaultRaised()
	local h = resolved()
	return type(h.default) == "table" and h.default or SpriteDimensionsPolyfill.default
end

--- Get the floor default box.
---@return SpriteDimensionsEntry
function SpriteDimensionsPolyfill.getDefaultFloor()
	local h = resolved()
	return type(h.defaultOnFloor) == "table" and h.defaultOnFloor or SpriteDimensionsPolyfill.defaultOnFloor
end

-- ============================================================================
-- 4) Minimal explicit entries (polyfill opinions)
-- ============================================================================

SpriteDimensionsPolyfill.set({
	"fixtures_counters_01_1",
	"furniture_tables_high_01_6",
	"furniture_tables_high_01_9",
	"fixtures_counters_01_4",
	"fixtures_counters_01_5",
	"furniture_office_desk_01_0",
	"furniture_office_desk_01_1",
	"furniture_endtable_01_0",
	"fixtures_counters_01_7",
}, SpriteDimensionsPolyfill.default)

SpriteDimensionsPolyfill.set({
	"furniture_tables_high_01_8",
	"furniture_tables_high_01_55",
}, {
	minOffsetX = 12,
	maxOffsetX = 31,
	minOffsetY = 12,
	maxOffsetY = 31,
	overrideExactOffsetZ = 10,
})
