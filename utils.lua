local Utils = {}

function Utils.TableSize(tbl)
    local count = 0
    for k, v in pairs(tbl) do
        count = count + 1
    end
    return count
end

function Utils.getKeysSortedByValue(tbl, sortFunction)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end

    table.sort(
        keys,
        function(a, b)
            return sortFunction(tbl[a], tbl[b])
        end
    )
    return keys
end

function Utils.sortedKeys(dataset)
    return Utils.getKeysSortedByValue(
        dataset or {},
        function(a, b)
            return a > b
        end
    )
end

function Utils.starts_with(str, start)
    return str:sub(1, #start) == start
end

return Utils
