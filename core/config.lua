-- Copyright (C) Dejiang Zhu (doujiang24)

local _M = {}

-- debug
_M.debug = "DEBUG"
_M.log_file = "logs/error.log"

-- router
_M.max_level = 2
_M.default_func = "index"
_M.remap_func = "_remap"
_M.default_ctr = "index"

-- form upload
_M.chunk_size = 8096        -- 8k
_M.recieve_timeout = 3000   -- 3s

_M.HTTP_RAW_POST_KEY = "HTTP_RAW_POST_KEY"

return _M
