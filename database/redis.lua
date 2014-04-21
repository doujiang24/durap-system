-- Copyright (C) Dejiang Zhu (doujiang24)

local redis = require "resty.redis"
local corehelper = require "system.helper.core"

local log_error = corehelper.log_error
local log_debug = corehelper.log_debug
local setmetatable = setmetatable
local unpack = unpack
local get_instance = get_instance
local insert = table.insert
local select = select


local _M = { _VERSION = '0.01' }

local commands = {
    'subscribe', 'psubscribe', 'unsubscribe', 'punsubscribe',
}

local mt = { __index = _M }

function _M.connect(self, config)
    local red = setmetatable({ conn = redis:new(), config = config }, mt);

    local conn = red.conn
    local host = config.host
    local port = config.port
    local timeout = config.timeout

    conn:set_timeout(timeout)
    local ok, err = conn:connect(host, port)

    if not ok then
        log_error("failed to connect redis: ", err)
        return
    end

    if config.password then
        local res, err = red:auth(config.password)
        if not res then
            log_error("failed to authenticate: ", err)
            return
        end
    end

    return red
end

function close(self)
    local conn = self.conn
    local ok, err = conn:close()
    if not ok then
        log_error("failed to close redis: ", err)
    end
end
_M.close = close

function _M.keepalive(self)
    local conn, config = self.conn, self.config
    if not config.idle_timeout or not config.max_keepalive then
        log_error("not set idle_timeout and max_keepalive in config; turn to close")
        return close(self)
    end
    local ok, err = conn:set_keepalive(config.idle_timeout, config.max_keepalive)
    if not ok then
        log_error("failed to set redis keepalive: ", err)
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

for i = 1, #commands do
    local cmd = commands[i]

    _M[cmd] =
        function (self, ...)
            local conn = self.conn
            local res, err = conn[cmd](conn, ...)
            if not res then
                log_error("failed to query pubsub command redis, error:", err, "operater:", cmd, ...)
            end

            local nch = select("#", ...)
            if 1 == nch then
                return res, err
            end

            local results = { res }
            for i = 1, nch - 1 do
                local res, err = conn:read_reply()
                if not res then
                    log_error("failed to read_reply for pubsub command redis, error:", err, "operater:", cmd, ...)
                end
                results[#results + 1] = res
            end

            return results, err
        end
end

local class_mt = {
    __index = function (table, key)
        return function (self, ...)
            local conn = self.conn
            local res, err = conn[key](conn, ...)
            if not res and err then
                local args = { ... }

                if "read_reply" == key and "timeout" == err then
                    --log_debug("failed to query redis, error:", err, "operater:", key, unpack(args))
                else
                    log_error("failed to query redis, error:", err, "operater:", key, unpack(args))
                end

                return false, err
            end
            return res
        end
    end
}

setmetatable(_M, class_mt)

return _M
