------------------------------------------------------------
--  dummy_interaction.lua  –  Interaction Action Handling
------------------------------------------------------------

DummyInteraction = DummyInteraction or {}

function DummyInteraction:Inject(entity)
    if not entity then return end

    entity.GetActions = function(selfEnt, userEnt, firstFast)
        local output = {}

        if selfEnt.actor and not selfEnt.actor:IsDead() then
            local activeIdx = DummySpawner.currentPresetIdx or 1
            local activePreset = DummyEquipment.ArmorPresets[activeIdx]
            local label = "Change Armor Preset (Current: " .. (activePreset and activePreset.name or "") .. ")"

            if AddInteractorAction then
                AddInteractorAction(
                    output,
                    firstFast,
                    Action()
                        :hint(label)
                        :hintType(AHT_RELEASE)
                        :action("use")
                        :uiOrder(1)
                        :func(function()
                            DummySpawner:NextPreset()
                        end)
                        :interaction(inr_loot)
                )
            end
        end

        return output
    end
end
