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
local pairs = pairs


local _M = { _VERSION = '0.01' }
local mt = { __index = _M }


local function _connect(config)
    local conn = redis:new()

    conn:set_timeout(config.timeout)

    local ok, err = conn:connect(config.host, config.port)

    if not ok then
        log_error("failed to connect redis: ", err)
        return
    end

    if config.password then
        local res, err = conn:auth(config.password)
        if not res then
            log_error("failed to authenticate: ", err)
            return
        end
    end

    return conn
end


function _M.connect(self, configs)
    local conns = {}

    for cluster_id, config in pairs(configs) do
        conns[cluster_id] = _connect(config)
    end

    return setmetatable({ conns = conns, configs = configs }, mt)
end


local function query(cluster_id, conn, cmd, ...)
    local res, err = conn[cmd](conn, ...)

    -- log_debug(cluster_id, cmd, ...)

    if not res and err then
        if cmd == "commit_pipeline " and err == "no pipeline" then
            -- log_debug("failed to commit the pipelined requests: ", err)
        else
            log_error("failed to query redis, error:", err, "operater:", cmd, ...)
        end

        return false, err
    end
    return res, err
end


local commands = redis.get_commands()
commands[#commands + 1] = 'init_pipeline'
commands[#commands + 1] = 'cancel_pipeline'
commands[#commands + 1] = 'commit_pipeline'

for i = 1, #commands do
    local cmd = commands[i]
    local cluster_cmd = "cluster_" .. cmd

    _M[cluster_cmd] = function (self, cluster_id, ...)
        if cluster_id then
            return query(cluster_id, self.conns[cluster_id], cmd, ...)
        end

        local ret = {}

        for cluster_id, conn in pairs(self.conns) do
            ret[cluster_id] = query(cluster_id, self.conns[cluster_id], cmd, ...)
        end

        return ret
    end
end


local commit_pipeline = _M.commit_pipeline

function _M.commit_pipeline(self, key)
    local ret = commit_pipeline(self, key)

    for cluster_id, results in ipairs(ret) do
        if results then
            for i, res in ipairs(results) do
                if type(res) == "table" then
                    if not res[1] and res[2] then
                        log_error("failed to run pipeline command: ", i, "cluster:", cluster_id, "err:", res[2])
                        results[i] = false
                    else
                        results[i] = res[1]
                    end
                end
            end
        end
    end

    return ret
end


local function close(cluster_id, conn)
    local ok, err = conn:close()
    if not ok then
        log_error("failed to close cluster redis: ", cluster_id, err)
    end
end


function _M.close(self)
    for cluster_id, conn in pairs(self.conns) do
        close(cluster_id, conn)
    end
end


function _M.keepalive(self)
    local configs = self.configs

    for cluster_id, conn in pairs(self.conns) do
        local config = configs[cluster_id]

        if not config.idle_timeout or not config.max_keepalive then
            log_error("not set idle_timeout, max_keepalive in config; turn to close")
            close(cluster_id, conn)
        else
            local ok, err = conn:set_keepalive(config.idle_timeout, config.max_keepalive)
            if not ok then
                log_error("failed to set redis keepalive: ", err)
            end
        end
    end
end


return _M
