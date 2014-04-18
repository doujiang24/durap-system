-- Copyright (C) Dejiang Zhu (doujiang24)

local strhelper = require "helper.string"
local cjson = require "cjson"

local traceback = debug.traceback
local setmetatable = setmetatable
local error = error
local concat = table.concat
local io_open = io.open
local unpack = unpack
local time = ngx.localtime
local type = type
local get_instance = get_instance
local maxn = table.maxn

local get_phase = ngx.get_phase
local ngx_var = ngx.var
local ngx_log = ngx.log
local ngx_err = ngx.ERR

local default_level = require("core.config").debug
local log_file = require("core.config").log_file

local _M = { _VERSION = '0.01' }

local levels = {
    'DEBUG',
    'INFO',
    'NOTICE',
    'WARN',
    'ERR',
    'CRIT',
    'ALERT',
}

for i, l in ipairs(levels) do
    _M[l] = i
end

local mt = { __index = _M }

function _M.init(self)
    return setmetatable(_M, { __index = get_instance() })
end

local function _log(self, log)
    local file = self.APPPATH .. log_file

    local fp, err = io_open(file, "a")
    if not fp then
        ngx_log(ngx_err, "failed to open file: ", file, "; error: ", err)
        return
    end

    local ok, err = fp:write(log, "\n\n")
    if not ok then
        ngx_log(ngx_err, "failed to write log file, log: ", log)
        return
    end

    fp:close()
end

function _M.log(self, level, ...)
    local conf = get_instance().loader:config('core')
    local debug_level = conf and conf.debug or default_level
    local log_level = _M[debug_level]

    if level < log_level then
        return
    end

    local args = { ... }
    for i = 1, maxn(args) do
        local typ = type(args[i])
        if typ == "table" then
            local ok, json_str = pcall(cjson.encode, args[i])
            json_str = ok and json_str or "[ERROR can not json encode table]"
            args[i] = "[TABLE]:" .. json_str

        elseif typ == "nil" then
            args[i] = "[NIL]"

        elseif typ == "boolean" then
            args[i] = args[i] and "[BOOLEAN]:true" or "[BOOLEAN]:false"

        elseif typ == "number" then
            args[i] = "[NUMBER]:" .. args[i]

        elseif typ ~= "string" then
            args[i] = "[" .. typ .. " VALUE]"
        end
    end

    local log_vars = {
        time() .. ", " .. levels[level],
        concat(args, ", \n"),
        traceback(),
    }

    local phase = get_phase()

    local request_info = "\nphase: " .. phase
    if "init" ~= phase and "timer" ~= phase then
        request_info = concat({
            request_info,
            "host: " .. ngx_var.host,
            "request: " .. ngx_var.request_uri,
            "args: " .. (ngx_var.args or '(empty)'),
            "request_body: " .. (ngx_var.request_body or '(empty)'),
        }, ", \n")
    end

    return _log(self, concat(log_vars, ", \n") .. request_info)
end

function _M.log_debug(self, ...)
    return _M.log(self, _M.DEBUG, ...)
end

function _M.log_info(self, ...)
    return _M.log(self, _M.INFO, ...)
end

function _M.log_notice(self, ...)
    return _M.log(self, _M.NOTICE, ...)
end

function _M.log_warn(self, ...)
    return _M.log(self, _M.WARN, ...)
end

function _M.log_error(self, ...)
    return _M.log(self, _M.ERR, ...)
end

function _M.log_crit(self, ...)
    return _M.log(self, _M.CRIT, ...)
end

function _M.log_alert(self, ...)
    return _M.log(self, _M.ALERT, ...)
end

return _M
