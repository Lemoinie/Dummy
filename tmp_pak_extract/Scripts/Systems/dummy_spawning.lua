------------------------------------------------------------
--  dummy_spawning.lua  â€“  Spawning & Stationary AI Logic
------------------------------------------------------------

DummySpawner = DummySpawner or {}

DummySpawner.SPAWN_DISTANCE    = 2.0
DummySpawner.ENTITY_CLASS      = "NPC"
DummySpawner.LOG_PREFIX        = "[Dummy] "
DummySpawner.KEYBIND_SPAWN     = nil          -- no default hotkey bound

-- Custom Dumb Dumb Soul GUID (dummyFaction, social_class_id=0, no reputation penalty)
DummySpawner.SOUL_GUID         = "a1b2c3d4-0003-4000-8000-100000000003"

DummySpawner.spawnedEntityId   = nil
DummySpawner.currentPresetIdx  = 1
DummySpawner.isHostile         = false
DummySpawner.isImmortal        = true          -- NPC is immortal by default (bInvulnerable=true at spawn)
DummySpawner.autoHealWaiting   = true         -- Auto-heal NPC in waiting mode if health is low

------------------------------------------------------------
--  HELPERS
------------------------------------------------------------

function DummySpawner:Log(msg)
    if System and System.LogAlways then
        System.LogAlways(self.LOG_PREFIX .. tostring(msg))
    end
end

function DummySpawner:BindKey(key)
    if key and key ~= "" and key ~= "none" and key ~= "off" then
        self.KEYBIND_SPAWN = key
        if System and System.ExecuteCommand then
            System.ExecuteCommand("bind " .. key .. " dummy_spawn")
            self:Log("Bound spawn hotkey to: " .. key)
        end
    end
end

------------------------------------------------------------
--  HEALING LOGIC
------------------------------------------------------------

function DummySpawner:Heal(entity)
    entity = entity or (self.spawnedEntityId and System.GetEntity(self.spawnedEntityId))
    if not entity then
        self:Log("No active dummy to heal.")
        return
    end

    self:Log("Healing Dumb Dumb to full health...")

    -- 1. Restore soul health & state values
    if entity.soul then
        pcall(function()
            local maxHp = 100
            if entity.soul.GetState then
                local currentMax = entity.soul:GetState("health_max") or entity.soul:GetState("max_health")
                if currentMax and currentMax > 0 then maxHp = currentMax end
            end
            if entity.soul.SetState then
                entity.soul:SetState("health", maxHp)
            end
            if entity.soul.Heal then
                entity.soul:Heal(maxHp)
            end
            if entity.soul.RemoveAllBleeding then
                entity.soul:RemoveAllBleeding()
            end
        end)
    end

    -- 2. Restore actor health
    pcall(function()
        if entity.actor and entity.actor.SetHealth then
            entity.actor:SetHealth(100)
        end
        if entity.SetHealth then
            entity:SetHealth(100)
        end
    end)

    -- 3. Restore entity properties health
    pcall(function()
        if entity.Properties and entity.Properties.Health then
            entity.Properties.Health.hp = entity.Properties.Health.max_hp or 100
        end
    end)
end

function DummySpawner:GetPlayer()
    if player then return player end
    if g_localActor then return g_localActor end
    if Game and Game.GetPlayer then return Game.GetPlayer() end
    return nil
end

function DummySpawner:GetPosInFront(entity, dist)
    local pos = entity.GetWorldPos and entity:GetWorldPos() or entity:GetPos()
    local dir
    if entity.GetDirectionVector then
        dir = entity:GetDirectionVector()
    elseif entity.GetDir then
        dir = entity:GetDir()
    else
        dir = { x = 0, y = 1, z = 0 }
    end
    return {
        x = pos.x + dir.x * dist,
        y = pos.y + dir.y * dist,
        z = pos.z,
    }, {
        x = -dir.x,
        y = -dir.y,
        z = -dir.z,
    }
end

