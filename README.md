# Dummy — KCD2 Target Dummy Mod

A modular, standalone mod for **Kingdom Come: Deliverance II** that spawns a custom training dummy named **Dumb Dumb** for combat testing, weapon practice, and armor preset swapping.

---

## 🌟 Key Features

### 👤 NPC Identity & HUD Nametag
- Spawns a custom male NPC named **Dumb Dumb**.
- Custom name is set via engine properties and deferred timers so the HUD nametag displays properly in-game.

### 🛡️ Zero Reputation Loss & Crime-Ignored
- **Custom Soul & Faction:** Powered by a standalone soul (`soul_dumb_dumb`) with non-civilian social class (`social_class_id="0"`) assigned to **`dummyFaction`**.
- **No Crime Penalties:** Attacking, hitting, or executing combos on Dumb Dumb causes **zero town reputation loss** and triggers **no crime reports** or guard alerts.

### 🚫 Permanent No-Flee AI & Behavioral Suppression
- **Custom Behavior Tree:** Driven by `dummy_scheduler.xml` under a dedicated `dummy_brain` AI switch.
- **Suppressed Panic:** Enclosed within `<EntityContext context="crime_suppressBehavioralReaction">` and `<EntityContext context="crime_preventDespawn">`.
- Dumb Dumb **never flees**, runs away, or panics regardless of how much damage he receives.

### 🎮 In-Game Interaction Prompts (E & V Keys)
Looking at Dumb Dumb displays custom interactive prompts:
- **Press `E` (`use`): "Change Armor Preset"** — Cycles Dumb Dumb's armor preset in real time.
- **Press `V` (`companion_bond`): "Make Hostile" / "Wait Here"** — Toggles Dumb Dumb between two operational modes:
  - **Wait Mode (Neutral - Default):** Dumb Dumb stands completely still, sheathes weapon, and acts as a stationary target.
  - **Hostile Mode (Combat Practice):** Dumb Dumb draws weapon and engages Henry in melee combat for sparring practice (while still never fleeing).

### ⚔️ Curated Armor Presets
Cycles cleanly through 3 distinct armor tiers:
1. **Light Armor:** Light gambeson, coif, and basic protection.
2. **Medium Armor:** Brigandine chest, mail coif, kettle hat, and padded leg protection.
3. **Heavy Full Plate Armor:** Full steel plate cuirass/breastplate, full plate arm & leg harness, padded chausses, hourglass plate gauntlets, mail hauberk & collar, and visored bascinet helmet.

---

## 💻 Console Commands

Open the console in-game (`~`):

| Command | Action |
|---|---|
| `dummy_spawn` *(or `dummy`)* | Toggle spawn / despawn of Dumb Dumb in front of Henry |
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
│   └── dummy.pak                        <-- Compiled engine data pak
└── pak_source/
    ├── AI/
    │   └── dummy_scheduler.xml          <-- No-flee behavior tree (Wait & Hostile states)
    ├── Libs/
    │   ├── Config/
    │   │   └── defaultProfile.xml       <-- Keybind profile mappings
    │   └── tables/
    │       ├── ai/                      <-- Brain, subbrain, & switching XML tables
    │       ├── item/                    <-- Custom heavy full plate clothing preset XML
    │       └── rpg/                     <-- Custom soul & dummyFaction XML tables
    ├── localization/
    │   └── English_xml.xml              <-- English UI localization keys for interaction prompts
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
   - Packs Lua scripts, AI behavior trees, RPG/Item/AI XML tables into `Data/dummy.pak`.
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
