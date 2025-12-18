---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
--!strict
local HttpService = game:GetService('HttpService')

local Promise = require(script.Parent.TypedPromise)

export type RequestOptions = {
    method: "GET" | "POST" | "PUT"  | "PATCH" | "DELETE";
    endpoint: string;
    body: any?;
}

local AYIOS_API_KEY = ''

type HttpResponse = {
    Success: boolean;
    StatusCode: number;
    StatusMessage: string;
    Body: string?;
}


local Network = {}
Network.BASE_URL = 'https://api.ayios.xyz/v0'
Network.CLIENT_VERSION = "1.0.0-sdk"
Network.Queue = {} :: {{options: RequestOptions, resolve: any, reject: any}}
Network.RequestTimes = {} :: {number}
Network.IsProcessing = false
Network.IsDebugMode = false

function Network:SetAPIKey(key: string)
    AYIOS_API_KEY = key
end

local function processNextRequest()
    if Network.IsProcessing or #Network.Queue == 0 then return end
    Network.IsProcessing = true
    
    local item = Network.Queue[1]
    
    -- Wait for rate limit (3 requests per 3 seconds)
    while #Network.RequestTimes >= 3 do
        local oldestTime = Network.RequestTimes[1]
        local waitTime = 3 - (os.clock() - oldestTime)
        if waitTime > 0 then
            task.wait(waitTime)
        end
        table.remove(Network.RequestTimes, 1)
    end

    Network.RequestTimes[#Network.RequestTimes + 1] = os.clock()

    -- Execute request, retry on 500x errors
    local success, response
    repeat
        success, response = pcall(function()
            if Network.IsDebugMode then
                print(`[AYIOS-SDK] Sending to {Network.BASE_URL}/{item.options.endpoint}`)
            end
            return HttpService:RequestAsync({
                Method = item.options.method,
                Url = `{Network.BASE_URL}{item.options.endpoint}`,
                Headers = {
                    ["Authorization"] = AYIOS_API_KEY,
                    ["X-Client-Version"] = Network.CLIENT_VERSION,
                    ["Content-Type"] = "application/json",
                },
                Body = if item.options.body then
                    HttpService:JSONEncode(item.options.body)
                else nil,
                Compress = Enum.HttpCompression.None
            })
        end)

        if success then
            if Network.IsDebugMode then
                print(`[AYIOS-SDK] {response.StatusCode}-{response.Body}-`)
            end

            if response.StatusCode >= 500 then
                warn(`[AYIOS-SDK] Server error {response.StatusCode}, retrying...`)
                task.wait(1)
            end
        else
            warn(`[AYIOS-SDK] Request failed: {response}, retrying...`)
            task.wait(1)
        end
    until success and response.StatusCode < 500

    item.resolve(response)
    table.remove(Network.Queue, 1)

    Network.IsProcessing = false

    -- Process next request if any
    if #Network.Queue > 0 then
        task.spawn(processNextRequest)
    end
end

function Network:CreateRequest(options: RequestOptions): Promise.TypedPromise<HttpResponse>
    return Promise.new(function(resolve, reject)
        Network.Queue[#Network.Queue + 1] = {
            options = options,
            resolve = resolve,
            reject = reject
        }

        task.spawn(processNextRequest)
    end)
end

function Network:CreateRequest2(options: RequestOptions)
    return Promise.new(function(resolve, reject)
        -- local bodyLength = if options.body then
        --     #HttpService:JSONEncode(options.body)
        --     else 0

        print(`[AYIOS-SDK] {Network.BASE_URL}/{options.endpoint}`)
        local response = HttpService:RequestAsync({
            Method = options.method,
            Url = `{Network.BASE_URL}/{options.endpoint}`,
            Headers = {
                ["Authorization"] = AYIOS_API_KEY,
                ["X-Client-Version"] = Network.CLIENT_VERSION,
                ["Content-Type"] = "application/json",
            },
            Body = if options.body then
                HttpService:JSONEncode(options.body)
            else nil,
            Compress = Enum.HttpCompression.None
        })
        -- print(response.StatusCode, `-{response.Body}-`)
        resolve(response)
    end)
end

return Network