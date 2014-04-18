-- Copyright (C) Dejiang Zhu (doujiang24)

local strhelper = require "helper.string"
local config = require "core.config"

local get_instance = get_instance

local setmetatable = setmetatable
local type = type
local select = select
local concat = table.concat
local unpack = unpack
local re_find = ngx.re.find
local str_sub = string.sub
local strip = strhelper.strip
local split = strhelper.split
local ngx_var = ngx.var
local exit = ngx.exit
local NOT_FOUND = ngx.HTTP_NOT_FOUND


local _M = { _VERSION = '0.01' }

local max_level = config.max_level
local default_func = config.default_func
local remap_func = config.remap_func
local default_ctr = config.default_ctr


local mt = { __index = _M }

local function _get_segments()
    local str = ngx_var.uri
    local from, to, err = re_find(str, "\\?", "jo")
    if from then
        str = str_sub(str, 1, from - 1)
    end

    return split(strip(str, "/"), "/")
end
_M.get_segments = _get_segments

function _M.new(self)
    return setmetatable(_M, { __index = get_instance() })
end

local function _route(self)
    local loader, segments = self.loader, _get_segments()
    local conf = loader:config('core')
    default_ctr = conf and conf.default_ctr or default_ctr

    local seg_len = #segments
    if seg_len == 0 then
        segments[1] = default_ctr
        seg_len = 1
    end

    local max = (seg_len > max_level) and max_level or seg_len
    local uri = nil

    for i = 1, max do
        uri = (uri and uri .. "/" or '') .. segments[i]

        local ctr = loader:controller(uri)
        if not ctr and not segments[i+1] then
            ctr = loader:controller(uri .. "/" .. default_ctr)
        end

        if ctr then
            local func = segments[i+1]
            if func and type(ctr[func]) == "function" then
                return ctr[func], select(i+2, unpack(segments))

            elseif type(ctr[remap_func]) == "function" then
                return ctr[remap_func], select(i+1, unpack(segments))

            elseif not func and type(ctr[default_func]) == "function" then
                return ctr[default_func]
            end
        end
    end

    get_instance().debug:log_info("router failed")
end

local function _run(func, ...)
    if func then
        return func(...)
    end
    return exit(NOT_FOUND)
end

function _M.run(self)
    return _run(_route(self))
end

function _M.get_uri(self)
    local segments = _get_segments(self)
    return concat(segments, "/")
end

return _M
