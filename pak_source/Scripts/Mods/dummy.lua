------------------------------------------------------------
--  dummy.lua  –  Dummy Mod Main Entry Point & Scaleform Menu Panel
------------------------------------------------------------

if System and System.LogAlways then
    System.LogAlways("[Dummy] === LOADING DUMMY.LUA (STANDALONE SCALEFORM PANEL) ===")
end

-- Configuration Defaults
DummyConfig = DummyConfig or {
    spawnKey = "/",
    menuKey = "F3",
    isImmortal = true,
    autoHealWaiting = true,
    defaultPreset = 1
}

-- Load configuration from dummy.cfg if available
function Dummy_LoadConfig()
    pcall(function()
        local f = io.open("mods/Dummy/dummy.cfg", "r") or io.open("dummy.cfg", "r")
        if f then
            for line in f:lines() do
                local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
                if k and v then
                    if k == "spawnKey" then DummyConfig.spawnKey = v
                    elseif k == "menuKey" then DummyConfig.menuKey = v
                    elseif k == "isImmortal" then DummyConfig.isImmortal = (v == "1" or v:lower() == "true")
                    elseif k == "autoHealWaiting" then DummyConfig.autoHealWaiting = (v == "1" or v:lower() == "true")
                    elseif k == "defaultPreset" then DummyConfig.defaultPreset = tonumber(v) or 1
                    end
                end
            end
            f:close()
        end
    end)

    if DummySpawner then
        DummySpawner.KEYBIND_SPAWN = DummyConfig.spawnKey or "/"
        DummySpawner.isImmortal = DummyConfig.isImmortal
        DummySpawner.autoHealWaiting = DummyConfig.autoHealWaiting
        DummySpawner.currentPresetIdx = DummyConfig.defaultPreset or 1
    end
end

Dummy_LoadConfig()

-- Global Wrapper Functions for Commands
function dummy_spawn() DummySpawner:Toggle() end
function dummy_next()  DummySpawner:NextPreset() end
function dummy_prev()  DummySpawner:PrevPreset() end
function dummy()       DummySpawner:Toggle() end

function dummy_preset(idx)
    local num = tonumber(idx)
    if num and num >= 1 and num <= 3 then
        DummySpawner.currentPresetIdx = num
        if DummySpawner.spawnedEntityId then
            DummyEquipment:ApplyPreset(DummySpawner.spawnedEntityId, num)
        end
        local names = { "Light Armor", "Medium Armor", "Heavy Full Plate Armor" }
        if Game and Game.SendInfoText then
            Game.SendInfoText("Applied Armor Preset " .. num .. ": " .. (names[num] or ""), false, 0, 3)
        end
    end
end

function dummy_bind(key)
    local kStr = tostring(key or "")
    if kStr ~= "" and kStr ~= "nil" then
        DummySpawner:BindKey(kStr)
        if Game and Game.SendInfoText then
            Game.SendInfoText("Dummy spawn hotkey bound to: " .. kStr, false, 0, 3)
        end
    end
end

function dummy_heal()
    if DummySpawner and DummySpawner.Heal then
        DummySpawner:Heal()
        if Game and Game.SendInfoText then
            Game.SendInfoText("ui_dummy_menu_opt1", false, 0, 3)
        end
    end
end

function dummy_immortal(enable)
    if enable ~= nil and enable ~= "" then
        local str = tostring(enable):lower()
        local state = (str == "1" or str == "true" or str == "on")
        if DummySpawner then DummySpawner.isImmortal = state end
        if DummySpawner.spawnedEntityId then
            local ent = System.GetEntity(DummySpawner.spawnedEntityId)
            if ent and ent.actor then
                pcall(function() ent.actor:SetInvulnerable(state) end)
            end
        end
        local key = state and "ui_dummy_menu_opt2_on" or "ui_dummy_menu_opt2_off"
        if Game and Game.SendInfoText then Game.SendInfoText(key, false, 0, 3) end
    else
        if DummyInteraction and DummyInteraction.ToggleImmortal then
            DummyInteraction:ToggleImmortal()
        end
    end
end

function dummy_autoheal(enable)
    if not DummySpawner then return end
    if enable == nil or enable == "" then
        DummySpawner.autoHealWaiting = not DummySpawner.autoHealWaiting
    else
        local str = tostring(enable):lower()
        DummySpawner.autoHealWaiting = (str == "1" or str == "true" or str == "on")
    end
    local key = DummySpawner.autoHealWaiting and "ui_dummy_menu_opt3_on" or "ui_dummy_menu_opt3_off"
    if Game and Game.SendInfoText then
        Game.SendInfoText(key, false, 0, 3)
    end
end

------------------------------------------------------------
--  SCALEFORM ON-SCREEN MENU PANEL SYSTEM
------------------------------------------------------------

DummyPanel = DummyPanel or { isOpen = false, sel = 1 }

