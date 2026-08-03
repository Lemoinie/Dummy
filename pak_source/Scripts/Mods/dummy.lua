------------------------------------------------------------
--  dummy.lua  –  Dummy Mod Main Entry Point & Console Menu
------------------------------------------------------------

if System and System.LogAlways then
    System.LogAlways("[Dummy] === LOADING DUMMY.LUA ===")
end

-- Global Wrapper Functions for Console Commands
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
            Game.SendInfoText("Dumb Dumb healed to full health!", false, 0, 3)
        end
    end
end

function dummy_immortal(enable)
    if DummyInteraction and DummyInteraction.ToggleImmortal then
        DummyInteraction:ToggleImmortal()
    end
end

function dummy_autoheal(enable)
    if not DummySpawner then return end
    if enable == nil or enable == "" then
        DummySpawner.autoHealWaiting = not DummySpawner.autoHealWaiting
    else
        local str = tostring(enable):lower()
        if str == "1" or str == "true" or str == "on" then
            DummySpawner.autoHealWaiting = true
        else
            DummySpawner.autoHealWaiting = false
        end
    end
    local statusStr = DummySpawner.autoHealWaiting and "ENABLED" or "DISABLED"
    if System and System.LogAlways then
        System.LogAlways("[Dummy] Auto-heal in Waiting mode: " .. statusStr)
    end
    if Game and Game.SendInfoText then
        Game.SendInfoText("Dummy Auto-Heal: " .. statusStr, false, 0, 3)
    end
end

function dummy_menu()
    if System and System.LogAlways then
        System.LogAlways("[Dummy] ================= DUMB DUMB MOD MENU =================")
        System.LogAlways("[Dummy]  Hotkeys:")
        System.LogAlways("[Dummy]    [" .. tostring(DummySpawner.KEYBIND_SPAWN or "/") .. "]        - Spawn / Despawn Dumb Dumb")
        System.LogAlways("[Dummy]    E          - Tap E on Dumb Dumb to cycle armor presets")
        System.LogAlways("[Dummy]    Hold V     - Hold V on Dumb Dumb to toggle Hostile / Wait mode")
        System.LogAlways("[Dummy]  Console Commands:")
        System.LogAlways("[Dummy]    dummy_spawn      - Toggle spawn/despawn")
        System.LogAlways("[Dummy]    dummy_next       - Cycle to next armor preset")
        System.LogAlways("[Dummy]    dummy_prev       - Cycle to previous armor preset")
        System.LogAlways("[Dummy]    dummy_preset <N> - Set preset (1=Light, 2=Medium, 3=Heavy)")
        System.LogAlways("[Dummy]    dummy_heal       - Heal Dumb Dumb to 100% full health")
        System.LogAlways("[Dummy]    dummy_immortal   - Toggle immortality on / off")
        System.LogAlways("[Dummy]    dummy_autoheal   - Toggle auto-healing in waiting mode")
        System.LogAlways("[Dummy]    dummy_bind <key> - Rebind spawn key (e.g. dummy_bind /)")
        System.LogAlways("[Dummy] ========================================================")
    end
    if Game and Game.SendInfoText then
        Game.SendInfoText("Dummy Mod: Press ~ for console menu (dummy_menu)", false, 0, 4)
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
    System.AddCCommand("dummy_immortal", "dummy_immortal()",    "Toggle Dumb Dumb invulnerability on/off")
    System.AddCCommand("dummy_autoheal", "dummy_autoheal(%1)",  "Toggle auto-healing in waiting mode (dummy_autoheal 1 / 0)")
    System.AddCCommand("dummy_menu",     "dummy_menu()",        "Display Dumb Dumb mod commands & menu")
    System.AddCCommand("dummy_help",     "dummy_menu()",        "Display Dumb Dumb mod commands & menu (alias)")
    if System.LogAlways then
        System.LogAlways("[Dummy] Console commands registered: dummy_spawn, dummy, dummy_next, dummy_prev, dummy_preset, dummy_bind, dummy_heal, dummy_immortal, dummy_autoheal, dummy_menu")
    end
end

-- Auto-bind default spawn hotkey on load (default '/')
if DummySpawner and DummySpawner.BindKey then
    DummySpawner:BindKey()
end

if System and System.LogAlways then
    System.LogAlways("[Dummy] === DUMMY.LUA LOADED SUCCESSFULLY ===")
end
