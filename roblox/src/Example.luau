local Players = game:GetService('Players')
local RunService = game:GetService("RunService")

local SDK = require('@self/AyiosSDK')
local ModerationSpec = require('@self/AyiosSDK/Services/Moderation/Spec')
local Bitfield = require('@self/AyiosSDK/Bitfield')

local RecordFlag = SDK.Moderation.Spec.RecordFlag
local RecordType = SDK.Moderation.Spec.RecordType

local PRODUCTION_PLACE_ID = 12345678;
local GAME_VERSION = '1.0.0'

SDK.AUTH_KEY = 'example.auth.key'

local CustomAttributes = {
    -- Anticheat ban? 
    is_anticheat_ban = 0,
    -- Set this to maybe reverse it later if you have problems
    is_anticheat_ban_potentially_false = 1,

}

-- If you're running your live game and not a development place
-- then create the server. Recommended to save Ayios the usage
if game.PlaceId == PRODUCTION_PLACE_ID then
    SDK.Gateway:CreateServer({
        created_at = os.time(),
        id = if RunService:IsStudio() then 'roblox-studio' else game.JobId,
        version = GAME_VERSION
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
        }.`,
        `Reason: {
            if Bitfield.hasBit(record.flags, RecordFlag.IS_REASON_FILTERED) then
                record.reason
            else
                'Roblox failed to filter this message.'
        }`,
        `The ban duration is {
            if record.expires_at == -1 then
                'permanent'
            else
                tostring(record.expires_at - record.issued_at) .. ' seconds'
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

SDK.Gateway.OnPlayerAction = function(directiveID: string, record: ModerationSpec.RecordDefinition)
    local player = Players:GetPlayerByUserId(record.offender_id)

    if not player then
        return SDK.Gateway:ExecuteDirectives({
            directives = {
                {
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
    else
        if record.type == RecordType.BAN then
            player:Kick(CreateBanMessage(record))
        else
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
            player:Kick(messages.concat('\n'))
        end
    end

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