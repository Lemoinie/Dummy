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

-- Register Console Commands
if System and System.AddCCommand then
    System.AddCCommand("dummy_spawn", "dummy_spawn()", "Toggle Dumb Dumb NPC spawn")
    System.AddCCommand("dummy",       "dummy_spawn()", "Toggle Dumb Dumb NPC spawn (short alias)")
    System.AddCCommand("dummy_next",  "dummy_next()",  "Cycle to next armor preset")
    System.AddCCommand("dummy_prev",  "dummy_prev()",  "Cycle to previous armor preset")
    if System.LogAlways then
        System.LogAlways("[Dummy] Console commands registered: dummy_spawn, dummy, dummy_next, dummy_prev")
    end
end

if System and System.LogAlways then
    System.LogAlways("[Dummy] === DUMMY.LUA LOADED SUCCESSFULLY ===")
end
