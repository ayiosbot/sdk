---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
--!strict
local HttpService = game:GetService("HttpService")

local Gateway = require('@self/Services/Gateway')
local Moderation = require('@self/Services/Moderation')
local Promise = require('@self/TypedPromise')
local Bitfield = require('@self/Bitfield')

export type RequestOptions = {
    method: "GET" | "POST" | "PUT"  | "PATCH" | "DELETE",
    endpoint: string,
    body: any?,
}
--todo: WHEN HOME FROM WORK
-- You need to update Network.luau and make it
-- use SDK CREATEREQUEST so things can be referenced.
-- Cyclic dependencies is an issue rn
local SDK_API_KEY = ''

local SDK = {
    BASE_URL = 'https://api.ayios.xyz/v0',
    CLIENT_VERSION = "1.0.0-sdk",

    Bitfield = Bitfield,
    Moderation = Moderation,
    Gateway = Gateway,
}

function SDK:SetAPIKey(key: string)
    SDK_API_KEY = key
end

function SDK:CreateRequest(options: RequestOptions)
    return Promise.new(function(resolve, reject)
        local bodyLength = if options.body then
            #HttpService:JSONEncode(options.body)
            else 0

        local response = HttpService:RequestAsync({
            Method = options.method,
            Url = `{SDK.BASE_URL}/{options.endpoint}`,
            Headers = {
                ["Authorization"] = SDK_API_KEY,
                ["X-Client-Version"] = SDK.CLIENT_VERSION,
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(bodyLength),
            },
            Body = if options.body then
                HttpService:JSONEncode(options.body)
            else nil,
            Compress = Enum.HttpCompression.Gzip
        })
        resolve(response)
    end)
end

return SDK