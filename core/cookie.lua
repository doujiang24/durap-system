-- Copyright (C) Dejiang Zhu (doujiang24)

local corehelper = require "helper.core"

local type = type
local insert = table.insert
local concat = table.concat
local log_error = corehelper.log_error
local ngx = ngx
local ngx_var = ngx.var
local ngx_header = ngx.header
local cookie_time = ngx.cookie_time
local escape_uri = ngx.escape_uri
local unescape_uri = ngx.unescape_uri
local time = ngx.time


local _M = { _VERSION = '0.01' }


function _M.get(key)
    if key then
        local str = ngx_var["cookie_" .. key]
        return str and unescape_uri(str)
    end
end

function _M.set(key, value, expire, path, domain, secure, httponly)
    local cookie = {}
    insert(cookie, key .. "=" .. escape_uri(value))
    if expire then
        insert(cookie, "expires=" .. cookie_time(expire + time()))
    end
    if path then
        insert(cookie, "path=" .. path)
    end
    if domain then
        insert(cookie, "domain=" .. domain)
    end
    if secure then
        insert(cookie, "secure")
    end
    if httponly then
        insert(cookie, "httponly")
    end
    local str = concat(cookie, "; ")

    local sent = ngx_header['Set-Cookie']
    if not sent then
        ngx_header['Set-Cookie'] = str
    elseif type(sent) == "table" then
        insert(sent, str)
        ngx_header['Set-Cookie'] = sent
    else
        ngx_header['Set-Cookie'] = { sent, str }
    end

    if ngx.headers_sent then
        log_error('failed to set cookie, header has seeded')
        return false
    end
    return true
end

return _M
