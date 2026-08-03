------------------------------------------------------------
--  dummy_interaction.lua  –  Interaction Action Handling
--
--  E (tap)            → "Talk to Dumb Dumb"
--  When dialog open:
--    E  (tap)         → "Heal yourself"
--    V  (hold)        → "Become Immortal / Mortal toggle"
--    R  (use_other)   → "Change Equipment" (cycle preset)
--    F  (use_quick)   → "End Dialog"
--  Outside dialog:
--    V  (hold)        → "Make Hostile / Wait Here" (unchanged)
------------------------------------------------------------

DummyInteraction = DummyInteraction or {}

-- Dialog menu state
DummySpawner = DummySpawner or {}
DummySpawner.dialogOpen     = false
DummySpawner.isImmortal     = true          -- Tracks immortality toggle

function DummyInteraction:Inject(entity)
    if not entity then return end

    ------------------------------------------------------------
    -- Action functions attached to the entity
    ------------------------------------------------------------

    -- Open / close the Dumb Dumb dialog menu
    entity.DummyOpenDialog = function(self, user)
        DummySpawner.dialogOpen = true
        if System and System.LogAlways then
            System.LogAlways("[Dummy] Dialog menu opened.")
        end
    end

    entity.DummyCloseDialog = function(self, user)
        DummySpawner.dialogOpen = false
        if System and System.LogAlways then
            System.LogAlways("[Dummy] Dialog menu closed.")
        end
    end

    -- Heal from within dialog
    entity.DummyDialogHeal = function(self, user)
        DummySpawner:Heal()
        DummySpawner.dialogOpen = false
        if Game and Game.SendInfoText then
            Game.SendInfoText("Dumb Dumb healed to full health!", false, 0, 3)
        end
    end

    -- Toggle immortality from within dialog
    entity.DummyDialogToggleImmortal = function(self, user)
        local ent = System.GetEntity(DummySpawner.spawnedEntityId)
        if not ent then return end

        DummySpawner.isImmortal = not DummySpawner.isImmortal
        local immortal = DummySpawner.isImmortal

        -- Apply or remove invulnerability
        pcall(function()
            if ent.SetInvulnerability then
                ent:SetInvulnerability(immortal)
            end
            ent.invulnerable = immortal
            if ent.Properties then
                ent.Properties.bInvulnerable = immortal
                if ent.Properties.Health then
                    ent.Properties.Health.bInvulnerable = immortal
                end
            end
        end)

        local statusMsg = immortal and "Dumb Dumb is now IMMORTAL." or "Dumb Dumb is now MORTAL."
        if System and System.LogAlways then
            System.LogAlways("[Dummy] " .. statusMsg)
        end
        if Game and Game.SendInfoText then
            Game.SendInfoText(statusMsg, false, 0, 3)
        end
        DummySpawner.dialogOpen = false
    end

    -- Cycle equipment preset from within dialog
    entity.DummyDialogChangeEquip = function(self, user)
        DummySpawner:NextPreset()
        -- Keep dialog open so player can cycle again without re-opening
        -- (close after a moment so it is navigable)
        DummySpawner.dialogOpen = false
    end

    -- Hostile toggle (outside dialog mode, unchanged V key)
    entity.DummyToggleHostile = function(self, user)
        DummySpawner:ToggleHostile()
    end

    ------------------------------------------------------------
    -- GetActions – main interactor pump
    ------------------------------------------------------------
    entity.GetActions = function(selfEnt, userEnt, firstFast)
        local output = {}

        if not (selfEnt.actor and not selfEnt.actor:IsDead()) then
            return output
        end

        if not AddInteractorAction then
            return output
        end

        if DummySpawner.dialogOpen then
            -- ── Dialog Menu Mode ──────────────────────────────────

            -- 1. E (tap) → Heal yourself
            AddInteractorAction(
                output, firstFast,
                Action()
                    :hint("ui_dummy_dialog_heal")
                    :hintType(AHT_RELEASE)
                    :action("use")
                    :uiOrder(1)
                    :func(selfEnt.DummyDialogHeal)
                    :interaction(inr_loot)
            )

            -- 2. V (hold) → Become Immortal / Mortal toggle
            local immortalHint = DummySpawner.isImmortal and "ui_dummy_dialog_make_mortal" or "ui_dummy_dialog_make_immortal"
            AddInteractorAction(
                output, firstFast,
                Action()
                    :hint(immortalHint)
                    :hintType(AHT_HOLD)
                    :action("companion_bond")
                    :uiOrder(2)
                    :func(selfEnt.DummyDialogToggleImmortal)
                    :interaction(inr_loot)
            )

            -- 3. R (use_other) → Change Equipment (cycle preset)
            AddInteractorAction(
                output, firstFast,
                Action()
                    :hint("ui_dummy_dialog_change_equip")
                    :hintType(AHT_RELEASE)
                    :action("use_other")
                    :uiOrder(3)
                    :func(selfEnt.DummyDialogChangeEquip)
                    :interaction(inr_loot)
            )

            -- 4. F (companion_follow) → End Dialog
            AddInteractorAction(
                output, firstFast,
                Action()
                    :hint("ui_dummy_dialog_end")
                    :hintType(AHT_RELEASE)
                    :action("companion_follow")
                    :uiOrder(4)
                    :func(selfEnt.DummyCloseDialog)
                    :interaction(inr_loot)
            )

        else
            -- ── Normal (idle) Mode ────────────────────────────────

            -- 1. E (tap) → Talk to Dumb Dumb (open dialog menu)
            AddInteractorAction(
                output, firstFast,
                Action()
                    :hint("ui_dummy_talk")
                    :hintType(AHT_RELEASE)
                    :action("use")
                    :uiOrder(1)
                    :func(selfEnt.DummyOpenDialog)
                    :interaction(inr_loot)
            )

            -- 2. V (hold) → Make Hostile / Wait Here
            local hostileHint = DummySpawner.isHostile and "ui_dummy_make_wait" or "ui_dummy_make_hostile"
            AddInteractorAction(
                output, firstFast,
                Action()
                    :hint(hostileHint)
                    :hintType(AHT_HOLD)
                    :action("companion_bond")
                    :uiOrder(2)
                    :func(selfEnt.DummyToggleHostile)
                    :interaction(inr_loot)
            )
        end

        return output
    end
end
