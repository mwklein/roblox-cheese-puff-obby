--[[
    PlayerData.spec.luau — Unit tests for src/shared/PlayerData.luau

    Run via TestRunner.server.luau in Studio (Play Solo or Server).
    No Roblox services are required; PlayerData is pure Lua.
--]]

return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local PlayerData = require(ReplicatedStorage.Shared.PlayerData)

    -- ── getDefault ────────────────────────────────────────────────────────────

    describe("PlayerData.getDefault", function()
        it("returns currentZone = 1", function()
            expect(PlayerData.getDefault().currentZone).to.equal(1)
        end)

        it("returns totalPuffs = 0", function()
            expect(PlayerData.getDefault().totalPuffs).to.equal(0)
        end)

        it("returns lastCheckpoint = 0", function()
            expect(PlayerData.getDefault().lastCheckpoint).to.equal(0)
        end)

        it("returns a rarePuffs sub-table", function()
            expect(type(PlayerData.getDefault().rarePuffs)).to.equal("table")
        end)

        it("all rare puffs default to false", function()
            local data = PlayerData.getDefault()
            for _, key in ipairs(PlayerData.RARE_PUFF_KEYS) do
                expect(data.rarePuffs[key]).to.equal(false)
            end
        end)

        it("returns independent tables on each call (no shared state)", function()
            local a = PlayerData.getDefault()
            local b = PlayerData.getDefault()
            a.rarePuffs.normal = true
            expect(b.rarePuffs.normal).to.equal(false)
        end)

        it("rarePuffs contains exactly ZONE_COUNT entries", function()
            local data = PlayerData.getDefault()
            local count = 0
            for _ in pairs(data.rarePuffs) do
                count += 1
            end
            expect(count).to.equal(PlayerData.ZONE_COUNT)
        end)
    end)

    -- ── rarePuffKeyForZone ────────────────────────────────────────────────────

    describe("PlayerData.rarePuffKeyForZone", function()
        it("returns 'normal' for zone 1", function()
            expect(PlayerData.rarePuffKeyForZone(1)).to.equal("normal")
        end)

        it("returns 'bronze' for zone 2", function()
            expect(PlayerData.rarePuffKeyForZone(2)).to.equal("bronze")
        end)

        it("returns 'silver' for zone 3", function()
            expect(PlayerData.rarePuffKeyForZone(3)).to.equal("silver")
        end)

        it("returns 'gold' for zone 4", function()
            expect(PlayerData.rarePuffKeyForZone(4)).to.equal("gold")
        end)

        it("returns 'flamingHot' for zone 5", function()
            expect(PlayerData.rarePuffKeyForZone(5)).to.equal("flamingHot")
        end)

        it("returns 'megaFlamingHot' for zone 6", function()
            expect(PlayerData.rarePuffKeyForZone(6)).to.equal("megaFlamingHot")
        end)

        it("returns 'rainbowHot' for zone 7", function()
            expect(PlayerData.rarePuffKeyForZone(7)).to.equal("rainbowHot")
        end)

        it("returns 'galaxy' for zone 8", function()
            expect(PlayerData.rarePuffKeyForZone(8)).to.equal("galaxy")
        end)

        it("returns 'theOne' for zone 9", function()
            expect(PlayerData.rarePuffKeyForZone(9)).to.equal("theOne")
        end)

        it("returns nil for zone 0 (out of range below)", function()
            expect(PlayerData.rarePuffKeyForZone(0)).to.equal(nil)
        end)

        it("returns nil for zone 10 (out of range above)", function()
            expect(PlayerData.rarePuffKeyForZone(10)).to.equal(nil)
        end)

        it("returns nil for large zone numbers", function()
            expect(PlayerData.rarePuffKeyForZone(999)).to.equal(nil)
        end)
    end)

    -- ── sanitise ─────────────────────────────────────────────────────────────

    describe("PlayerData.sanitise", function()
        -- Pass-through: valid data should be unchanged
        it("leaves valid in-range data unchanged", function()
            local data = PlayerData.getDefault()
            data.currentZone = 3
            data.totalPuffs = 5
            data.lastCheckpoint = 2
            data.rarePuffs.gold = true
            PlayerData.sanitise(data)
            expect(data.currentZone).to.equal(3)
            expect(data.totalPuffs).to.equal(5)
            expect(data.lastCheckpoint).to.equal(2)
            expect(data.rarePuffs.gold).to.equal(true)
        end)

        -- Missing top-level fields
        it("fills in missing currentZone with default (1)", function()
            local data = { totalPuffs = 5, lastCheckpoint = 0, rarePuffs = PlayerData.getDefault().rarePuffs }
            PlayerData.sanitise(data)
            expect(data.currentZone).to.equal(1)
        end)

        it("fills in missing totalPuffs with default (0)", function()
            local data = { currentZone = 1, lastCheckpoint = 0, rarePuffs = PlayerData.getDefault().rarePuffs }
            PlayerData.sanitise(data)
            expect(data.totalPuffs).to.equal(0)
        end)

        it("fills in missing lastCheckpoint with default (0)", function()
            local data = { currentZone = 1, totalPuffs = 0, rarePuffs = PlayerData.getDefault().rarePuffs }
            PlayerData.sanitise(data)
            expect(data.lastCheckpoint).to.equal(0)
        end)

        -- Wrong types for top-level fields
        it("resets string currentZone to default", function()
            local data = PlayerData.getDefault()
            data.currentZone = "bad"
            PlayerData.sanitise(data)
            expect(data.currentZone).to.equal(1)
        end)

        it("resets boolean totalPuffs to default", function()
            local data = PlayerData.getDefault()
            data.totalPuffs = true
            PlayerData.sanitise(data)
            expect(data.totalPuffs).to.equal(0)
        end)

        -- Clamping
        it("clamps currentZone below 1 up to 1", function()
            local data = PlayerData.getDefault()
            data.currentZone = -5
            PlayerData.sanitise(data)
            expect(data.currentZone).to.equal(1)
        end)

        it("clamps currentZone above ZONE_COUNT down to ZONE_COUNT", function()
            local data = PlayerData.getDefault()
            data.currentZone = 999
            PlayerData.sanitise(data)
            expect(data.currentZone).to.equal(PlayerData.ZONE_COUNT)
        end)

        it("clamps negative totalPuffs to 0", function()
            local data = PlayerData.getDefault()
            data.totalPuffs = -100
            PlayerData.sanitise(data)
            expect(data.totalPuffs).to.equal(0)
        end)

        it("clamps negative lastCheckpoint to 0", function()
            local data = PlayerData.getDefault()
            data.lastCheckpoint = -1
            PlayerData.sanitise(data)
            expect(data.lastCheckpoint).to.equal(0)
        end)

        -- Flooring
        it("floors decimal currentZone", function()
            local data = PlayerData.getDefault()
            data.currentZone = 2.9
            PlayerData.sanitise(data)
            expect(data.currentZone).to.equal(2)
        end)

        it("floors decimal totalPuffs", function()
            local data = PlayerData.getDefault()
            data.totalPuffs = 7.5
            PlayerData.sanitise(data)
            expect(data.totalPuffs).to.equal(7)
        end)

        it("floors decimal lastCheckpoint", function()
            local data = PlayerData.getDefault()
            data.lastCheckpoint = 3.9
            PlayerData.sanitise(data)
            expect(data.lastCheckpoint).to.equal(3)
        end)

        -- rarePuffs sub-table
        it("replaces missing rarePuffs with a full default sub-table", function()
            local data = { currentZone = 1, totalPuffs = 0, lastCheckpoint = 0 }
            PlayerData.sanitise(data)
            expect(type(data.rarePuffs)).to.equal("table")
            for _, key in ipairs(PlayerData.RARE_PUFF_KEYS) do
                expect(data.rarePuffs[key]).to.equal(false)
            end
        end)

        it("replaces non-table rarePuffs (e.g. a string) with defaults", function()
            local data = PlayerData.getDefault()
            data.rarePuffs = "corrupted"
            PlayerData.sanitise(data)
            expect(type(data.rarePuffs)).to.equal("table")
        end)

        it("fills in a single missing puff key (backward-compat with old saves)", function()
            local data = PlayerData.getDefault()
            data.rarePuffs.galaxy = nil
            PlayerData.sanitise(data)
            expect(data.rarePuffs.galaxy).to.equal(false)
        end)

        it("preserves a puff that is already marked collected (true)", function()
            local data = PlayerData.getDefault()
            data.rarePuffs.gold = true
            PlayerData.sanitise(data)
            expect(data.rarePuffs.gold).to.equal(true)
        end)

        it("resets a puff stored as a non-boolean value to false", function()
            local data = PlayerData.getDefault()
            data.rarePuffs.silver = 1  -- corrupt value from old save format
            PlayerData.sanitise(data)
            expect(data.rarePuffs.silver).to.equal(false)
        end)

        it("returns the same table it received (mutates in place)", function()
            local data = PlayerData.getDefault()
            local returned = PlayerData.sanitise(data)
            expect(returned).to.equal(data)
        end)
    end)

    -- ── Constants ─────────────────────────────────────────────────────────────

    describe("PlayerData constants", function()
        it("RARE_PUFF_KEYS has exactly 9 entries", function()
            expect(#PlayerData.RARE_PUFF_KEYS).to.equal(9)
        end)

        it("ZONE_COUNT equals 9", function()
            expect(PlayerData.ZONE_COUNT).to.equal(9)
        end)

        it("KEY_PREFIX is 'player_'", function()
            expect(PlayerData.KEY_PREFIX).to.equal("player_")
        end)

        it("every RARE_PUFF_KEY has a matching display name in RARE_PUFF_NAMES", function()
            for _, key in ipairs(PlayerData.RARE_PUFF_KEYS) do
                expect(PlayerData.RARE_PUFF_NAMES[key]).to.be.ok()
            end
        end)
    end)
end
