-- Copyright (C) Dejiang Zhu (doujiang24)

local mysql = require "resty.mysql"
local strhelper = require "system.helper.string"
local corehelper = require "system.helper.core"

local log_error = corehelper.log_error
local log_debug = corehelper.log_debug
local setmetatable = setmetatable
local insert = table.insert
local concat = table.concat
local quote_sql_str = ngx.quote_sql_str
local pairs = pairs
local strip = strhelper.strip
local lower = string.lower
local str_find = string.find
local type = type
local ipairs = ipairs
local tonumber = tonumber

local get_instance = get_instance


local _M = { _VERSION = '0.01' }


local mt = { __index = _M }

-- local functions
local function _where(self, key, value, mod, escape)
    escape = (escape == nil) and true or escape
    local ar_where = self.ar_where

    if not (type(key) == "table") then
        key = { [key] = value }
    end

    for k, v in pairs(key) do
        k = strip(k)
        local where_arr = {}

        if #ar_where >= 1 then
            insert(where_arr, mod)
        end

        if str_find(k, " ") then
            insert(where_arr, k)
        else
            insert(where_arr, "`" .. k .. "` =")
        end

        if escape == false then
            insert(where_arr, v)
        else
            insert(where_arr, quote_sql_str(v))
        end

        insert(ar_where, concat(where_arr, " "))
    end
    return self
end

local function _where_in(self, key, values, boolean_in, mod)
    if #values == 1 then
        return _where(self, key, values[1], mod)
    end

    local ar_where = self.ar_where
    local where_arr = {}

    if #ar_where >= 1 then
        insert(where_arr, mod)
    end

    insert(where_arr, "`" .. key .. "`")

    if not boolean_in then
        insert(where_arr, "not")
    end
    insert(where_arr, "in (")

    local vals = {}
    for i, v in ipairs(values) do
        insert(vals, quote_sql_str(v))
    end
    insert(where_arr, concat(vals, ", "))
    insert(where_arr, ")")

    insert(ar_where, concat(where_arr, " "))
    return self
end

local function _like(self, key, match, boolean_in, mod)
    local ar_where = self.ar_where

    local where_arr = {}

    if #ar_where >= 1 then
        insert(where_arr, mod)
    end

    insert(where_arr, "`" .. key .. "`")

    if not boolean_in then
        insert(where_arr, "not")
    end
    insert(where_arr, "like")

    local pattern = strip(quote_sql_str(match), "'")
    insert(where_arr, "'%" .. pattern .. "%'")

    insert(ar_where, concat(where_arr, " "))
    return self
end

