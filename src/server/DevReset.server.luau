--[[
    DevReset.server.luau -- ServerScriptService/Server
    DEVELOPMENT ONLY -- delete before publishing to players.

    Resets data on join for whitelisted developer usernames only.
    Safe to leave running during development -- will never affect
    real players since it checks username before resetting.
--]]

local Players = game:GetService("Players")
local API = require(script.Parent.DataManagerAPI)

-- Add your Roblox username here
local DEV_USERNAMES = {
	"loopback_again",
}

local function isDev(player: Player): boolean
	for _, name in ipairs(DEV_USERNAMES) do
		if player.Name == name then
			return true
		end
	end
	return false
end

Players.PlayerAdded:Connect(function(player: Player)
	if not isDev(player) then
		return
	end

	task.wait(3) -- wait for DataManager to populate session

	local data = API.getData(player)
	if not data then
		warn("[DevReset] No session found for", player.Name)
		return
	end

	data.currentZone = 1
	data.lastCheckpoint = 0
	data.totalPuffs = 0
	for k in pairs(data.rarePuffs) do
		data.rarePuffs[k] = false
	end

	API.saveNow(player)
	print("[DevReset] Reset complete for", player.Name, "-- starting at zone 1")
end)
