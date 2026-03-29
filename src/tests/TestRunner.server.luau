--[[
    TestRunner.server.luau — ServerScriptService/Server/Tests

    Bootstraps TestEZ and runs every *.spec.luau file under this folder.
    Execute in Studio via Play Solo or the server view.

    Results are printed to the Output window. A non-zero exitCode in the
    summary line indicates test failures.
--]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

-- TestEZ is installed as a Wally dev-dependency and synced into
-- ReplicatedStorage.DevPackages via default.project.json.
local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

-- Collect every spec module that lives alongside this runner.
-- TestBootstrap:run() expects ModuleScript instances, not string paths.
local specContainer = ServerScriptService.Server.Tests

TestEZ.TestBootstrap:run({ specContainer })
