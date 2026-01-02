---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
--!strict

local ModerationSpec = require(script.Parent.Parent.Moderation.Spec)

local DirectiveStatus = {
    PENDING = 0,
    COMPLETE = 1,
    FAILED = 2
}

local DirectiveType = {
    HEARTBEAT = 0,
    MODERATION = 1,
    ANNOUNCEMENT = 2,
    TRIGGER = 3,
    AYIOS_KILL = 4,
    AYIOS_RESET = 5
}

export type Player = {
    username: string;
    --[[
        Unix time
    ]]--
    joined_at: number;
}

export type ServerCreateDefinition = {
    id: string;
    version: string;
    max_players: number;
    -- created_at: string;
}

export type ServerDefinition = {
    id: string;
    version: string;
    max_players: number;
    created_at: string;
    place_id: string;
    players: { [string]: Player };
    directives: { [string]: AnyServerDirective };
}

export type BaseServerDirective = {
    type: number;
    id: string;
}
export type ModerationDirective = BaseServerDirective & {
    type: typeof(DirectiveType.MODERATION);
    record: ModerationSpec.RecordDefinition;
}

export type AnnouncementDirective = BaseServerDirective & {
    type: typeof(DirectiveType.ANNOUNCEMENT);
    content: string;
    --[[
        Roblox UID
    ]]--
    author: string;
}

export type AnyServerDirective = ModerationDirective | AnnouncementDirective;

export type ExecutedDirective = {
    id: string;
    status: number;
    attributes: { [string]: any };
}

export type ExecutedDirectivesFull = {
    directives: { [string]: ExecutedDirective };
}

-- {
--     "directives": {
--         "525cd52e-557a-4373-a24a-7c6647ce3bdb": {
--             "id": "525cd52e-557a-4373-a24a-7c6647ce3bdb",
--             "status": 2,
--             "attributes": {}
--         }
--     }
-- }
return {
    DirectiveStatus = DirectiveStatus,
    DirectiveType = DirectiveType
}