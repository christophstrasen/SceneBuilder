std = "lua51"  -- Specify Lua 5.1 standard

-- Define globals used in Project Zomboid
globals = {
    -- Core Game Functions
    "sendServerCommand",
    "getPlayer",
    "Events",
    "getCell",
    "getGameTime",
    "ZombRand",
    "ZombRandFloat",
    "print",
    "getDebug",
    "isServer",
    "isClient",

    -- Inventory and Item Management
    "instanceItem",
    "InventoryItemFactory",
    "ItemContainer",
    "InventoryItem",

    -- IsoWorld and Grid Management
    "IsoGridSquare",
    "IsoWorld",
    "IsoCell",
    "IsoChunk",
    "IsoMetaGrid",
    "IsoMetaCell",

    -- Characters
    "IsoPlayer",
    "IsoZombie",
    "IsoGameCharacter",

    -- UI Elements
    "ISUIElement",
    "ISBaseTimedAction",
    "ISTimedActionQueue",
    "ISPanel",
    "UIFont",

    -- Map specific
    "WorldMarkers",

    -- Special Objects
    "IsoDeadBody",
    "IsoObject",
    "IsoDirections",
    "RandomizedWorldBase",
    "addBloodSplat",

    --Time
    "getTimestampMs",

    -- Mod-Specific Globals
    "NarratedClues",
    "SceneBuilder",
    "SpriteDimensions",
    "SpriteDimensionsPolyfill"
}

-- Exclude unnecessary warnings
ignore = {
    "211", -- Unused variable
    "212", -- Unused argument
    "432", -- Shadowing upvalue argument (common in builder DSL closures)
    "631"  -- Line is too long (types and docs often exceed limits)
}
