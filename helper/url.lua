-- Copyright (C) Dejiang Zhu (doujiang24)

local ngx_header = ngx.header

local get_instance = get_instance
local exit = ngx.exit
local ngx_var = ngx.var
local re_match = ngx.re.match
local ngx_redirect = ngx.redirect
local escape_uri = ngx.escape_uri
local pairs = pairs
local type = type
local insert = table.insert
local concat = table.concat

local HTTP_MOVED_TEMPORARILY = ngx.HTTP_MOVED_TEMPORARILY


local _M = { _VERSION = '0.01' }


_M.encode_args = ngx.encode_args

function _M.site_url(url)
    if re_match(url, "^\\w+://", "i") then
        return url
    end

    local host = ngx_var.host
    return "http://" .. host .. "/" .. url
end

function _M.redirect(url, status)
    local request = get_instance().request
    local url, status = _M.site_url(url), status or HTTP_MOVED_TEMPORARILY
    return ngx_redirect(url, status)
end

function _M.root_domain(domain)
    if type(domain) ~= "string" then
        return nil, "root_domain bad arg type, not string"
    end

    local m, err = re_match(domain, [[^(.*?)([^.]+.[^.]+)$]], "jo")
    if not m then
        if err then
            return nil, "failed to match the domain: " .. err
        end

        return nil, "bad domain"
    else
        return m[2], nil
    end
end

function _M.url_domain(url)
    if type(url) ~= "string" then
        return nil, "url_domain bad arg type, not string"
    end

    local m, err = re_match(url, [[^(http[s]*)://([^:/]+)(?::(\d+))?(.*)]], "jo")

    if m then
        return m[2]

    elseif err then
        return nil, "failed to match the uri: " .. err

    end

    return nil, "bad uri"
end

return _M
