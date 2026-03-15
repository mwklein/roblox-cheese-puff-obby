--[[
    PlayerData.luau — Shared module (ReplicatedStorage/Shared)

    Defines the canonical data schema for each player and provides
    helper utilities used by both server and client code.
--]]

local PlayerData = {}

-- Ordered list of rare puff keys, matching zone indices 1–9.
PlayerData.RARE_PUFF_KEYS = {
    "normal",        -- Zone 1
    "bronze",        -- Zone 2
    "silver",        -- Zone 3
    "gold",          -- Zone 4
    "flamingHot",    -- Zone 5
    "megaFlamingHot",-- Zone 6
    "rainbowHot",    -- Zone 7
    "galaxy",        -- Zone 8
    "theOne",        -- Zone 9
}

-- Human-readable display names for each rare puff type.
PlayerData.RARE_PUFF_NAMES = {
    normal        = "Normal Puff",
    bronze        = "Bronze Puff",
    silver        = "Silver Puff",
    gold          = "Gold Puff",
    flamingHot    = "Flaming Hot Puff",
    megaFlamingHot= "Mega Flaming Hot Puff",
    rainbowHot    = "Rainbow Hot Puff",
    galaxy        = "Galaxy Puff",
    theOne        = "The One Puff",
}

-- Total number of zones.
PlayerData.ZONE_COUNT = 9

-- DataStore key prefix. Full key: "player_" .. player.UserId
PlayerData.KEY_PREFIX = "player_"

--- Returns a fresh default data table for a new player.
--- This must remain a function (not a constant) so each player
--- gets an independent copy of the rarePuffs sub-table.
function PlayerData.getDefault(): table
    return {
        currentZone    = 1,
        totalPuffs     = 0,
        lastCheckpoint = 0,
        rarePuffs = {
            normal         = false,
            bronze         = false,
            silver         = false,
            gold           = false,
            flamingHot     = false,
            megaFlamingHot = false,
            rainbowHot     = false,
            galaxy         = false,
            theOne         = false,
        },
    }
end

--- Returns the rare-puff key for a given zone number (1-indexed).
--- Returns nil for out-of-range zones.
function PlayerData.rarePuffKeyForZone(zone: number): string?
    return PlayerData.RARE_PUFF_KEYS[zone]
end

--- Validates and sanitises a data table loaded from DataStore.
--- Fills in any missing fields with defaults so old saves stay compatible.
function PlayerData.sanitise(data: table): table
    local default = PlayerData.getDefault()

    -- Top-level numeric fields
    if type(data.currentZone) ~= "number" then
        data.currentZone = default.currentZone
    end
    if type(data.totalPuffs) ~= "number" then
        data.totalPuffs = default.totalPuffs
    end
    if type(data.lastCheckpoint) ~= "number" then
        data.lastCheckpoint = default.lastCheckpoint
    end

    -- rarePuffs sub-table
    if type(data.rarePuffs) ~= "table" then
        data.rarePuffs = default.rarePuffs
    else
        for _, key in ipairs(PlayerData.RARE_PUFF_KEYS) do
            if type(data.rarePuffs[key]) ~= "boolean" then
                data.rarePuffs[key] = false
            end
        end
    end

    -- Clamp values to legal ranges
    data.currentZone = math.clamp(
        math.floor(data.currentZone), 1, PlayerData.ZONE_COUNT
    )
    data.totalPuffs     = math.max(0, math.floor(data.totalPuffs))
    data.lastCheckpoint = math.max(0, math.floor(data.lastCheckpoint))

    return data
end

return PlayerData
