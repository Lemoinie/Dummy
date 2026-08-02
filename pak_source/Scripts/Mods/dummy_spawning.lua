------------------------------------------------------------
--  dummy_spawning.lua  –  Spawning & Stationary AI Logic
------------------------------------------------------------

DummySpawner = DummySpawner or {}

DummySpawner.SPAWN_DISTANCE    = 2.0
DummySpawner.ENTITY_CLASS      = "NPC"
DummySpawner.LOG_PREFIX        = "[Dummy] "

-- Generic KCD2 male combat soul GUID (has nametag support, doesn't flee)
-- Using a weak mercenary soul that has bandit combat behavior tree
DummySpawner.SOUL_GUID         = "18a63cbf-db72-435d-9b89-ea47ea6b5ec2"

DummySpawner.spawnedEntityId   = nil
DummySpawner.currentPresetIdx  = 1

------------------------------------------------------------
--  HELPERS
------------------------------------------------------------

function DummySpawner:Log(msg)
    if System and System.LogAlways then
        System.LogAlways(self.LOG_PREFIX .. tostring(msg))
    end
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
--  FREEZE AI – called immediately after spawn AND on a timer
------------------------------------------------------------

function DummySpawner:FreezeEntity(entity)
    if not entity then return end

    -- Behavior tree: force permanent idle, no combat/flee trees
    if AI then
        pcall(function() AI.Enable(entity.id, false) end)
        pcall(function() AI.SetLeader(entity.id, nil) end)
        pcall(function() AI.SetBehaviorVariable(entity.id, "IsDisabled", 1) end)
        pcall(function() AI.SetBehaviorVariable(entity.id, "Alertness", 0) end)
        pcall(function() AI.SetBehaviorVariable(entity.id, "bIsDummy", 1) end)
    end
    if entity.EnableAI then
        pcall(function() entity:EnableAI(false) end)
    end
    entity.AI = entity.AI or {}
    entity.AI.bDisableAI   = true
    entity.AI.bIgnoredByAI = true

    -- Invulnerability flags (prevents HP change event triggering flee)
    if entity.SetInvulnerability then
        pcall(function() entity:SetInvulnerability(true) end)
    end
    entity.invulnerable = true
    if entity.Properties then
        entity.Properties.bInvulnerable = true
        if entity.Properties.Health then
            entity.Properties.Health.bInvulnerable = true
        end
    end

    -- Soul-level flee contexts
    if entity.soul then
        pcall(function() entity.soul:SetScriptContext("combat_flee",              false) end)
        pcall(function() entity.soul:SetScriptContext("crime_interruptFlee",      false) end)
        pcall(function() entity.soul:SetScriptContext("crime_fleeAfterSurrender", false) end)
        pcall(function() entity.soul:SetCrimeIgnored(true) end)
        pcall(function() entity.soul:SetHostile(true) end)
    end

    -- Swallow hit/damage events at Lua level
    entity.OnHit    = function() return false end
    entity.OnDamage = function() return false end
end

------------------------------------------------------------
--  SET NAME – called immediately AND deferred 500 ms
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
    if AI and AI.ChangeFaction then
        pcall(function() AI.ChangeFaction(entity.id, "bandit") end)
    end
    if entity.soul then
        pcall(function() entity.soul:SetFaction("bandit") end)
        pcall(function() entity.soul:SetCrimeIgnored(true) end)
        pcall(function() entity.soul:SetHostile(true) end)
    end
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
    local entityName = "DummyTarget_DumbDumb_" .. tostring(math.random(10000, 99999))

    -- Spawn with IdleSeq behavior tree so the NPC never enters combat or flee trees
    System.SpawnEntity({
        class       = self.ENTITY_CLASS,
        name        = entityName,
        position    = spawnPos,
        orientation = facingDir,
        properties  = {
            guidSharedSoulId        = self.SOUL_GUID,
            esModularBehaviorTree   = "IdleSeq",   -- KEY: locks NPC to idle, no flee/combat
            sWH_AI_EntityCategory   = "bandit",
            bWH_PerceptorObject     = true,
            bWH_PerceptibleObject   = true,
            bInvulnerable           = true,
        }
    })

    local entity = System.GetEntityByName(entityName)
    if not entity then
        self:Log("ERROR: System.SpawnEntity returned nil.")
        return
    end

    self.spawnedEntityId = entity.id
    self:Log("Spawned Dumb Dumb (id=" .. tostring(entity.id) .. ")")

    -- Apply immediately
    self:ApplyName(entity)
    self:ApplyFaction(entity)
    self:FreezeEntity(entity)

    -- Deferred re-apply: engine may override settings shortly after spawn
    local eid = entity.id
    if Script and Script.SetTimer then
        Script.SetTimer(500, function()
            local ent = System.GetEntity(eid)
            if ent then
                DummySpawner:ApplyName(ent)
                DummySpawner:FreezeEntity(ent)
            end
        end)
    end

    -- Inject interaction prompt
    if DummyInteraction and DummyInteraction.Inject then
        DummyInteraction:Inject(entity)
    end

    -- Apply initial armor preset
    self.currentPresetIdx = 1
    DummyEquipment:ApplyPreset(self.spawnedEntityId, self.currentPresetIdx)
end

function DummySpawner:Despawn()
    if not self.spawnedEntityId then
        self:Log("No dummy to despawn.")
        return
    end
    System.RemoveEntity(self.spawnedEntityId)
    self:Log("Despawned Dumb Dumb.")
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
