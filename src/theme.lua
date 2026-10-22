local M = {}
M.colours = {
    background = 0x1D1B18F2, border = 0x716049FF, accent = 0xBEA16FFF,
    row = 0x2E2825EA, alternate = 0x24211EEA, white = 0xFFFFFFFF,
    green = 0x72C98AFF, gold = 0xE2BF68FF, neutral = 0x938A7DFF,
}

function M.rectangle(parent, x, y, width, height, colour, outline)
    local rect = ui.Rectangle.new(parent)
    rect:SetPos(x, y)
    rect:SetSize(width, height)
    rect.fill = not outline
    rect.rgba = colour
    rect.clickthrough = true
    return rect
end

function M.panel(parent, width, height)
    local panel = ui.GroupBox.new(parent)
    panel:SetHeaderLayout(0, 0, 0, 0, 0)
    panel:SetSize(width, height)
    panel.stylesheetID = -1
    panel.clickthrough = false
    panel.enabled = true
    M.rectangle(panel, 0, 0, width, height, M.colours.background)
    M.rectangle(panel, 0, 0, width, height, M.colours.border, true)
    M.rectangle(panel, 1, 1, width - 2, 2, M.colours.accent)
    return panel
end

function M.text(parent, content, x, y, width, height, heading, right)
    local text = ui.Text.new(parent)
    text:SetPos(x, y)
    text:SetSize(width, height)
    text.font = heading and (id.Font.CINZEL_13PT_BOLD or id.Font.MUSEO_SANS_15PT_REGULAR)
        or (id.Font.MUSEO_SANS_13PT_REGULAR or id.Font.MUSEO_SANS_15PT_REGULAR)
    text.content = content
    text.rgba = M.colours.white
    text.isShadowed = true
    text.clickthrough = true
    text.maxLines = 1
    text:AlignTo(right and ui.AlignMode.TOPRIGHT or ui.AlignMode.TOPLEFT, ui.AlignMode.CENTRE)
    return text
end

function M.button(parent, label, x, y, width, height, action)
    local button = ui.Button.new(parent)
    button:SetPos(x, y)
    button:SetSize(width, height)
    button.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
    button.label = label
    button.enabled = true
    button.clickthrough = false
    button.text.rgba = M.colours.white
    button.text.font = id.Font.MUSEO_SANS_13PT_REGULAR or id.Font.MUSEO_SANS_15PT_REGULAR
    button:Subscribe(ui.Hook.ONBUTTONPRESSED, action)
    return button
end

function M.identity(component)
    return {component.interfaceID, component.staticID, component.categoryID, component.dynamicID}
end

function M.find(identity)
    return ui.Interfaces:GetComponent(identity[1], identity[2], identity[3], identity[4])
end

return M
