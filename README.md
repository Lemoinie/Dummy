# Dummy — KCD2 Target Dummy Mod

A modular, standalone mod for **Kingdom Come: Deliverance II** that spawns a custom training dummy named **Dumb Dumb** for combat testing, weapon practice, and armor preset swapping.

---

## 🌟 Features Summary

### 👤 NPC Identity & HUD Nametag
- Spawns a custom male NPC named **Dumb Dumb**.
- Linked via custom Skald database table (`skald_character__dummy.xml`) and UI localization (`char_dumb_dumb_uiName`) so the HUD target bar cleanly displays **Dumb Dumb**.

### 🛡️ Zero Reputation Loss & Crime-Ignored
- **Custom Soul & Faction:** Powered by a standalone soul (`soul_dumb_dumb`) with non-civilian social class (`social_class_id="0"`) assigned to **`dummyFaction`**.
- **No Crime Penalties:** Attacking, hitting, or executing combos on Dumb Dumb causes **zero town reputation loss** and triggers **no crime reports** or guard alerts.

### 🚫 Permanent No-Flee AI & Behavioral Suppression
- **Custom Behavior Tree:** Driven by `dummy_scheduler.xml` under a dedicated `dummy_brain` AI switch.
- **Suppressed Panic:** Enclosed within `<EntityContext context="crime_suppressBehavioralReaction">` and `<EntityContext context="crime_preventDespawn">`.
- Dumb Dumb **never flees**, runs away, or panics regardless of how much damage he receives.

### 🎮 In-Game Interaction Prompts (E & V Keys)
Looking at Dumb Dumb displays custom interactive prompts:
- **Press `E` (`use`): "Talk"** — Opens a Lua-driven dialog menu with quality-of-life options. No console commands needed:
  - **`E` → "Heal yourself"** — Restores Dumb Dumb to full health immediately.
  - **Hold `V` → "Become Immortal" / "Disable Immortality"** — Toggles Dumb Dumb's invulnerability on or off.
  - **`G` (loot key) → "Change Equipment"** — Opens an equipment sub-menu listing all 3 armor presets. Press `E` to apply the highlighted preset, or `V` to go back.
  - **Talk key → "End Dialog"** — Closes the dialog menu and returns to the normal interaction prompt.
- **Hold `V` (`companion_bond`): "Make Hostile" / "Wait Here"** — Toggles Dumb Dumb between two operational modes (only visible when menu is closed):
  - **Wait Mode (Neutral - Default):** Dumb Dumb stands completely still, sheathes weapon, and acts as a stationary target.
  - **Hostile Mode (Combat Practice):** Dumb Dumb draws weapon and engages Henry in melee combat for sparring practice. Holding `V` again instantly disengages combat (via watchdog loop in `combat_melee.xml`), sheathes weapon, clears target, and returns Dumb Dumb back to Wait mode.

### ⚔️ Curated Armor Presets
Cycles cleanly through 3 distinct armor tiers:
1. **Light Armor:** Light gambeson, coif, and basic protection.
2. **Medium Armor:** Brigandine chest, mail coif, kettle hat, and padded leg chausses.
3. **Heavy Full Plate Armor:** Full steel plate cuirass/breastplate, full plate arm & leg harness, padded chausses, hourglass plate gauntlets, mail hauberk & collar, and visored bascinet helmet.

---

## ⌨️ Keybindings & Hotkeys

- **Default Spawn / Despawn Key:** `/` (Slash)
  - Pressing `/` instantly spawns or despawns Dumb Dumb right in front of Henry.
  - ActionMap mapping in `Libs/Config/defaultProfile.xml` and auto-bound on startup.

---

## 💻 Console Commands

Open the console in-game (`~`):

