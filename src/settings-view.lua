local theme = require("src/theme")
local preferences = require("src/preferences")
local M = {}
function M.new(parent,settings,onChange,width,maxHeight,onClose)
    width = width or 320
    local height = math.min(412,maxHeight or 412)
    local header,footer = 70,34
    local optionPages, optionRows, counts = {},{}, {0,0}
    for i,option in ipairs(preferences.options) do
        local page = option.kind and 2 or 1
        counts[page] = counts[page] + 1
        optionPages[i],optionRows[i] = page,counts[page]
    end
    local root = theme.panel(parent,width,height)
    local identity = theme.identity(root)
    local title = theme.text(root,"Statue settings",16,10,width-(onClose and 100 or 32),25,true)
    local notice = theme.text(root,"",12,height-27,width-24,20)
    local controls,parts,previous = {},{},{}
    local page = 1
    local function refresh()
        if not theme.find(identity) then return end
        for i,option in ipairs(preferences.options) do
            local visible = optionPages[i] == page
            for _,part in ipairs(parts[i]) do part.hidden = not visible end
            local value = settings[option.key]
            if previous[i] ~= value then
                if not option.kind then controls[i].label = value == true and "On" or "Off"
                elseif option.choices then
                    local label = tostring(value)
                    for j,choice in ipairs(option.choices) do
                        if value == choice and option.labels then label = option.labels[j] end
                    end
                    controls[i].label = label
                else controls[i].content = value or option.default end
                previous[i] = value
            end
        end
    end
    local function apply(option,value)
        settings[option.key] = preferences.validate(option.key,value)
        local saved = preferences.save(settings,option.key)
        notice.content = saved and "" or "Applied; could not save on this device."
        refresh(); onChange()
    end
    for i,option in ipairs(preferences.options) do
        local row = optionRows[i]
        local rowHeight = math.min(44,math.floor((height-header-footer)/counts[optionPages[i]]))
        local y = header+(row-1)*rowHeight
        local background = theme.rectangle(root,8,y+2,width-16,rowHeight-4,
            row%2 == 1 and theme.colours.row or theme.colours.alternate)
        local isLabel = optionPages[i] == 2
        local controlWidth = isLabel and 122 or 58
        local name = theme.text(root,option.label,16,y+2,width-controlWidth-42,rowHeight-4)
        local isInput = option.kind == "String" and not option.choices
        local controlHeight = math.min(isInput and 32 or 28,rowHeight-4)
        local x,cy = width-controlWidth-16,y+math.floor((rowHeight-controlHeight)/2)
        local control
        if isInput then
            control = ui.InputField.new(root)
            control:SetPos(x,cy); control:SetSize(controlWidth,controlHeight)
            control:Setup(ui.TextContentVisibilityMode.VISIBLE,ui.InputFieldFilterMode.NONE,24)
            control.stylesheetID = id.StyleSheet.INPUT_DEFAULT
            control.enabled = true; control.clickthrough = false
            control.text.font = id.Font.MUSEO_SANS_13PT_REGULAR or id.Font.MUSEO_SANS_15PT_REGULAR
            control.text.rgba = theme.colours.white
            control.text.alignVertical = ui.AlignMode.CENTRE
            control.contentMargin.left = 6
            control.contentMargin.right = 6
            control.contentMargin.top = 2
            control.contentMargin.bottom = 2
            control.content = settings[option.key] or option.default
            control:Subscribe(ui.Hook.ONCONTENTCHANGED,function(c,cause,content)
                local result = ui.InputFieldActionResult
                if cause == result.SUBMIT or cause == result.SUBMIT_ON_FOCUS_LOSS then
                    apply(option,content); c.content = settings[option.key]
                elseif cause == result.SUBMIT_ON_ESCAPE then c.content = settings[option.key] end
            end)
        else
            control = theme.button(root,"",x,cy,controlWidth,controlHeight,function()
                if option.choices then
                    local nextIndex = 1
                    for j,choice in ipairs(option.choices) do
                        if settings[option.key] == choice then nextIndex = j % #option.choices + 1 end
                    end
                    apply(option,option.choices[nextIndex])
                else apply(option,not (settings[option.key] == true)) end
            end)
        end
        controls[i] = control; parts[i] = {background,name,control}
    end
    theme.button(root,"Display",12,40,84,25,function() page=1; refresh() end)
    theme.button(root,"Labels",104,40,84,25,function() page=2; refresh() end)
    if onClose then theme.button(root,"Close",width-68,11,52,24,onClose) end
    refresh()
    return {root=root,title=title,refresh=refresh,controls=controls,
        destroy=function() local current=theme.find(identity); if current then current:Destroy() end end}
end
return M
