-- Copyright (C) Dejiang Zhu (doujiang24)

local ipairs    = ipairs


local _M = { _VERSION = '0.01' }


function _M.merge(arr1, arr2)
    local start = #arr1

    for i, v in ipairs(arr2) do
        arr1[start + i] = v
    end

    return arr1
end


function _M.in_array(needle, arr)
    for i = 1, #arr do
        if arr[i] == needle then
            return true
        end
    end

    return false
end


return _M

