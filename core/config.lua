-- Copyright (C) 2013 doujiang24, MaMa Inc.

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
_M.chunk_size = 8096

return _M
