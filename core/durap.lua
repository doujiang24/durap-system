-- Copyright (C) Dejiang Zhu (doujiang24)

local request   = require "system.core.request"
local loader    = require "system.core.loader"
local debug     = require "system.core.debug"
local session   = require "system.core.session"
local router    = require "system.core.router"

local root_path     = require "dpconfig" .root_path
local applications  = require "dpconfig" .applications

local setmetatable  = setmetatable
local ngx_var       = ngx.var
local ngx           = ngx -- only for ngx.ctx

local cache_module  = {}
local auto_module   = {
        debug       = { debug, true },  -- module, cache able?
        loader      = { loader, true },
        router      = { router, true },
        request     = { request, false },
        session     = { session, false },
}


local _M = { _VERSION = '0.01' }


local function _auto_load(dp, key)
    local appname = dp.APPNAME
    if not cache_module[appname] then
        cache_module[appname] = {}
    end

    local val = cache_module[appname][key]
    if not val and auto_module[key] then
        local module    = auto_module[key][1]
        local cache     = auto_module[key][2]

        val = module.new()

        if cache then
            cache_module[appname][key] = val
        end
    end

    dp[key] = val
    return val
end

local mt = { __index = _auto_load }


function _M.init(self, appname)
    local name  = appname or applications[ngx_var.host] or applications.default
    local path  = root_path .. name .. "/"

    local dp    = setmetatable({
        APPNAME = name,
        APPPATH = path,
    }, mt)

    ngx.ctx.dp  = dp
    return dp
end


return _M
