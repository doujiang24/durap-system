-- Copyright (C) Dejiang Zhu (doujiang24)

local request = require "system.core.request"
local loader = require "system.core.loader"
local debug = require "system.core.debug"
local session = require "system.core.session"
local router = require "system.core.router"

local setmetatable = setmetatable
local ngx_var = ngx.var
local ngx = ngx -- only for ngx.ctx


local _M = { _VERSION = '0.01' }


local function _auto_load(table, key)
    local val = nil
    if key == "request" then
        val = request:new()

    elseif key == "debug" then
        val = debug:init()

    elseif key == "loader" then
        val = loader:new()

    elseif key == "session" then
        val = session:init()

    elseif key == "router" then
        val = router:new()
    end

    table[key] = val
    return val
end

local mt = { __index = _auto_load }


function _M.init(self, root, appname)
    local APPNAME = appname or ngx_var.APPNAME
    local APPPATH = (root or ngx_var.ROOT) .. APPNAME .. "/"

    local dp = setmetatable({
        APPNAME = APPNAME,
        APPPATH = APPPATH
    }, mt)
    ngx.ctx.dp = dp
    return dp
end

local class_mt = {
    __index = _auto_load
}

setmetatable(_M, class_mt)

return _M
