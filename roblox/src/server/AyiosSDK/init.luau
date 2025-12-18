---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
--!strict
local Gateway = require(script.Services.Gateway)
local Moderation = require(script.Services.Moderation)
local Promise = require(script.TypedPromise)
local Bitfield = require(script.Bitfield)
local Network = require(script.Network)

export type RequestOptions = {
    method: "GET" | "POST" | "PUT"  | "PATCH" | "DELETE",
    endpoint: string,
    body: any?,
}

local SDK = {
    BASE_URL = 'https://api.ayios.xyz/v0',
    CLIENT_VERSION = "1.0.0-sdk",

    Bitfield = Bitfield,
    Promise = Promise,
    Network = Network,
    Moderation = Moderation,
    Gateway = Gateway,
}

function SDK:SetAPIKey(key: string)
    Network:SetAPIKey(key)
end

function SDK:SetDebugMode(debugState: boolean)
    Network.IsDebugMode = debugState
end

function SDK:SetPlaceID(placeID: number | string)
    SDK.Gateway.PLACE_ID = tostring(placeID)
    SDK.Moderation.PLACE_ID = tostring(placeID)
end

return SDK