local function _having(self, condition, mod)
    local ar_having = self.ar_having

    insert(ar_having, ((#ar_having >= 1) and mod or "") .. " " .. condition)
    return self
end

local function _select_func(self, key, alias, func)
    local ar_select = self.ar_select
    local where_arr = {
        func,
        "(`",
        key,
        "`) as `",
        alias or (lower(func) .. "_" .. key),
        "`"
    }
    insert(ar_select, concat(where_arr))
    return self
end

local function _reset_vars(self)
    self.ar_select = {}
    self.ar_set = {}
    self.ar_where = {}
    self.ar_having = {}
    self.ar_order_by = {}
    self.ar_group_by = nil
    self.ar_limit = nil
    self.ar_offset = nil
end

function _M.where_export(self, op)
    local sqlvars = {
        (#self.ar_where >= 1) and concat(self.ar_where, " ") or " 1 ",
        self.ar_group_by and (" group by " .. self.ar_group_by) or "",
        (#self.ar_having >= 1) and (" having " .. concat(self.ar_having, " ")) or "",
        (#self.ar_order_by >= 1) and (" order by " .. concat(self.ar_order_by, ", ")) or ""
    }

    if self.ar_limit then
        if op == "update" then
            sqlvars[#sqlvars + 1] = " limit " .. self.ar_limit
        else
            sqlvars[#sqlvars + 1] = " limit " .. self.ar_offset .. ", " .. self.ar_limit
        end
    end

    _reset_vars(self)
    return concat(sqlvars)
end
-- end local functions


-- useful functions
function _M.connect(self, config)
    local mysql = setmetatable({ conn = mysql:new(), config = config }, mt)

    local conn = mysql.conn

    conn:set_timeout(config.timeout)

    local ok, err, errno, sqlstate = conn:connect({
        host = config.host,
        port = config.port,
        database = config.database,
        user = config.user,
        password = config.password,
        max_packet_size = config.max_packet_size
    })

    if not ok then
        log_error("failed to connect: ", err, ": ", errno, " ", sqlstate)
        return
    end

    _M.query(mysql, "set names " .. config.charset)
    return mysql
end

function _M.add(self, table, setarr)
    local keys, values = {}, {}
    for key, val in pairs(setarr) do
        insert(keys, key)
        insert(values, quote_sql_str(val))
    end
    local sqlvars = {
        "insert into `",
        table,
        "` (`",
        concat(keys, "`, `"),
        "`) values (",
        concat(values, ", "),
        ")"
    }
    local sql = concat(sqlvars, "")

    local res, err = _M.query(self, sql)
    return res and res.insert_id, err
end

function _M.replace(self, table, setarr)
    local keys, values = {}, {}
    for key, val in pairs(setarr) do
        insert(keys, key)
        insert(values, quote_sql_str(val))
    end
    local sqlvars = {
        "replace into `",
        table,
        "` (`",
        concat(keys, "`, `"),
        "`) values (",
        concat(values, ", "),
        ")"
    }
    local sql = concat(sqlvars, "")

    local res, err = _M.query(self, sql)
    return res and res.insert_id, err
end

function _M.count(self, table, wherearr)
    local sqlvars = {
        "SELECT COUNT(*) AS `num` FROM `",
        table,
        "` WHERE ",
        _M.where_export(self)
    }
    local sql = concat(sqlvars, "")

    local res, err = _M.query(self, sql)
    return res and tonumber(res[1].num), err
end

function _M.get(self, table, lmt, offset)
    local _ = lmt and _M.limit(self, lmt, offset)
    local ar_select = self.ar_select

    local sqlvars = {
        "select ",
        (#ar_select >= 1) and concat(ar_select, ", ") or "*",
        " from `",
        table,
        "` where ",
        _M.where_export(self),
    }
    local sql = concat(sqlvars)
    return _M.query(self, sql)
end

function _M.get_where(self, table, wherearr, limit, offset)
    _M.where(self, wherearr)
    return _M.get(self, table, limit, offset)
end

function _M.update(self, table, setarr, wherearr)
    if setarr then
        for k, v in pairs(setarr) do
            _M.set(self, k, v)
        end
    end
    if wherearr then
        for k, v in pairs(wherearr) do
            _M.where(self, k, v)
        end
    end

    local sqlvars = {
        "update `",
        table,
        "` ",
        " set ",
        concat(self.ar_set, ", "),
        " where ",
        _M.where_export(self, "update"),
    }
    local sql = concat(sqlvars)
    local res, err = _M.query(self, sql)
    return res and res.affected_rows, err
end

function _M.delete(self, table, wherearr)
    local sqlvars = {
        "delete from `",
        table,
        "` where ",
        _M.where_export(self, "update"),
    }
    local sql = concat(sqlvars)
    local res, err = _M.query(self, sql)
    return res and res.affected_rows, err
end

function _M.truncate(self, table)
    local sql = "truncate table `" ..  table .. "`"
    return _M.query(self, sql)
end

function _M.query(self, sql)
    local conn = self.conn
    -- log_debug("log sql:", sql)

    local res, err, errno, sqlstate = conn:query(sql)
    if not res then
        log_error("bad result: ", err, ": ", errno, ": ", sqlstate, ": sql:", sql, ": ", ".")
    end

    _reset_vars(self)
    return res, err
end
-- end useful functions


-- where functions
function _M.where(self, key, value, escape)
    escape = (escape == nil) and true or escape
    return _where(self, key, value, "and", escape)
end

function _M.or_where(self, key, value, escape)
    escape = (escape == nil) and true or escape
    return _where(self, key, value, "or", escape)
end

function _M.where_in(self, key, values)
    return _where_in(self, key, values, true, 'and')
end

function _M.where_not_in(self, key, values)
    return _where_in(self, key, values, false, 'and')
end

function _M.or_where_in(self, key, values)
    return _where_in(self, key, values, true, 'or')
end

function _M.or_where_not_in(self, key, values)
    return _where_in(self, key, values, false, 'or')
end

function _M.like(self, key, match)
    return _like(self, key, match, true, 'and')
end

function _M.not_like(self, key, match)
    return _like(self, key, match, false, 'and')
end

function _M.or_like(self, key, match)
    return _like(self, key, match, true, 'or')
end

function _M.or_not_like(self, key, match)
    return _like(self, key, match, false, 'or')
end
-- end where functions


-- select functions
function _M.select(self, key, escape)
    escape = (escape == nil) and true or escape
    local ar_select = self.ar_select
    if escape then
        key = "`" .. key .. "`"
    end
    insert(ar_select, key)
    return self
end

function _M.select_max(self, key, alias)
    return _select_func(self, key, alias, "max")
end

function _M.select_min(self, key, alias)
    return _select_func(self, key, alias, "min")
end

function _M.select_avg(self, key, alias)
    return _select_func(self, key, alias, "avg")
end

function _M.select_sum(self, key, alias)
    return _select_func(self, key, alias, "sum")
end

function _M.select_count(self, key, alias)
    return _select_func(self, key, alias, "count")
end
-- end select function


-- group by function
function _M.group_by(self, key)
    self.ar_group_by = key
    return self
end

function _M.having(self, condition)
    return _having(self, condition, "and")
end

function _M.or_having(self, condition)
    return _having(self, condition, "or")
end
-- end group by function

function _M.limit(self, limit, offset)
    self.ar_limit = limit
    self.ar_offset = offset or 0
    return self
end

function _M.set(self, key, value, escape)
    escape = (escape == nil) and true or escape
    local ar_set = self.ar_set

    local set_arr = {
        "`", key, "` = ",
        escape and quote_sql_str(value) or value
    }

    insert(ar_set, concat(set_arr))
    return self
end

function _M.order_by(self, key, order)
    order = order or "desc"
    local ar_order_by = self.ar_order_by

    local order_arr = { "`", key, "` ", order }
    insert(ar_order_by, concat(order_arr))
    return self
end

function _M.first_row(self, res)
    return res and res[1] or nil
end

function _M.close(self)
    local conn = self.conn
    local ok, err = conn:close()
    if not ok then
        log_error("failed to close mysql: ", err)
    end
end

function _M.keepalive(self)
    local conn, config = self.conn, self.config
    if not config.idle_timeout or not config.max_keepalive then
        log_error("not set idle_timeout and max_keepalive in config; turn to close")
        return _M.close(self)
    end

    local ok, err = conn:set_keepalive(config.idle_timeout, config.max_keepalive)
    if not ok then
        log_error("failed to set mysql keepalive: ", err)
    end
end

return _M
