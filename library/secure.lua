-- Copyright (C) Dejiang Zhu (doujiang24)

local corehelper = require "system.helper.core"

local pairs = pairs
local ipairs = ipairs
local table_sort = table.sort
local str_upper = string.upper
local md5 = ngx.md5


local _M = { _VERSION = '0.01' }


local function join_args(args)
    local keys, str = {}, ''
    for k, v in pairs(args) do
        keys[#keys + 1] = k
    end
    table_sort(keys)

    for _i, k in ipairs(keys) do
        if type(args[k]) == "table" then
            str = str .. k .. join_args(args[k])

        -- not boolean
        elseif type(args[k]) ~= "boolean" then
            str = str .. k .. args[k]
        end
    end

    return str
end

function _M.set_token(secretkey, args)
    local str = secretkey .. join_args(args) .. secretkey
    return str_upper(md5(str)), str
end

function _M.set_token2(secretkey, args, payload)
    local str = join_args(args) .. secretkey

    if payload then
        str = str .. payload
    end

    return md5(str), str
end


return _M

