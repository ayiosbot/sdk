--!strict
local HttpService = game:GetService('HttpService')

local Promise = require('@self/TypedPromise')
export type RequestOptions = {
    method: "GET" | "POST" | "PUT"  | "PATCH" | "DELETE";
    endpoint: string;
    body: any?;
}

local AYIOS_API_KEY = ''

local Network = {}
Network.BASE_URL = 'https://api.ayios.xyz/v0'
Network.CLIENT_VERSION = "1.0.0-sdk"

function Network:SetAPIKey(key: string)
    AYIOS_API_KEY = key
end


function Network:CreateRequest(options: RequestOptions)
    return Promise.new(function(resolve, reject)
        local bodyLength = if options.body then
            #HttpService:JSONEncode(options.body)
            else 0

        local response = HttpService:RequestAsync({
            Method = options.method,
            Url = `{Network.BASE_URL}/{options.endpoint}`,
            Headers = {
                ["Authorization"] = AYIOS_API_KEY,
                ["X-Client-Version"] = Network.CLIENT_VERSION,
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

return Network