local M = {}
function M.key(coord, shape, rotation)
    return tostring(coord) .. "/" .. tostring(shape) .. "/" .. tostring(rotation)
end
function M.list(values)
    local result = {}
    for _, value in ipairs(values or {}) do result[#result + 1] = tostring(value) end
    return table.concat(result, ",")
end
function M.read(name)
    local rows = {}
    for _, loc in ipairs(LocList.ByName(name)) do
        if loc.isValid then
            local cfg = loc.config
            local position = loc.position
            local row = {
                key = M.key(loc.coordGrid, loc.shapeType, loc.rotationType),
                displayName = loc.displayName,
                position = { x = position.x, y = position.y, z = position.z },
                length = loc.length,
                coord = tostring(loc.coordGrid),
                configID = loc.configID,
                configName = cfg and cfg.configName or "unavailable",
                hidden = loc.isHidden or loc.isRoofRemoved,
            }
            rows[#rows+1]=row
        end
    end
    table.sort(rows, function(a, b) return a.key < b.key end)
    return rows
end

function M.gate(name)
    local count = 0
    for _, npc in ipairs(NPCList.ByName(name)) do
        if npc.isValid then count = count + 1 end
    end
    if count == 0 then return "inactive" end
    if count > 1 then return "ambiguous" end
    return "observing"
end

function M.resolve(candidates, settings)
    settings = settings or {}
    local unique, seen = {}, {}
    for _, row in ipairs(candidates) do
        local identity = row.key .. "/" .. tostring(row.configID)
        local existing = seen[identity]
        if not existing then
            seen[identity] = row
            unique[#unique + 1] = row
        elseif existing.hidden and not row.hidden then
            existing.hidden = false
        end
    end
    table.sort(unique, function(a, b)
        return a.key .. "/" .. tostring(a.configID) < b.key .. "/" .. tostring(b.configID)
    end)
    local remaining = unique
    if #unique > 1 then
        local sameTile = true
        for _, row in ipairs(unique) do
            if row.coord ~= unique[1].coord then sameTile = false end
        end
        if sameTile then
            local visible = {}
            for _, row in ipairs(remaining) do
                if not row.hidden then visible[#visible + 1] = row end
            end
            if #visible > 0 then remaining = visible end
            local hasActiveConfig = false
            for _, row in ipairs(remaining) do
                if (settings.activeConfigIDs or {})[row.configID]
                    or (settings.statesByConfigID or {})[row.configID]
                    or (settings.statesByConfigName or {})[row.configName] then hasActiveConfig = true end
            end
            if hasActiveConfig then
                local active = {}
                for _, row in ipairs(remaining) do
                    if not (settings.inactiveConfigIDs or {})[row.configID] then
                        active[#active + 1] = row
                    end
                end
                remaining = active
            end
        end
    end
    return #remaining == 1 and remaining[1] or nil, #unique
end
function M.readTargets(names, settings)
    local rows = {}
    for _, name in ipairs(names) do
        local candidates = {}
        for _, suffix in ipairs({"", " (corrupted)", " (cleansed)", " (empowered)"}) do
            for _, row in ipairs(M.read(name .. suffix)) do
                candidates[#candidates + 1] = row
            end
        end
        local selected, count = M.resolve(candidates, settings)
        if selected then
            rows[#rows + 1] = selected
        else
            rows[#rows + 1] = {
                displayName = name,
                availability = count == 0 and "missing" or "ambiguous",
            }
        end
    end
    return rows
end
return M