| Command | Action |
|---|---|
| `dummy_spawn` *(or `dummy`)* | Toggle spawn / despawn of Dumb Dumb in front of Henry (bound to `/` by default) |
| `dummy_bind <key>` | Rebind the spawn/despawn hotkey (e.g., `dummy_bind /` or `dummy_bind f6`) |
| `dummy_heal` | Heal Dumb Dumb back to full health immediately |
| `dummy_autoheal [1/0]` | Toggle or set auto-healing in Waiting mode when health is low (default: ON) |
| `dummy_next` | Cycle forward to the next armor preset |
| `dummy_prev` | Cycle backward to the previous armor preset |
| `dummy_hostile` | Toggle Dumb Dumb between Hostile (Combat) and Wait (Neutral) modes |

---

## 🧩 Repository Architecture

Refactored following modern KCD2 modular architecture conventions:

```
Dummy/
├── mod.manifest                         <-- Mod metadata manifest
├── build_pak.bat                        <-- One-click batch installer
├── build_pak.ps1                        <-- PowerShell PAK compiler
├── README.md                            <-- Mod documentation
├── Data/
│   ├── dummy.pak                        <-- Compiled engine data pak
│   └── English_xml.pak                  <-- Compiled localization pak
└── pak_source/
    ├── AI/
    │   ├── dummy_scheduler.xml          <-- No-flee behavior tree (Wait & Hostile states)
    │   └── combat_melee.xml             <-- Sparring combat behavior tree with fast disengage
    ├── Libs/
    │   ├── Config/
    │   │   └── defaultProfile.xml       <-- Keybind profile mappings
    │   └── tables/
    │       ├── ai/                      <-- Brain, subbrain, switching, & smartEntity XML tables
    │       ├── item/                    <-- Custom heavy full plate clothing preset XML
    │       ├── rpg/                     <-- Custom soul & dummyFaction XML tables
    │       └── skald/                   <-- Custom skald character HUD name XML tables
    ├── localization/
    │   └── English_xml.xml              <-- UI localization keys for prompts & HUD names
    └── Scripts/
        └── mods/
            ├── dummy.lua                <-- Master entry point & CCommand registry
            ├── dummy_spawning.lua       <-- Spawning, despawning, & state toggling logic
            ├── dummy_equipment.lua      <-- Armor preset definitions & equipping logic
            └── dummy_interaction.lua    <-- Interactor action prompt injection (E & V keys)
```

---

## 🛠️ How to Build & Install

1. Double-click `build_pak.bat` (or run `build_pak.ps1` in PowerShell).
2. The build script automatically:
   - Packs Lua scripts, AI behavior trees, RPG/Item/AI/Skald XML tables into `Data/dummy.pak`.
   - Packs localization keys into `Data/English_xml.pak`.
   - Deploys all `.pak` files and `mod.manifest` to `C:\Games\Kingdom Come - Deliverance II\mods\Dummy`.

---

## ⚡ In-Game Loading

Open console (`~`):
```lua
#Script.ReloadScript("Scripts/Mods/dummy.lua")
```
Or add to your `autoexec.cfg`:
```cfg
#Script.ReloadScript("Scripts/Mods/dummy.lua")
```

---

## 🤝 Compatibility

- **100% Standalone:** Fully compatible with *Mercenaries* mod and all other KCD2 mods.
- Uses dedicated GUIDs for souls, brains, subbrains, and clothing presets, custom `dummyFaction`, custom `ui_dummy_*` localization keys, and isolated Lua namespaces (`DummySpawner`, `DummyEquipment`, `DummyInteraction`).

---

## 🙏 Credits & Acknowledgments

- **Written from scratch:** All Lua scripts, AI behavior tree XMLs, database tables, and localization keys in this codebase were written from scratch specifically for the *Dummy* mod.
- **Special Thanks:** Credit to **Alex / Heragoga** ([*Mercenaries* mod for KCD2](https://github.com/Heragoga/kcd2-mercenaries-mod)) for serving as a technical reference for KCD2 modular structure, AI behavior tree routing, and interactor action injection techniques.
