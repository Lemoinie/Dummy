-- E_MarkType -> map-icon basename for the game's DYNAMIC map marks: quest-givers, activity-givers,
-- tipsters, arenas, the barber, the shield-painter and the DLC activity-givers. Unlike the static POIs
-- (baked into minimap_poidata.lua), these are placed live by the game's concept graph on world entities;
-- the companion reads them off the compass and the pak renders them with the game's own glyph
-- (Libs/UI/Textures/Icons/Map/<name>_icon.dds). None of these types appear in the baked POI DB, so
-- showing them is purely additive.
--
-- Basenames resolved against the shipped IPL_GameData.pak icons (the same source tools/bake_poi.py uses);
-- E_MarkType numbering is WHGame's own (tools/bake_poi.py MARK_TYPE_NAME). Racing (86) ships no map icon,
-- so it's omitted; a type with no entry here simply isn't drawn as a giver.
MinimapMarkIcons = MinimapMarkIcons or {
   [4]  = "questGiver",              -- an NPC with a new quest to give
   [5]  = "activityGiver",           -- an NPC with a new activity
   [6]  = "hub",                     -- settlement / hub
   [9]  = "dog",                     -- the dog
   [69] = "skillTeacher",            -- trainer / skill teacher
   [70] = "fightArena",              -- fight arena
   [71] = "poiTipster",              -- reveals POIs on the map
   [78] = "fistFightArena",          -- fist-fight arena
   [81] = "barber",                  -- barber / bathhouse groomer
   [82] = "ShieldPainter",           -- shield painter
   [79] = "DLC0",
   [83] = "DLC1",                    -- Brushes with Death
   [84] = "DLC2",                    -- Legacy of the Forge
   [85] = "DLC3",                    -- Mysteria Ecclesiae
   [87] = "DLC2_smithing",
   [88] = "DLC2_dice",
   [89] = "DLC2_acquiringPackages",
   [90] = "DLC2_archery",
   [91] = "DLC2_donations",
   [92] = "DLC2_duels",
   [93] = "DLC2_stealingPackages",
   [94] = "DLC2_activities",
}

-- "New content" giver types that reach the minimap rim at ANY distance (edge-clamped when out of range),
-- like quest objective markers - so you can head toward a new quest/activity a town over. Everything else
-- in MinimapMarkIcons (services: trainers, barber, shield-painter, arenas, dog) stays nearby, distance-
-- filtered like a POI, to keep the rim uncluttered. E_MarkType keys: QuestGiver(4), ActivityGiver(5), the
-- quest tipster (6 - the "Hub" glyph, what QuestTipster remaps to; confirmed in-game standing on one),
-- PoiTipster(71) + the DLC2 activity-givers(87-94).
MinimapGiverFar = MinimapGiverFar or {
   [4] = true, [5] = true, [6] = true, [71] = true,
   [87] = true, [88] = true, [89] = true, [90] = true, [91] = true, [92] = true, [93] = true, [94] = true,
}
