------------------------------------------------------------
--  dummy.lua  –  Dummy Mod Main Entry Point & Module Loader
------------------------------------------------------------

if System and System.LogAlways then
    System.LogAlways("[Dummy] === LOADING DUMMY.LUA ===")
end

-- Global Wrapper Functions for Console Commands
function dummy_spawn() DummySpawner:Toggle() end
function dummy_next()  DummySpawner:NextPreset() end
function dummy_prev()  DummySpawner:PrevPreset() end
function dummy()       DummySpawner:Toggle() end

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

-- Register Console Commands
if System and System.AddCCommand then
    System.AddCCommand("dummy_spawn",    "dummy_spawn()",       "Toggle Dumb Dumb NPC spawn")
    System.AddCCommand("dummy",          "dummy_spawn()",       "Toggle Dumb Dumb NPC spawn (short alias)")
    System.AddCCommand("dummy_next",     "dummy_next()",        "Cycle to next armor preset")
    System.AddCCommand("dummy_prev",     "dummy_prev()",        "Cycle to previous armor preset")
    System.AddCCommand("dummy_bind",     "dummy_bind(%1)",      "Rebind spawn toggle hotkey (e.g. dummy_bind /)")
    System.AddCCommand("dummy_heal",     "dummy_heal()",        "Heal Dumb Dumb to full health")
    System.AddCCommand("dummy_autoheal", "dummy_autoheal(%1)",  "Toggle auto-healing in waiting mode (dummy_autoheal 1 / 0)")
    if System.LogAlways then
        System.LogAlways("[Dummy] Console commands registered: dummy_spawn, dummy, dummy_next, dummy_prev, dummy_bind, dummy_heal, dummy_autoheal")
    end
end

-- Auto-bind default spawn hotkey on load (default '/')
if DummySpawner and DummySpawner.BindKey then
    DummySpawner:BindKey()
end

if System and System.LogAlways then
    System.LogAlways("[Dummy] === DUMMY.LUA LOADED SUCCESSFULLY ===")
end
