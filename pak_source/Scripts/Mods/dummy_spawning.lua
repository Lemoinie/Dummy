------------------------------------------------------------
--  dummy_spawning.lua  –  Spawning & Stationary AI Logic
------------------------------------------------------------

DummySpawner = DummySpawner or {}

DummySpawner.SPAWN_DISTANCE    = 2.0
DummySpawner.ENTITY_CLASS      = "NPC"
DummySpawner.LOG_PREFIX        = "[Dummy] "
DummySpawner.KEYBIND_SPAWN     = "/"          -- default spawn/despawn hotkey

-- Custom Dumb Dumb Soul GUID (dummyFaction, social_class_id=0, no reputation penalty)
DummySpawner.SOUL_GUID         = "a1b2c3d4-0003-4000-8000-100000000003"

DummySpawner.spawnedEntityId   = nil
DummySpawner.currentPresetIdx  = 1
DummySpawner.isHostile         = false
DummySpawner.isImmortal        = true          -- Tracks immortality (default ON — spawns invulnerable)
DummySpawner.dialogOpen        = false         -- True when the in-world dialog menu is open
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
    if key and key ~= "" then
        self.KEYBIND_SPAWN = key
    end
    local keyToBind = self.KEYBIND_SPAWN or "/"
    if System and System.ExecuteCommand then
        System.ExecuteCommand("bind " .. keyToBind .. " dummy_spawn")
        self:Log("Bound spawn/despawn hotkey to: " .. keyToBind)
    end
end

------------------------------------------------------------
--  HEALING LOGIC
------------------------------------------------------------

function DummySpawner:Heal(entity)
    entity = entity or System.GetEntity(self.spawnedEntityId)
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
    local entity = System.GetEntity(self.spawnedEntityId)
    if not entity then return end

    local pl = self:GetPlayer()
    local targetId = pl and (pl.this and pl.this.id or pl.id) or nil

    if hostile then
        self:Log("Dumb Dumb is now HOSTILE!")
        pcall(function() entity.soul:SetHostile(true) end)
        if targetId then
            pcall(function() entity.soul:SetTarget(targetId) end)
        end
        pcall(function() entity.human:DrawWeapon(true) end)
        if AI and AI.ChangeFaction then
            pcall(function() AI.ChangeFaction(entity.id, "bandit") end)
        end
        if Game and Game.SendInfoText then
            Game.SendInfoText("ui_dummy_info_hostile", false, 0, 3)
        end
    else
        self:Log("Dumb Dumb is now WAITING (Neutral).")
        pcall(function() entity.soul:SetTarget(nil) end)
        pcall(function() entity.soul:SetHostile(false) end)
        pcall(function() entity.human:DrawWeapon(false) end)
        if AI and AI.ChangeFaction then
            pcall(function() AI.ChangeFaction(entity.id, "dummyFaction") end)
        end
        -- Sheathe weapon & clear target immediately
        pcall(function()
            if entity.actor and entity.human then
                entity.human:DrawWeapon(false)
            end
        end)
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
--  FREEZE AI – called immediately after spawn AND on a timer
------------------------------------------------------------

function DummySpawner:FreezeEntity(entity)
    if not entity then return end

    -- Disable flee / crime contexts on soul
    if entity.soul then
        pcall(function() entity.soul:SetScriptContext("combat_flee",              false) end)
        pcall(function() entity.soul:SetScriptContext("crime_interruptFlee",      false) end)
        pcall(function() entity.soul:SetScriptContext("crime_fleeAfterSurrender", false) end)
        pcall(function() entity.soul:SetCrimeIgnored(true) end)
        pcall(function() entity.soul:SetFaction("dummyFaction") end)
    end

    -- Invulnerability flags (prevents death / HP change event triggering panic)
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

    -- Prevent Lua hit/damage callbacks from interrupting AI and auto-heal in Waiting mode
    entity.OnHit = function(hit)
        if not DummySpawner.isHostile and DummySpawner.autoHealWaiting then
            DummySpawner:Heal(entity)
        end
        return false
    end
    entity.OnDamage = function(dmg)
        if not DummySpawner.isHostile and DummySpawner.autoHealWaiting then
            DummySpawner:Heal(entity)
        end
        return false
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
    if AI and AI.ChangeFaction then
        pcall(function() AI.ChangeFaction(entity.id, "dummyFaction") end)
    end
    if entity.soul then
        pcall(function() entity.soul:SetFaction("dummyFaction") end)
        pcall(function() entity.soul:SetCrimeIgnored(true) end)
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

    self.isHostile = false

    -- Spawn with custom dummy_brain (guidBrainId = a1b2c3d4-0001-4000-8000-100000000001)
    -- and custom Dumb Dumb soul (guidSharedSoulId = a1b2c3d4-0003-4000-8000-100000000003)
    System.SpawnEntity({
        class       = self.ENTITY_CLASS,
        name        = entityName,
        position    = spawnPos,
        orientation = facingDir,
        properties  = {
            guidSharedSoulId        = self.SOUL_GUID,
            guidBrainId             = "a1b2c3d4-0001-4000-8000-100000000001",  -- dummy_brain
            sWH_AI_EntityCategory   = "dummyFaction",
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

    -- Deferred re-apply
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
    self.isHostile        = false
    self.isImmortal       = true
    self.dialogOpen       = false
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
