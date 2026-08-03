------------------------------------------------------------
--  dummy.lua  –  Dummy Mod Standalone Main Entry Point & Config
------------------------------------------------------------

if System and System.LogAlways then
    System.LogAlways("[Dummy] === LOADING DUMMY.LUA (STANDALONE) ===")
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
    else
        if System and System.LogAlways then
            System.LogAlways("[Dummy] Usage: dummy_preset <1|2|3>")
            System.LogAlways("[Dummy]   1 = Light Armor, 2 = Medium Armor, 3 = Heavy Full Plate")
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
    else
        if System and System.LogAlways then
            System.LogAlways("[Dummy] Current spawn key: " .. tostring(DummySpawner.KEYBIND_SPAWN or "/"))
            System.LogAlways("[Dummy] Usage: dummy_bind <key> (e.g. dummy_bind / or dummy_bind f6)")
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

function dummy_menu()
    local presetNames = { "1: Light", "2: Medium", "3: Heavy Full Plate" }
    local curPreset = presetNames[DummySpawner.currentPresetIdx or 1] or "1: Light"
    local hostileState = DummySpawner.isHostile and "HOSTILE (Sparring)" or "WAIT (Neutral)"
    local autoHealState = DummySpawner.autoHealWaiting and "ON" or "OFF"
    local immortalState = (DummySpawner.isImmortal ~= false) and "ON" or "OFF"
    local isSpawned = DummySpawner.spawnedEntityId and "SPAWNED" or "DESPAWNED"

    if System and System.LogAlways then
        System.LogAlways("[Dummy] ================= DUMB DUMB MOD (STANDALONE) =================")
        System.LogAlways("[Dummy]  Status:    " .. isSpawned)
        System.LogAlways("[Dummy]  Mode:      " .. hostileState)
        System.LogAlways("[Dummy]  Armor:     " .. curPreset)
        System.LogAlways("[Dummy]  Immortal:  " .. immortalState)
        System.LogAlways("[Dummy]  Auto-Heal: " .. autoHealState)
        System.LogAlways("[Dummy]  Hotkeys:")
        System.LogAlways("[Dummy]    [" .. tostring(DummySpawner.KEYBIND_SPAWN or "/") .. "]        - Spawn / Despawn Dumb Dumb")
        System.LogAlways("[Dummy]    [" .. tostring(DummyConfig.menuKey or "F3") .. "]       - Display Mod Status Overview")
        System.LogAlways("[Dummy]    E          - Tap E on target to cycle armor presets")
        System.LogAlways("[Dummy]    Hold V     - Hold V on target to toggle Hostile / Wait mode")
        System.LogAlways("[Dummy]  Commands:")
        System.LogAlways("[Dummy]    dummy_spawn      - Toggle spawn/despawn")
        System.LogAlways("[Dummy]    dummy_next       - Cycle to next armor preset")
        System.LogAlways("[Dummy]    dummy_prev       - Cycle to previous armor preset")
        System.LogAlways("[Dummy]    dummy_preset <N> - Set armor preset (1=Light, 2=Medium, 3=Heavy)")
        System.LogAlways("[Dummy]    dummy_heal       - Heal Dumb Dumb to 100% full health")
        System.LogAlways("[Dummy]    dummy_immortal   - Toggle immortality on / off")
        System.LogAlways("[Dummy]    dummy_autoheal   - Toggle auto-healing in waiting mode")
        System.LogAlways("[Dummy]    dummy_bind <key> - Rebind spawn key (e.g. dummy_bind /)")
        System.LogAlways("[Dummy] ===================================================================")
    end
    if Game and Game.SendInfoText then
        Game.SendInfoText("ui_dummy_menu_opened", false, 0, 4)
    end
end

-- Register Console Commands
if System and System.AddCCommand then
    System.AddCCommand("dummy_spawn",    "dummy_spawn()",       "Toggle Dumb Dumb NPC spawn")
    System.AddCCommand("dummy",          "dummy_spawn()",       "Toggle Dumb Dumb NPC spawn (short alias)")
    System.AddCCommand("dummy_next",     "dummy_next()",        "Cycle to next armor preset")
    System.AddCCommand("dummy_prev",     "dummy_prev()",        "Cycle to previous armor preset")
    System.AddCCommand("dummy_preset",   "dummy_preset(%1)",    "Set specific armor preset (dummy_preset 1/2/3)")
    System.AddCCommand("dummy_bind",     "dummy_bind(%1)",      "Rebind spawn toggle hotkey (e.g. dummy_bind /)")
    System.AddCCommand("dummy_heal",     "dummy_heal()",        "Heal Dumb Dumb to full health")
    System.AddCCommand("dummy_immortal", "dummy_immortal(%1)",  "Toggle Dumb Dumb invulnerability (dummy_immortal 1 / 0)")
    System.AddCCommand("dummy_autoheal", "dummy_autoheal(%1)",  "Toggle auto-healing in waiting mode (dummy_autoheal 1 / 0)")
    System.AddCCommand("dummy_menu",     "dummy_menu()",        "Display Dumb Dumb Mod status and commands")
    System.AddCCommand("dummy_help",     "dummy_menu()",        "Display Dumb Dumb Mod status and commands (alias)")
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
