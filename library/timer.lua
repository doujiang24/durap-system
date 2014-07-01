-- Copyright (C) Dejiang Zhu (doujiang24)

local durap = require "system.core.durap"
local ngx   = ngx

local new_timer = ngx.timer.at


local _M = { _VERSION = '0.01' }

local back_func
back_func = function (premature, delay, appname, controller, func, ...)
    if premature then
        return
    end

    local dp = durap:init(appname)

    local ok, err = new_timer(delay, back_func, delay, appname, controller, func, ...)
    if not ok then
        dp.debug:log_error("failed to create timer: ", err, delay, appname, controller, func, ...)
    end

    return dp.loader:controller(controller)[func](...)
end

function _M.run(delay, appname, controller, func, ...)
    local ok, err = new_timer(delay, back_func, delay, appname, controller, func, ...)

    if not ok then
        local dp = durap:init(appname)
        dp.debug:log_error("failed to create timer: ", err, delay, appname, controller, func, ...)
    end
end


return _M

