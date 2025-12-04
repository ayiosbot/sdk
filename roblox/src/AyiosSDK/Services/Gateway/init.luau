---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Network = require('../Network')
local Promise = require('../TypedPromise')
local Spec = require('@self/Spec')
local ModerationSpec = require('./Moderation/Spec')

type Promise<T...> = Promise.TypedPromise<T...>;
type PlayerCache = {
    joined_at: number;
    username: string;
}

local PLAYER_JOIN_CONNECTION: RBXScriptConnection
local PLAYER_REMOVE_CONNECTION: RBXScriptConnection

local RecordType = ModerationSpec.RecordType
local RecordFlag = ModerationSpec.RecordFlag


function deepCopy<T>(original: T): T
    local copy
    if type(original) == "table" then
        copy = {}
        for key, value in pairs(original) do
            copy[deepCopy(key)] = deepCopy(value)
        end
    else
        copy = original
    end
    return copy :: T
end

local Gateway = {}
Gateway.BASE_URL = "/gateway-service"
Gateway.Spec = Spec
Gateway.IsProcessingActive = false
Gateway.RequestQueue = {}
Gateway.Cache = {
    Players     = {} :: { [string]: PlayerCache },
    NewPlayers  = {} :: { [string]: PlayerCache },
    LeftPlayers = {} :: { [string]: PlayerCache }
}

Gateway.OnPlayerAction = function(record: ModerationSpec.RecordDefinition)
    local messages = {
        -- parrot the not defined
        `[AYIOS-SDK] Action implementation (record {record._id}; user {record.offender_id}) not defined.`,
        `[AYIOS-SDK] Record details: Type {record.type}, Reason: {record.reason}`,
        `[AYIOS-SDK] Please implement 'Gateway.OnPlayerAction' to handle actions appropriately.`
    }
    for _, message in pairs(messages) do
        warn(message)
    end
end

function Gateway.BeginProcessing(self: typeof(Gateway))
    if Gateway.IsProcessingActive then
        warn('[AYIOS-SDK] BeginProcessing request ignored - already enabled')
        return
    end
    Gateway.IsProcessingActive = true
    PLAYER_JOIN_CONNECTION = Players.PlayerAdded:Connect(function(player)
        Gateway.Cache.NewPlayers[tostring(player.UserId)] = {
            joined_at = os.time(),
            username = player.Name
        }
    end)
    PLAYER_REMOVE_CONNECTION = Players.PlayerRemoving:Connect(function(player)
        if Gateway.Cache.Players[tostring(player.UserId)] then
            Gateway.Cache.LeftPlayers[tostring(player.UserId)] = {
                username = player.Name,
                joined_at = os.time()
            }
        end
        Gateway.Cache.NewPlayers[tostring(player.UserId)] = nil
    end)

    -- Begin processing (e.g. events, etc)
    -- Generally: Send a request to the server every 3s
    task.spawn(function()
        while true do
            if not Gateway.IsProcessingActive then break end
            task.wait(3)

            local newPlayerCache, oldPlayerCache =
                deepCopy(Gateway.Cache.NewPlayers),
                deepCopy(Gateway.Cache.LeftPlayers)

            Gateway.Cache.NewPlayers = {}
            Gateway.Cache.LeftPlayers = {}
            Gateway:UpdatePlayers(newPlayerCache, oldPlayerCache)
                :andThen(function(response)
                    for _, directive in pairs(response.directives) do
                        Gateway:ProcessDirective(directive)
                    end
                end)
                :catch(function(err)
                    warn('[AYIOS-SDK] Failed to update players: ' .. tostring(err))
                end)
        end
    end)
end

function Gateway.CreateServer(self: typeof(Gateway), serverData: Spec.ServerCreateDefinition): Promise<nil>
    return Promise.new(function(resolve, reject)
        Network:CreateRequest({
            method = 'POST',
            endpoint = `${self.BASE_URL}/servers/{game.PlaceId}/create`,
            body = serverData
        }):andThen(function(response)
            local success, data = pcall(function()
                return HttpService:JSONDecode(response.Body :: string)
            end)
            if success and response.Success then
                resolve(nil)
            else
                reject("[AYIOS-SDK] Failed to decode response body: " .. tostring(data))
            end
        end):catch(function(err)
            reject("[AYIOS-SDK] Request failed: " .. tostring(err))
        end)
    end)
