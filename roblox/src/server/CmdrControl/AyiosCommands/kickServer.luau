local Players = game:GetService("Players")
---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
local AyiosSDK = require(game.ServerScriptService.AyiosSDK)


return function (context, players: {Player}, reason)

    local results = {}
    for i,player in pairs(players) do
        task.spawn(function()
            local result, status = AyiosSDK.Moderation:CreateRecord({
                offender_id = player.UserId,
                moderator_id = context.Executor.UserId,
                type = AyiosSDK.Moderation.Spec.RecordType.KICK,
                reason = reason,
                place_id = AyiosSDK.Gateway.PLACE_ID,
                attributes = {},
                created_at = os.time(),
                version = 0,
                expires_at = -1,
                flags = AyiosSDK.Bitfield.apply(
                    0,
                    { AyiosSDK.Moderation.Spec.RecordFlag.ACTIVE }
                )
            }):awaitStatus()

            results[player.UserId] = { status, result }
        end)
    end
    context:Reply('Processing...')

    local elapsedTime = 0;
    repeat
        task.wait(0.1)
        elapsedTime = elapsedTime + 0.1
    until elapsedTime >= 10 or (#results == #players)


    for playerId, data in results do
        local status, result = data[1], data[2]
        if status == 'Resolved' then
            context:Reply(`Successfully {Players:GetNameFromUserIdAsync(playerId)}. Record ID: {result.record_id}`)
        else
            context:Reply(`Failed to kick player with UserId {playerId}. Error: {result}`)
        end
    end

    return 'Command executed. The players should be removed from game shortly.'
end