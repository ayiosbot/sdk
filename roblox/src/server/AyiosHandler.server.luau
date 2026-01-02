---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
local Players = game:GetService('Players')
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService('ServerScriptService')

local SDKM = ServerScriptService.AyiosSDK
local SDK = require(SDKM)
local ModerationSpec = require(SDKM.Services.Moderation.Spec)
local Bitfield = require(SDKM.Bitfield)
local Gateway = require(ServerScriptService.AyiosSDK.Services.Gateway)
local Secrets = require(script.Parent.Secrets)

local RecordFlag = SDK.Moderation.Spec.RecordFlag
local RecordType = SDK.Moderation.Spec.RecordType

local PRODUCTION_PLACE_ID = game.PlaceId -- 12345678;
local STAGING_PLACE_ID = 87654321;
local GAME_VERSION = `1.0.0`

SDK:SetPlaceID(1)
SDK:SetAPIKey(Secrets.API_KEY)
SDK:SetDebugMode(true)

local CustomAttributes = {
    -- Anticheat ban?
    is_anticheat_ban = 0,
    -- Set this to maybe reverse it later if you have problems
    is_anticheat_ban_potentially_false = 1,

}

if game.PlaceId == STAGING_PLACE_ID then
    GAME_VERSION = `{GAME_VERSION}-staging`
end



-- It is recommended to only create servers if
-- the place is production rather than a development place.
if game.PlaceId == PRODUCTION_PLACE_ID then
    if RunService:IsStudio() then
        SDK.Gateway.JOB_ID = '00000000-0000-0000-0000-000000000000'
    end
    print('create server')
    SDK.Gateway:CreateServer({
        -- created_at = os.time(),
        id = SDK.Gateway.JOB_ID,
        version = GAME_VERSION,
        max_players = Players.MaxPlayers
    }):andThen(function()
        SDK.Gateway:BeginProcessing()
    end)
end

function CreateBanMessage(record: ModerationSpec.RecordDefinition)
    local moderatorName = Players:GetNameFromUserIdAsync(record.moderator_id)
    local messages = {
        `You are banned from the game by {moderatorName}.`,
        `This ban will {
            if record.expires_at == -1 then
                'never expire'
            else
                'expire on ' .. os.date('%Y-%m-%d %H:%M:%S', record.expires_at)
                .. ` (in {tostring(record.expires_at - record.issued_at)} seconds)`
        }.`,
        `Reason: {
            -- In this case, you can store the detailed detection in the 'reason' field
            -- and then show a generic user message.
            -- This is not ideal for logs that show up in a public channel. Support
            -- will be added later to allow for a private moderation reason.
            if Bitfield.hasBit(record.flags, RecordFlag.IS_REASON_FILTERED) then
                if table.find(record.attributes, CustomAttributes.is_anticheat_ban) then
                    'Anticheat detection: Exploiting'
                else
                    record.reason
            else
                'Roblox failed to filter this message.'
        }`,
        `This action was {
            if table.find(record.attributes, CustomAttributes.is_anticheat_ban) then
                'issued by our anticheat systems.'
            else
                'issued by a human moderator.'
        }`
    }

    return table.concat(messages, '\n')
end


-- OnPlayerAction is called whenever an action is taken against a player
-- The player may or may not (but USUALLY is) within the server when this is called.
-- If they are not in the server, nothing is done (apart from executing the directive anyway)
SDK.Gateway.OnPlayerAction = function(directiveID: string, record: ModerationSpec.RecordDefinition)
    local player = Players:GetPlayerByUserId(record.offender_id)

    if not player then
        return SDK.Gateway:ExecuteDirectives({
            directives = {
                [directiveID] = {
                    id = directiveID,
                    status = SDK.Gateway.Spec.DirectiveStatus.FAILED,
                    attributes = {}
                }
            }
        })
    end

    if record.type == RecordType.WARN then
        -- It is up to the game developer to implement the warn function
        -- in their game. This is fired each time a user joins your game, until acknowledged.
        -- A user may have up to three unacknowledged warnings. After that, new ones will not be created.
        -- Note: as of December 2025, this is not yet implemented.
        warn('Player has been warned apparently')
    elseif record.type == RecordType.UNBAN then
        --- shouldnt happen but it will prob
    elseif record.type == RecordType.BAN then
        player:Kick(CreateBanMessage(record))
    elseif record.type == RecordType.KICK then
        warn('kicking player')
        -- This is basically guaranteed to be KICK at this point
        local messages = {
            `You have been kicked by a moderator.`,
            `Reason: {
                if Bitfield.hasBit(record.flags, RecordFlag.IS_REASON_FILTERED) then
                    record.reason
                else
                    'Roblox failed to filter this message.'
            }`
        }
        player:Kick(table.concat(messages, '\n'))
    end

    SDK.Gateway:ExecuteDirectives({
        directives = {
            [directiveID] = {
                id = directiveID,
                status = Gateway.Spec.DirectiveStatus.COMPLETE,
                attributes = {}
            }
        }
    }):catch(function() end)

    return
end

Players.PlayerAdded:Connect(function(player)
    SDK.Moderation:GetActiveRecords(player.UserId):andThen(function(records)
        if not records.active_ban then return end

        player:Kick(CreateBanMessage(records.active_ban))
        -- The ban is always guaranteed to be *active* (not expired / literally active) and of type 'ban'
        -- There is no need to check if it expired. It is automatically handled by Ayios.

        -- If it is active mute, that is different. You can handle that yourself.

    end):catch(function(err)
        warn('Failed to get active moderation records: ' .. tostring(err))
    end)
end)