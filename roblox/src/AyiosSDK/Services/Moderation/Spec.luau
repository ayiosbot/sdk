--!strict
local RecordType = {
    WARN   = 0,
    KICK   = 1,
    BAN    = 2,
    UNBAN  = 3,
    MUTE   = 4,
    UNMUTE = 5
}

local RecordFlag = {
    ACTIVE = 1,
    HAS_EVIDENCE = 2,
    IS_BATCH_BAN  = 4,
    IS_REASON_FILTERED = 8,
    IS_INCREMENT_BAN = 16,
    IS_MAX_INCREMENT_BAN = 32
}

export type RecordHistoryLogDefinition = {
    --[[
        0: System; anything else: some player
    ]]--
    author_id: number;
    old_content: string;
    new_content: string;
    --[[
        milliseconds
    ]]--
    created_at: number;
}

export type CreateRecordHistoryLogDefinition = {
    author_id: number;
    new_content: string;
    created_at: number;
}

export type CreateRecordDefinition = {

    version: number;
    moderator_id: number;
    flags: number;
    offender_id: number;
    place_id: string;
    --[[
        See `RecordType`
    ]]--
    type: number;
    expires_at: number;
    reason: string;
    history: {RecordHistoryLogDefinition};
    created_at: number;
    attributes: {number};
    metadata: {
        increment: {number}?
    }
}
export type RecordDefinition = CreateRecordDefinition & {
    _id: string;
}

export type ActiveRecordResponse = {
    active_ban: RecordDefinition?;
    active_mute: RecordDefinition?;
}


return {
    RecordType = RecordType,
    RecordFlag = RecordFlag
}