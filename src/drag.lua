local preferences = require("src/preferences")
local M = {}

function M.attach(title,panel,parent,settings,xKey,yKey)
    local capture
    title.clickthrough = false
    title.enabled = true
    local function clamp(x,y)
        return math.floor(math.max(0,math.min(x,parent.width-panel.width))),
            math.floor(math.max(0,math.min(y,parent.height-panel.height)))
    end
    title:Subscribe(ui.Hook.ONCLICK,function(_,x,y)
        local origin = parent.xyGlobal
        local pointerX = origin.x+panel.x+title.x+x
        local pointerY = origin.y+panel.y+title.y+y
        local raw = Mouse and Mouse.IsAvailable() and Mouse.GetPosition() or nil
        local percent = game and game.options and game.options.InterfaceScale
        local scale = percent and tonumber(percent.setting) or 100
        scale = scale > 0 and scale/100 or 1
        if raw then
            local sx = math.abs(pointerX)>=32 and raw.x/pointerX or nil
            local sy = math.abs(pointerY)>=32 and raw.y/pointerY or nil
            if sx and sy and sx>0 and math.abs(sx-sy)<(sx+sy)*0.05 then scale=(sx+sy)/2 end
        end
        capture={x=panel.x,y=panel.y,localX=x,localY=y,
            rawX=raw and raw.x,rawY=raw and raw.y,scale=scale}
    end)
    local function move(_,x,y)
        if not capture then return end
        local dx,dy = x-capture.localX,y-capture.localY
        if capture.rawX and Mouse and Mouse.IsAvailable() then
            local raw = Mouse.GetPosition()
            if raw then dx=(raw.x-capture.rawX)/capture.scale; dy=(raw.y-capture.rawY)/capture.scale end
        end
        local px,py = clamp(capture.x+dx,capture.y+dy)
        settings[xKey],settings[yKey]=px,py
        panel:SetPos(px,py)
    end
    title:Subscribe(ui.Hook.ONHOLD,move)
    local function finish()
        if not capture then return end
        local changed = settings[xKey] ~= capture.x or settings[yKey] ~= capture.y
        capture=nil
        if changed then preferences.save(settings,xKey); preferences.save(settings,yKey) end
    end
    title:Subscribe(ui.Hook.ONRELEASE,function(self,x,y)
        if not capture then return end
        move(self,x,y); finish()
    end)
    title:Subscribe(ui.Hook.ONDRAGCOMPLETE,finish)
end
return M
