------------------------------------------------------------
--  dummy_spawning.lua  –  Spawning & Stationary AI Logic
------------------------------------------------------------

DummySpawner = DummySpawner or {}

DummySpawner.SPAWN_DISTANCE    = 2.0
DummySpawner.ENTITY_CLASS      = "NPC"
DummySpawner.ENTITY_NAME       = "Dumb Dumb"
DummySpawner.LOG_PREFIX        = "[Dummy] "

-- Standalone KCD2 Male Combat/Bandit Soul GUID (Never Flees, Supports Nametags)
DummySpawner.SOUL_GUID         = "18a63cbf-db72-435d-9b89-ea47ea6b5ec2"

DummySpawner.spawnedEntityId   = nil
DummySpawner.currentPresetIdx  = 1

function DummySpawner:Log(msg)
    if System and System.LogAlways then
        System.LogAlways(self.LOG_PREFIX .. tostring(msg))
    end
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
    local pos = entity.GetWorldPos and entity:GetWorldPos() or entity:GetPos()
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
        z = pos.z,
    }
    local facingDir = {
        x = -dir.x,
        y = -dir.y,
        z = -dir.z,
    }
    return spawnPos, facingDir
end

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

    --------------------------------------------------
    -- Spawn Standalone Dummy Shell
    --------------------------------------------------
    System.SpawnEntity({
        class       = self.ENTITY_CLASS,
        name        = entityName,
        position    = spawnPos,
        orientation = facingDir,
        properties  = {
            guidSharedSoulId      = self.SOUL_GUID,
            sName                 = "Dumb Dumb",
            soc_name              = "Dumb Dumb",
            sWH_AI_EntityCategory = "bandit",
            bWH_PerceptorObject   = true,
            bWH_PerceptibleObject = true,
            bInvulnerable         = true,
        }
    })

    local entity = System.GetEntityByName(entityName)
    if not entity then
        self:Log("ERROR: System.SpawnEntity failed.")
        return
    end

    self.spawnedEntityId = entity.id
    self:Log("Spawned standalone 'Dumb Dumb' (id=" .. tostring(entity.id) .. ")")

    --------------------------------------------------
    -- 1. Display Name "Dumb Dumb"
    --------------------------------------------------
    pcall(function() entity:SetName("Dumb Dumb") end)
    if entity.Properties then
        entity.Properties.sName = "Dumb Dumb"
        entity.Properties.soc_name = "Dumb Dumb"
    end
    if entity.soul then
        pcall(function() entity.soul:SetUIName("Dumb Dumb") end)
        pcall(function() entity.soul:SetCustomName("Dumb Dumb") end)
    end
    if entity.actor then
        pcall(function() entity.actor:SetName("Dumb Dumb") end)
    end

    --------------------------------------------------
    -- 2. Bandit Faction & Crime Ignored (No Reputation Loss)
    --------------------------------------------------
    if AI and AI.ChangeFaction then
        pcall(function() AI.ChangeFaction(entity.id, "bandit") end)
        pcall(function() AI.ChangeFaction(entity.id, "enemy") end)
    end
    if entity.soul then
        pcall(function() entity.soul:SetFaction("bandit") end)
        pcall(function() entity.soul:SetFaction("enemy") end)
        pcall(function() entity.soul:SetCrimeIgnored(true) end)
        pcall(function() entity.soul:SetHostile(true) end)
    end

    --------------------------------------------------
    -- 3. Freeze AI & Disable Fleeing (Never Flee On Hit)
    --------------------------------------------------
    entity.OnHit = function(selfEnt, hit) return false end
    entity.OnDamage = function(selfEnt, hit) return false end

    if entity.SetInvulnerability then
        pcall(function() entity:SetInvulnerability(true) end)
    end
    entity.invulnerable = true

    if entity.soul then
        pcall(function() entity.soul:SetScriptContext("combat_flee", false) end)
        pcall(function() entity.soul:SetScriptContext("crime_interruptFlee", false) end)
        pcall(function() entity.soul:SetScriptContext("crime_fleeAfterSurrender", false) end)
    end

    if AI then
        pcall(function() AI.SetLeader(entity.id, nil) end)
        pcall(function() AI.Enable(entity.id, false) end)
        pcall(function() AI.SetBehaviorVariable(entity.id, "IsDisabled", 1) end)
        pcall(function() AI.SetBehaviorVariable(entity.id, "Alertness", 0) end)
        pcall(function() AI.SetBehaviorVariable(entity.id, "bIsDummy", 1) end)
    end

    if entity.EnableAI then
        pcall(function() entity:EnableAI(false) end)
    end
    entity.AI = entity.AI or {}
    entity.AI.bDisableAI = true
    entity.AI.bIgnoredByAI = true

    --------------------------------------------------
    -- 4. Inject Interaction Action (Change Armor Preset)
    --------------------------------------------------
    if DummyInteraction and DummyInteraction.Inject then
        DummyInteraction:Inject(entity)
    end

    -- Apply initial Light Armor preset
    self.currentPresetIdx = 1
    DummyEquipment:ApplyPreset(self.spawnedEntityId, self.currentPresetIdx)
end

function DummySpawner:Despawn()
    if not self.spawnedEntityId then
        self:Log("No dummy to despawn.")
        return
    end
    System.RemoveEntity(self.spawnedEntityId)
    self:Log("Despawned dummy.")
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

function DummySpawner:NextPreset()
    if not self.spawnedEntityId then
        self:Log("Spawn a dummy first (dummy_spawn).")
        return
    end
    self.currentPresetIdx = (self.currentPresetIdx % #DummyEquipment.ArmorPresets) + 1
    DummyEquipment:ApplyPreset(self.spawnedEntityId, self.currentPresetIdx)
end

function DummySpawner:PrevPreset()
    if not self.spawnedEntityId then
        self:Log("Spawn a dummy first (dummy_spawn).")
        return
    end
    self.currentPresetIdx = self.currentPresetIdx - 1
    if self.currentPresetIdx < 1 then
        self.currentPresetIdx = #DummyEquipment.ArmorPresets
    end
    DummyEquipment:ApplyPreset(self.spawnedEntityId, self.currentPresetIdx)
end
