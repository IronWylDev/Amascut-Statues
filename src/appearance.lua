local M = {}
function M.new()
    local entries = {}
    return {
        clear = function() entries = {} end,
        remember = function(key, configID, models, materials, colours, pendingTicks)
            entries[key] = {
                configID = configID,
                pendingTicks = pendingTicks or 0,
                signature = "config=" .. tostring(configID) .. ";models=" .. models
                    .. ";materials=" .. materials .. ";colours=" .. colours,
            }
        end,
        apply = function(rows, agePending)
            local retained, seen = {}, {}
            for _, row in ipairs(rows) do
                row.appearanceSignature = nil
                if row.key then seen[row.key] = true end
                local entry = row.key and entries[row.key]
                if entry and entry.configID == row.configID then
                    entry.pendingTicks = 0
                    row.appearanceSignature = entry.signature
                    retained[row.key] = entry
                end
            end
            for key, entry in pairs(entries) do
                if not seen[key] and entry.pendingTicks > 0 then
                    if agePending then entry.pendingTicks = entry.pendingTicks - 1 end
                    if entry.pendingTicks > 0 then retained[key] = entry end
                end
            end
            entries = retained
        end,
    }
end
return M
