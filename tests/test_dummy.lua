-- tests/test_dummy.lua
-- Standalone Lua test harness for Dummy Mod

local passed_tests = 0
local failed_tests = 0

function assert(condition, message)
    if not condition then
        print("FAIL: " .. (message or "Assertion failed"))
        failed_tests = failed_tests + 1
    else
        print("PASS: " .. (message or "Assertion passed"))
        passed_tests = passed_tests + 1
    end
end

-- 1. Mock CryEngine globals
System = {
    spawn_called = false,
    remove_called = false,
    last_spawn_params = nil,
    last_removed_id = nil,
    entities = {},
    
    LogAlways = function(msg) end,
    
    SpawnEntity = function(params)
        System.spawn_called = true
        System.last_spawn_params = params
        local ent = {
            id = 1234,
            GetName = function(self) return params.name end,
            SetName = function(self, name) self.name = name end,
            GetPos = function() return {x=0,y=0,z=0} end,
            Properties = { Health = { hp = 100, max_hp = 100 } },
            soul = {
                SetFaction = function(f) end,
                SetHostile = function(h) end,
                SetCrimeIgnored = function(c) end,
                SetTarget = function(t) end,
                SetState = function(self, k, v) end,
                Heal = function(self, maxHp) end,
                RemoveAllBleeding = function(self) end,
                GetState = function(self, k) return 100 end,
            },
            actor = {
                SetHealth = function(self, hp) end,
                EquipWeaponPreset = function(self, p) end,
                SetInvulnerable = function(self, b) end,
                SetLootable = function(self, b) end,
            }
        }
        System.entities[1234] = ent
        return ent
    end,
    
    GetEntity = function(id)
        return System.entities[id]
    end,
    
    GetEntityByName = function(name)
        for _, e in pairs(System.entities) do
            if e.name == name then return e end
        end
        return nil
    end,
    
    RemoveEntity = function(id)
        System.remove_called = true
        System.last_removed_id = id
        System.entities[id] = nil
    end
}

Game = {
    GetPlayer = function()
        return {
            id = 999,
            GetPos = function() return {x=0,y=0,z=0} end,
            GetDir = function() return {x=0,y=1,z=0} end
        }
    end,
    SendInfoText = function(msg) end
}

AI = {
    last_mode = nil,
    last_behavior_var = {},
    
    ChangeFaction = function(id, faction) end,
    SetBehaviorVariable = function(id, name, value)
        if name == "IsHostile" then
            AI.last_mode = (value == 1) and "hostile" or "wait"
        end
        AI.last_behavior_var[name] = value
    end
}

Script = {
    SetTimerForFunction = function(time, func, arg) end
}

DummyEquipment = {
    ArmorPresets = { {}, {}, {} },
    ApplyPreset = function(self, entId, idx)
        DummyEquipment.last_applied_preset = idx
    end
}

-- 2. Load the script
dofile("pak_source/Scripts/Mods/dummy_spawning.lua")

-- 3. Tests

function test_spawn()
    print("--- Running test_spawn ---")
    System.spawn_called = false
    DummySpawner:Spawn()
    assert(System.spawn_called == true, "System.SpawnEntity should be called")
    assert(DummySpawner.spawnedEntityId == 1234, "Dummy entity reference should be stored")
end

function test_change_preset()
    print("--- Running test_change_preset ---")
    DummySpawner.spawnedEntityId = 1234
    DummySpawner.currentPresetIdx = 1
    DummySpawner:NextPreset()
    assert(DummyEquipment.last_applied_preset == 2, "NextPreset should apply preset 2")
    assert(DummySpawner.currentPresetIdx == 2, "Current preset index should update")
end

function test_mode_hostile()
    print("--- Running test_mode_hostile ---")
    DummySpawner.spawnedEntityId = 1234
    DummySpawner:SetHostileState(true)
    assert(AI.last_mode == "hostile", "AI mode should be set to hostile (IsHostile=1)")
    assert(DummySpawner.isHostile == true, "DummySpawner state should be hostile")
end

function test_mode_wait()
    print("--- Running test_mode_wait ---")
    DummySpawner.spawnedEntityId = 1234
    DummySpawner:SetHostileState(false)
    assert(AI.last_mode == "wait", "AI mode should be set to wait (IsHostile=0)")
    assert(DummySpawner.isHostile == false, "DummySpawner state should be wait")
end

function test_heal()
    print("--- Running test_heal ---")
    DummySpawner.spawnedEntityId = 1234
    local ent = System.GetEntity(1234)
    ent.Properties.Health.hp = 10 -- simulate damage
    DummySpawner:Heal()
    assert(ent.Properties.Health.hp == 100, "Dummy health should be restored to 100")
end

function test_regression_no_save_persistence()
    print("--- Running test_regression_no_save_persistence ---")
    assert(DummySaving == nil, "DummySaving module should not exist")
    assert(DummySpawner.RestoreFromSave == nil, "RestoreFromSave method should be removed")
    assert(DummySpawner.MonitorLoop == nil, "MonitorLoop method should be removed")
    assert(DummySpawner.FindSavedDummy == nil, "FindSavedDummy method should be removed")
end

-- Run all tests
test_spawn()
test_change_preset()
test_mode_hostile()
test_mode_wait()
test_heal()
test_regression_no_save_persistence()

print("==================================")
print("TEST SUMMARY: " .. passed_tests .. " PASSED, " .. failed_tests .. " FAILED")
if failed_tests > 0 then
    os.exit(1)
else
    os.exit(0)
end
