local M = {}
M.options = {
    {key="showInactive", label="Show inactive", default=true},
    {key="showGuarded", label="Show guarded", default=true},
    {key="showCleansed", label="Show cleansed", default=true},
    {key="showEmpowered", label="Show empowered", default=true},
    {key="logging", label="Logging", default=true},
    {key="whiteLabels", label="White text labels", default=true},
    {key="hideUI", label="Hide UI", default=false},
    {key="guardedLabel", label="Guarded label", default="Guarded", kind="String"},
    {key="greenLabel", label="Green statue label", default="Green", kind="String"},
    {key="goldLabel", label="Gold statue label", default="Gold", kind="String"},
    {key="labelTextSize", label="Label text size", default=15, kind="Int", choices={13,15,18,21,24,27,30,35,40,45}},
    {key="labelPosition", label="Label position", default="centered", kind="String",
        choices={"centered","north","above"}, labels={"Centered","North base","Above statue"}},
}
local byKey = {}
for _, option in ipairs(M.options) do byKey[option.key] = option end
for _, key in ipairs({"panelX","panelY","settingsX","settingsY"}) do
    byKey[key] = {key=key,kind="Int"}
end
function M.validate(key, value)
    local option = byKey[key]
    if not option then return nil end
    if option.choices then
        for _, choice in ipairs(option.choices) do if value == choice then return value end end
        return option.default
    elseif option.kind == "String" then
        if type(value) ~= "string" then return option.default end
        value = value:gsub("<[^>]*>", ""):gsub("[%c<>]", ""):match("^%s*(.-)%s*$")
        if value == "" then return option.default end
        
        value = value:gsub("[^ -~]", ""):sub(1,24)
        return value ~= "" and value or option.default
    elseif option.kind == "Int" then
        if type(value) == "number" and value == value and math.abs(value) < 100000 then
            return math.floor(value)
        end
        return option.default
    end
    if type(value) == "boolean" then return value end
    return option.default
end
local function read(kind,key)
    if not PersistentDB then return nil end
    local ok,value = pcall(function() return PersistentDB["Get"..kind](PersistentDB,"ui."..key) end)
    if ok then return value end
end
function M.load(settings)
    for key, option in pairs(byKey) do
        local value = read(option.kind or "Bool",key)
        if key == "logging" and type(value) ~= "boolean" then
            local old = read("Bool","silenceLogging")
            if type(old) == "boolean" then value = not old end
        end
        if value == nil then value = settings[key] end
        settings[key] = M.validate(key,value)
    end
end
function M.save(settings,key)
    local option = byKey[key]
    if not PersistentDB or not option then return false end
    local value = M.validate(key,settings[key])
    if value == nil then return false end
    local ok,saved = pcall(function()
        return PersistentDB["Set"..(option.kind or "Bool")](PersistentDB,"ui."..key,value)
    end)
    return ok and saved == true
end
function M.font(settings)
    local size = M.validate("labelTextSize",settings.labelTextSize)
    local museo = (size == 13 or size == 15) and id.Font["MUSEO_SANS_"..size.."PT_REGULAR"]
    return museo or id.Font["NOTOSANS_"..size] or id.Font.MUSEO_SANS_15PT_REGULAR
end
function M.labelLayout(text,settings)
    local font = M.font(settings)
    local size = M.validate("labelTextSize",settings.labelTextSize)
    local width = math.max(110,#text*size)
    local height = math.max(26,math.ceil(size*1.6))
    if size > 15 and config and config.Font then
        local ok,w,h = pcall(function()
            local cfg = config.Font.FromID(font)
            return cfg:GetStringWidth(text,false)+12,cfg.maxAscent+cfg.maxDescent+8
        end)
        if ok and type(w)=="number" and type(h)=="number" then
            width=math.max(width,w); height=math.max(height,h)
        end
    end
    return font,width,height
end
function M.label(value, settings)
    if value == "corrupted" then return M.validate("guardedLabel",settings.guardedLabel) end
    if value == "not loaded" then return "Not Loaded" end
    if value == "green" then return M.validate("greenLabel",settings.greenLabel) end
    if value == "gold" then return M.validate("goldLabel",settings.goldLabel) end
    return value:sub(1,1):upper() .. value:sub(2)
end
function M.anchor(row,settings)
    local p = row.position
    if settings.labelPosition == "north" then
        return p.x, p.y + 32, p.z + (row.length or 1) * 256
    elseif settings.labelPosition == "above" then
        return p.x, p.y + 1536, p.z
    end
    return p.x, p.y + (settings.labelHeight or 512), p.z
end
function M.visible(value, settings)
    if value == "corrupted" then return settings.showGuarded ~= false end
    if value == "inactive" then return settings.showInactive ~= false end
    if value == "cleansed" then return settings.showCleansed ~= false end
    if value == "empowered" then return settings.showEmpowered ~= false end
    return true
end
return M