------------------------------------------------------------
--  STATE TOGGLING (Wait vs Hostile - key V)
------------------------------------------------------------
function DummySpawner:SetHostileState(hostile)
    self.isHostile = hostile
    local entity = (self.spawnedEntityId and System and System.GetEntity) and System.GetEntity(self.spawnedEntityId) or nil
    if not entity then return end

    local pl = self:GetPlayer()
    local targetId = pl and (pl.this and pl.this.id or pl.id) or nil

    if hostile then
        self:Log("Dumb Dumb is now HOSTILE!")
        if entity.soul then
            pcall(function() entity.soul:SetFaction("dummyFaction") end)
            pcall(function() entity.soul:SetHostile(true) end)
            pcall(function() entity.soul:SetCrimeIgnored(true) end)
            if targetId then
                pcall(function() entity.soul:SetTarget(targetId) end)
            end
        end
        if AI and AI.ChangeFaction then
            pcall(function() AI.ChangeFaction(entity.id, "dummyFaction") end)
        end
        pcall(function() entity.soul:SetState("health", 100) end)
        pcall(function() entity.soul:SetState("stamina", 100) end)
        if AI and AI.SetBehaviorVariable then
            pcall(function() AI.SetBehaviorVariable(entity.id, "IsHostile", true) end)
            pcall(function() AI.SetBehaviorVariable(entity.id, "isHostile", true) end)
            pcall(function() AI.SetBehaviorVariable(entity.id, "IsHostile", 1) end)
            pcall(function() AI.SetBehaviorVariable(entity.id, "isHostile", 1) end)
            if targetId then
                pcall(function() AI.SetBehaviorVariable(entity.id, "playerWUID", targetId) end)
                pcall(function() AI.SetBehaviorVariable(entity.id, "CombatTarget", targetId) end)
            end
        end
        if entity.actor and entity.actor.SetBrainVariable then
            pcall(function() entity.actor:SetBrainVariable("isHostile", true) end)
            if targetId then
                pcall(function() entity.actor:SetBrainVariable("CombatTarget", targetId) end)
            end
        end
        if Game and Game.SendInfoText then
            Game.SendInfoText("ui_dummy_info_hostile", false, 0, 3)
        end
    else
        self:Log("Dumb Dumb is now WAITING (Neutral).")
        if entity.soul then
            pcall(function() entity.soul:SetTarget(nil) end)
            pcall(function() entity.soul:SetHostile(false) end)
            pcall(function() entity.soul:SetCrimeIgnored(true) end)
            pcall(function() entity.soul:SetFaction("dummyFaction") end)
        end
        if AI and AI.ChangeFaction then
            pcall(function() AI.ChangeFaction(entity.id, "dummyFaction") end)
        end
        if AI and AI.SetBehaviorVariable then
            pcall(function() AI.SetBehaviorVariable(entity.id, "IsHostile", false) end)
            pcall(function() AI.SetBehaviorVariable(entity.id, "isHostile", false) end)
            pcall(function() AI.SetBehaviorVariable(entity.id, "IsHostile", 0) end)
            pcall(function() AI.SetBehaviorVariable(entity.id, "isHostile", 0) end)
            pcall(function() AI.SetBehaviorVariable(entity.id, "CombatTarget", 0) end)
        end
        if entity.actor and entity.actor.SetBrainVariable then
            pcall(function() entity.actor:SetBrainVariable("isHostile", false) end)
        end
        -- Auto-heal NPC in Waiting mode if option is enabled
        if self.autoHealWaiting then
            self:Heal(entity)
        end
        if Game and Game.SendInfoText then
            Game.SendInfoText("ui_dummy_info_waiting", false, 0, 3)
        end
    end

end

function DummySpawner:ToggleHostile()
    self:SetHostileState(not self.isHostile)
end

------------------------------------------------------------
--  FREEZE AI â€“ called immediately after spawn AND on a timer
------------------------------------------------------------

