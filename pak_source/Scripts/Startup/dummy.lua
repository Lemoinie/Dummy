------------------------------------------------------------
--  dummy.lua  –  Dummy Mod for KCD2
------------------------------------------------------------

System.LogAlways("[Dummy] === LOADING DUMMY.LUA ===")

-------------------------------
-- Module table
-------------------------------
DummySpawner = DummySpawner or {}

-------------------------------
-- Configuration
-------------------------------
DummySpawner.SPAWN_DISTANCE    = 2.0          -- metres in front of player
DummySpawner.ENTITY_CLASS      = "NPC"        -- CryEngine entity class for human NPCs
DummySpawner.ENTITY_NAME       = "DummyNPC"   -- unique name
DummySpawner.LOG_PREFIX        = "[Dummy] "   -- log prefix
DummySpawner.KEYBIND_SPAWN     = "/"          -- default spawn/despawn hotkey

-------------------------------
-- State
-------------------------------
DummySpawner.spawnedEntityId   = nil          -- entityId of active dummy
DummySpawner.currentPresetIdx  = 1            -- active armor preset

------------------------------------------------------------
--  HELPERS
------------------------------------------------------------
function DummySpawner:BindKey(key)
    if key and key ~= "" then
        self.KEYBIND_SPAWN = key
    end
    local keyToBind = self.KEYBIND_SPAWN or "/"
    if System and System.ExecuteCommand then
        System.ExecuteCommand("bind " .. keyToBind .. " dummy_spawn")
        self:Log("Bound spawn hotkey to: " .. keyToBind)
    end
end

------------------------------------------------------------
--  ARMOR PRESETS  –  REAL KCD2 ITEM UUIDs
------------------------------------------------------------
DummySpawner.ArmorPresets = {
    -- 1 ▸ Light
    {
        name   = "Light Armor",
        slots  = {
            head   = "441e44c2-718d-c0bb-4c52-32ce88adda98",   -- Padded Coif
            body   = "46898847-2ffc-dcda-890e-8027524c2f91",   -- Aachen Short Gambeson
            legs   = "c6a66736-2f9e-4c0c-9def-4d6fd5906b82",   -- Padded Chausses
            gloves = "c8abe6d0-fbd8-49b2-a8e4-94e892aca6fa",   -- Riding Gloves
            boots  = "40692480-f24c-54fa-c938-50ccf45918b9",   -- Nobleman's Boots
        },
    },
    -- 2 ▸ Medium
    {
        name   = "Medium Armor",
        slots  = {
            head   = "25054826-ae61-4599-a070-c8ea6248e616",   -- Brunswick's Chainmail Coif
            body   = "413806e7-f3b7-c6cf-2309-e47ce3c97fa2",   -- Hauberk
            legs   = "c6a66736-2f9e-4c0c-9def-4d6fd5906b82",   -- Padded Chausses
            gloves = "c052fb20-9f20-4ebd-8b7f-8ff937ee11b0",   -- Brunswick's Gauntlets
            boots  = "40692480-f24c-54fa-c938-50ccf45918b9",   -- Nobleman's Boots
        },
    },
    -- 3 ▸ Heavy
    {
        name   = "Heavy Armor (Brunswick)",
        slots  = {
            head   = "157697b8-f618-4856-aea2-3b3cba06c1d6",   -- Brunswick's Bascinet
            body   = "8f0afc06-e359-4371-b1ce-a312f5d4aa64",   -- Brunswick's Brigandine
            legs   = "96981577-61e6-4e10-bb01-c3cb879aa920",   -- Brunswick's Plate Leg Armor
            gloves = "c052fb20-9f20-4ebd-8b7f-8ff937ee11b0",   -- Brunswick's Gauntlets
            boots  = "40692480-f24c-54fa-c938-50ccf45918b9",   -- Nobleman's Boots
        },
    },
    -- 4 ▸ Civilian
    {
        name   = "Civilian Outfit",
        slots  = {
            head   = nil,
            body   = "08b22db7-f612-40a3-b7b0-351a731bf5e0",   -- Capon's Gambeson
            legs   = "4187ee7a-4331-8224-4853-0d071256b7ad",   -- Blue Hose
            gloves = nil,
            boots  = "40692480-f24c-54fa-c938-50ccf45918b9",   -- Nobleman's Boots
        },
    },
    -- 5 ▸ Noble
    {
        name   = "Noble Attire",
        slots  = {
            head   = nil,
            body   = "a7fe9db7-83d6-460c-a0d8-64b67355ace6",   -- Noble Gambeson
            legs   = "4181c649-2642-3d6c-7eb4-6c09f74dbe8d",   -- Decorated Blue Hose
            gloves = "c8abe6d0-fbd8-49b2-a8e4-94e892aca6fa",   -- Riding Gloves
            boots  = "40692480-f24c-54fa-c938-50ccf45918b9",   -- Nobleman's Boots
        },
    },
}

