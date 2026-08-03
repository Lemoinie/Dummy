------------------------------------------------------------
--  dummy_interaction.lua  –  Interaction & Dialog Menu
------------------------------------------------------------
--
--  Flow:
--    1. Player presses E  → opens the "Dumb Dumb dialog" menu
--    2. Menu stays open, showing options as interactor actions
--       attached to already-existing vanilla action slots:
--         E (use)              → confirm selected option
--         [ ]  / V (companion_bond) → cycle selection up/down
--    3. Menu closes on "End Dialog" or on despawn.
--
--  IMPORTANT: No new keybinds are created.  All actions used here
--  (use / companion_bond / loot) are pre-existing vanilla game actions.
------------------------------------------------------------

DummyInteraction = DummyInteraction or {}

-- Menu state:  nil = closed,  1-N = open on page N
DummyInteraction.menuOpen      = false
DummyInteraction.menuPage      = 0    -- 0 = root, 1 = equipment sub-menu

------------------------------------------------------------
--  MENU DEFINITIONS
------------------------------------------------------------

-- Root menu options – shown when dialog is first opened
DummyInteraction.rootMenu = {
    { hint = "ui_dummy_dlg_heal",       action = "use",            hintType = "AHT_RELEASE", page = nil,      func = "DummyMenuHeal"          },
    { hint = "ui_dummy_dlg_immortal",   action = "companion_bond", hintType = "AHT_HOLD",    page = nil,      func = "DummyMenuToggleImmortal" },
    { hint = "ui_dummy_dlg_equip",      action = "loot",           hintType = "AHT_RELEASE", page = "equip",  func = nil                       },
    { hint = "ui_dummy_dlg_end",        action = "talk",           hintType = "AHT_RELEASE", page = "close",  func = "DummyMenuClose"          },
}

------------------------------------------------------------
--  HELPERS
------------------------------------------------------------

function DummyInteraction:CloseMenu(entity)
    self.menuOpen = false
    self.menuPage = 0
    -- force a refresh so the "Talk [E]" prompt reappears
    if entity and entity.this then
        pcall(function() entity.this:ActivateOutput("OnUse", 0) end)
    end
    if System and System.LogAlways then
        System.LogAlways("[Dummy] Dialog menu closed.")
    end
end

function DummyInteraction:OpenMenu(entity)
    self.menuOpen = true
    self.menuPage = 0
    if System and System.LogAlways then
        System.LogAlways("[Dummy] Dialog menu opened.")
    end
end

------------------------------------------------------------
--  INJECT INTO ENTITY
------------------------------------------------------------

