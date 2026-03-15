--[[
    DataManager.server.luau — ServerScriptService/Server

    Responsibilities:
    • Load player data from DataStore on join (with retry + fallback to defaults).
    • Expose an in-memory cache of live player data to other server scripts
      via the shared DataManagerAPI ModuleScript.
    • Auto-save all sessions every AUTO_SAVE_INTERVAL seconds.
    • Save + clean up on PlayerRemoving to prevent data loss.

    Never trust the client — all writes go through server-side functions only.
--]]

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData        = require(ReplicatedStorage.Shared.PlayerData)

-- API module shared with ZoneManager (same ServerScriptService container).
local DataManagerAPI = require(script.Parent.DataManagerAPI)

-- ── Constants ─────────────────────────────────────────────────────────────────

local STORE_NAME         = "CheesePuffObby_v1"
local AUTO_SAVE_INTERVAL = 60  -- seconds between background saves
local MAX_RETRIES        = 3   -- DataStore retry attempts
local RETRY_DELAY        = 2   -- seconds between retries

-- ── DataStore reference ───────────────────────────────────────────────────────

local dataStore = DataStoreService:GetDataStore(STORE_NAME)

-- ── In-memory session cache ───────────────────────────────────────────────────

local sessionCache: { [Player]: table } = {}

-- ── Helper: build DataStore key ───────────────────────────────────────────────

local function datastoreKey(player: Player): string
    return PlayerData.KEY_PREFIX .. player.UserId
end

-- ── Helper: load from DataStore with retries ──────────────────────────────────

local function loadFromStore(player: Player): table
    local key     = datastoreKey(player)
    local loaded  = nil
    local success = false

    for attempt = 1, MAX_RETRIES do
        local ok, result = pcall(function()
            return dataStore:GetAsync(key)
        end)

        if ok then
            loaded  = result
            success = true
            break
        else
            warn(string.format(
                "[DataManager] GetAsync failed for %s (attempt %d/%d): %s",
                player.Name, attempt, MAX_RETRIES, tostring(result)
            ))
            if attempt < MAX_RETRIES then
                task.wait(RETRY_DELAY)
            end
        end
    end

    if not success then
        warn("[DataManager] All retries exhausted for " .. player.Name
            .. ". Falling back to default data.")
    end

    if loaded == nil then
        return PlayerData.getDefault()
    end

    return PlayerData.sanitise(loaded)
end

-- ── Helper: save to DataStore with retries ────────────────────────────────────

local function saveToStore(player: Player, data: table)
    local key = datastoreKey(player)

    for attempt = 1, MAX_RETRIES do
        local ok, err = pcall(function()
            dataStore:SetAsync(key, data)
        end)

        if ok then
            return
        else
            warn(string.format(
                "[DataManager] SetAsync failed for %s (attempt %d/%d): %s",
                player.Name, attempt, MAX_RETRIES, tostring(err)
            ))
            if attempt < MAX_RETRIES then
                task.wait(RETRY_DELAY)
            end
        end
    end

    warn("[DataManager] Failed to save data for " .. player.Name
        .. " after " .. MAX_RETRIES .. " attempts.")
end

-- ── Public API (assigned into the shared module) ─────────────────────────────

function DataManagerAPI.getData(player: Player): table?
    return sessionCache[player]
end

function DataManagerAPI.addPuff(player: Player, count: number?)
    local data = sessionCache[player]
    if not data then
        return
    end
    data.totalPuffs = data.totalPuffs + (count or 1)
end

--- Returns false if the puff was already owned (duplicate guard).
function DataManagerAPI.collectRarePuff(player: Player, puffKey: string): boolean
    local data = sessionCache[player]
    if not data then
        return false
    end

    if data.rarePuffs[puffKey] == nil then
        warn("[DataManager] Unknown rare puff key: " .. tostring(puffKey))
        return false
    end

    if data.rarePuffs[puffKey] == true then
        return false
    end

    data.rarePuffs[puffKey] = true
    data.totalPuffs = data.totalPuffs + 1

    local zoneForPuff = table.find(PlayerData.RARE_PUFF_KEYS, puffKey)
    if zoneForPuff and zoneForPuff >= data.currentZone then
        data.currentZone    = math.min(zoneForPuff + 1, PlayerData.ZONE_COUNT)
        data.lastCheckpoint = 0
    end

    return true
end

function DataManagerAPI.setCheckpoint(player: Player, checkpointIndex: number)
    local data = sessionCache[player]
    if not data then
        return
    end
    data.lastCheckpoint = math.max(0, math.floor(checkpointIndex))
end

function DataManagerAPI.saveNow(player: Player)
    local data = sessionCache[player]
    if not data then
        return
    end
    saveToStore(player, data)
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
    task.spawn(function()
        local data          = loadFromStore(player)
        sessionCache[player] = data
        print(string.format(
            "[DataManager] Loaded data for %s — zone %d, %d puffs",
            player.Name, data.currentZone, data.totalPuffs
        ))
    end)
end

local function onPlayerRemoving(player: Player)
    local data = sessionCache[player]
    if data then
        saveToStore(player, data)
        sessionCache[player] = nil
        print("[DataManager] Saved and cleared session for " .. player.Name)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

-- ── Auto-save loop ────────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        task.wait(AUTO_SAVE_INTERVAL)
        local count = 0
        for player, data in pairs(sessionCache) do
            saveToStore(player, data)
            count += 1
        end
        if count > 0 then
            print(string.format("[DataManager] Auto-saved %d session(s).", count))
        end
    end
end)
