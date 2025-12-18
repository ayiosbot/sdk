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

local Network = require(script.Parent.Parent.Network)
local Promise = require(script.Parent.Parent.TypedPromise)
local Spec = require(script.Spec)
local ModerationSpec = require(script.Parent.Moderation.Spec)

type Promise<T...> = Promise.TypedPromise<T...>;
type PlayerCache = {
    joined_at: number;
    user_id: number;
    username: string;
}

local PLAYER_JOIN_CONNECTION: RBXScriptConnection
local PLAYER_REMOVE_CONNECTION: RBXScriptConnection



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
Gateway.PLACE_ID = tostring(game.PlaceId)
Gateway.JOB_ID = game.JobId :: string
Gateway.Spec = Spec
Gateway.IsProcessingActive = false
Gateway.RequestQueue = {}
Gateway.Cache = {
    Players     = {} :: { PlayerCache },
    NewPlayers  = {} :: { PlayerCache },
    LeftPlayers = {} :: { PlayerCache }
}

Gateway.OnPlayerAction = function(directiveID: string, record: ModerationSpec.RecordDefinition)
    local messages = {
        -- parrot the not defined
        `[AYIOS-SDK] Action implementation (record {record._id}; user {record.offender_id}) not defined.`,
        `[AYIOS-SDK] Record details: Type {record.type}, Reason: {record.reason}`,
        `[AYIOS-SDK] Please implement 'Gateway.OnPlayerAction' to handle actions appropriately.`,
        `[AYIOS-SDK] Directive ID: {directiveID}`
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
    local players = Players:GetPlayers()

    for _, player in pairs(players) do
        local isInPlayers = false
        local isInNewPlayers = false

        for _, p in pairs(Gateway.Cache.Players) do
            if p.user_id == player.UserId then
                isInPlayers = true
                break
            end
        end
        for _, p in pairs(Gateway.Cache.NewPlayers) do
            if p.user_id == player.UserId then
                isInNewPlayers = true
                break
            end
        end

        if not isInPlayers and not isInNewPlayers then
            table.insert(Gateway.Cache.NewPlayers, {
                joined_at = os.time(),
                user_id = player.UserId,
                username = player.Name
            })
        end
    end

    PLAYER_JOIN_CONNECTION = Players.PlayerAdded:Connect(function(player)
        table.insert(Gateway.Cache.NewPlayers, {
            joined_at = os.time(),
            user_id = player.UserId,
            username = player.Name
        })
    end)

    PLAYER_REMOVE_CONNECTION = Players.PlayerRemoving:Connect(function(player)
        for index, cachedPlayer in pairs(Gateway.Cache.Players) do
            if cachedPlayer.user_id == player.UserId then
                table.remove(Gateway.Cache.Players, index)

                table.insert(Gateway.Cache.LeftPlayers, {
                    username = player.Name,
                    joined_at = cachedPlayer.joined_at,
                    user_id = player.UserId
                })
                break
            end
        end

        for index, cachedPlayer in pairs(Gateway.Cache.NewPlayers) do
            if cachedPlayer.user_id == player.UserId then
                table.remove(Gateway.Cache.NewPlayers, index)
                break
            end
        end
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
            for _, player in pairs(newPlayerCache) do
                table.insert(Gateway.Cache.Players, player)
            end

            Gateway:UpdatePlayers(newPlayerCache, oldPlayerCache)
                :andThen(function(response)
                    for _, directive in pairs(response.directives) do
                        warn('[AYIOS-SDK] Processing directive ' .. tostring(directive.id))
                        Gateway:ProcessDirective(directive)
                    end
                end)
                :catch(function(err)
                    warn('[AYIOS-SDK] Failed to update players: ' .. tostring(err))
                end)
        end
    end)

    game:BindToClose(function()
        Gateway:Destroy(false)
        Gateway:DeleteServer(Gateway.JOB_ID):catch(function(err)
            warn('[AYIOS-SDK] Failed to delete server on shutdown: ' .. tostring(err))
        end)
    end)
end

function Gateway.Destroy(self: typeof(Gateway), doReset: boolean)
    PLAYER_JOIN_CONNECTION:Disconnect()
    PLAYER_REMOVE_CONNECTION:Disconnect()
    Gateway.Cache.Players = {}
    Gateway.Cache.NewPlayers = {}
    Gateway.Cache.LeftPlayers = {}
    Gateway.RequestQueue = {}
    Gateway.IsProcessingActive = false

    if doReset then
        Gateway:BeginProcessing()
    end
end

function Gateway.CreateServer(self: typeof(Gateway), serverData: Spec.ServerCreateDefinition): Promise<nil>
    return Promise.new(function(resolve, reject)
        Network:CreateRequest({
            method = 'POST',
            endpoint = `{self.BASE_URL}/servers/{Gateway.PLACE_ID}/create`,
            body = serverData
        }):andThen(function(response)
            if response.Success then
                resolve(nil)
            else
                if response.StatusCode == 409 then
                    -- who cares if conflict? thats ok!
                    warn("[AYIOS-SDK] Create server request conflict - server already exists. Ignoring error")
                    return resolve(nil)
                end
                reject("[AYIOS-SDK] Create server request failed")
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
            endpoint = `{self.BASE_URL}/servers/{Gateway.PLACE_ID}/{Gateway.JOB_ID}/players`,
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
    if not serverID then serverID = Gateway.JOB_ID end
    return Promise.new(function(resolve, reject)
        Network:CreateRequest({
            method = 'DELETE',
            endpoint = `{self.BASE_URL}/servers/{Gateway.PLACE_ID}/{serverID}`,
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
        Gateway.OnPlayerAction(directive.id, directive.record)
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
            endpoint = `{self.BASE_URL}/servers/{Gateway.PLACE_ID}/{Gateway.JOB_ID}/directives/execute`,
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