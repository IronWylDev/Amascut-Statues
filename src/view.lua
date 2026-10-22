local detector = require("src/detector")
local preferences = require("src/preferences")
local theme = require("src/theme")
local SettingsView = require("src/settings-view")
local M = {}
local function sentence(value)
    if value == "corrupted" then return "Guarded" end
    if value == "not loaded" then return "Not Loaded" end
    return value:sub(1, 1):upper() .. value:sub(2)
end

function M.new(settings, onCapture)
    local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
    if not parent then error("Plugin UI layer unavailable; reload in the beta world") end
    local size = settings.panelSize or 200
    local box = theme.panel(parent, size, size)
    box.hidden = settings.hideUI == true
    local title = theme.text(box, "Amascut Statues", 12, 8, size - 24, 24, true)
    title:AlignTo(ui.AlignMode.CENTRE)
    require("src/drag").attach(title,box,parent,settings,"panelX","panelY")
    local currentRows, worldLabels, rowViews = {}, {}, {}
    for i = 1, settings.worldLabelsEnabled and #settings.altarNames or 0 do
        local text = theme.text(parent, "", 0, 0, 110, 26)
        text.font = id.Font.MUSEO_SANS_15PT_REGULAR
        text:AlignTo(ui.AlignMode.CENTRE)
        text.hidden = true
        worldLabels[i] = text
    end
    for i, name in ipairs(settings.altarNames) do
        local y = 44 + (i - 1) * 24
        local background = theme.rectangle(box, 8, y, size - 16, 22,
            i % 2 == 1 and theme.colours.row or theme.colours.alternate)
        local accent = theme.rectangle(box, 8, y, 3, 22, theme.colours.neutral)
        local nameText = theme.text(box, name:gsub("^Altar of ", ""), 18, y, 78, 22)
        local valueText = theme.text(box, "Unknown", 96, y, size - 108, 22, false, true)
        rowViews[i] = {background=background, accent=accent, name=nameText, value=valueText}
    end
    local needsRefresh, settingsOpen = true, false
    local pendingState = "unknown"
    local captureButton = theme.button(box, "Log states", size - 94, size - 36, 84, 26, function()
        if onCapture then onCapture() end
    end)
    captureButton.hidden = settings.hideUI == true
    local settingsButton = theme.button(box, "Settings", 10, size - 36, size - 110, 26, function()
        settingsOpen = not settingsOpen
        needsRefresh = true
    end)
    local settingsPage = SettingsView.new(parent, settings, function() needsRefresh = true end,
        nil, nil, function() settingsOpen = false; needsRefresh = true end)
    settingsPage.root.hidden = true
    require("src/drag").attach(settingsPage.title,settingsPage.root,parent,settings,"settingsX","settingsY")

    local function render()
        box.hidden = settings.hideUI == true
        captureButton.hidden = settings.hideUI == true
        settingsPage.root.hidden = settings.hideUI == true or not settingsOpen
        settingsPage.refresh()
        local slot = 0
        for i in ipairs(settings.altarNames) do
            local row = currentRows[i]
            local value = (row and detector.colour(row, settings) or pendingState):gsub(" %(provisional%)", "")
            local visible = preferences.visible(value, settings)
            local parts = rowViews[i]
            for _, component in pairs(parts) do component.hidden = not visible end
            if visible then
                local y = 44 + slot * 24
                parts.background:SetPos(8, y)
                parts.accent:SetPos(8, y)
                parts.name:SetPos(18, y)
                parts.value:SetPos(96, y)
                slot = slot + 1
            end
            local colour = theme.colours[value] or theme.colours.neutral
            parts.accent.rgba = colour
            parts.value.content = sentence(value)
            parts.value.rgba = theme.colours.white
            if worldLabels[i] then
                worldLabels[i].content = preferences.label(value,settings)
                local font,width,height = preferences.labelLayout(worldLabels[i].content,settings)
                worldLabels[i].font = font
                worldLabels[i]:SetSize(width,height)
                local labelColour = value == "green" and 0x55FF66FF
                    or value == "gold" and 0xFFD45AFF or theme.colours.white
                worldLabels[i].rgba = settings.whiteLabels ~= false and theme.colours.white or labelColour
            end
        end
        needsRefresh = false
    end

    local function draw()
        if not World.IsAvailable() then return end
        if needsRefresh then render() end
        local x = math.max(0, math.min(settings.panelX or 30, parent.width - size))
        local y = math.max(0, math.min(settings.panelY or 180, parent.height - size))
        box:SetPos(x, y)
        local settingsWidth = settingsPage.root.width
        local settingsX = x + size + 8
        if settingsX + settingsWidth > parent.width then settingsX = x - settingsWidth - 8 end
        settingsPage.root:SetPos(math.max(0, math.min(settings.settingsX or settingsX,parent.width-settingsWidth)),
            math.max(0, math.min(settings.settingsY or y,parent.height-settingsPage.root.height)))
        local origin = parent.xyGlobal
        for i, text in ipairs(worldLabels) do
            text.hidden = true
            local row = currentRows[i]
            if settings.worldLabelsEnabled and row and row.position and not row.hidden and not row.availability
                and preferences.visible(detector.colour(row, settings), settings) then
                local ok, point = pcall(ScreenConvert.Vector3ToScreen,
                    Vector3.new(preferences.anchor(row,settings)))
                if ok and point then
                    local px, py = point.x - origin.x, point.y - origin.y
                    if px >= 0 and px <= parent.width and py >= 0 and py <= parent.height then
                        text:SetPos(math.floor(px - text.width/2), math.floor(py - text.height/2))
                        text.hidden = false
                    end
                end
            end
        end
    end
    return {
        draw = draw,
        invalidate = function() needsRefresh = true end,
        toggleUI = function()
            settings.hideUI = not (settings.hideUI == true)
            preferences.save(settings, "hideUI")
            needsRefresh = true
        end,
        update = function(state, reason, rows)
            currentRows, pendingState = rows or {}, state
            needsRefresh = true
        end,
        clear = function()
            currentRows, pendingState = {}, "loading"
            needsRefresh = true
        end,
        destroy = function()
            for _, text in ipairs(worldLabels) do text:Destroy() end
            settingsPage.destroy()
            box:Destroy()
        end,
    }
end
return M