function DummySpawner:FreezeEntity(entity)
    if not entity then return end

    -- Disable flee / crime contexts on soul
    if entity.soul then
        pcall(function() entity.soul:SetScriptContext("combat_flee",              false) end)
        pcall(function() entity.soul:SetScriptContext("crime_interruptFlee",      false) end)
        pcall(function() entity.soul:SetScriptContext("crime_fleeAfterSurrender", false) end)
        pcall(function() entity.soul:SetCrimeIgnored(true) end)
        pcall(function() entity.soul:SetLootable(false) end)
        pcall(function() entity.soul:SetCanBeLooted(false) end)
        pcall(function() entity.soul:SetFaction("dummyFaction") end)
    end

    -- Unlootable & non-searchable flags
    if entity.actor then
        pcall(function() entity.actor:SetLootable(false) end)
    end

    -- Invulnerability flags (prevents death / HP change event triggering panic)
    local makeImmortal = (DummySpawner.isImmortal ~= false)
    if entity.SetInvulnerability then
        pcall(function() entity:SetInvulnerability(makeImmortal) end)
    end
    if entity.actor then
        pcall(function() entity.actor:SetInvulnerable(makeImmortal) end)
    end
    entity.invulnerable = makeImmortal
    if entity.Properties then
        entity.Properties.bInvulnerable = makeImmortal
        entity.Properties.bLootable = false
        entity.Properties.bCanBeLooted = false
        entity.Properties.bDisableLoot = true
        entity.Properties.bSearchable = false
        if entity.Properties.Health then
            entity.Properties.Health.bInvulnerable = makeImmortal
        end
    end
end

------------------------------------------------------------
--  SET NAME
------------------------------------------------------------

function DummySpawner:ApplyName(entity)
    if not entity then return end
    pcall(function() entity:SetName("Dumb Dumb") end)
    if entity.Properties then
        entity.Properties.sName    = "Dumb Dumb"
        entity.Properties.soc_name = "Dumb Dumb"
    end
    if entity.soul then
        pcall(function() entity.soul:SetCustomName("Dumb Dumb") end)
        pcall(function() entity.soul:SetUIName("Dumb Dumb") end)
    end
    if entity.actor then
        pcall(function() entity.actor:SetName("Dumb Dumb") end)
    end
end

------------------------------------------------------------
--  FACTION
------------------------------------------------------------

function DummySpawner:ApplyFaction(entity)
    if not entity then return end
    local faction = self.isHostile and "bandit" or "dummyFaction"
    if AI and AI.ChangeFaction then
        pcall(function() AI.ChangeFaction(entity.id, faction) end)
    end
    if entity.soul then
        pcall(function() entity.soul:SetFaction(faction) end)
        pcall(function() entity.soul:SetCrimeIgnored(true) end)
    end
end

------------------------------------------------------------
--  SPAWN / DESPAWN
------------------------------------------------------------

function DummySpawner:Spawn()
    if self.spawnedEntityId and System and System.GetEntity and System.GetEntity(self.spawnedEntityId) then
        self:Log("Dummy already active â€“ despawning first.")
        self:Despawn()
    end

    local pl = self:GetPlayer()
    if not pl then
        self:Log("ERROR: Could not find player entity.")
        if Game and Game.SendInfoText then
            Game.SendInfoText("Dummy Spawn Error: Player not found", false, 0, 3)
        end
        return
    end

    local spawnPos, facingDir = self:GetPosInFront(pl, self.SPAWN_DISTANCE)
    local entityName = "DummyTarget_DumbDumb_Unique"

    self.isHostile = false

    local ok = pcall(function()
        System.SpawnEntity({
            class       = self.ENTITY_CLASS,
            name        = entityName,
            position    = spawnPos,
            orientation = facingDir,
            Properties  = {
                guidSharedSoulId        = self.SOUL_GUID,
                guidBrainId             = "a1b2c3d4-0001-4000-8000-100000000001",  -- dummy_brain
                sWH_AI_EntityCategory   = "dummyFaction",
                bWH_PerceptorObject     = true,
                bWH_PerceptibleObject   = true,
                bInvulnerable           = true,
            }
        })
    end)

    local entity = System.GetEntityByName and System.GetEntityByName(entityName)
    if not entity then
        self:Log("ERROR: System.SpawnEntity returned nil.")
        if Game and Game.SendInfoText then
            Game.SendInfoText("Dummy Spawn Failed!", false, 0, 3)
        end
        return
    end

    self.spawnedEntityId = entity.id
    self:Log("Spawned Dumb Dumb (id=" .. tostring(entity.id) .. ")")

    -- Equip a training sword so Dumb Dumb can attack when Hostile
    pcall(function()
        if entity.actor and entity.actor.EquipWeaponPreset then
            entity.actor:EquipWeaponPreset("94600b75-8cd2-42f5-8a85-9e5ad0db8318")
        end
    end)

    -- Apply immediately
    self:ApplyName(entity)
    self:ApplyFaction(entity)
    self:FreezeEntity(entity)

    -- Deferred re-apply using named function
    if Script and Script.SetTimerForFunction then
        pcall(function() Script.SetTimerForFunction(500, "DummySpawner.DelayedSpawnFinish", entity.id) end)
    end

    -- Inject interaction prompt
    if DummyInteraction and DummyInteraction.Inject then
        DummyInteraction:Inject(entity)
    end

    -- Apply initial armor preset
    DummyEquipment:ApplyPreset(self.spawnedEntityId, self.currentPresetIdx)

    if Game and Game.SendInfoText then
        Game.SendInfoText("ui_dummy_spawned", false, 0, 3)
    end