end

function Gateway.UpdatePlayers(
    self: typeof(Gateway),
    newPlayers: typeof(Gateway.Cache.NewPlayers),
    leftPlayers: typeof(Gateway.Cache.LeftPlayers)
): Promise<Spec.ServerDefinition>
    -- code
    return Promise.new(function(resolve, reject)
        Network:CreateRequest({
            method = 'PATCH',
            endpoint = `${self.BASE_URL}/servers/{game.PlaceId}/{game.JobId}/players`,
            body = {
                new_players = newPlayers,
                left_players = leftPlayers
            }
        }):andThen(function(response)
            if response.Success then
                local success, data = pcall(function()
                    return HttpService:JSONDecode(response.Body :: string)
                end)
                if success then
                    resolve(data :: Spec.ServerDefinition)
                else
                    reject("[AYIOS-SDK] Failed to decode response body: " .. tostring(data))
                end
            else
                reject("[AYIOS-SDK] Failed to update players: " .. tostring(response.StatusMessage))
            end
        end):catch(function(err)
            reject("[AYIOS-SDK] Request failed: ".. tostring(err))
        end)
    end)
end

function Gateway.DeleteServer(self: typeof(Gateway), serverID: string): Promise<nil>
    if not serverID then serverID = game.JobId end
    return Promise.new(function(resolve, reject)
        Network:CreateRequest({
            method = 'DELETE',
            endpoint = `${self.BASE_URL}/servers/{game.PlaceId}/{serverID}`,
            body = {
                id = serverID
            }
        }):andThen(function(response)
            if response.Success then
                resolve(nil)
            else
                reject("[AYIOS-SDK] Failed to delete server: " .. tostring(response.StatusMessage))
            end
        end):catch(function(err)
            reject("[AYIOS-SDK] Request failed: " .. tostring(err))
        end)
    end)
end

function Gateway.ProcessDirective(self: typeof(Gateway), directive: Spec.AnyServerDirective)
    if directive.type == Spec.DirectiveType.ANNOUNCEMENT then
        directive = directive :: Spec.AnnouncementDirective
        print(`[AYIOS-SDK] Announcement: {directive.content} from {directive.author}`)
    elseif directive.type == Spec.DirectiveType.MODERATION then
        directive = directive :: Spec.ModerationDirective

        if directive.record.type == RecordType.WARN then
            -- ban, kick, mute are executed by ayios
            -- unban, warn, unmute are separate
            -- but warn might need processing
        else

        end

    elseif directive.type == Spec.DirectiveType.TRIGGER then
        -- custom (not implemented)
    elseif directive.type == Spec.DirectiveType.AYIOS_KILL then
        -- kil
    elseif directive.type == Spec.DirectiveType.AYIOS_RESET then
        -- reset
    elseif directive.type == Spec.DirectiveType.HEARTBEAT then
        -- idk
    end
end
-- {{base_url}}/gateway-service/servers/:place_id/:server_id/directives/execute
-- {
--     "directives": {
--         "525cd52e-557a-4373-a24a-7c6647ce3bdb": {
--             "id": "525cd52e-557a-4373-a24a-7c6647ce3bdb",
--             "status": 2,
--             "attributes": {}
--         }
--     }
-- }

function Gateway.ExecuteDirectives(self: typeof(Gateway), data: Spec.ExecutedDirectivesFull): Promise<nil>
    return Promise.new(function(resolve, reject)
        Network:CreateRequest({
            method = 'POST',
            endpoint = `${self.BASE_URL}/servers/{game.PlaceId}/{game.JobId}/directives/execute`,
            body = data
        }):andThen(function(response)
            if response.Success then
                resolve(nil)
            else
                reject("[AYIOS-SDK] Failed to execute directives: " .. tostring(response.StatusMessage))
            end
        end):catch(function(err)
            reject("[AYIOS-SDK] Request failed: ".. tostring(err))
        end)
    end)
end






return Gateway