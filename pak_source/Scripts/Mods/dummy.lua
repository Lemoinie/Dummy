------------------------------------------------------------
--  dummy.lua  –  Dummy Mod Entry Point & Dedicated On-Screen F3 Menu
------------------------------------------------------------

if System and System.LogAlways then
    System.LogAlways("[Dummy] === LOADING DUMMY.LUA ===")
end

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
        local keys = { "ui_dummy_menu_opt4_1", "ui_dummy_menu_opt4_2", "ui_dummy_menu_opt4_3" }
        if Game and Game.SendInfoText and keys[num] then
            Game.SendInfoText(keys[num], false, 0, 3)
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

function dummy_immortal()
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
        DummySpawner.autoHealWaiting = (str == "1" or str == "true" or str == "on")
    end
    local key = DummySpawner.autoHealWaiting and "ui_dummy_menu_opt3_on" or "ui_dummy_menu_opt3_off"
    if Game and Game.SendInfoText then
        Game.SendInfoText(key, false, 0, 3)
    end
end

------------------------------------------------------------
--  DEDICATED ON-SCREEN F3 MENU SYSTEM
------------------------------------------------------------

DummyMenu = DummyMenu or { isOpen = false, sel = 1 }

function DummyMenu:LockPlayer(lock)
    pcall(function()
        if ActionMapManager and ActionMapManager.EnableActionMap then
            ActionMapManager.EnableActionMap("player", not lock)
        end
    end)
end

function dummy_opt1()
    dummy_heal()
end

function dummy_opt2()
    dummy_immortal()
end

function dummy_opt3()
    dummy_autoheal()
end

function dummy_opt4()
    dummy_next()
    local idx = DummySpawner.currentPresetIdx or 1
    local keys = { "ui_dummy_menu_opt4_1", "ui_dummy_menu_opt4_2", "ui_dummy_menu_opt4_3" }
    if Game and Game.SendInfoText and keys[idx] then
        Game.SendInfoText(keys[idx], false, 0, 3)
    end
end

function dummy_opt5()
    if DummySpawner then
        DummySpawner:ToggleHostile()
        local key = DummySpawner.isHostile and "ui_dummy_menu_opt5_hostile" or "ui_dummy_menu_opt5_wait"
        if Game and Game.SendInfoText then
            Game.SendInfoText(key, false, 0, 3)
        end
    end
end

function dummy_opt6()
    if DummySpawner then
        dummy_spawn()
        local key = DummySpawner.spawnedEntityId and "ui_dummy_menu_opt6_spawn" or "ui_dummy_menu_opt6_despawn"
        if Game and Game.SendInfoText then
            Game.SendInfoText(key, false, 0, 3)
        end
    end
end

function dummy_opt0()
    dummy_menu_close()
end

function dummy_menu_close()
    DummyMenu.isOpen = false
    DummyMenu:LockPlayer(false)
    if Game and Game.SendInfoText then
        Game.SendInfoText("ui_dummy_menu_closed_msg", false, 0, 2)
    end
end

function dummy_menu()
    DummyMenu.isOpen = not DummyMenu.isOpen

    if DummyMenu.isOpen then
        DummyMenu:LockPlayer(true)

        -- Bind quick selection keys 1-6 and 0
        if System and System.ExecuteCommand then
            System.ExecuteCommand("bind 1 dummy_opt1")
            System.ExecuteCommand("bind 2 dummy_opt2")
            System.ExecuteCommand("bind 3 dummy_opt3")
            System.ExecuteCommand("bind 4 dummy_opt4")
            System.ExecuteCommand("bind 5 dummy_opt5")
            System.ExecuteCommand("bind 6 dummy_opt6")
            System.ExecuteCommand("bind 0 dummy_opt0")
        end

        if Game and Game.SendInfoText then
            Game.SendInfoText("ui_dummy_menu_opened", false, 0, 8)
        end
        if System and System.LogAlways then
            System.LogAlways("[Dummy] Dedicated On-Screen Menu Opened (F3). Player movement locked. Select 1-6 or 0.")
        end
    else
        dummy_menu_close()
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
    System.AddCCommand("dummy_menu",     "dummy_menu()",        "Toggle Dumb Dumb F3 Dedicated On-Screen Menu")
    System.AddCCommand("dummy_opt1",     "dummy_opt1()",        "Menu option 1: Heal")
    System.AddCCommand("dummy_opt2",     "dummy_opt2()",        "Menu option 2: Toggle Immortal")
    System.AddCCommand("dummy_opt3",     "dummy_opt3()",        "Menu option 3: Toggle AutoHeal")
    System.AddCCommand("dummy_opt4",     "dummy_opt4()",        "Menu option 4: Cycle Armor Preset")
    System.AddCCommand("dummy_opt5",     "dummy_opt5()",        "Menu option 5: Toggle Hostile Mode")
    System.AddCCommand("dummy_opt6",     "dummy_opt6()",        "Menu option 6: Toggle Spawn")
    System.AddCCommand("dummy_opt0",     "dummy_opt0()",        "Menu option 0: Close Menu")
end

-- Auto-bind default spawn hotkey (/) and menu hotkey (F3) on load
if DummySpawner and DummySpawner.BindKey then
    DummySpawner:BindKey()
end

if System and System.LogAlways then
    System.LogAlways("[Dummy] === DUMMY.LUA LOADED SUCCESSFULLY ===")
end