DummyPanel.items = {
    {
        label = "Spawn / Despawn",
        get = function() return DummySpawner.spawnedEntityId and "SPAWNED" or "DESPAWNED" end,
        action = function() DummySpawner:Toggle() end,
        desc = "Spawn or despawn Dumb Dumb NPC right in front of Henry."
    },
    {
        label = "Heal Dumb Dumb",
        get = function() return "Full (100%)" end,
        action = function() DummySpawner:Heal() end,
        desc = "Restore Dumb Dumb to 100% full health."
    },
    {
        label = "Immortal Mode",
        get = function() return (DummySpawner.isImmortal ~= false) and "ON" or "OFF" end,
        action = function() dummy_immortal() end,
        desc = "Toggle Dumb Dumb invulnerability on or off."
    },
    {
        label = "Auto-Heal (Wait)",
        get = function() return DummySpawner.autoHealWaiting and "ON" or "OFF" end,
        action = function() dummy_autoheal() end,
        desc = "Auto-heal Dumb Dumb when health is low in waiting mode."
    },
    {
        label = "Armor Preset",
        get = function()
            local names = { "Light", "Medium", "Heavy Full Plate" }
            return names[DummySpawner.currentPresetIdx or 1] or "Light"
        end,
        action = function() DummySpawner:NextPreset() end,
        desc = "Cycle Dumb Dumb's armor preset (Light -> Medium -> Heavy Full Plate)."
    },
    {
        label = "Hostile Mode",
        get = function() return DummySpawner.isHostile and "Hostile (Sparring)" or "Wait (Neutral)" end,
        action = function() DummySpawner:ToggleHostile() end,
        desc = "Toggle between stationary target (Wait) and sparring practice (Hostile)."
    },
    {
        label = "[ Close Menu ]",
        get = function() return "" end,
        action = function() DummyPanel:Close() end,
        desc = "Close the configuration panel menu."
    }
}

function DummyPanel:Render()
    if not self.isOpen then return end
    if self.sel < 1 then self.sel = #self.items end
    if self.sel > #self.items then self.sel = 1 end

    local parts = {}
    for i, it in ipairs(self.items) do
        local val = it.get and tostring(it.get()) or ""
        parts[i] = it.label .. "=" .. val
    end
    local desc = (self.items[self.sel] and self.items[self.sel].desc) or ""
    local rowsStr = table.concat(parts, "|")

    if UIAction and UIAction.CallFunction then
        pcall(function() UIAction.CallFunction("dummy_ui", "dummy_ui", "UiShow", 1) end)
        pcall(function() UIAction.CallFunction("dummy_ui", "dummy_ui", "UiRender", self.sel - 1, rowsStr, desc) end)
    end
end

function DummyPanel:Open()
    self.isOpen = true
    self.sel = 1
    if UIAction and UIAction.ShowElement then
        pcall(function() UIAction.ShowElement("dummy_ui", "dummy_ui") end)
    end
    self:Render()
end

function DummyPanel:Close()
    self.isOpen = false
    if UIAction and UIAction.CallFunction then
        pcall(function() UIAction.CallFunction("dummy_ui", "dummy_ui", "UiShow", 0) end)
    end
end

function DummyPanel:Toggle()
    if self.isOpen then self:Close() else self:Open() end
end

function DummyPanel:Nav(cmd)
    if not self.isOpen then return end
    if cmd == "up" then
        self.sel = self.sel - 1
        self:Render()
    elseif cmd == "down" then
        self.sel = self.sel + 1
        self:Render()
    elseif cmd == "select" or cmd == "enter" or cmd == "space" then
        local it = self.items[self.sel]
        if it and it.action then it.action() end
        self:Render()
    end
end

function dummy_menu()
    DummyPanel:Toggle()
end

function dummy_panel_up()     DummyPanel:Nav("up") end
function dummy_panel_down()   DummyPanel:Nav("down") end
function dummy_panel_select() DummyPanel:Nav("select") end

-- Register Console Commands
if System and System.AddCCommand then
    System.AddCCommand("dummy_spawn",        "dummy_spawn()",          "Toggle Dumb Dumb NPC spawn")
    System.AddCCommand("dummy",              "dummy_spawn()",          "Toggle Dumb Dumb NPC spawn (short alias)")
    System.AddCCommand("dummy_next",         "dummy_next()",           "Cycle to next armor preset")
    System.AddCCommand("dummy_prev",         "dummy_prev()",           "Cycle to previous armor preset")
    System.AddCCommand("dummy_preset",       "dummy_preset(%1)",       "Set specific armor preset (dummy_preset 1/2/3)")
    System.AddCCommand("dummy_bind",         "dummy_bind(%1)",         "Rebind spawn toggle hotkey (e.g. dummy_bind /)")
    System.AddCCommand("dummy_heal",         "dummy_heal()",           "Heal Dumb Dumb to full health")
    System.AddCCommand("dummy_immortal",     "dummy_immortal(%1)",     "Toggle Dumb Dumb invulnerability (dummy_immortal 1 / 0)")
    System.AddCCommand("dummy_autoheal",     "dummy_autoheal(%1)",     "Toggle auto-healing in waiting mode (dummy_autoheal 1 / 0)")
    System.AddCCommand("dummy_menu",         "dummy_menu()",           "Toggle Dumb Dumb On-Screen Menu Panel")
    System.AddCCommand("dummy_panel_up",     "dummy_panel_up()",       "Move menu selection up")
    System.AddCCommand("dummy_panel_down",   "dummy_panel_down()",     "Move menu selection down")
    System.AddCCommand("dummy_panel_select", "dummy_panel_select()",   "Select menu item")
end

-- Auto-bind default spawn hotkey (/) and menu hotkey (F3) on load
if DummySpawner and DummySpawner.BindKey then
    DummySpawner:BindKey(DummyConfig.spawnKey)
    if System and System.ExecuteCommand then
        System.ExecuteCommand("bind " .. (DummyConfig.menuKey or "f3") .. " dummy_menu")
    end
end

if System and System.LogAlways then
    System.LogAlways("[Dummy] === DUMMY.LUA LOADED SUCCESSFULLY ===")
end
