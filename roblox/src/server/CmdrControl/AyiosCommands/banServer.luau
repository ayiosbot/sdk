---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
local AyiosSDK = require(game.ServerScriptService.AyiosSDK)


return function (context, playerId, reason)
    local status, result = AyiosSDK.Moderation:CreateRecord({
        offender_id = playerId,
        moderator_id = context.Executor.UserId,
        type = AyiosSDK.Moderation.Spec.RecordType.BAN,
        reason = reason or "No reason provided",
        -- filtered_reason = 'mandatory somehow',
        place_id = AyiosSDK.Gateway.PLACE_ID,
        attributes = {},
        created_at = os.time(),
        -- history = {},
        -- metadata = {
        --     increment = {-1},
        -- },
        version = 0,
        expires_at = -1,
        flags = AyiosSDK.Bitfield.apply(
            0,
            {
                AyiosSDK.Moderation.Spec.RecordFlag.ACTIVE
            }
        )
        -- custom_attributes = {
        --     is_anticheat_ban = false,
        --     is_anticheat_ban_potentially_false = false,
        -- }
    }):awaitStatus()

    -- the
    if status == 'Resolved' then
        local message = `Player banned successfully. Record ID: {result.record_id}`

        if result.directive_id then
            message = `{message}\nThe player will be removed from game shortly.`
        end

        return message
    else
        return `CmdFail: {result}`
    end
end