end

function DummySpawner:Despawn()
    local entity = (self.spawnedEntityId and System and System.GetEntity) and System.GetEntity(self.spawnedEntityId) or nil

    if not entity then
        self:Log("No active dummy to despawn.")
        self.spawnedEntityId = nil
        return
    end

    pcall(function()
        System.RemoveEntity(self.spawnedEntityId)
    end)

    self:Log("Despawned Dumb Dumb.")
    self.spawnedEntityId  = nil
    self.currentPresetIdx = 1
    self.isHostile        = false
    self.isImmortal       = true

    if Game and Game.SendInfoText then
        Game.SendInfoText("ui_dummy_despawned", false, 0, 3)
    end
end

function DummySpawner:Toggle()
    local isSpawned = (self.spawnedEntityId and System and System.GetEntity and System.GetEntity(self.spawnedEntityId))
    if isSpawned then
        self:Despawn()
    else
        self:Spawn()
    end
end

------------------------------------------------------------
--  DELAYED SPAWN FINISH
------------------------------------------------------------

function DummySpawner.DelayedSpawnFinish(entID)
    local entity = (entID and System and System.GetEntity) and System.GetEntity(entID) or nil
    if entity then
        DummySpawner:ApplyName(entity)
        DummySpawner:FreezeEntity(entity)
        if DummyInteraction and DummyInteraction.Inject then
            DummyInteraction:Inject(entity)
        end
    end
end

------------------------------------------------------------
--  PRESET CYCLING
------------------------------------------------------------

function DummySpawner:NextPreset()
    if not self.spawnedEntityId then
        self:Log("Spawn a dummy first.")
        return
    end
    self.currentPresetIdx = (self.currentPresetIdx % #DummyEquipment.ArmorPresets) + 1
    DummyEquipment:ApplyPreset(self.spawnedEntityId, self.currentPresetIdx)
end

function DummySpawner:PrevPreset()
    if not self.spawnedEntityId then
        self:Log("Spawn a dummy first.")
        return
    end
    self.currentPresetIdx = self.currentPresetIdx - 1
    if self.currentPresetIdx < 1 then
        self.currentPresetIdx = #DummyEquipment.ArmorPresets
    end
    DummyEquipment:ApplyPreset(self.spawnedEntityId, self.currentPresetIdx)
end

function DummySpawner:DebugAI()
    local entity = (self.spawnedEntityId and System and System.GetEntity) and System.GetEntity(self.spawnedEntityId) or nil
    if not entity then
        self:Log("DebugAI: No active dummy entity found.")
        return
    end

    self:Log("=== DUMMY AI DEBUG ===")
    self:Log("Entity ID: " .. tostring(entity.id))
    self:Log("Name: " .. tostring(entity:GetName()))
    self:Log("DummySpawner.isHostile: " .. tostring(self.isHostile))
    
    if entity.soul then
        self:Log("Hostile State (Soul): " .. tostring(entity.soul:IsHostile()))
    else
        self:Log("No soul component found.")
    end

    if entity.actor then
        self:Log("Actor State: " .. tostring(entity.actor:GetState() or "unknown"))
        self:Log("Brain Target WUID: " .. tostring(entity.actor:GetBrainVariable("CombatTarget") or "none"))
        self:Log("Brain isHostile: " .. tostring(entity.actor:GetBrainVariable("isHostile") or "none"))
    else
        self:Log("No actor component found.")
    end
    
    if AI then
        local aiTarget = AI.GetAttentionTarget(entity.id)
        self:Log("AI Attention Target: " .. tostring(aiTarget and aiTarget.id or "none"))
        self:Log("AI Behavior Variable isHostile: " .. tostring(AI.GetBehaviorVariable(entity.id, "isHostile") or "none"))
    end
    self:Log("======================")
end