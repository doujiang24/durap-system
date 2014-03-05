-- Copyright (C) 2013 doujiang24, MaMa Inc.

local upload = require "resty.upload"
local config = require "core.config"

local ngx = ngx
local ngx_var = ngx.var
local ngx_req = ngx.req
local ngx_header = ngx.header

local setmetatable = setmetatable

local get_instance = get_instance
local read_body = ngx.req.read_body
local get_headers = ngx.req.get_headers
local get_uri_args = ngx.req.get_uri_args
local get_post_args = ngx.req.get_post_args
local pairs = pairs
local type = type
local io_open = io.open
local insert = table.insert
local concat = table.concat
local match = string.match
local find = string.find
local time = ngx.time
local random = math.random


local _M = { _VERSION = '0.01' }

local chunk_size = config.chunk_size

local mt = { __index = _M }

local function _get_uri_args(self)
    self.get_vars = get_uri_args()

    return self.get_vars
end

function _M.ip_address()
    return ngx_var.remote_addr
end

local function _tmp_name(self)
    local apppath = get_instance().APPPATH
    return apppath .. "tmp/" .. time() .. _M.ip_address() .. random(10000, 99999)
end

local function _get_form_data(self)
    local base_path, save_files, ret = self.base_path, self.save_files, {}

    local form, err = upload:new(chunk_size)
    if not form then
        get_instance().debug:log_info("failed to new upload: ", err)
        return ret
    end

    form:set_timeout(3000) -- 3 sec

    local key, value, filename, filetype, savename, filesuffix
    while true do
        local typ, res, err = form:read()
        if not typ then
            get_instance().debug:log_info(
                "failed to read upload form: ", err)
            return ret
        end

        if "header" == typ then

            if res[1] == "Content-Disposition" then
                key = match(res[2], "name=\"(.-)\"")
                filename = match(res[2], "filename=\"(.-)\"")
                if filename then
                    filesuffix = match(filename, ".-(.[^.]*)$")
                end

            elseif res[1] == "Content-Type" then
                filetype = res[2]
            end

            -- upload file
            if filename and filetype then
                savename = save_files[key]

                -- save file to disk
                if savename and base_path then
                    savename = savename .. (filesuffix or '')
                    value, err = io_open(base_path .. savename, 'w')

                    if not value then
                        get_instance().debug:log_error(
                            'failed to open file for save file:',
                            base_path .. savename, " error:",  err)
                    end

                else
                    value = nil
                    get_instance().debug:log_info(
                        'file uploaded not save, key:', key)
                end

            -- upload key value
            else
                value = ''
            end

        elseif "body" == typ then

            if "userdata" == type(value) then
                value:write(res)

            elseif value then
                value = value .. res
            end
            -- will drop values when value is nil(not saved file)

        elseif "part_end" == typ then

            if type(value) == "userdata" then
                value:close()
                ret[key] = { filename = filename, savename = savename, filetype = filetype }

            else
                local kv = ret[key]
                if not kv then
                    ret[key] = value

                elseif type(kv) == "table" then
                    ret[key][#kv] = value

                else
                    ret[key] = { ret[key], value }
                end
            end

            key, value, filename, filetype, savename = nil, nil, nil, nil
        end

        if typ == "eof" then
            break
        end
    end

    return ret
end

local function _get_post_args(self)
    self.post_vars = {}
    if "POST" == ngx_var.request_method then
        local header = headers(self, 'Content-Type')

        if header == "application/x-www-form-urlencoded" then
            read_body()
            self.post_vars = get_post_args()

        elseif header == "text/plain" then
            get_instance().debug:log_info('not supported enctype: text/palin')

        else
            -- multipart/form-data
            self.post_vars = _get_form_data(self)
        end
        -- text/plain not supported now
    end
    return self.post_vars
end

function _M.new(self)
    local res = {
        get_vars = nil,
        post_vars = nil,
        input_vars = nil,
        header_vars = nil,
        base_path = nil,
        save_files = {},
    }
    return setmetatable(res, mt)
end

function _M.upload_files(self, files, base_path)
    self.save_files = files
    self.base_path = base_path
end

function headers(self, key)
    if not self.header_vars then
        self.header_vars = get_headers()
    end

    if key then
        return self.header_vars[key]
    else
        return self.header_vars
    end
end
_M.headers = headers

function _M.get(self, key)
    local get_vars = self.get_vars or _get_uri_args(self)
    if key then
        return get_vars[key]
    end
    return get_vars
end

function _M.post(self, key)
    local post_vars = self.post_vars or _get_post_args(self)

    if key then
        return post_vars[key]
    end
    return post_vars
end

function _M.input(self, key)
    if not self.input_vars then
        local vars = _M.get(self)
        local post = _M.post(self)
        for k, v in pairs(post) do
            vars[k] = v
        end
        self.input_vars = vars
    end
    if key then
        return self.input_vars[key]
    else
        return self.input_vars
    end
end

return _M
