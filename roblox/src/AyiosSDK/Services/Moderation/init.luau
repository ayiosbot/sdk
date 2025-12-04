---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
--!strict
local HttpService = game:GetService("HttpService")

local Network = require('../Network')
local Promise = require('../TypedPromise')
local Spec = require('@self/Spec')

type Promise<T...> = Promise.TypedPromise<T...>;

local Moderation = {}
Moderation.BASE_URL = "/moderation-service"
Moderation.Spec = Spec
-- what if i just switch to
-- Result, and then ise promises too? idk

function Moderation.GetActiveRecords(self: typeof(Moderation), userID: number): Promise<Spec.ActiveRecordResponse>
    return Promise.new(function(resolve, reject)
        Network:CreateRequest({
            method = 'GET',
            endpoint = `${self.BASE_URL}/records/{game.PlaceId}/{userID}`
        }):andThen(function(response)
            local success, data = pcall(function()
                return HttpService:JSONDecode(response.Body :: string) :: Spec.ActiveRecordResponse
            end)
            if success and response.Success then
                resolve(data)
            else
                reject("[AYIOS-SDK] Failed to decode response body: " .. tostring(data))
            end
        end):catch(function(err)
            reject("[AYIOS-SDK] Request failed: " .. tostring(err))
        end)
    end)
end

return Moderation