------------------------------------------------------------
--  UTILITY HELPERS
------------------------------------------------------------

function DummySpawner:Log(msg)
    System.LogAlways(self.LOG_PREFIX .. tostring(msg))
end

function DummySpawner:GetPlayer()
    local pl = nil
    if player then
        pl = player
    elseif g_localActor then
        pl = g_localActor
    elseif Game and Game.GetPlayer then
        pl = Game.GetPlayer()
    elseif System and System.GetEntityByName then
        pl = System.GetEntityByName("yourPlayer")
             or System.GetEntityByName("intPlayer")
             or System.GetEntityByName("intHenry")
    end
    return pl
end

function DummySpawner:GetPosInFront(entity, dist)
    local pos = entity:GetWorldPos and entity:GetWorldPos() or entity:GetPos()
    local dir
    if entity.GetDirectionVector then
        dir = entity:GetDirectionVector()
    elseif entity.GetDir then
        dir = entity:GetDir()
    else
        dir = { x = 0, y = 1, z = 0 }
    end

    local spawnPos = {
        x = pos.x + dir.x * dist,
        y = pos.y + dir.y * dist,
        z = pos.z + dir.z * dist,
    }
    local facingDir = {
        x = -dir.x,
        y = -dir.y,
        z = -dir.z,
    }
    return spawnPos, facingDir
end

------------------------------------------------------------
--  SPAWN / DESPAWN
------------------------------------------------------------

function DummySpawner:Spawn()
    if self.spawnedEntityId then
        self:Log("Dummy already exists – despawning first.")
        self:Despawn()
    end

    local pl = self:GetPlayer()
    if not pl then
        self:Log("ERROR: Could not find player entity.")
        return
    end

    local spawnPos, facingDir = self:GetPosInFront(pl, self.SPAWN_DISTANCE)

    local spawnParams        = {}
    spawnParams.class        = self.ENTITY_CLASS
    spawnParams.name         = self.ENTITY_NAME
    spawnParams.position     = spawnPos
    spawnParams.orientation  = facingDir
    spawnParams.scale        = { x = 1, y = 1, z = 1 }
    spawnParams.properties   = {
        bAutoDisable  = 0,
    }

    local entity = System.SpawnEntity(spawnParams)
    if not entity then
        self:Log("ERROR: System.SpawnEntity returned nil.")
        return
    end

    self.spawnedEntityId = entity.id
    self:Log("Spawned dummy (id=" .. tostring(entity.id) .. ") at "
             .. string.format("%.1f, %.1f, %.1f", spawnPos.x, spawnPos.y, spawnPos.z))

    if entity.actor and entity.actor.SetBrainVariable then
        entity.actor:SetBrainVariable("Alertness", 0)
    end
    if AI and AI.SetBehaviorVariable then
        AI.SetBehaviorVariable(entity.id, "Alertness",    0)
        AI.SetBehaviorVariable(entity.id, "IsHostile",    0)
        AI.SetBehaviorVariable(entity.id, "CombatTarget", 0)
    end

    self.currentPresetIdx = 1
    self:ApplyPreset(self.currentPresetIdx)
end

function DummySpawner:Despawn()
    if not self.spawnedEntityId then
        self:Log("No dummy to despawn.")
        return
    end
    System.RemoveEntity(self.spawnedEntityId)
    self:Log("Despawned dummy (id=" .. tostring(self.spawnedEntityId) .. ").")
    self.spawnedEntityId  = nil
    self.currentPresetIdx = 1
end

function DummySpawner:Toggle()
    if self.spawnedEntityId then
        self:Despawn()
    else
        self:Spawn()
    end
end

------------------------------------------------------------
--  ARMOR PRESETS
------------------------------------------------------------

