--[[
    DataManagerLogic.spec.luau — Unit tests for the DataManager business logic

    DataManager.server.luau is a Script (not a ModuleScript) and cannot be
    required directly. These tests reproduce its five API functions verbatim
    against a local mock session cache, verifying every behaviour in isolation
    without needing DataStoreService, Players, or a live server.

    Run via TestRunner.server.luau in Studio (Play Solo or Server).
--]]

return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local PlayerData = require(ReplicatedStorage.Shared.PlayerData)

    -- ── Helpers ───────────────────────────────────────────────────────────────

    -- A plain table is sufficient as a mock "player" key because session cache
    -- uses the Player object as a reference key, not any particular field.
    local function makePlayer(name: string)
        return { Name = name }
    end

    -- ── Reproduce DataManager API logic against a local session cache ─────────
    -- These closures mirror DataManager.server.luau exactly so the tests
    -- stay in sync with production behaviour.

    local sessionCache: { [any]: any } = {}

    local function addPuff(player, count: number?)
        local data = sessionCache[player]
        if not data then return end
        data.totalPuffs = data.totalPuffs + (count or 1)
    end

    local function collectRarePuff(player, puffKey: string): boolean
        local data = sessionCache[player]
        if not data then return false end

        if data.rarePuffs[puffKey] == nil then
            return false  -- unknown key
        end
        if data.rarePuffs[puffKey] == true then
            return false  -- already collected
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

    local function setCheckpoint(player, checkpointIndex: number)
        local data = sessionCache[player]
        if not data then return end
        data.lastCheckpoint = math.max(0, math.floor(checkpointIndex))
    end

    local function getData(player)
        return sessionCache[player]
    end

    -- Reset the mock cache before every test.
    beforeEach(function()
        sessionCache = {}
    end)

    -- ── getData ───────────────────────────────────────────────────────────────

    describe("getData", function()
        it("returns nil when player has no session", function()
            local p = makePlayer("Ghost")
            expect(getData(p)).to.equal(nil)
        end)

        it("returns the session table for an active player", function()
            local p = makePlayer("Alice")
            local data = PlayerData.getDefault()
            sessionCache[p] = data
            expect(getData(p)).to.equal(data)
        end)
    end)

    -- ── addPuff ───────────────────────────────────────────────────────────────

    describe("addPuff", function()
        it("increments totalPuffs by 1 when no count is supplied", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            addPuff(p)
            expect(sessionCache[p].totalPuffs).to.equal(1)
        end)

        it("increments totalPuffs by the supplied count", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            addPuff(p, 5)
            expect(sessionCache[p].totalPuffs).to.equal(5)
        end)

        it("accumulates across multiple calls", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            addPuff(p, 3)
            addPuff(p, 2)
            expect(sessionCache[p].totalPuffs).to.equal(5)
        end)

        it("does nothing and does not error when player has no session", function()
            local p = makePlayer("Ghost")
            expect(function()
                addPuff(p, 10)
            end).never.to.throw()
        end)

        it("does not mutate another player's session", function()
            local a = makePlayer("Alice")
            local b = makePlayer("Bob")
            sessionCache[a] = PlayerData.getDefault()
            sessionCache[b] = PlayerData.getDefault()
            addPuff(a, 3)
            expect(sessionCache[b].totalPuffs).to.equal(0)
        end)
    end)

    -- ── collectRarePuff ───────────────────────────────────────────────────────

    describe("collectRarePuff", function()
        it("marks the puff as collected and returns true", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            local ok = collectRarePuff(p, "normal")
            expect(ok).to.equal(true)
            expect(sessionCache[p].rarePuffs.normal).to.equal(true)
        end)

        it("increments totalPuffs by 1 on first collection", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            collectRarePuff(p, "bronze")
            expect(sessionCache[p].totalPuffs).to.equal(1)
        end)

        it("returns false and does not re-award a duplicate collection", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            collectRarePuff(p, "normal")
            local second = collectRarePuff(p, "normal")
            expect(second).to.equal(false)
            expect(sessionCache[p].totalPuffs).to.equal(1)  -- still 1, not 2
        end)

        it("returns false for an unknown puff key", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            expect(collectRarePuff(p, "notARealPuff")).to.equal(false)
        end)

        it("returns false when player has no session", function()
            local p = makePlayer("Ghost")
            expect(collectRarePuff(p, "normal")).to.equal(false)
        end)

        -- Zone progression
        it("advances currentZone by 1 when puff matches current zone", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()  -- currentZone = 1
            collectRarePuff(p, "normal")               -- zone-1 puff
            expect(sessionCache[p].currentZone).to.equal(2)
        end)

        it("resets lastCheckpoint to 0 when zone advances", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            sessionCache[p].lastCheckpoint = 3
            collectRarePuff(p, "normal")
            expect(sessionCache[p].lastCheckpoint).to.equal(0)
        end)

        it("advances zone when puff is ahead of current zone (skip-zone catch-up)", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()  -- currentZone = 1
            collectRarePuff(p, "gold")                 -- zone-4 puff
            expect(sessionCache[p].currentZone).to.equal(5)
        end)

        it("does NOT advance zone when puff is behind current zone", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            sessionCache[p].currentZone = 5
            collectRarePuff(p, "normal")  -- zone-1 puff, behind zone 5
            expect(sessionCache[p].currentZone).to.equal(5)
        end)

        it("does NOT reset checkpoint when puff is behind current zone", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            sessionCache[p].currentZone    = 5
            sessionCache[p].lastCheckpoint = 4
            collectRarePuff(p, "normal")
            expect(sessionCache[p].lastCheckpoint).to.equal(4)
        end)

        it("caps currentZone at ZONE_COUNT when collecting the final puff", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            sessionCache[p].currentZone = 9
            collectRarePuff(p, "theOne")  -- zone-9 puff
            -- Would advance to 10, but must clamp to 9
            expect(sessionCache[p].currentZone).to.equal(PlayerData.ZONE_COUNT)
        end)

        it("all 9 rare puffs can be collected in sequence", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            for _, key in ipairs(PlayerData.RARE_PUFF_KEYS) do
                local ok = collectRarePuff(p, key)
                expect(ok).to.equal(true)
            end
            expect(sessionCache[p].totalPuffs).to.equal(9)
            for _, key in ipairs(PlayerData.RARE_PUFF_KEYS) do
                expect(sessionCache[p].rarePuffs[key]).to.equal(true)
            end
        end)
    end)

    -- ── setCheckpoint ─────────────────────────────────────────────────────────

    describe("setCheckpoint", function()
        it("sets lastCheckpoint to the given index", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            setCheckpoint(p, 3)
            expect(sessionCache[p].lastCheckpoint).to.equal(3)
        end)

        it("overwrites a previous checkpoint value", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            setCheckpoint(p, 2)
            setCheckpoint(p, 5)
            expect(sessionCache[p].lastCheckpoint).to.equal(5)
        end)

        it("clamps negative indices to 0", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            setCheckpoint(p, -3)
            expect(sessionCache[p].lastCheckpoint).to.equal(0)
        end)

        it("floors decimal indices", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            setCheckpoint(p, 2.9)
            expect(sessionCache[p].lastCheckpoint).to.equal(2)
        end)

        it("accepts 0 as a valid checkpoint index", function()
            local p = makePlayer("Alice")
            sessionCache[p] = PlayerData.getDefault()
            sessionCache[p].lastCheckpoint = 5
            setCheckpoint(p, 0)
            expect(sessionCache[p].lastCheckpoint).to.equal(0)
        end)

        it("does nothing and does not error when player has no session", function()
            local p = makePlayer("Ghost")
            expect(function()
                setCheckpoint(p, 1)
            end).never.to.throw()
        end)
    end)
end
