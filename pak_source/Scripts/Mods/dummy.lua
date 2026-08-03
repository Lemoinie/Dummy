------------------------------------------------------------
--  dummy.lua  –  Dummy Mod Entry Point & Minimap Companion Menu Panel Integration
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
--  MINIMAP COMPANION MENU PANEL (version.dll) INTEGRATION
------------------------------------------------------------

function Dummy_InjectMinimapMenu()
    -- Initialize or hook into global minimap menu table read by version.dll
    _G.minimap = _G.minimap or {}
    local M = _G.minimap
    M.ui = M.ui or { open = false, menu = "main", sel = 1, stack = {} }
    M.menus = M.menus or {}

    -- Build Dumb Dumb Submenu definition
    local onoff = function(v) return v and "ON" or "OFF" end
    local dummyMenu = {
        { label = "< Back", back = true, desc = "Return to parent menu." },
        {
            label = "Spawn / Despawn",
            get = function() return DummySpawner.spawnedEntityId and "SPAWNED" or "DESPAWNED" end,
            change = function() DummySpawner:Toggle() end,
            desc = "Spawn or despawn Dumb Dumb NPC right in front of Henry."
        },
        {
            label = "Heal Dumb Dumb",
            action = function() DummySpawner:Heal() end,
            desc = "Restore Dumb Dumb to 100% full health."
        },
        {
            label = "Immortal Mode",
            get = function() return onoff(DummySpawner.isImmortal ~= false) end,
            change = function() if DummyInteraction and DummyInteraction.ToggleImmortal then DummyInteraction:ToggleImmortal() end end,
            desc = "Toggle Dumb Dumb invulnerability on or off."
        },
        {
            label = "Auto-Heal (Wait)",
            get = function() return onoff(DummySpawner.autoHealWaiting) end,
            change = function() dummy_autoheal() end,
            desc = "Auto-heal Dumb Dumb when health is low in waiting mode."
        },
        {
            label = "Armor Preset",
            get = function()
                local names = { "Light", "Medium", "Heavy Full Plate" }
                return names[DummySpawner.currentPresetIdx or 1] or "Light"
            end,
            change = function(dir)
                if dir and dir < 0 then DummySpawner:PrevPreset() else DummySpawner:NextPreset() end
            end,
            desc = "Cycle Dumb Dumb's armor preset (Light / Medium / Heavy Full Plate)."
        },
        {
            label = "Hostile Mode",
            get = function() return DummySpawner.isHostile and "Hostile (Sparring)" or "Wait (Neutral)" end,
            change = function() DummySpawner:ToggleHostile() end,
            desc = "Toggle between stationary target (Wait) and sparring practice (Hostile)."
        }
    }

    M.menus.dummy = dummyMenu

    -- Inject into main menu if present
    if M.menus.main then
        local exists = false
        for _, item in ipairs(M.menus.main) do
            if item.goto_ == "dummy" then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(M.menus.main, {
                label = "Dumb Dumb Mod",
                goto_ = "dummy",
                desc = "Configure Dumb Dumb NPC spawning, healing, immortality, and armor presets."
            })
        end
    else
        M.menus.main = {
            {
                label = "Dumb Dumb Mod",
                goto_ = "dummy",
                desc = "Configure Dumb Dumb NPC spawning, healing, immortality, and armor presets."
            }
        }
    end

    if System and System.LogAlways then
        System.LogAlways("[Dummy] Injected Dumb Dumb Mod options into Minimap Companion Panel (version.dll).")
    end
end

-- Try injecting immediately and retry after load
Dummy_InjectMinimapMenu()

function dummy_menu()
    -- Open or focus the minimap companion panel on F3
    if _G.minimap and _G.minimap.UiOpen then
        _G.minimap.UiOpen(true)
        if _G.minimap.UiEnter then
            _G.minimap.UiEnter("dummy")
        end
    else
        Dummy_InjectMinimapMenu()
        if _G.minimap and _G.minimap.UiOpen then
            _G.minimap.UiOpen(true)
        else
            if Game and Game.SendInfoText then
                Game.SendInfoText("ui_dummy_menu_opened", false, 0, 4)
            end
        end
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
    System.AddCCommand("dummy_menu",     "dummy_menu()",        "Toggle Dumb Dumb Minimap Companion Menu Panel")
end

-- Auto-bind default spawn hotkey (/) and menu hotkey (F3) on load
if DummySpawner and DummySpawner.BindKey then
    DummySpawner:BindKey()
end

if System and System.LogAlways then
    System.LogAlways("[Dummy] === DUMMY.LUA LOADED SUCCESSFULLY ===")
end
