-- Copyright (C) Dejiang Zhu (doujiang24)

local cjson         = require "cjson"

local setmetatable  = setmetatable
local traceback     = debug.traceback
local concat        = table.concat
local io_open       = io.open
local type          = type
local pcall         = pcall
local maxn          = table.maxn
local str_lower     = string.lower

local get_instance  = get_instance
local time          = ngx.localtime
local get_phase     = ngx.get_phase
local ngx_var       = ngx.var
local ngx_log       = ngx.log
local ngx_err       = ngx.ERR

local default_level = require "system.core.config" .debug
local log_file      = require "system.core.config" .log_file


local levels = {
    'DEBUG',
    'INFO',
    'NOTICE',
    'WARN',
    'ERR',
    'CRIT',
    'ALERT',
}

local _M = { _VERSION = '0.01' }

for num, level in ipairs(levels) do
    _M[level] = num
end

local mt = { __index = _M }

function _M.new()
    local dp    = get_instance()
    local conf  = dp.loader:config('core')
    local level = conf and conf.debug or default_level
    local m     = {
        file    = dp.APPPATH .. log_file,
        level   = _M[level],
    }
    return setmetatable(m, mt)
end

local function _log(self, log)
    local file = self.file

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

local function log(self, level, ...)
    local log_level = self.level

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
_M.log = log


for num, level in ipairs(levels) do
    local func = "log_" .. str_lower(level)
    _M[func] = function(self, ...)
        return log(self, num, ...)
    end
end


return _M
