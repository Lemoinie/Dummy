------------------------------------------------------------
--  dummy_interaction.lua  –  Interaction Action Handling
------------------------------------------------------------

DummyInteraction = DummyInteraction or {}

function DummyInteraction:Inject(entity)
    if not entity then return end

    entity.DummyCyclePreset = function(self, user)
        DummySpawner:NextPreset()
    end

    entity.GetActions = function(selfEnt, userEnt, firstFast)
        local output = {}

        -- Do NOT include BasicAIActions: strips all dialogue/pickpocket/vanilla options
        if selfEnt.actor and not selfEnt.actor:IsDead() then

            if AddInteractorAction then
                AddInteractorAction(
                    output,
                    firstFast,
                    Action()
                        :hint("ui_dummy_change_preset")  -- localization key, not raw string
                        :hintType(AHT_RELEASE)
                        :action("use")
                        :uiOrder(1)
                        :func(selfEnt.DummyCyclePreset)
                        :interaction(inr_loot)
                )
            end
        end

        return output
    end
end
