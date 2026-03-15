--[[
    DataManagerAPI.luau — ModuleScript (ServerScriptService/Server)

    The shared API surface between DataManager.server.luau (which populates it)
    and ZoneManager.server.luau (which consumes it).

    Because Roblox caches module results, both scripts receive the exact same
    table, so mutations made by DataManager are immediately visible to
    ZoneManager — no _G required.
--]]

local DataManagerAPI = {}

-- These functions are assigned by DataManager.server.luau at startup.
-- They are nil until that script runs, so ZoneManager must WaitForChild
-- on the DataManager script or rely on task.defer ordering (DataManager
-- loads first alphabetically and both are in the same Script container).

DataManagerAPI.getData           = nil :: ((Player) -> table?)?
DataManagerAPI.addPuff           = nil :: ((Player, number?) -> ())?
DataManagerAPI.collectRarePuff   = nil :: ((Player, string) -> boolean)?
DataManagerAPI.setCheckpoint     = nil :: ((Player, number) -> ())?
DataManagerAPI.saveNow           = nil :: ((Player) -> ())?

return DataManagerAPI
