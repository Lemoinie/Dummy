------------------------------------------------------------
--  dummy_equipment.lua  –  Armor Presets & Equipment Logic
------------------------------------------------------------

DummyEquipment = DummyEquipment or {}

DummyEquipment.ArmorPresets = {
    -- 1 ▸ Light Armor
    {
        name = "Light Armor",
        guid = "0083b6bd-6ebd-47f3-b324-48d64c7ee625",
    },
    -- 2 ▸ Medium Armor
    {
        name = "Medium Armor",
        guid = "01234e1e-d58d-4c6b-9f5e-5eafba96e3a5",
    },
    -- 3 ▸ Heavy Armor
    {
        name = "Heavy Armor",
        guid = "15dff4c0-790a-47b9-b513-6392eb2b2c10",
    },
    -- 4 ▸ Bandit Outfit
    {
        name = "Bandit Outfit",
        guid = "20aba0c4-1cfb-42de-97dd-939530d6240d",
    },
    -- 5 ▸ Cuman Armor
    {
        name = "Cuman Armor",
        guid = "08d7d086-327a-4f95-92d3-6a6c60a494f0",
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
    if not entity then
        return
    end

    if System and System.LogAlways then
        System.LogAlways("[Dummy] Equipping clothing preset: " .. preset.name .. " (" .. preset.guid .. ")")
    end

    if entity.actor and entity.actor.EquipClothingPreset then
        entity.actor:EquipClothingPreset(preset.guid)
    end
end
