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


return _M

