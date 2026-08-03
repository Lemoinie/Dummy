------------------------------------------------------------
--  dummy_interaction.lua  –  Native Interaction Action Handling
------------------------------------------------------------

DummyInteraction = DummyInteraction or {}

function DummyInteraction:Inject(entity)
    if not entity then return end

    entity.DummyToggleHostile = function(selfEnt, user)
        DummySpawner:ToggleHostile()
    end

    entity.GetActions = function(selfEnt, userEnt, firstFast)
        local output = {}

        if selfEnt.actor and not selfEnt.actor:IsDead() then
            if AddInteractorAction then
                -- 1. Native Talk prompt (E key) -> opens native Skald dialogue
                AddInteractorAction(
                    output,
                    firstFast,
                    Action()
                        :hint("@ui_hud_talk")
                        :action("talk")
                        :uiOrder(1)
                        :func(BasicAIActions.OnTalk)
                        :interaction(inr_talk)
                )

                -- 2. Hold V -> Toggle Wait / Hostile
                local hostileHint = DummySpawner.isHostile and "ui_dummy_make_wait" or "ui_dummy_make_hostile"
                AddInteractorAction(
                    output,
                    firstFast,
                    Action()
                        :hint(hostileHint)
                        :hintType(AHT_HOLD)
                        :action("companion_bond")
                        :uiOrder(2)
                        :func(selfEnt.DummyToggleHostile)
                        :interaction(inr_loot)
                )
            end
        end

        return output
    end
end

function DummyInteraction:ToggleImmortal(entity)
    entity = entity or System.GetEntity(DummySpawner.spawnedEntityId)
    if not entity then return end

    if DummySpawner.isImmortal == nil then DummySpawner.isImmortal = true end
    DummySpawner.isImmortal = not DummySpawner.isImmortal
    local immortal = DummySpawner.isImmortal

    pcall(function()
        if entity.SetInvulnerability then
            entity:SetInvulnerability(immortal)
        end
        entity.invulnerable = immortal
        if entity.Properties then
            entity.Properties.bInvulnerable = immortal
            if entity.Properties.Health then
                entity.Properties.Health.bInvulnerable = immortal
            end
        end
    end)

    local statusKey = immortal and "ui_dummy_dlg_immortal_on" or "ui_dummy_dlg_immortal_off"
    if Game and Game.SendInfoText then
        Game.SendInfoText(statusKey, false, 0, 3)
    end
    if System and System.LogAlways then
        System.LogAlways("[Dummy] Immortal mode: " .. tostring(immortal))
    end
end
