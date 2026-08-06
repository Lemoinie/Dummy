------------------------------------------------------------
--  dummy_equipment.lua  â€“  Armor Presets & Equipment Logic
------------------------------------------------------------

DummyEquipment = DummyEquipment or {}

DummyEquipment.ArmorPresets = {
    -- 1 â–¸ Light Armor
    {
        name = "Light Armor",
        guid = "0083b6bd-6ebd-47f3-b324-48d64c7ee625",
        locKey = "ui_dummy_change_preset_light",
    },
    -- 2 â–¸ Medium Armor
    {
        name = "Medium Armor",
        guid = "01234e1e-d58d-4c6b-9f5e-5eafba96e3a5",
        locKey = "ui_dummy_change_preset_medium",
    },
    -- 3 â–¸ Heavy Full Plate Armor
    {
        name = "Heavy Full Plate Armor",
        guid = "a1b2c3d4-0004-4000-8000-100000000004", -- Custom Full Plate Preset
        fallbackGuid = "b7d72548-8a0a-4631-b1c1-21c692ec99c4", -- Knight Full Plate
        locKey = "ui_dummy_change_preset_heavy",
    },
}

function DummyEquipment:ApplyPreset(entityId, index)
    local preset = self.ArmorPresets[index]
    if not preset then
        if System and System.LogAlways then
            System.LogAlways("[Dummy] ERROR: Invalid preset index " .. tostring(index))
        end
        return
    end

    local entity = System.GetEntity(entityId)
    if not entity or not entity.actor then
        return
    end

    -- Undress first so layer armor replaces cleanly
    pcall(function()
        if entity.actor.Undress then
            entity.actor:Undress()
        end
    end)

    -- Equip the preset
    local ok = pcall(function()
        entity.actor:EquipClothingPreset(preset.guid)
    end)

    if not ok and preset.fallbackGuid then
        pcall(function()
            entity.actor:EquipClothingPreset(preset.fallbackGuid)
        end)
    end

    -- Re-equip weapon after undressing, otherwise the Dummy can't fight!
    pcall(function()
        if entity.actor.EquipWeaponPreset then
            entity.actor:EquipWeaponPreset("94600b75-8cd2-42f5-8a85-9e5ad0db8318")
        end
    end)

    if System and System.LogAlways then
        System.LogAlways("[Dummy] Applied armor preset " .. tostring(index) .. ": " .. preset.name)
    end
end