function DummyInteraction:Inject(entity)
    if not entity then return end

    -- ── action callbacks injected on the entity table ──────────

    entity.DummyTalk = function(selfEnt, user)
        DummyInteraction:OpenMenu(selfEnt)
    end

    entity.DummyMenuHeal = function(selfEnt, user)
        DummyInteraction:CloseMenu(selfEnt)
        DummySpawner:Heal()
        if Game and Game.SendInfoText then
            Game.SendInfoText("ui_dummy_dlg_heal_done", false, 0, 3)
        end
    end

    entity.DummyMenuToggleImmortal = function(selfEnt, user)
        DummyInteraction:CloseMenu(selfEnt)
        DummyInteraction:ToggleImmortal(selfEnt)
    end

    entity.DummyMenuOpenEquip = function(selfEnt, user)
        DummyInteraction.menuPage = "equip"
    end

    entity.DummyMenuClose = function(selfEnt, user)
        DummyInteraction:CloseMenu(selfEnt)
    end

    entity.DummyToggleHostile = function(selfEnt, user)
        DummySpawner:ToggleHostile()
    end

    -- ── equipment sub-menu callbacks (one per preset) ──────────

    local numPresets = DummyEquipment and #DummyEquipment.ArmorPresets or 0
    for i = 1, numPresets do
        local idx = i
        entity["DummyEquipPreset" .. i] = function(selfEnt, user)
            DummyInteraction:CloseMenu(selfEnt)
            DummyInteraction.menuPage = 0
            DummySpawner.currentPresetIdx = idx
            DummyEquipment:ApplyPreset(DummySpawner.spawnedEntityId, idx)
        end
    end

    entity.DummyEquipBack = function(selfEnt, user)
        DummyInteraction.menuPage = 0
    end

    -- ── GetActions: the heart of the menu system ────────────────

    entity.GetActions = function(selfEnt, userEnt, firstFast)
        local output = {}

        if not (selfEnt.actor and not selfEnt.actor:IsDead()) then
            return output
        end

        if not AddInteractorAction then return output end

        -- ── MENU CLOSED: show "Talk" on E, "Make Hostile / Wait" on V ──
        if not DummyInteraction.menuOpen then

            -- E: Talk (opens dialog menu)
            AddInteractorAction(
                output, firstFast,
                Action()
                    :hint("ui_dummy_dlg_talk")
                    :hintType(AHT_RELEASE)
                    :action("use")
                    :uiOrder(1)
                    :func(selfEnt.DummyTalk)
                    :interaction(inr_talk)
            )

            -- V: Toggle Wait / Hostile  (hold V)
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

            return output
        end

        -- ── MENU OPEN – equipment sub-menu ───────────────────────
        if DummyInteraction.menuPage == "equip" then
            local presets = DummyEquipment and DummyEquipment.ArmorPresets or {}
            for i, preset in ipairs(presets) do
                local funcName = "DummyEquipPreset" .. i
                AddInteractorAction(
                    output, firstFast,
                    Action()
                        :hint(preset.locKey or preset.name)
                        :hintType(AHT_RELEASE)
                        :action("use")
                        :uiOrder(i)
                        :func(selfEnt[funcName])
                        :interaction(inr_loot)
                )
            end

            -- Back option on V
            AddInteractorAction(
                output, firstFast,
                Action()
                    :hint("ui_dummy_dlg_back")
                    :hintType(AHT_RELEASE)
                    :action("companion_bond")
                    :uiOrder(10)
                    :func(selfEnt.DummyEquipBack)
                    :interaction(inr_loot)
            )

            return output
        end

        -- ── MENU OPEN – root dialog menu ─────────────────────────
        -- E  → Heal
        AddInteractorAction(
            output, firstFast,
            Action()
                :hint("ui_dummy_dlg_heal")
                :hintType(AHT_RELEASE)
                :action("use")
                :uiOrder(1)
                :func(selfEnt.DummyMenuHeal)
                :interaction(inr_loot)
        )

        -- V (hold) → Toggle Immortal
        local immortalHint = DummySpawner.isImmortal ~= false
                             and "ui_dummy_dlg_mortal" or "ui_dummy_dlg_immortal"
        AddInteractorAction(
            output, firstFast,
            Action()
                :hint(immortalHint)
                :hintType(AHT_HOLD)
                :action("companion_bond")
                :uiOrder(2)
                :func(selfEnt.DummyMenuToggleImmortal)
                :interaction(inr_loot)
        )

        -- Loot / G → Change Equipment (opens equipment sub-menu)
        AddInteractorAction(
            output, firstFast,
            Action()
                :hint("ui_dummy_dlg_equip")
                :hintType(AHT_RELEASE)
                :action("loot")
                :uiOrder(3)
                :func(selfEnt.DummyMenuOpenEquip)
                :interaction(inr_loot)
        )

        -- Talk key → End Dialog
        AddInteractorAction(
            output, firstFast,
            Action()
                :hint("ui_dummy_dlg_end")
                :hintType(AHT_RELEASE)
                :action("talk")
                :uiOrder(4)
                :func(selfEnt.DummyMenuClose)
                :interaction(inr_loot)
        )

        return output
    end
end

------------------------------------------------------------
--  IMMORTAL TOGGLE (driven from the menu)
------------------------------------------------------------

function DummyInteraction:ToggleImmortal(entity)
    entity = entity or System.GetEntity(DummySpawner.spawnedEntityId)
    if not entity then return end

    -- Flip state (default is immortal = true, set at spawn)
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
