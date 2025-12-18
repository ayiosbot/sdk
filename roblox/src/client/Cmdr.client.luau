---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))
local Admins = require(ReplicatedStorage.Admins)
local Messages = require(ReplicatedStorage.Messages)

-- Configurable, and you can choose multiple keys
Cmdr:SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.Semicolon })

Cmdr.Registry:RegisterHook("BeforeRun", function(context)
    local isAdmin = table.find(Admins, context.Executor.UserId)
    if not isAdmin then
        return Messages.AdminResponse
    end

    return nil
end)