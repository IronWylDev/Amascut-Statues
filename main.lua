local settings = require("settings")
local preferences = require("src/preferences")
local observer = require("src/observer")
local appearance = require("src/appearance").new()
preferences.load(settings)

local view
local settingsPage
local detector = require("src/detector")
local captureClock, lastCapture = 0, -math.huge
local rows, tracked = {}, {}
local elapsed, settleTicks = 0, 0
local waitingForGame, stopped = false, false
local lastError

local function publish(state, nextRows)
    rows = nextRows or {}
    view.update(state, nil, rows)
end

local function capture()
    if settings.logging == false or captureClock-lastCapture < 1 then return end
    lastCapture = captureClock
    if #rows == 0 then print("[Amascut altars] No loaded altar snapshot"); return end
    for i,row in ipairs(rows) do
        print("[Amascut altars] " .. settings.altarNames[i] .. ": "
            .. preferences.label(detector.colour(row,settings),settings)
            .. "; config=" .. tostring(row.configID)
            .. "; appearance=" .. (row.appearanceSignature or "not observed"))
    end
end
view = require("src/view").new(settings,capture)
Event.SettingsLayerReady.Subscribe("amascut.settings",function(event)
    settingsPage = nil
    local width = math.max(280,math.min(420,event.component.width-24))
    settingsPage = require("src/settings-view").new(event.component,settings,view.invalidate,width,event.component.height-24)
    settingsPage.root:SetPos(12,12)
end)

local function reset()
    rows, tracked = {}, {}
    elapsed = 0
    settleTicks = settings.transitionServerTicks
    appearance.clear()
    view.clear()
end

local function sample()
    if stopped or waitingForGame then return end
    if not World.IsAvailable() then reset(); return end
    if settleTicks > 0 then settleTicks = settleTicks - 1; return end
    elapsed = 0
    if not settings.enabled then
        tracked = {}
        appearance.clear()
        publish("disabled")
        return
    end
    local ok, state, nextRows = pcall(function()
        local gate = observer.gate(settings.bossName)
        if gate == "inactive" then return "not loaded", {} end
        if gate ~= "observing" then return gate, {} end
        return gate, observer.readTargets(settings.altarNames, settings)
    end)
    if not ok then
        tracked = {}
        appearance.clear()
        publish("error")
        if settings.logging ~= false and state ~= lastError then
            print("[Amascut altars] " .. tostring(state))
        end
        lastError = state
        return
    end
    appearance.apply(nextRows, true)
    lastError, tracked = nil, {}
    for _, row in ipairs(nextRows) do
        if row.key then tracked[row.key] = row end
    end
    publish(state, nextRows)
end

Event.ServerLogic.Subscribe("amascut.sample", sample)
Event.Draw.Subscribe("amascut.draw", function(event)
    if stopped then return end
    captureClock = captureClock + math.max(0,event.timeDeltaSecs or 0)
    if not World.IsAvailable() then reset(); return end
    if settingsPage then settingsPage.refresh() end
    if waitingForGame or settleTicks > 0 then return end
    if settings.enabled then
        elapsed = elapsed + math.max(0, event.timeDeltaSecs or 0)
        if elapsed >= settings.staleSeconds then
            tracked = {}
            appearance.clear()
            publish("stale")
        end
    end
    view.draw()
end)
Event.KeyDown.Subscribe("amascut.ui", function(event)
    if stopped or event.isRepeat then return end
    if event.modifiers ~= (ModifierKey.CONTROL | ModifierKey.SHIFT) then return end
    if event.gameKey == GameKey.F10 then view.toggleUI()
    elseif settings.enabled and event.gameKey == GameKey.F9 then capture() end
end)
Event.GameStateChanged.Subscribe("amascut.reset", function(event)
    waitingForGame = event.newState ~= GameState.GAME
    reset()
end)

local rebuildEvents = {Event.WorldCreated, Event.WorldUpdated, Event.RegionCreated, Event.RegionUpdated}
for _, source in ipairs(rebuildEvents) do source.Subscribe("amascut.transition", reset) end

Event.LocRemoved.Subscribe("amascut.removed", function(event)
    if stopped or waitingForGame or settleTicks > 0 or not World.IsAvailable() then return end
    if tracked[observer.key(event.coordGrid, event.shapeType, event.rotationType)] then
        tracked = {}
        appearance.clear()
        publish("unknown")
    end
end)
Event.LocCustomised.Subscribe("amascut.appearance", function(event)
    if stopped or not settings.enabled or waitingForGame or not World.IsAvailable() then return end
    local key = observer.key(event.coordGrid, event.shapeType, event.rotationType)
    local selected = tracked[key]
    local cfg = event.config
    local configID = cfg and cfg.id or (selected and selected.configID)
    local name = cfg and cfg.name or (selected and selected.displayName)
    local target = selected ~= nil
    if not target and name then
        for _, baseName in ipairs(settings.altarNames) do
            for _, suffix in ipairs({"", " (corrupted)", " (cleansed)", " (empowered)"}) do
                if name:lower() == (baseName .. suffix):lower() then target = true end
            end
        end
    end
    if not target then return end
    appearance.remember(key, configID, observer.list(event.customModels),
        observer.list(event.customMaterials), observer.list(event.customColours), selected and 0 or 3)
    if selected then
        appearance.apply(rows)
        view.update("observing", nil, rows)
    end
end)

sample()

return {stop = function()
    if stopped then return end
    stopped = true
    for _, source in ipairs(rebuildEvents) do source.Unsubscribe("amascut.transition") end
    Event.ServerLogic.Unsubscribe("amascut.sample")
    Event.Draw.Unsubscribe("amascut.draw")
    Event.KeyDown.Unsubscribe("amascut.ui")
    Event.SettingsLayerReady.Unsubscribe("amascut.settings")
    if settingsPage then settingsPage.destroy(); settingsPage = nil end
    Event.GameStateChanged.Unsubscribe("amascut.reset")
    Event.LocRemoved.Unsubscribe("amascut.removed")
    Event.LocCustomised.Unsubscribe("amascut.appearance")
    rows, tracked = {}, {}
    appearance.clear()
    view.destroy()
end}
