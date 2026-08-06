------------------------------------------------------------
--  dummy.lua  –  Dummy Mod Startup (Command Registration)
------------------------------------------------------------

System.LogAlways("[Dummy] === LOADING STARTUP/DUMMY.LUA ===")

------------------------------------------------------------
--  REGISTER CONSOLE COMMANDS
------------------------------------------------------------
if System and System.AddCCommand then
    System.AddCCommand("dummy_spawn",    "dummy_spawn()",         "Toggle Dumb Dumb NPC spawn")
    System.AddCCommand("dummy",          "dummy_spawn()",         "Toggle Dumb Dumb NPC spawn (short alias)")
    System.AddCCommand("dummy_next",     "dummy_next()",          "Cycle to next armor preset")
    System.AddCCommand("dummy_prev",     "dummy_prev()",          "Cycle to previous armor preset")
    System.AddCCommand("dummy_preset",   "dummy_preset(%line)",   "Set specific armor preset (dummy_preset 1/2/3)")
    System.AddCCommand("dummy_mode",     "dummy_mode(%line)",     "Toggle Dumb Dumb mode (Wait vs Hostile)")
    System.AddCCommand("dummy_hostile",  "dummy_hostile(%line)",  "Toggle Dumb Dumb Hostile mode (alias for dummy_mode)")
    System.AddCCommand("dummy_bind",     "dummy_bind(%line)",     "Rebind spawn toggle hotkey (e.g. dummy_bind /)")
    System.AddCCommand("dummy_heal",     "dummy_heal()",          "Heal Dumb Dumb to full health")
    System.AddCCommand("dummy_immortal", "dummy_immortal(%line)", "Toggle Dumb Dumb invulnerability")
    System.AddCCommand("dummy_autoheal", "dummy_autoheal(%line)", "Toggle auto-healing in waiting mode")
    System.AddCCommand("dummy_status",   "dummy_status()",        "Display Dumb Dumb Mod status and command list")
    System.AddCCommand("dummy_info",     "dummy_info()",          "Display Dumb Dumb Mod status (alias)")
    System.AddCCommand("dummy_help",     "dummy_help()",          "Display Dumb Dumb Mod status (alias)")
    System.LogAlways("[Dummy] Console commands registered successfully.")
else
    System.LogAlways("[Dummy] WARNING: System.AddCCommand not available at boot!")
end

System.LogAlways("[Dummy] === STARTUP/DUMMY.LUA LOADED SUCCESSFULLY ===")
