--[[
    HUDController.client.luau — StarterPlayerScripts/Client

    Responsibilities:
    • Listen to server RemoteEvents (CollectPuff, ZoneComplete, AnnounceOneP).
    • Update the player's HUD in response to those events.
    • All UI mutations happen here; nothing is trusted from the server beyond
      the event payload — layout / display is purely cosmetic.

    TODO (Studio): Create a ScreenGui named "ObbyHUD" under StarterGui with
      the following children before this script will display live data:
        • TextLabel  "ZoneLabel"      — shows "Zone X / 9"
        • TextLabel  "PuffCount"      — shows total puff count
        • Frame      "RarePuffPanel"  — contains ImageLabels for each rare puff
        • TextLabel  "Announcement"   — full-width banner for One Puff events
          (set Visible = false by default; shown briefly then hidden)
        • TextLabel  "CollectToast"   — brief pop-up "Collected <name>!"

    The code below references those instances by name. If they are missing it
    will warn and skip gracefully so the logic layer still functions.
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local PlayerData = require(ReplicatedStorage.Shared.PlayerData)

local localPlayer = Players.LocalPlayer

-- ── Wait for RemoteEvents ─────────────────────────────────────────────────────

local Events         = ReplicatedStorage:WaitForChild("Events")
local evCollectPuff  = Events:WaitForChild("CollectPuff")  :: RemoteEvent
local evZoneComplete = Events:WaitForChild("ZoneComplete") :: RemoteEvent
local evAnnounceOneP = Events:WaitForChild("AnnounceOneP") :: RemoteEvent

-- ── HUD reference helpers ─────────────────────────────────────────────────────
--
-- TODO (Studio): Replace WaitForChild timeouts with your actual ScreenGui path
--   once the ObbyHUD ScreenGui exists. Until then these return nil and every
--   function below is a no-op.

local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Try to find the HUD. Returns nil if not present (graceful degradation).
local function findHUD(): ScreenGui?
    -- TODO (Studio): Rename "ObbyHUD" if you call your ScreenGui something else.
    return playerGui:FindFirstChild("ObbyHUD") :: ScreenGui?
end

local function findLabel(name: string): TextLabel?
    local hud = findHUD()
    if not hud then return nil end
    return hud:FindFirstChild(name, true) :: TextLabel?
end

-- ── Local state (mirrors server state) ───────────────────────────────────────
--
-- We maintain a lightweight client-side mirror so the HUD can display totals
-- without a round-trip. The server is the source of truth; this is display only.

local clientState = {
    currentZone = 1,
    totalPuffs  = 0,
    rarePuffs   = {},
}

-- ── UI update functions ───────────────────────────────────────────────────────

local function refreshZoneLabel()
    local label = findLabel("ZoneLabel")
    if label then
        label.Text = string.format("Zone  %d / %d", clientState.currentZone, PlayerData.ZONE_COUNT)
    end
end

local function refreshPuffCount()
    local label = findLabel("PuffCount")
    if label then
        label.Text = string.format("Puffs  %d", clientState.totalPuffs)
    end
end

--- Shows a brief toast message (e.g. "Collected Galaxy Puff!").
--- Tweens opacity in then out over toastDuration seconds.
local function showToast(message: string, toastDuration: number?)
    local duration = toastDuration or 2.5
    local label = findLabel("CollectToast")
    if not label then
        -- Fallback: just print to output so progress is still visible.
        print("[HUDController] Toast:", message)
        return
    end

    label.Text = message
    label.TextTransparency = 0
    label.Visible = true

    -- Tween out after duration.
    task.delay(duration, function()
        local tween = TweenService:Create(
            label,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextTransparency = 1 }
        )
        tween:Play()
        tween.Completed:Connect(function()
            label.Visible = false
        end)
    end)
end

--- Shows the announcement banner for The One Puff transfers.
local function showAnnouncement(message: string)
    local label = findLabel("Announcement")
    if not label then
        print("[HUDController] Announcement:", message)
        return
    end

    label.Text = message
    label.TextTransparency = 0
    label.Visible = true

    -- Hold for 5 seconds then fade out.
    task.delay(5, function()
        local tween = TweenService:Create(
            label,
            TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextTransparency = 1 }
        )
        tween:Play()
        tween.Completed:Connect(function()
            label.Visible = false
        end)
    end)
end

--- Updates the rare-puff panel to highlight collected puffs.
--- TODO (Studio): In the RarePuffPanel, add one ImageLabel per rare puff key,
---   named exactly after the key (e.g. "flamingHot"). Uncollected puffs should
---   have ImageTransparency = 0.6 (dimmed); collected ones = 0 (full colour).
local function refreshRarePuffPanel()
    local hud = findHUD()
    if not hud then return end
    local panel = hud:FindFirstChild("RarePuffPanel", true)
    if not panel then return end

    for _, key in ipairs(PlayerData.RARE_PUFF_KEYS) do
        local icon = panel:FindFirstChild(key)
        if icon and icon:IsA("ImageLabel") then
            icon.ImageTransparency = clientState.rarePuffs[key] and 0 or 0.6
        end
    end
end

-- ── RemoteEvent handlers ──────────────────────────────────────────────────────

-- CollectPuff: server → this client only
-- Args: puffType (string), isRare (boolean)
evCollectPuff.OnClientEvent:Connect(function(puffType: string, isRare: boolean)
    -- Update local state.
    clientState.totalPuffs += 1
    if isRare then
        clientState.rarePuffs[puffType] = true
    end

    -- Refresh HUD elements.
    refreshPuffCount()
    if isRare then
        refreshRarePuffPanel()
        local displayName = PlayerData.RARE_PUFF_NAMES[puffType] or puffType
        showToast("Collected " .. displayName .. "!")
    else
        showToast("+1 Puff", 1.2)
    end
end)

-- ZoneComplete: server → this client only
-- Args: completedZone (number)
evZoneComplete.OnClientEvent:Connect(function(completedZone: number)
    -- Advance the local zone mirror.
    clientState.currentZone = math.min(completedZone + 1, PlayerData.ZONE_COUNT)
    refreshZoneLabel()

    local msg = completedZone == PlayerData.ZONE_COUNT
        and "You completed the final zone!"
        or  string.format("Zone %d complete!", completedZone)
    showToast(msg, 3)
end)

-- AnnounceOneP: server → ALL clients
-- Args: winnerName (string), prevHolder (string?)
evAnnounceOneP.OnClientEvent:Connect(function(winnerName: string, prevHolder: string?)
    local msg: string
    if prevHolder then
        msg = string.format(
            "%s claimed The One Puff from %s!",
            winnerName, prevHolder
        )
    else
        msg = string.format("%s is the first to claim The One Puff!", winnerName)
    end

    showAnnouncement(msg)

    -- Extra toast for the local player if they are the winner.
    if localPlayer.Name == winnerName then
        showToast("YOU hold The One Puff!", 4)
    end
end)

-- ── Initial HUD setup ─────────────────────────────────────────────────────────
--
-- TODO (Studio): Once the HUD ScreenGui is built, call these on CharacterAdded
--   to reset the HUD display to the player's saved state. Currently they are
--   called with default values.
--
-- To properly initialise from saved data, you would fire a RemoteFunction from
-- here to the server to fetch the current session state (currentZone, totalPuffs,
-- rarePuffs) and populate clientState before refreshing the HUD.

task.spawn(function()
    -- Small delay to let the HUD ScreenGui load after character spawn.
    task.wait(1)
    refreshZoneLabel()
    refreshPuffCount()
    refreshRarePuffPanel()
    print("[HUDController] HUD initialised.")
end)
