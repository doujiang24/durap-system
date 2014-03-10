-- Copyright (C) 2013 doujiang24, MaMa Inc.

local upload = require "resty.upload"
local config = require "core.config"
local stringhelper = require "helper.string"
local filehelper = require "helper.file"

local ngx = ngx
local ngx_var = ngx.var

local get_instance = get_instance
local read_body = ngx.req.read_body
local get_headers = ngx.req.get_headers
local get_uri_args = ngx.req.get_uri_args
local get_post_args = ngx.req.get_post_args
local setmetatable = setmetatable
local pairs = pairs
local type = type
local io_open = io.open
local match = string.match
local uniqid = stringhelper.uniqid
local detect = filehelper.detect
local req_socket = ngx.req.socket


local _M = { _VERSION = '0.01' }

local chunk_size = config.chunk_size
local recieve_timeout = config.recieve_timeout
local HTTP_RAW_POST_KEY = config.HTTP_RAW_POST_KEY -- "HTTP_RAW_DATA"

local mt = { __index = _M }


local function _newfile(path, name)
    local file, err = io_open(path .. name, 'w')

    if not file then
        get_instance().debug:log_error( 'failed to new file:',
            path .. name, " error:",  err)
    end

    return file, name, path
end

local function _get_uri_args(self)
    self.get_vars = get_uri_args()

    return self.get_vars
end

local function ip_address()
    return ngx_var.remote_addr
end
_M.ip_address = ip_address

local function _save_raw_file(self)
    local base_path, save_files, ret = self.base_path, self.save_files, {}
    local savename = not save_files and uniqid() or save_files[HTTP_RAW_POST_KEY]

    if not base_path or not savename then
        return ret
    end

    local filesize, file = 0, nil

    local sock, err = req_socket()
    if not sock then
        get_instance().debug:log_error('failed to init request socket, err:', err)
        return ret
    end
    sock:settimeout(recieve_timeout)

    while true do
        local data, err, partial = sock:receive(chunk_size)

        if err and err ~= 'closed' then
            get_instance().debug:log_error('fail to recieve raw post data, err:', err)
            file:close()
            return ret
        end

        local chunk = data or partial
        if chunk then
            if not file then
                file, savename = _newfile(base_path, savename .. "." .. detect(chunk))

                if not file then
                    return ret
                end
            end

            filesize = filesize + #chunk
            file:write(chunk)
        end

        if not data then
            file:close()
            break
        end
    end

    ret[HTTP_RAW_POST_KEY] = {
        savename = savename,
        filesize = filesize,
    }
    return ret
end

local function _get_form_data(self)
    local base_path, save_files, ret = self.base_path, self.save_files, {}

    local form, err = upload:new(chunk_size)
    if not form then
        get_instance().debug:log_info("failed to new upload: ", err)
        return ret
    end
    form:set_timeout(recieve_timeout)

    local key, value, filename, filetype, filesize, savename, filesuffix
    while true do
        local typ, res, err = form:read()
        if not typ then
            get_instance().debug:log_info(
                "failed to read upload form: ", err)
            return ret
        end

        if typ == "header" then

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
                savename = not save_files and uniqid() or save_files[key]

                -- save file to disk
                if savename and base_path then
                    savename = savename .. (filesuffix or '')
                    value = _newfile(base_path, savename)

                else
                    value = nil
                    get_instance().debug:log_info(
                        'file uploaded not save, key:', key)
                end

            -- upload key value
            else
                value = ''
            end

        elseif typ == "body" then

            if type(value) == "userdata" then
                value:write(res)
                filesize = (filesize or 0) + #res

            elseif value then
                value = value .. res
            end
            -- will drop values when value is nil(not saved file)

        elseif typ == "part_end" then

            if type(value) == "userdata" then
                value:close()
                ret[key] = {
                    filename = filename,
                    savename = savename,
                    filetype = filetype,
                    filesize = filesize
                }

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

            key, value, filename, filetype, filesize, savename = nil, nil, nil, nil, nil

        elseif typ == "eof" then
            break
        end
    end

    return ret
end

local function headers(self, key)
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

local function _get_post_args(self)
    self.post_vars = {}
    if "POST" == ngx_var.request_method then
        local header = headers(self, 'Content-Type')

        -- print(header)
        if header == "application/x-www-form-urlencoded" then
            read_body()
            self.post_vars = get_post_args()

        elseif header == "applicatoin/octet-stream" then
            self.post_vars = _save_raw_file(self)

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

function _M.set_save_files(self, base_path, files)
    self.base_path = base_path
    self.save_files = files
end

function _M.get(self, key)
    local get_vars = self.get_vars or _get_uri_args(self)
    if key then
        return get_vars[key]
    end
    return get_vars
end

local function post(self, key)
    local post_vars = self.post_vars or _get_post_args(self)

    if key then
        return post_vars[key]
    end
    return post_vars
end
_M.post = post

function _M.input(self, key)
    if not self.input_vars then
        local vars = get_uri_args()
        local posts = post(self)
        for k, v in pairs(posts) do
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
