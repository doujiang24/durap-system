-- Copyright (C) Dejiang Zhu (doujiang24)
-- this library based on lua-gd, install first : https://github.com/ittner/lua-gd

local gd = require "gd"
local corehelper = require "helper.core"

local get_instance = get_instance
local pairs = pairs
local ipairs = ipairs
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local strlen = string.len
local io_open = io.open
local math_random = math.random
local math_pi = math.pi
local log_error = corehelper.log_error


local _M = { _VERSION = '0.01' }

local rand_font = ngx.var.ROOT .. "system/library/upcel.ttf"

local im = gd.createTrueColor(100, 100)
local white = im:colorAllocate(244, 244, 244)
local rand_colors = { im:colorAllocate(240, 36, 36), im:colorAllocate(36, 240, 36), im:colorAllocate(36, 36, 240), }

local rand_codes = { '2', '3', '4', '5', '6', '7', '8', '9', 'b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'm', 'n', 'p', 'q', 'r', 's', 't', 'v', 'w', 'x', 'y', 'z', }

local magics = {
    { "\137PNG", "createFromPng", "png" },
    { "GIF87a", "createFromGif", "gif" },
    { "GIF89a", "createFromGif", "gif" },
    { "\255\216\255\224\0\16\74\70\73\70\0", "createFromJpeg", "jpeg" },
    { "\255\216\255\225\19\133\69\120\105\102\0", "createFromJpeg", "jpeg" },  -- JPEG Exif
}
local def_ptsize = 20
local largest_scale = 0.8

local function _loadimg(fname)
    local fp = io_open(fname, "rb")
    if not fp then
        return nil, "Error opening file"
    end

    local header = fp:read(16)
    if not header then
        return nil, "Error reading file"
    end
    fp:close()

    local func
    for _, v in ipairs(magics) do
        if header:sub(1, #v[1]) == v[1] then
            return gd[v[2]](fname), v[3]
        end
    end

    return nil, "Image type not recognized"
end

local function _save(gdImg, typ, filename)
    local ok, err = gdImg[typ](gdImg, filename, 100)
    if not ok then
        log_error("failed to save image:", filename, "; maybe permission denied to overwrite", err)
    end
    return ok
end

function _M.text_watermark(source, text, position)
    local position = position or "rightBottom"

    local srcImg, srcTyp = _loadimg(source)
    local srcW, srcH = srcImg:sizeXY()

    local color = gd.createTrueColor(1, 1):colorAllocate(0, 0, 0)
    local angle = 0
    local len = strlen(text)
    local ptsize = srcH > def_ptsize * 2 and def_ptsize or math_floor(srcH / 2)

    local x, y = 0, ptsize -- leftTop
    if position == "center" then
        x = math_floor( (srcW - ptsize * len) / 2 )
        y = math_floor( (srcH - ptsize) / 2 )
    elseif position == "rightBottom" then
        x = srcW - ptsize * len
        y = srcH - ptsize
    end

    gd.useFontConfig(true)
    srcImg:stringFT(color, "Comic Sans MS", ptsize, angle, x, y, text)

    return _save(srcImg, srcTyp, source)
end

-- position: leftTop, center, rightBottom
function _M.watermark(source, logo, position)
    local position = position or "rightBottom"

    local srcImg, srcTyp = _loadimg(source)
    local logImg = _loadimg(logo)

    local srcW, srcH = srcImg:sizeXY()
    local logW, logH = logImg:sizeXY()

    local dstW, dstH = logW, logH
    local scale = math_min( logW / srcW, logH / srcH )
    if scale > largest_scale then
        dstW = math_floor(logW * largest_scale / scale)
        dstH = math_floor(logH * largest_scale / scale)
    end

    local dstX, dstY = 0, 0 -- leftTop
    if position == "center" then
        dstX = math_floor( (srcW - dstW) / 2 )
        dstY = math_floor( (srcH - dstH) / 2 )
    elseif position == "rightBottom" then
        dstX = srcW - dstW
        dstY = srcH - dstH
    end

    srcImg:copyResized(logImg, dstX, dstY, 0, 0, dstW, dstH, logW, logH)
    return _save(srcImg, srcTyp, source)
end

-- keep the full picture content and scale
function _M.thumb(source, destination, max_width, max_height)
    local position = position or "rightBottom"

    local srcImg, srcTyp = _loadimg(source)

    local srcW, srcH = srcImg:sizeXY()

    local dstW, dstH = srcW, srcH
    if max_width < srcW or max_height < srcH then
        local scale = math_max( srcW / max_width, srcH / max_height )
        dstW = srcW / scale
        dstH = srcH / scale
    end

    local img = gd.createPalette(dstW, dstH)
    img:copyResized(srcImg, 0, 0, 0, 0, dstW, dstH, srcW, srcH)

    return _save(img, srcTyp, destination)
end

function _M.randcode()
    local ptsize, width, height, code = 40, 100, 40, ''

    local img = gd.createTrueColor(width, height)
    img:filledRectangle(0, 0, width, height, white)

    for i = 1, 4 do
        local char = rand_codes[math_random(#rand_codes)]
        local color = rand_colors[math_random(#rand_colors)]
        local angle = math_random() / math_pi

        img:stringFT(color, rand_font, ptsize, angle, 5 + (i-1) * 25, 30, char)

        code = code .. char
    end

    return code, img
end

return _M
