local M = {}

function M.colour(row, settings)
    if row.availability == "missing" then return "not loaded" end
    if row.availability then return row.availability end
    if row.hidden then return "hidden" end
    if settings.inactiveConfigIDs[row.configID] then return "inactive" end
    local variant = settings.statesByConfigID[row.configID]
        or settings.statesByConfigName[row.configName]
    if variant then return variant end
    local colour = settings.coloursByAppearance[row.appearanceSignature]
    if colour then return colour end
    if not row.appearanceSignature then
        local name = settings.corruptedConfigNames[row.configID]
        if name and name == row.configName then return "corrupted" end
    end
    return "unknown"
end

return M
