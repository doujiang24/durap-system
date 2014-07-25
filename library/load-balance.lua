-- Copyright (C) Dejiang Zhu (doujiang24)

local setmetatable  = setmetatable
local crc32_short   = ngx.crc32_short


local _M = {}
local mt = { __index = _M }


local function hash_server(self, key)
    local len = #self.servers

    return crc32_short(key) % len + 1
end


local methods = {
    hash    = hash_server,
}


function _M.new(self, servers, opts)
    local balance = { servers = servers }

    balance.get_server_id = methods[opts.method]

    return setmetatable(balance, mt)
end


function _M.get_servers(self)
    return self.servers
end


return _M
