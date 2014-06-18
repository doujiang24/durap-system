-- Copyright (C) Dejiang Zhu (doujiang24)

local corehelper = require "system.helper.core"
local filehelper = require "system.helper.file"
local ltp = require "system.library.ltp.template"

local setmetatable = setmetatable
local pcall = pcall
local assert = assert
local loadfile = loadfile
local type = type
local setfenv = setfenv
local concat = table.concat
local show_error = corehelper.show_error
local get_instance = get_instance
local fexists = filehelper.exists
local fread_all = filehelper.read_all
local ltp_load_template = ltp.load_template
local ltp_execute_template = ltp.execute_template

local _G = _G
local cache_module = {}


local _M = { _VERSION = '0.01' }


function _M.new(self)
    return setmetatable(_M, { __index = get_instance() })
end

local function _get_cache(self, module)
    local appname = self.APPNAME
    return cache_module[appname] and cache_module[appname][module]
end

local function _set_cache(self, name, val)
    local appname = self.APPNAME
    if not cache_module[appname] then
        cache_module[appname] = {}
    end
    cache_module[appname][name] = val
end

local function _load_module(self, dir, name)
    local file = dir .. "." .. name
    local cache = _get_cache(self, file)
    if cache == nil then
        local ok, module = pcall(require, self.APPNAME .. "." .. file)
        if not ok then
            get_instance().debug:log_debug('failed to load: ', file, ' err: ', module)
        end

        _set_cache(self, file, module or false)
        return module
    end
    return cache
end

function _M.core(self, cr)
    return _load_module(self, "core", cr)
end

function _M.controller(self, contr)
    return _load_module(self, "controller", contr)
end

function _M.model(self, mod, ...)
    local m = _load_module(self, "model", mod)
    return m and type(m.new) == "function" and m:new(...) or m
end

function _M.config(self, conf)
    return _load_module(self, "config", conf)
end

function _M.library(self, lib)
    return _load_module(self, "library", lib)
end

local function _ltp_function(self, tpl)
    local cache = _get_cache(self, tpl)
    if cache == nil then
        local tplfun = false
        local filename = self.APPPATH .. tpl
        if fexists(filename) then
            local fdata = fread_all(filename)
            tplfun = ltp_load_template(fdata, '<?lua','?>')
        else
            show_error("failed to load tpl:", filename)
        end
        _set_cache(self, tpl, tplfun)
        return tplfun
    end
    return cache
end

function _M.view(self, tpl, data)
    local template, data = "views/" .. tpl .. ".tpl", data or {}
    local tplfun = _ltp_function(self, template)
    local output = {}
    setmetatable(data, { __index = _G })
    ltp_execute_template(tplfun, data, output)
    return output
end

return _M
