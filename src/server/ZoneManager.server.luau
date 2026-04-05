--[[
    ZoneManager.server.luau — ServerScriptService/Server

    Responsibilities:
    • Wire up Touched events on common puff collectibles and checkpoint parts
      (geometry must be tagged in Studio — see TODO comments below).
    • Handle zone completion: fire ZoneComplete RemoteEvent to the completing
      player, update DataManager, and trigger rare-puff award.
    • Enforce "The One Puff" championship belt mechanic:
        – Only one player server-wide may hold theOne at a time.
        – When Zone 9 is completed, the belt transfers and AnnounceOneP fires
          to ALL clients.
    • All inputs validated server-side before mutating player data.

    Depends on: DataManagerAPI (ModuleScript in the same Server folder)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local DataManagerAPI = require(script.Parent.DataManagerAPI)
-- Wait for DataManager to populate the API (it runs concurrently at startup).
while DataManagerAPI.addPuff == nil do
	task.wait(0.1)
end
-- ── RemoteEvents ──────────────────────────────────────────────────────────────

local Events = ReplicatedStorage:WaitForChild("Events")
local evCollectPuff = Events:WaitForChild("CollectPuff") :: RemoteEvent
local evZoneComplete = Events:WaitForChild("ZoneComplete") :: RemoteEvent
local evAnnounceOneP = Events:WaitForChild("AnnounceOneP") :: RemoteEvent

-- ── "The One Puff" server state ───────────────────────────────────────────────

-- Tracks which player currently holds The One Puff (nil = no holder yet).
local onePuffHolder: Player? = nil

-- ── Helper: get Player from a hit part ───────────────────────────────────────

local function playerFromHit(hit: BasePart): Player?
	local character = hit.Parent
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

-- ── Cooldown guard (prevents rapid duplicate triggers) ───────────────────────

-- Maps "player_instanceId" → last trigger time (seconds).
local lastTrigger: { [string]: number } = {}
local TRIGGER_COOLDOWN = 0.5 -- seconds

local function canTrigger(player: Player, instanceId: string): boolean
	local key = player.UserId .. "_" .. instanceId
	local now = os.clock()
	if (lastTrigger[key] or 0) + TRIGGER_COOLDOWN > now then
		return false
	end
	lastTrigger[key] = now
	return true
end

-- Clean up cooldown entries when a player leaves.
Players.PlayerRemoving:Connect(function(player: Player)
	local prefix = player.UserId .. "_"
	for key in pairs(lastTrigger) do
		if key:sub(1, #prefix) == prefix then
			lastTrigger[key] = nil
		end
	end
end)

-- ── Common puff collection ────────────────────────────────────────────────────

--- Wires a single common-puff part so touching it awards one puff to the player.
--- The part is made invisible and non-collidable after collection per-player
--- via a BoolValue child named after the player's UserId (no Part destroy, since
--- it needs to exist for other players).
local function wireCommonPuff(puffPart: BasePart)
	print("[ZoneManager] Wiring common puff:", puffPart:GetFullName())
	puffPart.Touched:Connect(function(hit: BasePart)
		print("[ZoneManager] Touched by:", hit.Name, "| Parent:", hit.Parent and hit.Parent.Name or "nil")

		local player = playerFromHit(hit)
		if not player then
			print("[ZoneManager] No player found from hit")
			return
		end
		print("[ZoneManager] Player found:", player.Name)

		if not canTrigger(player, tostring(puffPart)) then
			print("[ZoneManager] Blocked by cooldown")
			return
		end
		print("[ZoneManager] Passed cooldown check")

		-- Per-player collection flag stored as a BoolValue child.
		local flagName = "collected_" .. player.UserId
		if puffPart:FindFirstChild(flagName) then
			print("[ZoneManager] Already collected by", player.Name)
			return
		end
		print("[ZoneManager] Passed collection flag check")

		local flag = Instance.new("BoolValue")
		flag.Name = flagName
		flag.Parent = puffPart

		-- Update DataStore session.
		DataManagerAPI.addPuff(player, 1)
		print("[ZoneManager] addPuff called successfully")

		-- Notify this client so the HUD can update.
		evCollectPuff:FireClient(player, "common", false, puffPart)
		print("[ZoneManager] FireClient called")
	end)
end

-- ── Rare puff collection ──────────────────────────────────────────────────────

--- Wires the rare-puff part at the end of a zone.
--- puffKey must match one of PlayerData.RARE_PUFF_KEYS.
--- zoneNumber is validated against the player's current zone before awarding.
local function wireRarePuff(puffPart: BasePart, puffKey: string, zoneNumber: number)
	-- Validate puffKey at wire-time, not at touch-time.
	if not table.find(PlayerData.RARE_PUFF_KEYS, puffKey) then
		error("[ZoneManager] Invalid puffKey passed to wireRarePuff: " .. tostring(puffKey))
	end

	puffPart.Touched:Connect(function(hit: BasePart)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		if not canTrigger(player, tostring(puffPart) .. "_rare") then
			return
		end

		-- Server-side validation: player must be on the correct zone.
		local data = DataManagerAPI.getData(player)
		if not data then
			return
		end
		if data.currentZone ~= zoneNumber then
			return
		end

		-- Attempt to award the rare puff (returns false if already owned).
		local awarded = DataManagerAPI.collectRarePuff(player, puffKey)
		if not awarded then
			return
		end

		-- Notify the player.
		evCollectPuff:FireClient(player, puffKey, true, puffPart)
		evZoneComplete:FireClient(player, zoneNumber)

		-- Save immediately on zone completion.
		DataManagerAPI.saveNow(player)

		print(string.format("[ZoneManager] %s completed zone %d (%s).", player.Name, zoneNumber, puffKey))

		-- The One Puff special handling (Zone 9).
		if puffKey == "theOne" then
			local prevHolder = onePuffHolder
			local prevName: string? = prevHolder and prevHolder.Name or nil

			-- Revoke from previous holder if they're still in the server.
			if prevHolder and prevHolder ~= player then
				local prevData = DataManagerAPI.getData(prevHolder)
				if prevData then
					prevData.rarePuffs.theOne = false
				end
			end

			onePuffHolder = player

			-- Announce server-wide.
			evAnnounceOneP:FireAllClients(player.Name, prevName)
			print(
				string.format(
					"[ZoneManager] The One Puff transferred to %s (prev: %s).",
					player.Name,
					tostring(prevName)
				)
			)
		end
	end)
end

-- ── Checkpoint wiring ─────────────────────────────────────────────────────────

--- Wires a checkpoint part. checkpointIndex is an integer ≥ 1.
--- On touch, the player's respawn position is updated and lastCheckpoint saved.
local function wireCheckpoint(checkpointPart: BasePart, checkpointIndex: number)
	checkpointPart.Touched:Connect(function(hit: BasePart)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		if not canTrigger(player, tostring(checkpointPart) .. "_cp") then
			return
		end

		local data = DataManagerAPI.getData(player)
		if not data then
			return
		end

		-- Only move forward, never back.
		if checkpointIndex <= data.lastCheckpoint then
			return
		end

		DataManagerAPI.setCheckpoint(player, checkpointIndex)

		-- Update the player's respawn CFrame so they spawn at this checkpoint.
		-- TODO (Studio): Anchor an invisible SpawnLocation (or HumanoidRootPart
		--   CFrame setter) at each checkpoint part position. Then uncomment:
		--[[
        local character = player.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Set a persistent spawn CFrame via a leaderstats attribute or
                -- a custom SpawnLocation that gets enabled here.
            end
        end
        ]]
	end)
end

-- ── Kill zone wiring (Zone 5 +) ───────────────────────────────────────────────

--- Wires a kill-zone part (lava, fire, etc.).
--- On touch, the player's Humanoid health is set to 0 (respawns at checkpoint).
local function wireKillZone(killPart: BasePart)
	killPart.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end)
end

-- ── Zone 8: Low-gravity VectorForce ───────────────────────────────────────────
--
-- workspace.Gravity is global, so we cannot change it per-player.
-- Instead, each player entering Zone 8 gets a VectorForce attachment that
-- applies an upward counter-force, simulating lower gravity for that character.
--
-- TODO (Studio): Create a "Zone8Region" Part tagged "Zone8Entry" and
--   "Zone8Exit" in the workspace. The code below will pick them up.
--   Adjust ZONE8_GRAVITY_SCALE to tune the feel (0 = weightless, 0.5 = half).
--
local ZONE8_GRAVITY_SCALE = 0.4 -- fraction of normal gravity to counteract
local ZONE8_ATTACHMENT_NAME = "LowGravForce"

local function applyLowGravity(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	if hrp:FindFirstChild(ZONE8_ATTACHMENT_NAME) then
		return
	end -- already applied

	local attachment = Instance.new("Attachment")
	attachment.Name = ZONE8_ATTACHMENT_NAME
	attachment.Parent = hrp

	local vf = Instance.new("VectorForce")
	vf.Attachment0 = attachment
	-- Counter-force = mass * g * scale.  Roblox default gravity = 196.2 stud/s².
	-- Mass isn't directly readable, so we use a fixed value tuned for R15 rigs.
	-- TODO (Studio): Tune this value in play-test; typical R15 character ~16 kg.
	vf.Force = Vector3.new(0, workspace.Gravity * 16 * ZONE8_GRAVITY_SCALE, 0)
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.Parent = attachment

	print("[ZoneManager] Low gravity applied to " .. character.Name)
end

local function removeLowGravity(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local attachment = hrp:FindFirstChild(ZONE8_ATTACHMENT_NAME)
	if attachment then
		attachment:Destroy()
		print("[ZoneManager] Low gravity removed from " .. character.Name)
	end
end

-- ── CollectionService tag wiring ──────────────────────────────────────────────
--
-- In Studio, add these CollectionService tags to the relevant parts:
--
--   "CommonPuff"       — any common puff collectible in the workspace
--   "RarePuff_Z<N>"   — the rare puff at the end of zone N (e.g. "RarePuff_Z1")
--   "Checkpoint_<N>"  — checkpoint parts, N = integer index (e.g. "Checkpoint_3")
--   "KillZone"        — any lava / fire / void kill part
--   "Zone8Entry"      — trigger part that starts low-gravity for Zone 8
--   "Zone8Exit"       — trigger part that ends low-gravity for Zone 8
--
-- This script listens for tagged instances and wires them up automatically,
-- so parts added dynamically (or at runtime via Studio) are also handled.

-- Common puffs
local function onCommonPuffAdded(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	wireCommonPuff(part :: BasePart)
end
CollectionService:GetInstanceAddedSignal("CommonPuff"):Connect(onCommonPuffAdded)
for _, part in ipairs(CollectionService:GetTagged("CommonPuff")) do
	onCommonPuffAdded(part)
end

-- Rare puffs: tag format "RarePuff_Z<N>"
for zoneNum = 1, PlayerData.ZONE_COUNT do
	local tag = "RarePuff_Z" .. zoneNum
	local puffKey = PlayerData.rarePuffKeyForZone(zoneNum)
	if not puffKey then
		continue
	end

	local function onRarePuffAdded(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		wireRarePuff(part :: BasePart, puffKey, zoneNum)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onRarePuffAdded)
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		onRarePuffAdded(part)
	end
end

-- Checkpoints: tag format "Checkpoint_<N>"
-- TODO (Studio): Tag each checkpoint platform with "Checkpoint_<N>" where N
--   is a sequential integer (e.g. "Checkpoint_1", "Checkpoint_2", ...).
--   Checkpoints span across all zones; the index just tracks progress order.
for checkpointIdx = 1, 999 do
	local tag = "Checkpoint_" .. checkpointIdx
	local function onCheckpointAdded(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		wireCheckpoint(part :: BasePart, checkpointIdx)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onCheckpointAdded)
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		onCheckpointAdded(part)
	end
end

-- Kill zones
local function onKillZoneAdded(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	wireKillZone(part :: BasePart)
end
CollectionService:GetInstanceAddedSignal("KillZone"):Connect(onKillZoneAdded)
for _, part in ipairs(CollectionService:GetTagged("KillZone")) do
	onKillZoneAdded(part)
end

-- Zone 8 low-gravity entry/exit triggers
-- TODO (Studio): Place large invisible Parts tagged "Zone8Entry" and "Zone8Exit"
--   at the entrance and exit of Zone 8. They should span the full traversal
--   path so every player route triggers them.
local function onZone8EntryAdded(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local entryPart = part :: BasePart
	entryPart.Touched:Connect(function(hit: BasePart)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local character = player.Character
		if character then
			applyLowGravity(character)
		end
	end)
end

local function onZone8ExitAdded(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local exitPart = part :: BasePart
	exitPart.Touched:Connect(function(hit: BasePart)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local character = player.Character
		if character then
			removeLowGravity(character)
		end
	end)
end

CollectionService:GetInstanceAddedSignal("Zone8Entry"):Connect(onZone8EntryAdded)
for _, part in ipairs(CollectionService:GetTagged("Zone8Entry")) do
	onZone8EntryAdded(part)
end

CollectionService:GetInstanceAddedSignal("Zone8Exit"):Connect(onZone8ExitAdded)
for _, part in ipairs(CollectionService:GetTagged("Zone8Exit")) do
	onZone8ExitAdded(part)
end

-- Clean up low-gravity force when a player's character respawns.
Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(_character: Model)
		-- Low-gravity attachment lives in the character so it's destroyed on
		-- respawn automatically.  Nothing to do here — character is new.
	end)
end)

-- ── Zone 7: Color-match mechanic ──────────────────────────────────────────────
--
-- TODO (Studio): Zone 7 platforms cycle through colors. Each platform part
--   should be tagged "ColorPlatform". A server-side loop (or RunService)
--   changes their BrickColor on a timer. When a player stands on a platform
--   whose current color matches the "required color" (display in HUD via a
--   custom RemoteEvent), they survive; otherwise the platform briefly
--   becomes non-collidable and they fall.
--
--   Implementation sketch:
--     1. Tag platforms "ColorPlatform" and add a StringValue "RequiredColor".
--     2. Run a loop here that sets part.BrickColor to a random sequence.
--     3. On Touched, compare part.BrickColor to RequiredColor.
--     4. If mismatch, set CanCollide = false for 1s then restore.

print("[ZoneManager] Initialised. Waiting for tagged parts in Studio.")