function DummySpawner:StripEquipment(entity)
    if not entity or not entity.inventory then
        self:Log("WARNING: Entity has no inventory component – cannot strip.")
        return
    end
    local slotNames = { "head", "body", "legs", "gloves", "boots", "outer",
                        "weapon_melee", "weapon_ranged", "shield" }
    for _, slot in ipairs(slotNames) do
        if entity.inventory.UnequipSlot then
            entity.inventory:UnequipSlot(slot)
        end
    end
    if entity.inventory.ClearAll then
        entity.inventory:ClearAll()
    end
end

function DummySpawner:EquipItem(entity, slot, itemId)
    if not entity or not entity.inventory then
        self:Log("WARNING: Entity has no inventory – cannot equip " .. tostring(itemId))
        return
    end

    if entity.inventory.CreateItem then
        entity.inventory:CreateItem(itemId, 1.0, 1)
    elseif entity.inventory.AddItem then
        entity.inventory:AddItem(itemId)
    else
        self:Log("WARNING: No CreateItem/AddItem method on inventory.")
        return
    end

    if entity.inventory.EquipItem then
        entity.inventory:EquipItem(itemId, slot)
    elseif entity.inventory.SetSlot then
        entity.inventory:SetSlot(slot, itemId)
    end
end

function DummySpawner:ApplyPreset(index)
    local preset = self.ArmorPresets[index]
    if not preset then
        self:Log("ERROR: Preset index " .. tostring(index) .. " does not exist.")
        return
    end

    local entity = System.GetEntity(self.spawnedEntityId)
    if not entity then
        self:Log("ERROR: Dummy entity not found.")
        self.spawnedEntityId = nil
        return
    end

    self:Log("Applying preset: " .. preset.name)
    self:StripEquipment(entity)
    for slot, itemId in pairs(preset.slots) do
        if itemId then
            self:EquipItem(entity, slot, itemId)
        end
    end
    self:Log("Preset '" .. preset.name .. "' applied successfully.")
end

function DummySpawner:NextPreset()
    if not self.spawnedEntityId then
        self:Log("Spawn a dummy first (dummy_spawn).")
        return
    end
    self.currentPresetIdx = (self.currentPresetIdx % #self.ArmorPresets) + 1
    self:ApplyPreset(self.currentPresetIdx)
end

function DummySpawner:PrevPreset()
    if not self.spawnedEntityId then
        self:Log("Spawn a dummy first (dummy_spawn).")
        return
    end
    self.currentPresetIdx = self.currentPresetIdx - 1
    if self.currentPresetIdx < 1 then
        self.currentPresetIdx = #self.ArmorPresets
    end
    self:ApplyPreset(self.currentPresetIdx)
end

------------------------------------------------------------
--  GLOBAL WRAPPER FUNCTIONS FOR CONSOLE COMMANDS
------------------------------------------------------------
function dummy_spawn()
    DummySpawner:Toggle()
end

function dummy_next()
    DummySpawner:NextPreset()
end

function dummy_prev()
    DummySpawner:PrevPreset()
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

------------------------------------------------------------
--  REGISTER CONSOLE COMMANDS
------------------------------------------------------------
if System and System.AddCCommand then
    System.AddCCommand("dummy_spawn",    "dummy_spawn()",       "Toggle Dummy NPC spawn")
    System.AddCCommand("dummy",          "dummy_spawn()",       "Toggle Dummy NPC spawn (short alias)")
    System.AddCCommand("dummy_next",     "dummy_next()",        "Cycle to next armor preset")
    System.AddCCommand("dummy_prev",     "dummy_prev()",        "Cycle to previous armor preset")
    System.AddCCommand("dummy_bind",     "dummy_bind(%1)",      "Rebind spawn toggle hotkey (e.g. dummy_bind /)")
    System.AddCCommand("dummy_heal",     "dummy_heal()",        "Heal Dumb Dumb to full health")
    System.AddCCommand("dummy_autoheal", "dummy_autoheal(%1)",  "Toggle auto-healing in waiting mode (dummy_autoheal 1 / 0)")
    System.LogAlways("[Dummy] Console commands registered: dummy_spawn, dummy, dummy_next, dummy_prev, dummy_bind, dummy_heal, dummy_autoheal")
else
    System.LogAlways("[Dummy] WARNING: System.AddCCommand not available at boot!")
end

-- Auto-bind default spawn hotkey on load (default '/')
if DummySpawner and DummySpawner.BindKey then
    DummySpawner:BindKey()
end

System.LogAlways("[Dummy] === DUMMY.LUA LOADED SUCCESSFULLY ===")
