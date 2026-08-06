------------------------------------------------------------
--  dummy_interaction.lua  â€“  Interaction Action Handling
------------------------------------------------------------

DummyInteraction = DummyInteraction or {}

function DummyInteraction:Inject(entity)
    if not entity then return end

    entity.DummyCyclePreset = function(self, user)
        DummySpawner:NextPreset()
    end

    entity.DummyToggleHostile = function(self, user)
        DummySpawner:ToggleHostile()
    end

    entity.GetActions = function(selfEnt, userEnt, firstFast)
        local output = {}

        -- Keep interaction active when NPC is not dead
        if selfEnt.actor and not selfEnt.actor:IsDead() then

            if AddInteractorAction then
                -- 1. Action E: Change Armor Preset (Tap E)
                AddInteractorAction(
                    output,
                    firstFast,
                    Action()
                        :hint("ui_dummy_change_preset")  -- localization key
                        :hintType(AHT_RELEASE)
                        :action("use")
                        :uiOrder(1)
                        :func(selfEnt.DummyCyclePreset)
                        :interaction(inr_loot)
                )

                -- 2. Action V: Toggle Wait / Hostile (Hold V - companion_bond)
                local hostileHint = DummySpawner.isHostile and "ui_dummy_make_wait" or "ui_dummy_make_hostile"
                AddInteractorAction(
                    output,
                    firstFast,
                    Action()
                        :hint(hostileHint)
                        :hintType(AHT_HOLD)  -- Key V (companion_bond) requires AHT_HOLD in KCD2 engine
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
