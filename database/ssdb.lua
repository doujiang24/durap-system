-- Copyright (C) Dejiang Zhu (doujiang24)

local ssdb          = require "resty.ssdb"
local corehelper    = require "system.helper.core"

local log_error = corehelper.log_error
local log_debug = corehelper.log_debug
local setmetatable = setmetatable
local unpack = unpack
local get_instance = get_instance
local insert = table.insert
local select = select


local _M = { _VERSION = '0.01' }

local mt = { __index = _M }

function _M.connect(self, config)
    local conn      = ssdb:new()

    conn:set_timeout(config.timeout)

    local ok, err = conn:connect(config.host, config.port)
    if not ok then
        log_error("failed to connect ssdb: ", err)
        return
    end

    return setmetatable({ conn = conn, config = config }, mt)
end

function close(self)
    local conn = self.conn
    local ok, err = conn:close()
    if not ok then
        log_error("failed to close ssdb: ", err)
    end
end
_M.close = close

function _M.keepalive(self)
    local conn      = self.conn
    local config    = self.config

    local ok, err = conn:set_keepalive(config.idle_timeout, config.max_keepalive)
    if not ok then
        log_error("failed to set ssdb keepalive: ", err)
    end
end

function _M.commit_pipeline(self)
    local conn, ret = self.conn, {}
    local results, err = conn:commit_pipeline()

    if not results then
        log_error("failed to commit the pipelined requests: ", err)
        return ret
    end

    for i, res in ipairs(results) do
        if type(res) == "table" then
            if not res[1] then
                log_error("failed to run command: ", i, "; err:", res[2])
                insert(ret, false)
            else
                insert(ret, res[1])
            end
        else
            insert(ret, res)
        end
    end
    return ret
end

local class_mt = {
    __index = function (table, key)
        return function (self, ...)
            local conn = self.conn
            local res, err = conn[key](conn, ...)

            -- log_debug(key, ...)

            if not res and err then
                log_error("failed to query ssdb, error:", err, "operater:", key, ...)
                return nil, err
            end

            return res
        end
    end
}

setmetatable(_M, class_mt)

return _M

