# Dummy — KCD2 Target Dummy Mod

A modular mod for **Kingdom Come: Deliverance II** that spawns a neutral, stationary training dummy named **Dumb Dumb** for combat testing, equipment previewing, and armor preset swapping.

## Features

- **Spawn/Despawn**: Spawn **Dumb Dumb** directly in front of Henry using console command or keybind.
- **Name Tag**: NPC displays **Dumb Dumb** on HUD.
- **Crime-Ignored / Bandit Faction**: Striking or attacking **Dumb Dumb** produces zero reputation penalties and triggers no crime reports.
- **Stationary AI**: Dumb Dumb stays frozen in place where spawned and never flees or follows Henry.
- **Interactive Armor Preset Swapping**: Walk up to Dumb Dumb and press `E` (Use) on the **"Change Armor Preset"** prompt to cycle presets visually on target.
- **Console Commands**:
  - `dummy_spawn` (or `dummy`) — Toggle spawn/despawn
  - `dummy_next` — Cycle armor preset forward
  - `dummy_prev` — Cycle armor preset backward

## Repository Architecture

Refactored following modern KCD2 modular modding conventions (inspired by *Mercenaries*):

```
Dummy/
├── mod.manifest
├── build_pak.bat
├── README.md
├── .gitignore
├── Data/
│   └── dummy.pak
└── pak_source/
    ├── Libs/
    │   └── Config/
    │       └── defaultProfile.xml
    └── Scripts/
        └── mods/
            ├── dummy.lua               <-- Master module entry point & CCommand registry
            ├── dummy_spawning.lua      <-- Spawning, despawning & stationary AI logic
            ├── dummy_equipment.lua     <-- Armor presets & clothing preset equippers
            └── dummy_interaction.lua   <-- Interactor action prompt injection
```

## How to Build

Double-click `build_pak.bat`. It will compress `pak_source` into an engine-compatible `Data/dummy.pak` and automatically copy the mod into your KCD2 `mods/Dummy` directory!

## In-Game Loading

Open console (`~`):
```lua
#Script.ReloadScript("Scripts/Mods/dummy.lua")
```
Or add to your `autoexec.cfg`:
```cfg
#Script.ReloadScript("Scripts/Mods/dummy.lua")
```
