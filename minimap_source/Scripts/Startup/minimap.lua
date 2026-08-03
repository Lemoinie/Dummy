-- ============================================================================
-- KCD2 Minimap - data engine  (Scripts/Startup/minimap.lua, auto-runs)
--
-- Responsibilities:
--   * start a self-rescheduling poll loop once a game is loaded
--     (the shipping DynamicFog mod proves this pattern works),
--   * read the player's world position + heading every tick,
--   * project world -> map UV with per-level, CALIBRATABLE constants,
--   * assemble a marker list (user waypoints + optional catalog/entities),
--   * push everything to the Flash element "minimap" via UIAction.*,
--   * expose console commands for toggling / zoom / calibration / waypoints.
--
-- All projection math lives here (not in Flash) so alignment can be tuned live
-- in-game without rebuilding the .gfx.  See docs/CALIBRATION.md.
-- ============================================================================

Minimap = Minimap or {}
local M = Minimap

M.ELEMENT  = "minimap"
M.INSTANCE = 0          -- UIElement instance id (see docs if nothing renders: try -1)
M.HUD_ELEMENT = "hud"   -- the vanilla HUD element (HUD.xml); has a "Compass" movieclip
M.HUD_INST = -1         -- -1 = all instances
M.VERSION  = "1.18"

-- ---------------------------------------------------------------------------
-- configuration (persisted to kcd2minimap.cfg via the companion .asi)
-- ---------------------------------------------------------------------------
M.cfg = {
   enabled      = 1,
   uiKey        = "F6",   -- settings-panel hotkey: F1-F12, a single letter, or a VK number. The
                          -- companion reads it (_G.minimap_ui_key); edit it in kcd2minimap.cfg.
   size         = 256,    -- viewport px
   shape        = 0,      -- 0 circle, 1 square
   mapAlpha     = 85,     -- 0..100
   autoDim      = 0,      -- 1 = auto-dim the whole minimap by in-game time of day (so it doesn't glare at night)
   dimNight     = 45,     -- brightness % at deep night when autoDim is on (100 = no dimming)
   rotateMap    = 1,      -- 1 = rotate so facing is up, 0 = north-up
   corner       = 1,      -- 0 TL, 1 TR, 2 BL, 3 BR
   margin       = 24,     -- px from edges
   showPlayer   = 1,      -- draw the player arrow at the centre (0 = hardcore, no "you are here")
   frameStyle   = 0,      -- 0 ornate Apse ring, 1 thin ring, 2 border off
   showNorth    = 1,      -- north marker on/off (the marker art follows the border style)
   showClock    = 1,      -- show the in-game clock (HH:MM) beside the minimap
   showObjDist  = 1,      -- show the distance in metres on each tracked quest/objective icon
   objDistMin   = 0,      -- only label objectives at least this far (metres); 0 = no minimum
   objDistMax   = 0,      -- only label objectives within this range (metres); 0 = no maximum
   aspectAuto   = 1,      -- 1 = auto-fit to the display aspect (the companion reports the output
                          -- resolution; the minimap + panel stay round/true on ultrawide/stretched HUDs)
   aspect       = 100,    -- manual horizontal scale %, used when aspectAuto = 0 (100 = off; 32:9 ~= 50)
   radius       = 160,    -- world metres shown from centre to rim (zoom)
   period       = 80,     -- poll interval ms
   headingOff   = 0,      -- extra deg added to yaw (CompassOffset is folded in via mapRotDeg)
   headingSign  = -1,     -- 1 or -1 (game yaw direction)
   hires        = 1,      -- 1 = stitched high-detail map, 0 = stock overview tile
   hideOnMenu   = 1,      -- 1 = hide while a full-screen menu/UI is open
   hideInDialog = 1,      -- 1 = also hide during dialogue/conversations
   hideInCombat = 0,      -- 1 = hide the minimap while in combat (declutter fights)
   showOnHorse  = 0,      -- 1 = only show the minimap while mounted (auto-hide on foot)
   hideWithHud  = 0,      -- 1 = also hide when the game HUD is off (wh_ui_ShowHud=0). 0 keeps showing, so
                          -- the minimap still appears in Hardcore mode, which disables the HUD by default.
   autocal      = 1,      -- 1 = auto-read WorldCrop from the game's map data
   showCatalog  = 0,      -- static POI catalog markers (needs global calib)
   showLive     = 1,      -- live quest/objective markers from the native plugin
   showUntracked = 0,     -- 0 = tracked quests only (default), 1 = every active quest (companion reads this)
   showPoi      = 1,      -- live POI markers from the native plugin (fallback if no baked data)
   showBaked    = 1,      -- render the baked static POI database (markers on spawn, no map open)
   showGivers   = 1,      -- live quest-giver/activity-giver/tipster/etc. marks from the native plugin (per-type filter via poiOff)
   grayUndisc   = 1,      -- 1 = gray undiscovered POIs like the main map, 0 = all coloured
   hideUndisc   = 0,      -- 1 = hide undiscovered POIs entirely (only show what you've found)
   treasure     = 1,      -- buried-treasure marks: 0 off, 1 discovered only, 2 reveal all (region-wide, greyed until found)
   poiOff       = {},     -- per-icon filter: poiOff[iconBasename]=true hides that POI type (map + rim)
   edgeQuests   = 1,      -- quests/objectives/waypoints beyond range ride the rim (else they clip)
   edgePois     = 1,      -- POIs beyond range ride the rim (bounded by poiRange)
   edgeGivers   = 1,      -- givers/tipsters ride the rim when off-range (else they only show on the map)
   giverRange   = 0,      -- rim distance cap for givers, in metres (0 = no cap; lower it to declutter a busy region)
   hideCompass  = 0,      -- hide the vanilla HUD compass (the minimap rim replaces it)
   poiRange     = 240,    -- show POIs within this many metres of the player (clutter control)
   iconSize     = 16,     -- POI icon size in px (0 = plain dots)
   showEntities = 0,      -- nearby-entity markers
   entityRadius = 120,    -- metres for entity scan
}

-- per-level world->map projection, EXACT from the game's own map config
-- (Libs/Tables/level.xml -> docs/level.xml; the same data ApseMap.gfx consumes via
-- GlobalMapData.SetData / MEnum.GetMapFromWorldCoord). No manual calibration:
--   norm  = ( (x-wc.x)/wc.w , (lvl.y - y - wc.y)/wc.h )
--   pixel = Transformation(norm)   -- createBox(scale,scale,-rot) folds in CompassOffset
--   u,v   = pixel / (tc.w*2048 , tc.h*2048)
-- Bumping CALVER invalidates stale saved (old-affine) calibration.
M.CALVER = 5
M.TILE = 2048
M.levels = {
   -- wc = WorldCrop {MapWorldOrig.x, .y, MapWorldSize.x, .y};  rot = CompassOffset (deg);
   -- lvl = MapLevelSize;  ts = MapTilesSize;  tc = MapTilesCrop {Orig.x,.y, Size.x,.y}
   trosecko    = { wc = {496, 704, 2652, 2652}, rot = 0,  lvl = {4096, 4096}, ts = {3, 3}, tc = {0, 0, 3, 3}, du = 0, dv = 0 },
   kutnohorsko = { wc = {0, 0, 4096, 4096},     rot = 45, lvl = {4096, 4096}, ts = {6, 6}, tc = {0, 1, 6, 5}, du = 0, dv = 0 },
   -- monastery (DLC): the game ships no global_map_klaster detail tiles - that texture is a blank
   -- placeholder - so the real map is the local-map set klaster_1..9, stitched by build_maps.py.
   -- monastery (DLC): a LOCAL map. Its projection isn't shipped in level.xml (that entry describes the
   -- blank global placeholder), but it's still fully derivable from game data - the same way the regions
   -- are - by composing klaster's own level.xml global-map transform (wc/rot/lvl/ts/tc below) with the
   -- ui_local_maps.xml crop of that global-map pixel space (crop = {posX, posY, W, H}). The stitched
   -- klaster_1..9 tiles are the art for that crop. Verified: every monastery POI + MapDefaultPos projects
   -- onto its drawn building. (A manual aff, if ever set via minimap_p1/p2, still overrides this.)
   klaster     = { wc = {0, 0, 2048, 2048},     rot = 45, lvl = {2048, 2048}, ts = {3, 3}, tc = {0, 0, 3, 3},
                   du = 0, dv = 0, crop = {2913, 2148, 1062, 935} },
}
M.levelOrder = { "trosecko", "kutnohorsko", "klaster" }

M.state = {
   running   = false,
   inGame    = false,   -- real gameplay confirmed (event or a live marker feed); gates map visibility
   timerId   = nil,
   level     = "trosecko",   -- the region (from the level cvar)
   localMap  = nil,          -- the detailed town map the player is inside, or nil (region map)
   mapSent   = nil,
   shown     = false,
   px = 0, py = 0, pz = 0, yaw = 0,
   waypoints = {},   -- { {x=,y=,type=,level=}, ... } user-dropped, entity space
   flag = nil,       -- player-placed world-map flag {x=,y=} (via companion minimap_flag), or nil
}

-- ---------------------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------------------
local function log(msg)
   System.LogAlways("[minimap] " .. tostring(msg))
end
M.log = log

local function clamp(v, a, b) if v < a then return a elseif v > b then return b else return v end end

local function getPlayer()
   local p = g_localActor
   if p == nil and Game and Game.GetPlayer then p = Game.GetPlayer() end
   return p
end

-- returns x,y,z metres or nil
local function playerPos()
   local p = getPlayer()
   if not p or not p.GetWorldPos then return nil end
   local ok, pos = pcall(function() return p:GetWorldPos() end)
   if not ok or not pos then return nil end
   return pos.x or pos[1], pos.y or pos[2], pos.z or pos[3]
end

-- true while the player is in combat (soul may be momentarily absent, so pcall-guard it)
local function inCombat()
   local p = getPlayer()
   if not p or not p.soul then return false end
   local ok, v = pcall(function() return p.soul:IsInCombatDanger() end)
   return ok and v == true
end

-- true while the player is mounted (for the "only show on horseback" option). human:IsMounted() is the
-- engine's own check (confirmed in-game: false on foot, true riding); pcall-guard it as human can be
-- briefly absent during transitions.
local function isMounted()
   local p = getPlayer()
   if not p or not p.human or not p.human.IsMounted then return false end
   local ok, v = pcall(function() return p.human:IsMounted() end)
   return ok and v == true
end

-- returns heading degrees (0..360), or nil
local function playerHeadingDeg()
   local p = getPlayer()
   if not p or not p.GetWorldAngles and not p.GetAngles then return nil end
   local ok, ang
   if p.GetWorldAngles then ok, ang = pcall(function() return p:GetWorldAngles() end) end
   if (not ok or not ang) and p.GetAngles then ok, ang = pcall(function() return p:GetAngles() end) end
   if not ok or not ang then return nil end
   local yawRad = ang.z or ang[3] or 0
   local deg = yawRad * 180.0 / math.pi
   deg = deg * M.cfg.headingSign + M.cfg.headingOff
   deg = deg % 360
   if deg < 0 then deg = deg + 360 end
   return deg
end

-- Overall minimap brightness 0..100 for the current in-game hour, when autoDim is on. Full through the
-- day, easing down across dusk to dimNight and back up across dawn. Off (or no clock) -> always 100.
local function timeBrightness()
   if M.cfg.autoDim ~= 1 then return 100 end
   local hod
   if Calendar and Calendar.GetWorldHourOfDay then
      local ok, h = pcall(function() return Calendar.GetWorldHourOfDay() end)
      if ok and type(h) == "number" then hod = h end
   end
   if hod == nil then return 100 end
   local lo = M.cfg.dimNight or 45
   if lo < 10 then lo = 10 elseif lo > 100 then lo = 100 end
   local function lerp(a, b, t) return a + (b - a) * t end
   if hod >= 7 and hod < 20 then return 100                        -- daytime: full brightness
   elseif hod >= 22 or hod < 5 then return lo                      -- deep night: dimmed
   elseif hod >= 20 then return lerp(100, lo, (hod - 20) / 2.0)    -- dusk 20:00 -> 22:00
   else return lerp(lo, 100, (hod - 5) / 2.0) end                  -- dawn 05:00 -> 07:00
end

-- In-game wall clock "HH:MM" from the game's own Calendar bind (24h, floored the same way the game's
-- TimeUtils.ConvertDecimalHoursToDigitalTimeOfDay does). Pak-only - reads the world clock directly, so
-- it needs no companion and tracks time skips (sleeping/waiting) exactly. nil if the bind isn't up yet.
local function worldClockStr()
   if not (Calendar and Calendar.GetWorldHourOfDay) then return nil end
   local ok, hod = pcall(function() return Calendar.GetWorldHourOfDay() end)
   if not ok or type(hod) ~= "number" then return nil end
   local secs = math.floor(hod * 3600)
   return string.format("%02d:%02d", math.floor(secs / 3600) % 24, math.floor(secs / 60) % 60)
end

-- ---------------------------------------------------------------------------
-- persistence (kcd2minimap.cfg, written by the companion .asi)
-- ---------------------------------------------------------------------------

-- normalise a settings-panel hotkey token: F1-F12, a single letter, or a decimal virtual-key code.
-- Returns the canonical upper-case token, or nil if it isn't a key (the companion re-validates too).
local function normalizeKey(s)
   s = tostring(s or ""):gsub("%s+", ""):upper()
   if s:match("^F%d%d?$") then local n = tonumber(s:sub(2)); if n and n >= 1 and n <= 12 then return s end
   elseif s:match("^%a$") then return s
   elseif s:match("^%d+$") then local n = tonumber(s); if n and n > 0 and n < 256 then return s end
   end
   return nil
end

-- serialise the user-facing settings to a "key=value" text block. The companion writes this to
-- kcd2minimap.cfg, so settings persist + are editable outside the game without kcd2db. Only plain
-- scalars, the panel hotkey and the poiOff set are stored (calibration is baked; hires/shape forced).
function M.SerializeCfg()
   local lines = {}
   for k, v in pairs(M.cfg) do
      if k == "enabled" then
         -- session-only console toggle (minimap_toggle); never persisted, so a stale kcd2minimap.cfg
         -- can't leave the map switched off after an update - it always defaults back on
      elseif k == "uiKey" and type(v) == "string" then lines[#lines + 1] = "uiKey=" .. v
      elseif type(v) == "number" then lines[#lines + 1] = k .. "=" .. tostring(v)
      elseif type(v) == "boolean" then lines[#lines + 1] = k .. "=" .. (v and "1" or "0")
      elseif k == "poiOff" and type(v) == "table" then
         local offs = {}
         for icon, hidden in pairs(v) do if hidden then offs[#offs + 1] = icon end end
         table.sort(offs)
         lines[#lines + 1] = "poiOff=" .. table.concat(offs, ",")
      end
   end
   table.sort(lines)
   return table.concat(lines, "\n")
end

function M.SaveCfg()
   _G.minimap_show_untracked = (M.cfg.showUntracked == 1) and "1" or "0"   -- companion reads this each sync
   _G.minimap_ui_key = M.cfg.uiKey or "F6"   -- companion reads this to bind the settings-panel hotkey
   _G.minimap_cfg_out = M.SerializeCfg()   -- the companion picks this up and writes the config file
end

-- apply a "key=value" text block from the config file (called by the companion). Overrides defaults/db.
function minimap_loadcfg(text)
   if type(text) ~= "string" then return end
   for line in text:gmatch("[^\r\n]+") do
      local k, val = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
      if k == "poiOff" then
         M.cfg.poiOff = {}
         for icon in (val or ""):gmatch("[^,]+") do M.cfg.poiOff[icon] = true end
      elseif k == "enabled" then
         -- ignore: session-only console toggle, always defaults on (see SerializeCfg). Skipping it
         -- here neutralises any stale enabled=0 left in an old config from a previous build/session.
      elseif k and k:lower() == "uikey" then
         local nk = normalizeKey(val); if nk then M.cfg.uiKey = nk end   -- panel hotkey (companion binds it)
      elseif k and val and type(M.cfg[k]) == "number" then
         local n = tonumber(val); if n then M.cfg[k] = n end
      end
   end
   M.cfg.hires = 1; M.cfg.shape = 0   -- forced regardless of the file
   if M.cfg.poiRange and M.cfg.poiRange < 20 then M.cfg.poiRange = 240 end   -- migrate the old zoom-multiple to metres
   _G.minimap_show_untracked = (M.cfg.showUntracked == 1) and "1" or "0"   -- apply the loaded value for the companion
   _G.minimap_ui_key = M.cfg.uiKey or "F6"                                 -- apply the loaded hotkey for the companion
   pcall(function() M.PushConfig() end)   -- re-apply size/corner/etc. to the live view
   _G.minimap_cfg_out = M.SerializeCfg()  -- normalise the file back (drops junk / unknown keys)
end

function M.LoadCfg()
   -- Settings come from kcd2minimap.cfg via the companion (minimap_loadcfg, applied a moment after
   -- load). Calibration is baked into M.levels; discovered state is re-read live from the game.
   -- Here we only pin the two forced values.
   M.cfg.hires = 1   -- always high-detail map (no longer user-toggleable)
   M.cfg.shape = 0   -- always a circle (no longer user-toggleable)
end

-- ---------------------------------------------------------------------------
-- level detection
-- ---------------------------------------------------------------------------
-- the engine cvars that actually hold the loaded level (verified present in WHGame.dll)
local LEVEL_CVARS = { "mapname", "sv_map" }

-- returns the raw level string + the source it came from, or nil
local function rawLevelName()
   if System and System.GetCVar then
      for _, cv in ipairs(LEVEL_CVARS) do
         local ok, v = pcall(function() return System.GetCVar(cv) end)
         if ok and v ~= nil and tostring(v) ~= "" then return tostring(v), cv end
      end
   end
   if GameToken and GameToken.GetToken then
      local ok, v = pcall(function() return GameToken.GetToken("Game.Global.Previous_Level") end)
      if ok and v ~= nil and tostring(v) ~= "" then return tostring(v), "token:Previous_Level" end
   end
   return nil, nil
end

local function matchLevel(name)
   if not name then return nil end
   name = string.lower(name)
   for _, lv in ipairs(M.levelOrder) do
      if string.find(name, lv, 1, true) then return lv end
   end
   if string.find(name, "tros", 1, true) then return "trosecko" end
   if string.find(name, "kutn", 1, true) or string.find(name, "kutt", 1, true) then return "kutnohorsko" end
   if string.find(name, "klaster", 1, true) or string.find(name, "monast", 1, true) then return "klaster" end
   return nil
end

-- returns matched level id, raw string, source
local function detectLevel()
   local raw, src = rawLevelName()
   return matchLevel(raw), raw, src
end

-- ---------------------------------------------------------------------------
-- projection
-- ---------------------------------------------------------------------------
-- synthetic per-town-map cfgs: the region's global transform (wc/rot/lvl/ts/tc) + the town map's crop.
-- Built lazily from MinimapLocalMaps + cached, so a town map projects exactly like the region does,
-- just cropped to its tiles.
M.localCfg = {}
local function levelCfg()
   local lm = M.state.localMap
   if lm and type(MinimapLocalMaps) == "table" and MinimapLocalMaps[lm] then
      local c = M.localCfg[lm]
      if not c then
         local d = MinimapLocalMaps[lm]
         local base = M.levels[d.region] or M.levels.trosecko
         c = { wc = base.wc, rot = base.rot, lvl = base.lvl, ts = base.ts, tc = base.tc,
               du = 0, dv = 0, crop = d.crop }
         M.localCfg[lm] = c
      end
      return c
   end
   return M.levels[M.state.level] or M.levels.trosecko
end

-- Build the exact world->map transform for a level cfg (replicates the AS2 GlobalMapData.SetData:
-- a unit square rotated by CompassOffset, scaled to fit the tile grid, offset by the crop).
local function computeT(L)
   local TILE = M.TILE or 2048
   local rot = -(L.rot or 0) * math.pi / 180
   local cq, sq = math.cos(rot), math.sin(rot)
   -- corners of the unit square under createBox(1,1,rot): tp(x,y)=(cq*x-sq*y, sq*x+cq*y)
   local cx = { 0, cq, cq - sq, -sq }
   local cy = { 0, sq, sq + cq, cq }
   local minX = math.min(cx[1], cx[2], cx[3], cx[4])
   local maxX = math.max(cx[1], cx[2], cx[3], cx[4])
   local minY = math.min(cy[1], cy[2], cy[3], cy[4])
   local maxY = math.max(cy[1], cy[2], cy[3], cy[4])
   local sx = L.ts[1] * TILE / math.abs(maxX - minX)
   local sy = L.ts[2] * TILE / math.abs(maxY - minY)
   local tx = -minX * sx - L.tc[1] * TILE
   local ty = -minY * sy - L.tc[2] * TILE
   return {
      -- Transformation = createBox(sx, sy, rot, tx, ty)
      a = sx * cq, b = sx * sq, c = -sy * sq, d = sy * cq, tx = tx, ty = ty,
      mapW = L.tc[3] * TILE, mapH = L.tc[4] * TILE,
      sx = sx, wx = L.wc[1], wy = L.wc[2], ww = L.wc[3], wh = L.wc[4], lvlY = L.lvl[2],
      crop = L.crop,   -- local maps: a {posX,posY,W,H} sub-rectangle of the global-map px space
   }
end

-- transform for the active map (town or region), cached on its cfg
local function levelTransform()
   local L = levelCfg()
   if not L._T then L._T = computeT(L) end
   return L
end

-- world -> map UV (0..1) from the engine's own projection (level.xml). Local-map levels (the
-- monastery) compose an extra ui_local_maps crop step; a manual affine still overrides both.
local function worldToUV(x, y)
   local L = levelCfg()
   local A = L.aff
   if A then
      return A[1] * x + A[2] * y + A[5] + (L.du or 0),
             A[3] * x + A[4] * y + A[6] + (L.dv or 0)
   end
   L = levelTransform()
   local T = L._T
   local nx = (x - T.wx) / T.ww
   local ny = (T.lvlY - y - T.wy) / T.wh
   local px = T.a * nx + T.c * ny + T.tx
   local py = T.b * nx + T.d * ny + T.ty
   if T.crop then   -- local map: the tiles are a crop [posX,posY]+[W,H] of the global-map px space
      return (px - T.crop[1]) / T.crop[3] + (L.du or 0),
             (py - T.crop[2]) / T.crop[4] + (L.dv or 0)
   end
   return px / T.mapW + (L.du or 0), py / T.mapH + (L.dv or 0)
end

-- the map's intrinsic rotation (deg), folded into the heading so map and markers rotate
-- together. Regional = CompassOffset (MEnum.GetMapFromWorldAzimuth = azimuth + Rotation);
-- affine = the angle of world +X in UV space.
local function mapRotDeg()
   local L = levelCfg()
   if L.aff then return -math.deg(math.atan2(L.aff[3], L.aff[1])) end
   return -(L.rot or 0)
end

-- world metres across the full map texture width, for zoom
local function mapSpanMetres()
   local L = levelCfg()
   if L.aff then
      local uvpm = math.sqrt(L.aff[1] * L.aff[1] + L.aff[3] * L.aff[3])   -- UV per world metre
      if uvpm <= 0 then return 8192 end
      return 1.0 / uvpm                                                   -- metres across the image (UV width 1)
   end
   local T = levelTransform()._T
   local ppm = T.sx / T.ww          -- pixels per world metre
   if ppm <= 0 then return 8192 end
   if T.crop then return T.crop[3] / ppm end   -- local map spans the crop width (global px) in metres
   return T.mapW / ppm
end

-- ---------------------------------------------------------------------------
-- detailed town maps: swap to the close-up map when inside a town's area
-- ---------------------------------------------------------------------------
-- the player's pixel position in the CURRENT REGION's global-map image (pre-crop). Town-map crops +
-- trigger areas are in this frame, so we hit-test against it. Uses the region transform, never a town's.
local function regionGlobalPx(x, y)
   local R = M.levels[M.state.level]
   if not R then return nil end
   if not R._T then R._T = computeT(R) end
   local T = R._T
   local nx = (x - T.wx) / T.ww
   local ny = (T.lvlY - y - T.wy) / T.wh
   return T.a * nx + T.c * ny + T.tx, T.b * nx + T.d * ny + T.ty
end

-- point-in-polygon (ray cast) over a flat {x1,y1,x2,y2,...} ring
local function pointInPoly(x, y, poly)
   local n = #poly
   if n < 6 then return false end
   local inside = false
   local jx, jy = poly[n - 1], poly[n]
   for i = 1, n, 2 do
      local ix, iy = poly[i], poly[i + 1]
      if ((iy > y) ~= (jy > y)) and (x < (jx - ix) * (y - iy) / (jy - iy) + ix) then
         inside = not inside
      end
      jx, jy = ix, iy
   end
   return inside
end

-- Interior maps (the monastery) overlay the whole region footprint, so a 2D bounds test can't tell them
-- apart from outside. They carry the game's own "inside" polygons (the SmartAreaShapes named
-- ...locationInsideMonasteryMapArea, baked into the manifest); the player is inside if within any of them.
local function pointInAnyArea(x, y, areas)
   if type(areas) ~= "table" then return false end
   for _, poly in ipairs(areas) do
      if pointInPoly(x, y, poly) then return true end
   end
   return false
end

-- the detailed local map the player is inside (smallest active area wins if they overlap), or nil.
-- interior-overlay maps (inside==1) additionally require the engine "inside" signal.
local function detectLocalMap(x, y)
   if type(MinimapLocalMaps) ~= "table" then return nil end
   local gx, gy = regionGlobalPx(x, y)
   if not gx then return nil end
   local best, bestArea
   for name, d in pairs(MinimapLocalMaps) do
      if d.region == M.state.level and d.active then
         local ax, ay, aw, ah, ell = d.active[1], d.active[2], d.active[3], d.active[4], d.active[5]
         local inside
         if ell == 1 then
            local rx, ry = aw * 0.5, ah * 0.5
            local ex, ey = (gx - (ax + rx)) / rx, (gy - (ay + ry)) / ry
            inside = (ex * ex + ey * ey) <= 1
         else
            inside = gx >= ax and gx <= ax + aw and gy >= ay and gy <= ay + ah
         end
         if inside and d.inside == 1 then inside = pointInAnyArea(x, y, d.inside_areas) end   -- building-interior overlay
         if inside and (not bestArea or aw * ah < bestArea) then best, bestArea = name, aw * ah end
      end
   end
   return best
end

-- optional fine-tune nudge (du,dv); the transform is exact so this is rarely needed.
local function recenterTo(pu, pv)
   local x, y = playerPos()
   if not x then return false end
   local L = levelTransform()
   local bu, bv = worldToUV(x, y)
   L.du = (L.du or 0) + (pu - bu)
   L.dv = (L.dv or 0) + (pv - bv)
   return true
end

-- Read the game's own map calibration (WorldCrop + LevelSize) out of the data the
-- engine pushes to the ApseMap element (the g_GlobalMapA array). Layout, from
-- GlobalMapData.SetData (0-based): [4,5]=LevelSize, [6,7,8,9]=WorldCrop(x,y,w,h).
-- Lua arrays are 1-based, so we read [5..10]. Available once the world map UI has
-- been initialised (open the map once if it hasn't fired). minimap_dumpmap shows
-- the raw array if the indices need adjusting.
-- try a few element/instance/name combinations; the engine populates this only
-- while the world map UI is active, so the poll loop keeps probing until it sees data
local function readGlobalMapArray()
   if not (UIAction and UIAction.GetArray) then return nil end
   local combos = {
      { "ApseMap", -1, "GlobalMap" }, { "ApseMap", 0, "GlobalMap" },
      { "ApseMap", -1, "g_GlobalMapA" }, { "ApseMap", 0, "g_GlobalMapA" },
   }
   for _, c in ipairs(combos) do
      local a
      local ok = pcall(function() a = UIAction.GetArray(c[1], c[2], c[3]) end)
      if ok and type(a) == "table" and #a > 0 then return a end
   end
   return nil
end

-- NOTE: UIAction.GetArray returns the engine's GlobalMap array as EMPTY even with
-- the world map open (the engine pushes it straight to Flash, bypassing Lua), so
-- automatic calibration is not possible. Kept only as a diagnostic.
function M.TryAutoCal()
   local arr = readGlobalMapArray()
   if not arr then return false end
   local s = ""
   for i = 1, math.min(#arr, 20) do s = s .. "[" .. i .. "]=" .. tostring(arr[i]) .. " " end
   log("GlobalMap array n=" .. #arr .. " :: " .. s)
   return false
end

-- ---------------------------------------------------------------------------
-- discovered-POI tracking
-- ---------------------------------------------------------------------------
-- The baked static POIs (MinimapPOIData) carry no per-save discovered state, so we track it ourselves
-- for the session: a POI greys out (undiscovered) until the player gets within its discovery radius, OR
-- the native map feed reports it discovered. Not persisted - the game exposes no per-save baked-POI
-- discovery to read back, so it's re-derived live each session. Greys/colours baked POIs like the main map.
M.disc = {}   -- { [level] = { ["floorX,floorY"] = true } }  (session-only, not persisted)
local function discKey(x, y) return math.floor(x) .. "," .. math.floor(y) end
local function isDiscovered(level, x, y) local s = M.disc[level]; return s ~= nil and s[discKey(x, y)] == true end
local function markDiscovered(level, x, y)
   local s = M.disc[level]; if not s then s = {}; M.disc[level] = s end
   s[discKey(x, y)] = true
end

-- Treasure sites are gated on the player having the corresponding treasure map (found + read it), not on
-- the game's POI-discovered state (reading a map reveals nothing on the world map - "GPS won't work"). We
-- read the game's own inventory + document-read binds: g_localActor.inventory:GetCountOfClass(guid) and
-- Minigame.WasBookOpened(guid) (see native/asi/re/WHGame-1.5.6.md, treasure section). M.state.treasureOwned
-- is the cached { [mapGuid] = true } set, refreshed on a throttle (inventory changes slowly).
function M.TreasureOwned(guids)
   if not guids or guids == "" then return false end
   local owned = M.state.treasureOwned
   if not owned then return false end
   for g in guids:gmatch("[^;]+") do if owned[g] then return true end end
   return false
end
function M.RefreshTreasureOwned(verbose)
   local owned = {}
   local act = rawget(_G, "g_localActor")
   local inv = act and act.inventory
   local mg  = rawget(_G, "Minigame")
   local baked = MinimapPOIData and MinimapPOIData[M.state.level]
   if type(baked) == "table" then
      local seen = {}
      for i = 1, #baked do
         local r = baked[i]
         if r[5] == 4 and r[6] then
            for guid in r[6]:gmatch("[^;]+") do
               if not seen[guid] then
                  seen[guid] = true
                  local held, read = 0, nil
                  if inv and inv.GetCountOfClass then
                     local ok, c = pcall(function() return inv:GetCountOfClass(guid) end)
                     if ok and type(c) == "number" then held = c end
                  end
                  if mg and mg.WasBookOpened then
                     local ok, b = pcall(function() return mg.WasBookOpened(guid) end)
                     if ok then read = b end
                  end
                  if (held > 0) or (read == true) then owned[guid] = true end
                  if verbose then
                     log(string.format("  treasure map %s… : count=%s read=%s -> %s",
                        guid:sub(1, 8), tostring(held), tostring(read), owned[guid] and "SHOWN" or "hidden"))
                  end
               end
            end
         end
      end
   end
   M.state.treasureOwned = owned
   return owned
end

-- ---------------------------------------------------------------------------
-- markers
-- ---------------------------------------------------------------------------
-- assemble flat array [n, u,v,type, ...] for the visible markers
local function buildMarkers()
   local out = {}       -- flat {u,v,type, ...}
   local icons = {}     -- parallel icon name per marker ("" = a coloured dot)
   local n = 0
   local maxN = 160
   -- each flash "icon" entry is "iconName,letter,id" then optional positional fields: [3]=dist(m) [4]=radiusUV
   -- [5]=poly. letter = quest objective char (""=none); edge tags "ride the rim when out of range" (flash reads
   -- it as type+100); dist = metres to the marker (quest markers only, ""=none); radiusUV = search-area radius
   -- in map-UV (Flash draws a circle fallback); poly = the exact outline as UV offsets "du_dv;du_dv;...".
   local function add(u, v, t, icon, letter, edge, id, radiusUV, polyStr, dist)
      out[#out+1] = u; out[#out+1] = v; out[#out+1] = (edge and (t + 100) or t)
      local e = (icon or "") .. "," .. (letter or "") .. "," .. (id or "")
      -- emit up to the last present field, so a plain marker stays 3 fields (unchanged); dist holds the
      -- [3] slot (even as "") whenever an area marker needs radiusUV/poly to stay at [4]/[5].
      local hasArea = (radiusUV and radiusUV > 0) or polyStr
      if dist or hasArea then e = e .. "," .. (dist and tostring(dist) or "") end
      if hasArea then
         e = e .. "," .. string.format("%.5f", radiusUV or 0)
         if polyStr then e = e .. "," .. polyStr end
      end
      icons[#icons+1] = e
      n = n + 1
   end
   local edgeQ = M.cfg.edgeQuests == 1
   local edgeP = M.cfg.edgePois == 1

   -- user waypoints (entity space; always aligned with the player feed)
   for _, w in ipairs(M.state.waypoints) do
      if (not w.level or w.level == M.state.level) and n < maxN then
         local u, v = worldToUV(w.x, w.y)
         add(u, v, w.type or 4, "", nil, edgeQ)
      end
   end

   -- player-placed world-map flag (right-click waypoint, fed by the companion). Uses the game's own
   -- checkpoint flag icon; edge-clamped so it rides the rim as a navigation aid when off the minimap.
   -- (type 8 -> red dot fallback in dots mode / if the icon can't load.)
   if M.state.flag and n < maxN then
      local u, v = worldToUV(M.state.flag.x, M.state.flag.y)
      add(u, v, 8, "checkpoint", nil, true, "flag")
   end

   -- static POI catalog (global-space coords -> world via per-level globalcal)
   if M.cfg.showCatalog == 1 and MinimapData and MinimapData.catalog then
      local cat = MinimapData.catalog[M.state.level]
      local gc  = MinimapData.globalCal and MinimapData.globalCal[M.state.level]
      if cat and gc then
         for _, poi in ipairs(cat) do
            if n >= maxN then break end
            local wx = (poi.x - gc.offx) / gc.scale
            local wy = (poi.y - gc.offy) / gc.scale
            local u, v = worldToUV(wx, wy)
            add(u, v, poi.type or 0, "", nil, edgeP)
         end
      end
   end

   -- LIVE quest markers from the native plugin, rendered with the game's own quest icon
   -- (quest_<type>_<colour>). _G.minimap_live_markers = { {x,y,type,icon}, ... }
   if M.cfg.showLive == 1 and type(_G.minimap_live_markers) == "table" then
      local lm = _G.minimap_live_markers
      for i = 1, #lm do
         if n >= maxN then break end
         local m = lm[i]
         if m and m.x then
            local u, v = worldToUV(m.x, m.y)
            -- area objectives carry a search radius (metres): convert to a UV radius via the same
            -- projection (isotropic per level), so Flash can scale the circle fallback with the map.
            local ruv = 0
            if m.areaR and m.areaR > 0 then
               local u2, v2 = worldToUV(m.x + m.areaR, m.y)
               local du, dv = u2 - u, v2 - v
               ruv = math.sqrt(du * du + dv * dv)
            end
            -- exact outline: project each world vertex to UV and pass it as an offset from the centre,
            -- so Flash draws the real polygon (same map-space frame as the markers).
            local polyStr
            if m.poly and #m.poly >= 3 then
               local parts = {}
               for i2 = 1, #m.poly do
                  local pu, pv = worldToUV(m.poly[i2].x, m.poly[i2].y)
                  parts[i2] = string.format("%.5f_%.5f", pu - u, pv - v)
               end
               -- ";" between points, NOT "|": the whole icon list is sent to Flash "|"-joined, so a "|"
               -- inside a polygon would split into extra entries and misalign every later marker's icon.
               polyStr = table.concat(parts, ";")
            end
            local dm
            if M.cfg.showObjDist == 1 and M.state.px then
               local ddx, ddy = m.x - M.state.px, m.y - M.state.py
               local d = math.sqrt(ddx * ddx + ddy * ddy)
               local lo = M.cfg.objDistMin or 0
               local hi = M.cfg.objDistMax or 0
               if d >= lo and (hi <= 0 or d <= hi) then
                  dm = math.floor(d / 5 + 0.5) * 5   -- metres to this objective, nearest 5
               end
            end
            add(u, v, m.type or 1, m.icon or "", m.letter or "", edgeQ, m.id, ruv, polyStr, dm)
         end
      end
   end

   -- POI markers. Primary source is the BAKED static database (MinimapPOIData) extracted
   -- from the game's whdata: full region POI set with the game's own map icons, available
   -- on spawn with no map-open. Undiscovered POIs grey out (see discovery tracking above).
   -- Falls back to the live native POI feed for any region without baked data.
   --   record = { worldX, worldY, iconBasename, discoveryDist, category }
   local baked = type(MinimapPOIData) == "table" and MinimapPOIData[M.state.level]
   local px, py = M.state.px, M.state.py
   local maxD  = M.cfg.poiRange or 240   -- absolute metres: show POIs within this distance of the player
   local maxD2 = maxD * maxD
   local tmode = M.cfg.treasure or 0   -- buried treasure: 0 off, 1 discovered only, 2 reveal all
   if type(baked) == "table" and px and (M.cfg.showBaked == 1 or tmode > 0) then
      local level = M.state.level
      local off = M.cfg.poiOff or {}
      local pois = (M.cfg.showBaked == 1)
      for i = 1, #baked do
         if n >= maxN then break end
         local r = baked[i]
         local rx, ry = r[1], r[2]
         local dx, dy = rx - px, ry - py
         local d2 = dx * dx + dy * dy
         if r[5] == 4 then   -- buried treasure: gated on owning its map, shown region-wide (rim-clamped)
            if tmode > 0 then
               local owned = M.TreasureOwned(r[6])   -- r[6] = ";"-joined map GUIDs (nil/"" = no collectible map)
               if tmode == 2 or owned then   -- reveal all: every site; discovered: only sites whose map you have
                  local icon = owned and "treasure" or "treasure_undiscovered"   -- grey = you don't have the map
                  local u, v = worldToUV(rx, ry)
                  add(u, v, 6, icon, "", true, math.floor(rx) .. "_" .. math.floor(ry))
               end
            end
         elseif pois and not off[r[3]] and d2 <= maxD2 then   -- r[3] = icon basename; per-type filter + range
            local dd = r[4] or 15
            if d2 <= dd * dd then markDiscovered(level, rx, ry) end   -- proximity reveal
            local known = isDiscovered(level, rx, ry)
            if known or M.cfg.hideUndisc ~= 1 then
               local disc = known or (M.cfg.grayUndisc ~= 1)
               local icon = disc and r[3] or (r[3] .. "_undiscovered")
               local u, v = worldToUV(rx, ry)
               -- stable id = world position (comma-free), so the clip is reused across map switches
               -- (interior<->grounds, town<->region) instead of reloading its icon = no dot flash.
               add(u, v, 6, icon, "", edgeP, math.floor(rx) .. "_" .. math.floor(ry))
            end
         end
      end
   elseif M.cfg.showPoi == 1 and type(_G.minimap_poi_markers) == "table" and px then
      local pm = _G.minimap_poi_markers
      for i = 1, #pm do
         if n >= maxN then break end
         local p = pm[i]
         if p and not (M.cfg.poiOff and M.cfg.poiOff[p.icon]) then
            local dx, dy = p.x - px, p.y - py
            if dx * dx + dy * dy <= maxD2 then
               local u, v = worldToUV(p.x, p.y)
               add(u, v, p.type or 6, p.icon, p.letter, edgeP, math.floor(p.x) .. "_" .. math.floor(p.y))
            end
         end
      end
   end

   -- LIVE giver/tipster markers (quest-givers, activity-givers, tipsters, arenas, barber, ...) from the
   -- native compass feed. MinimapMarkIcons maps the E_MarkType to the game's own map icon; drawn like a POI
   -- (type 6), distance-filtered and per-type filterable via poiOff (keyed by icon basename, so the F6 POI
   -- filters + the "Givers & tipsters" group toggle them). Additive: these types are never in the baked DB.
   if M.cfg.showGivers == 1 and type(_G.minimap_giver_markers) == "table"
      and type(MinimapMarkIcons) == "table" and px then
      local gm  = _G.minimap_giver_markers
      local off = M.cfg.poiOff or {}
      local farSet = (type(MinimapGiverFar) == "table") and MinimapGiverFar or {}
      local edgeG = M.cfg.edgeGivers == 1
      local gcap = M.cfg.giverRange or 0
      local giverCap2 = (gcap > 0) and (gcap * gcap) or nil   -- rim distance cap (metres^2); nil = no cap
      for i = 1, #gm do
         if n >= maxN then break end
         local g = gm[i]
         local icon = g and MinimapMarkIcons[g.type]   -- nil for a non-giver type -> skip (no baked dup)
         if icon and not off[icon] then
            -- "new content" givers (quest/activity givers, tipsters) can ride the rim so you can navigate to
            -- a far new quest; services stay nearby (distance-filtered like a POI). The rim is opt-out
            -- (edgeGivers) and distance-capped (giverRange metres), so a quest-dense region like Kuttenberg
            -- doesn't flood the edge.
            local far = farSet[g.type] == true
            local dx, dy = g.x - px, g.y - py
            local d2 = dx * dx + dy * dy
            local rim = far and edgeG and (giverCap2 == nil or d2 <= giverCap2)   -- far giver rides the rim
            if rim or d2 <= maxD2 then
               local u, v = worldToUV(g.x, g.y)
               -- off-circle -> rim only when edgeGivers is on (far: within giverRange; near/service: like a POI)
               local giverEdge = (far and rim) or (not far and edgeG)
               -- id = position+icon so a giver keeps its clip (most givers are static NPCs/locations)
               add(u, v, 6, icon, "", giverEdge, math.floor(g.x) .. "_" .. math.floor(g.y) .. "_" .. icon)
            end
         end
      end
   end

   -- nearby entities (entity space)
   if M.cfg.showEntities == 1 and System and System.GetEntitiesInSphere then
      local cx, cy, cz = M.state.px, M.state.py, M.state.pz
      local ok, ents = pcall(function() return System.GetEntitiesInSphere({ x=cx, y=cy, z=cz }, M.cfg.entityRadius) end)
      if ok and type(ents) == "table" then
         for _, e in ipairs(ents) do
            if n >= maxN then break end
            local ep = e.GetWorldPos and e:GetWorldPos()
            if ep then
               local u, v = worldToUV(ep.x or ep[1], ep.y or ep[2])
               add(u, v, 2, "")
            end
         end
      end
   end

   table.insert(out, 1, n)
   return out, icons
end

-- ---------------------------------------------------------------------------
-- Flash bridge
-- ---------------------------------------------------------------------------
local function ui_call(fn, ...)
   if not UIAction then return end
   local args = { ... }
   local n = select("#", ...)
   pcall(function()
      UIAction.CallFunction(M.ELEMENT, M.INSTANCE, fn, unpack(args, 1, n))
   end)
end

-- The engine renders the HUD for a 16:9 reference and stretches that surface to fill the screen, so
-- on any other display aspect a drawn circle composites as an oval. We counter-scale the whole UI
-- horizontally by design_aspect / screen_aspect: 1.0 at 16:9 (no-op), 0.5 at 32:9, etc. The screen
-- resolution is ground truth the pak can't see (Stage reports the pre-stretch surface), so the .asi
-- reports it via minimap_screen(); with no companion / no report yet we fall back to the manual value.
M.DESIGN_ASPECT = 16 / 9
function M.EffAspect()
   if (M.cfg.aspectAuto or 0) == 1 then
      local w, h = M.state.screenW, M.state.screenH
      if w and h and h > 0 then
         return clamp(math.floor(M.DESIGN_ASPECT / (w / h) * 100 + 0.5), 25, 400)
      end
   end
   return clamp(M.cfg.aspect or 100, 25, 400)
end

function M.PushConfig()
   if not UIAction then return end
   pcall(function() UIAction.ShowElement(M.ELEMENT, M.INSTANCE) end)
   ui_call("MinimapConfig", M.cfg.size, M.cfg.shape, M.cfg.mapAlpha, M.cfg.rotateMap, M.cfg.corner, M.cfg.margin, M.cfg.iconSize, M.cfg.showPlayer, M.cfg.frameStyle, M.cfg.showNorth, M.EffAspect())
   M.state.mapSent = nil  -- force map reload
   M.ApplyCompass()
   M.PushDim(true)        -- (re)apply the time-of-day brightness (covers an autoDim toggle from F6)
   M.PushClock(true)      -- (re)apply the clock (covers a showClock toggle from F6 + the initial push)
end

-- Push the current time-of-day brightness to Flash, on change (or forced). Called ~1s from the tick and
-- on any config change; the dim rides on the whole minimap clip so markers + border fade together.
function M.PushDim(force)
   local b = math.floor(timeBrightness() + 0.5)
   if force or b ~= M.state.dimPct then M.state.dimPct = b; ui_call("MinimapDim", b) end
end

function M.PushShow(v)
   M.state.shown = v
   ui_call("MinimapShow", v and 1 or 0)
   -- the clock plaque is part of the frame clip, so it hides/shows with the map automatically
end

-- Push the in-game time to the clock plaque mounted on the minimap frame, on change (or forced). "" hides
-- the plaque (showClock off / not in game). The plaque is part of the frame clip, so it rides the frame's
-- own night-dimming and hides with the map. The objective distance now rides each quest icon (buildMarkers).
function M.PushClock(force)
   local s = ""
   if M.cfg.showClock == 1 and M.state.shown and M.cfg.enabled == 1 then s = worldClockStr() or "" end
   if force or s ~= M.state.clockText then M.state.clockText = s; ui_call("MinimapClock", s) end
end

-- on-screen warning shown when the native companion (.asi) never checks in. It's not a permanent
-- fixture: it appears, counts down and auto-hides (the countdown makes clear it's temporary), so
-- someone running without the companion isn't nagged every session. The map works without it.
M.NOTICE    = "Minimap companion (version.dll) required.\nThe F6 menu, live quest/POI markers and discovered locations need it. See the mod page for install instructions."
M.NOTICE_MS = 20000   -- how long the notice stays up after it first appears

-- Push the notice text to Flash, but only when it changes (the countdown rewrites it once a second).
-- nil / "" hides it.
function M.SetNotice(text)
   local s = text or ""
   if s == M.state.noticeText then return end
   M.state.noticeText = s
   M.state.noticeOn   = (s ~= "")
   ui_call("Notice", s)
end

-- Hide/show the vanilla HUD compass.
--
-- The engine keeps a visibility cvar per HUD element: "wh_ui_Show" .. element name, int, default 1,
-- built and owned by C_UIHudMask. It ANDs it into its own apply pass (IsElementVisible(id) =
-- m_visibleBits[id] and cvar ~= 0, result pushed to the HUD clip of that name), and re-runs that pass
-- on every UI change. Compass is element 0, so wh_ui_ShowCompass=0 makes the GAME keep its own compass
-- hidden and there is nothing left for us to re-assert.
--
-- The old way - poking the "Compass" clip with UIAction.SetVisible - only overwrote the state the
-- engine had just written, so anything that re-showed the HUD put the compass back until the ~1s
-- re-assert in Tick caught it: the "compass flashes up for half a second after quest dialogue" report.
-- Traced in-game: ending a dialogue clears the engine's Dialog UI source, which re-derives the hud mask
-- and brings the full gameplay HUD back with the compass bit set ~290ms later, and the old re-assert
-- then took up to another ~960ms to put it away. Kept below as the fallback for a build with no cvar.
M.COMPASS_CVAR = "wh_ui_ShowCompass"

local function cvarNum(name)
   if not (System and System.GetCVar) then return nil end
   local ok, v = pcall(function() return System.GetCVar(name) end)
   if not ok then return nil end
   return tonumber(v)
end

-- Point the engine's compass cvar at `vis`. true = it exists and now holds what we asked for, so the
-- engine is doing the hiding; false = no such cvar here (or it wouldn't take) - use the clip fallback.
local function compassCvar(vis)
   if not (System and System.SetCVar) then return false end
   local want = vis and 1 or 0
   local cur = cvarNum(M.COMPASS_CVAR)
   if cur == nil then return false end          -- not registered: hud mask not up yet, or a build without it
   if cur == want then return true end
   pcall(function() System.SetCVar(M.COMPASS_CVAR, want) end)
   return cvarNum(M.COMPASS_CVAR) == want       -- read back: only ours if it actually took
end

function M.ApplyCompass()
   if not M.state.inGame then return end   -- never touch the vanilla compass at the menu (the loop can
                                           -- start on the menu backdrop; forcing it visible there is wrong)
   local vis = M.cfg.hideCompass ~= 1
   if compassCvar(vis) then return end
   -- Fallback: poke the movieclip instead (HUD.xml registers "Compass" for exactly this). The 4-arg
   -- movieclip form is safe either way: if the engine's SetVisible is the 3-arg element form, the
   -- extra "Compass" arg just no-ops a show.
   if not UIAction or not UIAction.SetVisible then return end
   -- Never force the vanilla compass VISIBLE while a menu/dialogue is open. The game hides the whole HUD
   -- there; overriding it pops the compass bar over the menu (changing any F6 setting runs PushConfig ->
   -- here, so toggling a setting in the inventory made the compass appear - the reported bug). Hiding it
   -- (hideCompass=1) still applies: it needs re-asserting after the engine re-shows the HUD post-menu.
   if vis and M.IsBlockingUIOpen() then return end
   pcall(function() UIAction.SetVisible(M.HUD_ELEMENT, M.HUD_INST, "Compass", vis) end)
end

-- ---------------------------------------------------------------------------
-- blocking-UI detection (hide the minimap while a menu/dialogue is open)
-- KCD2 menus don't fire a clean open/close event and don't hard-pause (they
-- divide the game time scale), so we POLL the engine's full-UI gate. All calls
-- are pcall'd and fail OPEN (unknown -> stay shown) so a wrong bind never breaks.
-- ---------------------------------------------------------------------------
local function tryGame(name)
   if not Game or not Game[name] then return nil end
   local ok, v = pcall(function() return Game[name](Game) end)   -- Game:Foo()
   if not ok then ok, v = pcall(function() return Game[name]() end) end  -- Game.Foo()
   if ok then return v end
   return nil
end

local function hudHiddenByCvar()
   if not (System and System.GetCVar) then return false end
   local ok, v = pcall(function() return System.GetCVar("wh_ui_ShowHud") end)
   return ok and tostring(v) == "0"
end

-- world time is paused whenever a full menu (map/inventory/perks/codex/questbook)
-- or the ESC menu is open. VERIFIED: the game's own flowgraphs gate on
-- Calendar.IsWorldTimePaused() (e.g. AI/world/so_bathhouse.xml).
local function worldTimePaused()
   if not (Calendar and Calendar.IsWorldTimePaused) then return nil end
   local ok, p = pcall(function() return Calendar.IsWorldTimePaused() end)
   if ok then return p end
   return nil
end

function M.IsBlockingUIOpen()
   if M.state.apseOpen then return true end                       -- full menu open (reported by the ASI from the UI feeds)
   -- worldTimePaused() is only the PAK-ONLY menu fallback: with the companion, apseOpen (the engine's
   -- E_UIApseView byte) is authoritative, and Calendar.IsWorldTimePaused() reads TRUE during Hardcore
   -- gameplay (not just menus) - which was hiding the minimap the whole time on Hardcore.
   if not M.state.asiSeen and worldTimePaused() == true then return true end
   if tryGame("IsPaused") == true then return true end            -- generic paused/menu state
   if tryGame("IsGameplayStarted") == false then return true end  -- loading / fast-travel / cutscene
   if M.cfg.hideWithHud == 1 and hudHiddenByCvar() then return true end  -- opt-in; else Hardcore (HUD off) hides us
   if M.cfg.hideInDialog == 1 then
      if M.state.letterbox then return true end   -- companion: letterbox bars = dialogue/cutscene (the reliable signal)
      -- pak-only fallback (no companion): these binds are unreliable on 1.5.6 but cost nothing to try.
      local a = g_localActor
      if a then
         if a.human and a.human.IsInDialog then
            local ok, d = pcall(function() return a.human.IsInDialog() end)
            if ok and d == true then return true end
         end
         if a.IsWaitingForDialogueReply then
            local ok, d = pcall(function() return a:IsWaitingForDialogueReply() end)
            if ok and d == true then return true end
         end
      end
   end
   return false
end

-- diagnostic: dump each UI-state signal so we can see which one detects a menu
function M.CmdUiState()
   log("---- minimap uistate ----")
   log("Calendar.IsWorldTimePaused = " .. tostring(worldTimePaused()))
   log("IsGameplayStarted = " .. tostring(tryGame("IsGameplayStarted")))
   log("IsPaused          = " .. tostring(tryGame("IsPaused")))
   log("wh_ui_ShowHud=0   = " .. tostring(hudHiddenByCvar()) .. "  (hides only if hideWithHud=1; now " .. M.cfg.hideWithHud .. ")")
   local a = g_localActor
   local dlg = "n/a"
   if a and a.IsWaitingForDialogueReply then
      local ok, d = pcall(function() return a:IsWaitingForDialogueReply() end); dlg = ok and tostring(d) or "err"
   end
   log("IsWaitingForDialogueReply = " .. dlg)
   log("companion apseOpen=" .. tostring(M.state.apseOpen) .. " letterbox=" .. tostring(M.state.letterbox)
       .. "  (letterbox=dialogue/cutscene; hides only if hideInDialog=1; now " .. M.cfg.hideInDialog .. ")")
   log("=> IsBlockingUIOpen = " .. tostring(M.IsBlockingUIOpen()))
end

-- ---------------------------------------------------------------------------
-- the tick
-- ---------------------------------------------------------------------------
-- The tick body. Pulled out of the scheduler (M.Tick) so a Lua error in here can never end the
-- self-rescheduling chain: that used to leave the map frozen in place after a cutscene / save-load /
-- death, recoverable only with a console minimap_reload (see the reports). Every early return just
-- returns; M.Tick always re-arms the timer afterwards, error or not.
local function tickBody()
   -- watchdog: never leave the player frozen if the panel closed without us re-enabling
   if M.state.playerLocked and not M.ui.open then M.LockPlayer(false) end

   -- re-sync the auto-open flag + display settings to the companion every ~1s so F6 changes drive
   -- the minimap live without a restart.
   M.cfgTick = (M.cfgTick or 0) + 1
   if M.cfgTick % 12 == 0 then
      -- push display settings to Flash only when they actually changed
      local sig = string.format("%s,%s,%s,%s,%s,%s,%s,%s,%s", M.cfg.size, M.cfg.shape, M.cfg.mapAlpha, M.cfg.rotateMap, M.cfg.corner, M.cfg.margin, M.cfg.frameStyle, M.cfg.showNorth, M.EffAspect())
      if sig ~= M.lastDispSig then M.lastDispSig = sig; M.PushConfig() end
      if M.cfg.hideCompass == 1 then M.ApplyCompass() end   -- a cvar compare once it took; still covers a
                                                            -- late hud-mask init and the clip fallback
      if M.cfg.autoDim == 1 then M.PushDim() end            -- track the in-game time of day (dusk/dawn ramps)
   end

   -- refresh which treasure maps the player holds (~2s; inventory changes slowly). Also refresh the
   -- instant the cache is empty so treasure markers appear without waiting a full cycle.
   if (M.cfg.treasure or 0) > 0 and (M.state.treasureOwned == nil or M.cfgTick % 24 == 0) then
      pcall(M.RefreshTreasureOwned)
   end

   if M.cfg.enabled ~= 1 then M.PushShow(false); return end
   -- stay hidden until real gameplay is confirmed: the main-menu backdrop is a live level, so it can
   -- expose a player position - playerPos() alone can't tell "in game" from "at the menu". The latch
   -- is set by the OnGameplayStarted event + the companion's live marker feeds (a loaded save's data).
   -- OnGameplayEnded clears it (e.g. on death), but the matching OnGameplayStarted isn't reliably
   -- delivered on every load path (reload-after-death, auto-continue, exit save), so re-assert it here
   -- from the same positive gate EnsureStarted uses - a player present AND the world clock running
   -- (worldTimePaused()==false, which reads nil/paused on the menu backdrop, so it can't latch there).
   -- Without this a pak-only load where the event is missed left the map hidden until a game restart.
   if not M.state.inGame then
      if getPlayer() ~= nil and worldTimePaused() == false then
         M.state.inGame = true
      else
         if M.state.shown then M.PushShow(false) end
         return
      end
   end

   local x, y, z = playerPos()
   if not x then
      -- not in world yet; keep polling
      M.PushShow(false); M.SetNotice(nil)
      return
   end
   M.state.px, M.state.py, M.state.pz = x, y, z

   -- (re)detect level + (re)send map tile on change
   local lv, raw = detectLevel()
   if lv and lv ~= M.state.level then
      log("level detected: " .. lv .. " (from '" .. tostring(raw) .. "')")
      M.state.level = lv; M.state.mapSent = nil; M.state.localMap = nil; M.SaveCfg()
      _G.minimap_poi_markers = nil; _G.minimap_live_markers = nil; _G.minimap_giver_markers = nil  -- region changed: drop stale
      M.state.flag = nil                                           -- the map flag is per-level too
      _G.minimap_poi_dirty = true                                   -- re-seed discovery from any feed
   end
   -- swap to a detailed town map while inside one, back to the region map on leaving
   local nl = detectLocalMap(x, y)
   if nl ~= M.state.localMap then
      M.state.localMap = nl
      M.state.mapSent = nil
      log("map: " .. (nl or M.state.level))
   end
   local activeMap = M.state.localMap or M.state.level
   local L = levelCfg()
   local mapKey = activeMap .. ":" .. M.cfg.hires
   if M.state.mapSent ~= mapKey then
      -- pass the tile grid (from the build-generated MinimapMapGrid manifest) so Flash streams tiles
      local g = (type(MinimapMapGrid) == "table" and MinimapMapGrid[activeMap]) or {}
      ui_call("MinimapSetMap", activeMap, M.cfg.hires, g.imgW or 0, g.imgH or 0, g.tile or 0, g.cols or 0, g.rows or 0)
      M.state.mapSent = mapKey
   end

   -- hide while a blocking full-screen UI is open (map/inventory/perks/codex/dialogue)
   if M.cfg.hideOnMenu == 1 and M.IsBlockingUIOpen() then
      if M.state.shown then M.PushShow(false) end
      M.SetNotice(nil)
      return
   end
   if M.cfg.hideInCombat == 1 and inCombat() then   -- still gameplay (ingame stays 1), just hidden
      if M.state.shown then M.PushShow(false) end
      return
   end
   if M.cfg.showOnHorse == 1 and not isMounted() then   -- "only on horseback": hidden while on foot
      if M.state.shown then M.PushShow(false) end
      return
   end
   if not M.state.shown then M.PushShow(true) end

   -- the companion is required for markers, discovered-state and F6. When it's installed it checks
   -- in during the menus (before gameplay), so this only elapses when it's genuinely missing; warn
   -- in the log + on screen. Short window: long enough for a present ASI, short enough to be useful.
   if M.state.asiSeen then
      M.SetNotice(nil)
   else
      M.state.noAsiTicks = (M.state.noAsiTicks or 0) + 1
      if M.state.noAsiTicks >= 60 then   -- ~5s before the notice first appears
         if not M.state.asiWarned then
            M.state.asiWarned = true
            log("companion version.dll not detected - it's required for live quest/POI markers, discovered locations and the F6 panel. Put version.dll in <game>/Bin/Win64MasterMasterSteamPGO/ (manual install, mod managers won't place it there).")
         end
         -- show it, then auto-hide after NOTICE_MS, counting down in real ms so it reads as temporary
         M.state.noticeMs = (M.state.noticeMs or 0) + M.cfg.period
         local remain = math.ceil((M.NOTICE_MS - M.state.noticeMs) / 1000)
         if remain > 0 then M.SetNotice(M.NOTICE .. "\n\n(hides in " .. remain .. "s)")
         else               M.SetNotice(nil) end
      end
   end

   -- heading on the map = player yaw + the map's rotation (folded in here)
   local h = (playerHeadingDeg() or 0) + mapRotDeg()
   M.state.yaw = h

   local u, v = worldToUV(x, y)
   ui_call("MinimapUpdate", u, v, M.cfg.radius, mapSpanMetres(), h)

   -- re-seed discovered POIs from the native map feed only when it changed (cheap-guarded)
   if _G.minimap_poi_dirty then _G.minimap_poi_dirty = nil; M.SeedDiscoveryFromNative(M.state.level) end

   local markers, icons = buildMarkers()
   M.state.markerN = markers[1] or 0
   if UIAction and UIAction.SetArray then
      pcall(function() UIAction.SetArray(M.ELEMENT, M.INSTANCE, "MinimapMarkers", markers) end)
      -- icon names go as a "|"-delimited string arg (SetArray can't carry strings)
      ui_call("MinimapApplyMarkers", table.concat(icons, "|"))
   end

   M.PushClock()
   M.PushDiag()
end

-- Scheduler wrapper: THE thing that keeps the map alive across cutscenes / saves / deaths. Clears
-- the pending id, bumps the heartbeat (M.EnsureStarted watches it to detect a dropped timer), runs
-- the body under pcall so a Lua error is logged but never stops the loop, then unconditionally
-- re-arms. A raw error in the body used to skip the reschedule and freeze the map for good.
function M.Tick()
   M.state.timerId = nil
   M.state.hb = (M.state.hb or 0) + 1
   local ok, err = pcall(tickBody)
   if not ok then
      M.state.tickErr = tostring(err)
      log("tick error (loop kept alive): " .. tostring(err))
   end
   M.Reschedule()
end

function M.Reschedule()
   if M.state.timerId then Script.KillTimer(M.state.timerId); M.state.timerId = nil end
   M.state.timerId = Script.SetTimer(M.cfg.period, function() M.Tick() end)
end

-- Fast, lightweight updater (~60Hz): pushes ONLY the heading so the map rotation tracks the camera
-- at the render framerate instead of the ~12Hz main tick (that was the stutter when looking around).
-- Pan + markers stay on M.Tick - keeping the per-frame work to one angle read avoids marker/map
-- desync and keeps it cheap. Runs while the loop runs; a no-op when the minimap is hidden.
M.FAST_PERIOD = 16
function M.FastTick()
   M.state.fastTimerId = nil
   pcall(function()
      if M.state.shown and M.cfg.enabled == 1 then
         local h = playerHeadingDeg()
         if h then ui_call("MinimapHeading", h + mapRotDeg()) end
      end
   end)
   M.RescheduleFast()
end
function M.RescheduleFast()
   if M.state.fastTimerId then Script.KillTimer(M.state.fastTimerId); M.state.fastTimerId = nil end
   M.state.fastTimerId = Script.SetTimer(M.FAST_PERIOD, function() M.FastTick() end)
end

-- Force both poll timers to re-arm from scratch. Reschedule/RescheduleFast each kill any existing
-- timer first (harmless on a stale id the engine already dropped), so this always leaves exactly one
-- live main + fast timer - never a duplicate. Used by the stall watchdog and the transition-event
-- brackets to recover a loop the engine stopped on a load/pause without our code being told.
function M.RearmLoop()
   M.Reschedule()
   M.RescheduleFast()
end

-- Clear the stall-watchdog calibration. Called on every confirmed (re)start so a prior freeze can't
-- leave an inflated gap estimate behind that slows the NEXT recovery - that was the "map freezes after
-- a while, and takes longer each time to come back" degradation. minimap_reload runs through here too.
function M.ResetWatchdog()
   M.state.hbSeen = nil; M.state.hbStall = 0; M.state.hbMaxGap = 0; M.state.hbRearmed = nil
end

function M.Start()
   if M.state.running then return end
   M.state.running = true
   M.ResetWatchdog()          -- fresh calibration each load, so a past freeze can't slow this recovery
   _G.minimap_freshload = 1   -- signal the ASI: fresh save load -> reset quest markers
   _G.minimap_live_markers = nil   -- drop the previous save's quest markers; the ASI repopulates live
   _G.minimap_poi_markers = nil    -- and its discovered POIs (minimap_apply_poi only assigns non-empty, so
                                   -- without this the old save's POIs linger until the new scan's first push)
   _G.minimap_giver_markers = nil  -- and its giver/tipster marks (repopulated by the next compass scan)
   M.LoadCfg()
   _G.minimap_cfg_out = M.SerializeCfg()   -- expose current settings so the .asi can write the config file
   M.PushConfig()
   M.Reschedule()
   M.RescheduleFast()
   log("started v" .. M.VERSION)
end

-- Confirm real gameplay + start the loop. Called only from the companion's live marker feeds
-- (minimap_apply / minimap_apply_poi), which carry a loaded save's quest/POI data. Two guards keep
-- this from firing on the main-menu backdrop (a live level that can expose a player and partly-live
-- feeds): a player must be present AND the in-game clock must be running (worldTimePaused()==false;
-- it reads nil/paused at the menu). Sets the gameplay latch (the tick won't show the map until it's
-- set) and starts the loop - covering the load paths OnGameplayStarted misses (e.g. auto-continue).
function M.EnsureStarted()
   if getPlayer() == nil then return end            -- still loading / pre-spawn; a later feed call retries
   if worldTimePaused() ~= false then return end    -- clock not running = menu backdrop / loading, not real play
   M.state.inGame = true
   if not M.state.running then pcall(function() M.Start() end); return end
   -- The loop is flagged running - make sure it's actually ticking. The engine can silently drop our
   -- Script timer across a save/level load (and it leaves running=true, so the guard above won't
   -- restart it): that's the "map stuck in place until minimap_reload" bug. The companion calls this
   -- every feed, so watch the tick heartbeat (M.state.hb) and re-arm if it's frozen. Self-calibrating
   -- so it can't false-trigger at slow tick periods / high framerates: remember the largest gap (feeds
   -- between two ticks) seen while healthy, and only declare the loop dead after several times that.
   local hb = M.state.hb or 0
   if hb ~= M.state.hbSeen then
      -- Raise the healthy-gap estimate, but ONLY from a gap small enough to be real between-tick
      -- spacing. A wide gap means the game-time tick was frozen (load / pause / frame hitch) while the
      -- per-frame feeds kept arriving - that's the stall we detect, not a rate, so it must not feed the
      -- threshold. It used to, unbounded: every death/reload ratcheted hbMaxGap up and the re-arm
      -- threshold (hbMaxGap*4) with it, so the map took longer and longer to unfreeze and finally never
      -- did. Cap it at one tick period's worth of feeds at a high framerate - feeds can't outrun frames.
      local gap    = M.state.hbStall or 0
      local gapCap = math.max(30, (M.cfg.period or 80) * 0.2)   -- ~200 fps worth of feeds per tick
      if gap > (M.state.hbMaxGap or 0) and gap <= gapCap then M.state.hbMaxGap = gap end
      M.state.hbSeen = hb; M.state.hbStall = 0; M.state.hbRearmed = nil
   else
      -- Heartbeat hasn't advanced since the last feed. Rule out the benign case first: KCD stops our
      -- game-time Script tick whenever the sim is frozen - an open menu/inventory (apseOpen) or a
      -- cinematic dialogue/cutscene (letterbox) - while the companion's per-frame feeds that drive this
      -- watchdog keep arriving. That's an expected pause, not a dropped timer, and re-arming can't help
      -- (the fresh timer is frozen too), so don't count it. Skipping this was the console spam a tester
      -- reported: the watchdog logged + re-armed several times a second for as long as a menu stayed open.
      if M.state.apseOpen or M.state.letterbox then
         M.state.hbStall = 0; M.state.hbRearmed = nil
      else
         M.state.hbStall = (M.state.hbStall or 0) + 1
         if M.state.hbStall >= math.max(30, (M.state.hbMaxGap or 0) * 4) then
            M.state.hbStall = 0
            -- Re-arm once per stall episode. A genuinely dropped timer (load / level change) needs a
            -- single kick and the next tick advances hb, clearing the latch above. If hb still doesn't
            -- move after that, the sim is paused for a reason we don't flag (hard pause, open console) -
            -- repeating won't unfreeze a frozen-time timer, so log once and stay quiet until a tick lands.
            -- Preserves the v1.11 dropped-timer recovery while killing the repeat spam.
            if not M.state.hbRearmed then
               M.state.hbRearmed = true
               log("poll loop stalled (timer dropped on load?) - re-arming")
               pcall(function() M.RearmLoop() end)
            end
         end
      end
   end
end

function M.Stop()
   if M.state.timerId then Script.KillTimer(M.state.timerId); M.state.timerId = nil end
   if M.state.fastTimerId then Script.KillTimer(M.state.fastTimerId); M.state.fastTimerId = nil end
   M.state.running = false
   M.PushShow(false)
end

-- ---------------------------------------------------------------------------
-- event hooks
-- ---------------------------------------------------------------------------
function M.OnGameLoaded(elementName, instanceId, eventName)
   log("game loaded -> starting")
   M.state.running = false
   M.state.inGame = true   -- authoritative gameplay signal from the engine
   M.Start()
end

-- Event brackets for the transitions where the engine stops our poll timer (hard pause / load /
-- cutscene). Each re-arms the loop so it survives them. OnGameResume is the important one: it fires
-- coming back from a pause/load/cutscene, exactly where the timer was dropped and (before this) we
-- did nothing but assume "the next tick re-evaluates" - but a dropped timer has no next tick, so the
-- map stayed frozen. Re-arming is a no-op cost when the timer is already alive (RearmLoop kill+arms).
function M.OnGameplayEndedEvt() M.state.inGame = false; M.PushShow(false); pcall(function() M.RearmLoop() end) end
function M.OnGamePauseEvt()     M.PushShow(false); pcall(function() M.RearmLoop() end) end
function M.OnGameResumeEvt()    pcall(function() M.RearmLoop() end) end

-- ---------------------------------------------------------------------------
-- console commands
-- ---------------------------------------------------------------------------
-- KCD's console wraps %line args in double-quotes, so strip them before parsing
local function cleanArgs(line)
   line = tostring(line or "")
   line = line:gsub('"', "")
   line = line:gsub("^%s+", ""):gsub("%s+$", "")
   return line
end

local function num(s, dflt)
   local v = tonumber(cleanArgs(s))
   if v == nil then return dflt end
   return v
end

function M.CmdToggle()
   M.cfg.enabled = (M.cfg.enabled == 1) and 0 or 1
   log("enabled = " .. M.cfg.enabled)
   if M.cfg.enabled == 0 then M.PushShow(false) end
   M.SaveCfg()
end

function M.CmdZoom(line)
   local v = num(line)
   if v then M.cfg.radius = clamp(v, 25, 2000); log("radius = " .. M.cfg.radius .. " m"); M.SaveCfg() else
      log("usage: minimap_zoom <metres>  (current " .. M.cfg.radius .. ")") end
end

function M.CmdSize(line)
   local v = num(line)
   if v then M.cfg.size = clamp(v, 96, 800); M.PushConfig(); log("size = " .. M.cfg.size); M.SaveCfg() end
end

function M.CmdAspect(line)
   local a = cleanArgs(line)
   if a:match("auto") then
      M.cfg.aspectAuto = 1; M.PushConfig(); M.SaveCfg()
      log("aspect = auto (effective " .. M.EffAspect() .. " %)"); return
   end
   local v = num(line)
   if v then
      M.cfg.aspectAuto = 0; M.cfg.aspect = clamp(v, 40, 200); M.PushConfig(); M.SaveCfg()
      log("aspect = " .. M.cfg.aspect .. " % (manual)")
   else
      log("usage: minimap_aspect <percent|auto>  (horizontal width; 100 = off, ~50 rounds a 32:9 oval; "
          .. "auto fits the display. current " .. (M.cfg.aspectAuto == 1 and ("auto=" .. M.EffAspect()) or (M.cfg.aspect .. "%")) .. ")")
   end
end

function M.CmdRotate()
   M.cfg.rotateMap = (M.cfg.rotateMap == 1) and 0 or 1; M.PushConfig(); M.SaveCfg()
   log("rotateMap = " .. M.cfg.rotateMap)
end

function M.CmdCorner(line)
   local v = num(line)
   if v and v >= 0 and v <= 3 then M.cfg.corner = v; M.PushConfig(); M.SaveCfg(); log("corner = " .. v)
   else log("usage: minimap_corner <0 TL|1 TR|2 BL|3 BR>") end
end

function M.CmdLevel(line)
   line = cleanArgs(line):gsub("%s+", "")
   if M.levels[line] then M.state.level = line; M.state.mapSent = nil; M.SaveCfg(); log("level = " .. line)
   else log("usage: minimap_level <trosecko|kutnohorsko|klaster>  (current " .. M.state.level .. ")") end
end

-- diagnostic: dump every level-name source so we can see what the engine exposes
function M.CmdDetect()
   log("---- minimap detect ----")
   if System and System.GetCVar then
      for _, cv in ipairs(LEVEL_CVARS) do
         local ok, v = pcall(function() return System.GetCVar(cv) end)
         log(string.format("cvar %-10s = %s", cv, ok and ("'" .. tostring(v) .. "'") or "<err>"))
      end
   end
   if GameToken and GameToken.GetToken then
      local ok, v = pcall(function() return GameToken.GetToken("Game.Global.Previous_Level") end)
      log("token Previous_Level = " .. (ok and ("'" .. tostring(v) .. "'") or "<err>"))
   end
   local lv, raw, src = detectLevel()
   log("matched = " .. tostring(lv) .. " (raw '" .. tostring(raw) .. "' via " .. tostring(src) .. ")")
   log("current level = " .. M.state.level)
end

-- dump the engine's GlobalMap array so we can verify the auto-cal indices
function M.CmdDumpMap()
   if not (UIAction and UIAction.GetArray) then log("no UIAction.GetArray on this build"); return end
   for _, inst in ipairs({ -1, 0 }) do
      local arr
      local ok = pcall(function() arr = UIAction.GetArray("ApseMap", inst, "GlobalMap") end)
      log(string.format("GetArray(ApseMap, %d, GlobalMap): ok=%s type=%s", inst, tostring(ok), type(arr)))
      if type(arr) == "table" then
         local s = ""
         for i = 1, math.min(#arr, 22) do s = s .. "[" .. i .. "]=" .. tostring(arr[i]) .. " " end
         log("  n=" .. #arr .. "  " .. s)
      end
   end
   log("(expecting LevelSize at [5,6], WorldCrop x,y,w,h at [7,8,9,10])")
end

function M.CmdAutoCal()
   log("calibration is already automatic + exact (baked from the game's level.xml map config)")
   log(string.format("  %s: rot=%.1f deg span=%.0f m", M.state.level, mapRotDeg(), mapSpanMetres()))
end

-- minimap_set <key> <value>   (live tweak of heading/display; map calibration is automatic)
function M.CmdSet(line)
   local key, val = string.match(cleanArgs(line), "(%S+)%s+(%S+)")
   if not key then
      log("usage: minimap_set <headingoff|headingsign|alpha|period> <value>")
      return
   end
   local v = tonumber(val)
   key = string.lower(key)
   if key == "headingoff" then M.cfg.headingOff = v
   elseif key == "headingsign" then M.cfg.headingSign = v
   elseif key == "alpha" then M.cfg.mapAlpha = clamp(v,0,100); M.PushConfig()
   elseif key == "period" then M.cfg.period = clamp(v,16,1000)
   else log("unknown key: " .. key .. " (map calibration is now automatic from level.xml)"); return end
   log(string.format("set %s = %s", key, tostring(v)))
   M.SaveCfg()
end

-- fine-tune offset nudge (du,dv in UV). The transform is exact, so this is rarely needed.
function M.CmdPan(line)
   local du, dv = string.match(cleanArgs(line), "([%-%d%.]+)%s+([%-%d%.]+)")
   du, dv = tonumber(du), tonumber(dv)
   if not du or not dv then log("usage: minimap_pan <du> <dv>  (nudge map offset, e.g. 0.01 0)"); return end
   local L = levelCfg(); L.du = (L.du or 0) + du; L.dv = (L.dv or 0) + dv
   M.SaveCfg(); log(string.format("pan %+.3f,%+.3f  (du=%.3f dv=%.3f)", du, dv, L.du, L.dv))
end

-- rotate the heading/arrow. e.g. minimap_head 15  /  minimap_head -15
function M.CmdHead(line)
   local d = num(line)
   if not d then log("usage: minimap_head <deg>  (turn arrow/map, e.g. 15 or -15)"); return end
   M.cfg.headingOff = (M.cfg.headingOff + d) % 360
   M.SaveCfg(); log(string.format("headingOff = %.1f", M.cfg.headingOff))
end

function M.CmdCalInfo()
   local L = levelCfg()
   log(string.format("calinfo %s: rot=%.1f deg  span=%.0f m  (exact, auto from level.xml)  du=%.3f dv=%.3f",
        M.state.level, mapRotDeg(), mapSpanMetres(), L.du or 0, L.dv or 0))
   log("calibration is automatic; minimap_pan du dv nudges the offset, minimap_head turns the arrow.")
end

-- raw player yaw in degrees (before sign/offset)
local function rawYawDeg()
   local p = getPlayer()
   if not p then return nil end
   local ok, ang
   if p.GetWorldAngles then ok, ang = pcall(function() return p:GetWorldAngles() end) end
   if (not ok or not ang) and p.GetAngles then ok, ang = pcall(function() return p:GetAngles() end) end
   if not ok or not ang then return nil end
   return (ang.z or ang[3] or 0) * 180.0 / math.pi
end

-- "I am facing north right now" — sets headingOff so facing north reads as 0
function M.CmdNorth()
   local y = rawYawDeg()
   if not y then log("north: no player position"); return end
   M.cfg.headingOff = (-(y * M.cfg.headingSign)) % 360
   log(string.format("north set: headingOff=%.1f (raw yaw %.1f). If the arrow points wrong, try minimap_set headingsign -1 then minimap_north again.", M.cfg.headingOff, y))
   M.SaveCfg()
end

-- reset all per-level calibration to the code defaults (clears saved values)
function M.CmdMenuHide()
   M.cfg.hideOnMenu = (M.cfg.hideOnMenu == 1) and 0 or 1
   M.SaveCfg()
   log("hideOnMenu = " .. M.cfg.hideOnMenu)
end

function M.CmdHideWithHud()
   M.cfg.hideWithHud = (M.cfg.hideWithHud == 1) and 0 or 1
   M.SaveCfg()
   log("hideWithHud = " .. M.cfg.hideWithHud .. " (0 = keep the minimap up even when the game HUD is off, e.g. Hardcore)")
end

function M.CmdHideCombat()
   M.cfg.hideInCombat = (M.cfg.hideInCombat == 1) and 0 or 1
   M.SaveCfg()
   log("hideInCombat = " .. M.cfg.hideInCombat)
end

function M.CmdCompass()
   M.cfg.hideCompass = (M.cfg.hideCompass == 1) and 0 or 1
   M.SaveCfg()
   M.ApplyCompass()
   local cv = cvarNum(M.COMPASS_CVAR)
   log("hideCompass = " .. M.cfg.hideCompass .. "  (" .. M.COMPASS_CVAR .. " = "
       .. (cv and tostring(cv) or "absent, using the SetVisible fallback") .. ")")
end

function M.CmdPlayer()
   M.cfg.showPlayer = (M.cfg.showPlayer == 1) and 0 or 1
   M.SaveCfg(); M.PushConfig()
   log("showPlayer = " .. M.cfg.showPlayer)
end

-- escape hatch: force-restore player control + close the panel, if it ever gets stuck
function M.CmdUnstick()
   M.LockPlayer(false)
   M.ui.open = false
   _G.minimap_ui_open = "0"
   pcall(function() ui_call("UiShow", 0) end)
   log("unlocked + panel closed")
end

function M.CmdLive()
   M.cfg.showLive = (M.cfg.showLive == 1) and 0 or 1
   M.SaveCfg()
   log("showLive = " .. M.cfg.showLive)
end

function M.CmdPoi()
   M.cfg.showPoi = (M.cfg.showPoi == 1) and 0 or 1
   M.SaveCfg()
   log("showPoi = " .. M.cfg.showPoi .. " (POI markers, distance-filtered)")
end

function M.CmdClock()
   M.cfg.showClock = (M.cfg.showClock == 1) and 0 or 1
   log("showClock = " .. M.cfg.showClock)
   M.PushClock(true)
   M.SaveCfg()
end

function M.CmdObjDist()
   M.cfg.showObjDist = (M.cfg.showObjDist == 1) and 0 or 1
   log("showObjDist = " .. M.cfg.showObjDist)
   M.SaveCfg()
end

-- live giver/tipster marks (quest-givers, activity-givers, tipsters, arenas, ...) from the compass feed
function M.CmdGivers()
   M.cfg.showGivers = (M.cfg.showGivers == 1) and 0 or 1
   M.SaveCfg()
   local gm = _G.minimap_giver_markers
   log("showGivers = " .. M.cfg.showGivers .. (type(gm) == "table" and (" (" .. #gm .. " near you)") or ""))
end

-- baked static POI database (the markers-on-spawn source)
function M.CmdBaked()
   M.cfg.showBaked = (M.cfg.showBaked == 1) and 0 or 1
   M.SaveCfg()
   local b = type(MinimapPOIData) == "table" and MinimapPOIData[M.state.level]
   log("showBaked = " .. M.cfg.showBaked .. (b and (" (" .. #b .. " POIs in " .. M.state.level .. ")") or " (no baked data for this region)"))
end

function M.CmdGrayUndisc()
   M.cfg.grayUndisc = (M.cfg.grayUndisc == 1) and 0 or 1
   M.SaveCfg()
   log("grayUndisc = " .. M.cfg.grayUndisc .. " (1 = gray undiscovered POIs)")
end

function M.CmdHideUndisc()
   M.cfg.hideUndisc = (M.cfg.hideUndisc == 1) and 0 or 1
   M.SaveCfg()
   log("hideUndisc = " .. M.cfg.hideUndisc .. " (1 = only show discovered POIs)")
end

-- buried-treasure marks: cycle off -> discovered (have the map) -> reveal all
function M.CmdTreasure()
   M.cfg.treasure = ((M.cfg.treasure or 0) + 1) % 3
   M.SaveCfg()
   local names = { [0] = "off", [1] = "discovered (maps you hold)", [2] = "reveal all" }
   log("treasure = " .. M.cfg.treasure .. " (" .. (names[M.cfg.treasure] or "?") .. ")")
end

-- diag: dump the inventory/read check for every treasure map that has a known site (verifies the
-- GetCountOfClass / WasBookOpened binds fire and which of the player's maps are recognised).
function M.CmdTreasureDiag()
   local act = rawget(_G, "g_localActor")
   local inv = act and act.inventory
   local mg  = rawget(_G, "Minigame")
   log(string.format("treasure diag: inventory=%s GetCountOfClass=%s Minigame.WasBookOpened=%s",
      tostring(inv ~= nil), tostring(inv and inv.GetCountOfClass ~= nil), tostring(mg and mg.WasBookOpened ~= nil)))
   -- map GUIDs that have a baked dig-site position (the "discovered" gate only works for these)
   local located = {}
   if type(MinimapPOIData) == "table" then
      for _, lvl in pairs(MinimapPOIData) do
         if type(lvl) == "table" then
            for i = 1, #lvl do local r = lvl[i]
               if r[5] == 4 and r[6] then for g in r[6]:gmatch("[^;]+") do located[g] = true end end
            end
         end
      end
   end
   local maps = MinimapTreasureMaps or {}
   local held, errShown = 0, false
   for i = 1, #maps do
      local guid, name = maps[i][1], maps[i][2]
      local c, rd = 0, nil
      if inv and inv.GetCountOfClass then
         local ok, v = pcall(function() return inv:GetCountOfClass(guid) end)
         if ok then if type(v) == "number" then c = v end
         elseif not errShown then errShown = true; log("  GetCountOfClass error: " .. tostring(v)) end
      end
      if mg and mg.WasBookOpened then
         local ok, v = pcall(function() return mg.WasBookOpened(guid) end)
         if ok then rd = v end
      end
      if (c and c > 0) or rd == true then
         held = held + 1
         log(string.format("  HELD: %-32s count=%s read=%s %s", name, tostring(c), tostring(rd),
            located[guid] and "[location known]" or "[no location - reveal-only]"))
      end
   end
   local nloc = 0; for _ in pairs(located) do nloc = nloc + 1 end
   log(string.format("  -> %d of %d treasure maps in your inventory; %d map(s) have a known dig location",
      held, #maps, nloc))
end

-- dev: reveal every baked POI in the current region (colour them all)
function M.CmdDiscoverAll()
   local b = type(MinimapPOIData) == "table" and MinimapPOIData[M.state.level]
   if not b then log("no baked data for " .. M.state.level); return end
   for i = 1, #b do markDiscovered(M.state.level, b[i][1], b[i][2]) end
   log("discovered all " .. #b .. " POIs in " .. M.state.level)
end

-- forget discovered POIs for the current region (re-grey everything)
function M.CmdDiscoverReset()
   M.disc[M.state.level] = {}
   log("reset discovered POIs for " .. M.state.level)
end

-- POI icon size in px (0 = plain dots). e.g. minimap_iconsize 20
function M.CmdIconSize(line)
   local v = num(line)
   if not v then log("usage: minimap_iconsize <px>  (0 = dots; default 16)"); return end
   M.cfg.iconSize = clamp(v, 0, 64)
   M.PushConfig()
   M.SaveCfg()
   log("iconSize = " .. M.cfg.iconSize .. " px")
end

function M.CmdReset()
   for _, lv in ipairs(M.levelOrder) do
      local L = M.levels[lv]; if L then L.du = 0; L.dv = 0; L._T = nil end
   end
   M.cfg.headingOff = 0; M.cfg.headingSign = -1
   M.SaveCfg()
   log("reset offset nudges + heading (the world->map calibration itself is automatic from level.xml)")
end

-- one-shot offset nudge: "I am standing at image fraction u,v" — keeps the
-- rotation/scale, only re-solves the offset so the dot lands at (u,v).
function M.CmdHere(line)
   local us, vs = string.match(cleanArgs(line), "([%-%d%.]+)%s+([%-%d%.]+)")
   local u, v = tonumber(us), tonumber(vs)
   if not u or not v then
      log("usage: minimap_here <u> <v>   (your spot as image fractions 0..1, from the map grid)")
      return
   end
   if recenterTo(u, v) then
      M.SaveCfg(); log(string.format("nudged %s to u=%.3f v=%.3f", M.state.level, u, v))
   else
      log("here: no player position (load a game first)")
   end
end

-- Point calibration for local-map levels (the monastery). Regional maps derive their transform
-- from level.xml, so p1/p2 are unnecessary there. The DLC monastery has no such data, so its
-- entity->UV affine is solved from spots marked in-game: stand somewhere, read your true position
-- off the map image as fractions u,v (use build/maps/klaster_calib.png), and run minimap_pN u v.
-- Two points solve rotation+scale+offset; a third adds shear/mirror. The solved affine is logged
-- so it can be baked as the level's aff default. (Session-only; re-run after a reload.)
M.calPts = {}

local function calSet(n, line)
   local us, vs = string.match(cleanArgs(line), "([%-%d%.]+)%s+([%-%d%.]+)")
   local u, v = tonumber(us), tonumber(vs)
   if not u or not v then
      log(string.format("usage: minimap_p%d <u> <v>   (your current spot as image fractions 0..1)", n)); return false
   end
   local x, y = playerPos()
   if not x then log(string.format("p%d: no player position (load a game first)", n)); return false end
   M.calPts[n] = { x = x, y = y, u = u, v = v }
   log(string.format("p%d = world (%.1f, %.1f) -> uv (%.3f, %.3f)", n, x, y, u, v))
   return true
end

-- apply + log a solved affine {a,b,c,d,e,f}: u = a*x + b*y + e, v = c*x + d*y + f
local function calApply(a, b, c, d, e, f)
   local L = levelCfg()
   L.aff = { a, b, c, d, e, f }; L.du = 0; L.dv = 0; L._T = nil
   M.state.mapSent = nil
   log(string.format("calibrated %s  aff = {%.6g, %.6g, %.6g, %.6g, %.6g, %.6g}",
        M.state.level, a, b, c, d, e, f))
   log(string.format("  rot=%.1f deg  span=%.0f m   -> bake into M.levels.%s.aff",
        mapRotDeg(), mapSpanMetres(), M.state.level))
end

-- two-point similarity (rotation + uniform scale + translation, no mirror)
local function calSolve2()
   local p1, p2 = M.calPts[1], M.calPts[2]
   local dx, dy = p2.x - p1.x, p2.y - p1.y
   local det = dx * dx + dy * dy
   if det <= 1e-9 then log("cal: points 1 and 2 are too close together"); return end
   local A = ((p2.u - p1.u) * dx + (p2.v - p1.v) * dy) / det
   local C = ((p2.v - p1.v) * dx - (p2.u - p1.u) * dy) / det
   local e = p1.u - (A * p1.x - C * p1.y)
   local f = p1.v - (C * p1.x + A * p1.y)
   calApply(A, -C, C, A, e, f)
end

-- three-point full affine (adds shear + mirror; use if a 2-point map still walks diagonally)
local function calSolve3()
   local p1, p2, p3 = M.calPts[1], M.calPts[2], M.calPts[3]
   local det = p1.x * (p2.y - p3.y) - p1.y * (p2.x - p3.x) + (p2.x * p3.y - p3.x * p2.y)
   if math.abs(det) <= 1e-9 then log("cal: the three points are collinear"); return end
   local function col(u1, u2, u3)   -- inverse of [[x1,y1,1],[x2,y2,1],[x3,y3,1]] times a (u1,u2,u3) column
      local a = (u1 * (p2.y - p3.y) + u2 * (p3.y - p1.y) + u3 * (p1.y - p2.y)) / det
      local b = (u1 * (p3.x - p2.x) + u2 * (p1.x - p3.x) + u3 * (p2.x - p1.x)) / det
      local e = (u1 * (p2.x * p3.y - p3.x * p2.y) + u2 * (p3.x * p1.y - p1.x * p3.y)
               + u3 * (p1.x * p2.y - p2.x * p1.y)) / det
      return a, b, e
   end
   local a, b, e = col(p1.u, p2.u, p3.u)
   local c, d, f = col(p1.v, p2.v, p3.v)
   calApply(a, b, c, d, e, f)
end

function M.CmdP1(line) if calSet(1, line) then log("now move to another spot and run minimap_p2 <u> <v>") end end
function M.CmdP2(line)
   if not calSet(2, line) then return end
   if not M.calPts[1] then log("set minimap_p1 first"); return end
   calSolve2()
end
function M.CmdP3(line)
   if not calSet(3, line) then return end
   if not (M.calPts[1] and M.calPts[2]) then log("set minimap_p1 and minimap_p2 first"); return end
   calSolve3()
end

-- print current player world pos + computed UV (diagnostic)
function M.CmdCalibrate()
   local x, y, z = playerPos()
   if not x then log("calibrate: no player position (load a game first)"); return end
   local u, v = worldToUV(x, y)
   local h = playerHeadingDeg()
   log("---- minimap position (exact, auto from level.xml) ----")
   log(string.format("level=%s", M.state.level))
   log(string.format("world  x=%.1f y=%.1f z=%.1f", x, y, z))
   log(string.format("UV     u=%.4f v=%.4f   (0..1 on map image)", u, v))
   log(string.format("heading=%.1f (sign=%d off=%d) mapRot=%.1f span=%.0f m",
        h or -1, M.cfg.headingSign, M.cfg.headingOff, mapRotDeg(), mapSpanMetres()))
end

-- diagnose interior detection: which interior maps exist for this region + whether we're inside one
function M.CmdInteriorTest()
   local x, y = playerPos()
   if not x then log("interiortest: no player (load a game first)"); return end
   log(string.format("interiortest: pos=(%.1f,%.1f) region=%s localMap=%s",
        x, y, M.state.level, tostring(M.state.localMap)))
   if type(MinimapLocalMaps) ~= "table" then log("  no MinimapLocalMaps loaded"); return end
   local any = false
   for name, d in pairs(MinimapLocalMaps) do
      if d.inside == 1 and d.region == M.state.level then
         any = true
         log(string.format("  %s: %d inside-area(s) -> inside=%s", name,
              d.inside_areas and #d.inside_areas or 0, tostring(pointInAnyArea(x, y, d.inside_areas))))
      end
   end
   if not any then log("  (no interior map for this region)") end
end

-- drop a user waypoint at the current position
function M.CmdMark(line)
   local x, y = playerPos()
   if not x then log("mark: no player position"); return end
   local t = num(line, 4)
   table.insert(M.state.waypoints, { x = x, y = y, type = t, level = M.state.level })
   log(string.format("marked waypoint #%d at %.0f,%.0f (level %s)", #M.state.waypoints, x, y, M.state.level))
end

function M.CmdClearMarks()
   M.state.waypoints = {}
   log("cleared waypoints")
end

-- test the native-plugin live-marker bridge: inject 4 markers around the player
-- into _G.minimap_live_markers (the same table the companion feeds).
function M.CmdTestLive()
   local x, y = playerPos()
   if not x then log("testlive: no player position"); return end
   _G.minimap_live_markers = {
      4,
      x + 80, y,      1,   -- quest (gold), 80m east
      x - 80, y,      5,   -- objective, 80m west
      x, y + 80,      6,   -- poi, 80m north
      x, y - 80,      7,   -- fast-travel, 80m south
   }
   log("injected 4 test live markers around the player (set showLive=1 to see them)")
end

-- Native-plugin bridge entry point. The ASI calls _G.minimap_apply(blob) on the
-- engine main thread (via CScriptSystem) to push live markers without any Lua bind.
-- This is the cross-VM channel the native side drives.
--   blob "test"  -> inject 4 markers around the player (bridge smoke test);
--   blob "c,x,y,t,x,y,t,..." -> set _G.minimap_live_markers (entity world coords),
--                               where c = marker count, then (x,y,type) triples.
-- Types: 1 quest, 5 objective, 6 poi, 7 fast-travel (see flash mm_markerColor).
-- parse the native feed "x,y,type,icon,letter;..." -> { {x,y,type,icon,letter}, ... }
-- (entity world coords; icon = a map icon name "" = dot; letter = quest objective char).
local function parseMarkerBlob(blob)
   local list = {}
   for rec in string.gmatch(blob, "[^;]+") do
      -- "x,y,type,icon,letter[,id[,areaR[,poly]]]" - id (quest "name:objName"), areaR (search-region radius
      -- in metres, 0 for a point objective) and poly (exact outline "wx_wy|wx_wy|..." in world coords) are
      -- optional (POIs / point objectives omit them)
      -- id captured as "anything but the field/record delimiters" so a quest/objective name with an
      -- unexpected char can't truncate it (and derail areaR/poly); the native guarantees no ',' or ';' in it.
      local xs, ys, ts, icon, letter, id, ar, poly = string.match(rec, "([%-%d.]+),([%-%d.]+),([%-%d.]+),([%w_]*),(%w*),?([^,;]*),?([%-%d.]*),?([%d%-._|]*)")
      local x, y = tonumber(xs), tonumber(ys)
      if x and y then
         local pts
         if poly and poly ~= "" then
            pts = {}
            for px, py in poly:gmatch("([%-%d.]+)_([%-%d.]+)") do
               pts[#pts + 1] = { x = tonumber(px), y = tonumber(py) }
            end
         end
         list[#list + 1] = { x = x, y = y, type = tonumber(ts) or 6, icon = icon or "", letter = letter or "", id = id or "", areaR = tonumber(ar) or 0, poly = pts }
      end
   end
   return list
end

_G.minimap_apply_count = 0
function minimap_apply(blob)
   _G.minimap_apply_count = (_G.minimap_apply_count or 0) + 1
   M.EnsureStarted()   -- the companion feeds this every tick in gameplay -> reliable start trigger
   M.PushDiag()        -- refresh the diag line every companion tick, even if the loop never started
   -- NB: don't force M.cfg.showLive here - the companion pushes markers every frame, so forcing it
   -- would override (and break) the F6 "Quest markers" toggle. showLive defaults on; the toggle owns it.
   if blob == nil or blob == "test" then
      local x, y = playerPos()
      if x then
         _G.minimap_live_markers = {
            { x = x + 80, y = y, type = 1, icon = "quest_main_red" },
            { x = x - 80, y = y, type = 5, icon = "" },
            { x = x, y = y + 80, type = 6, icon = "Herbalist" },
            { x = x, y = y - 80, type = 7, icon = "" },
         }
      end
      return
   end
   _G.minimap_live_markers = parseMarkerBlob(blob)
end

-- Player-placed world-map flag (the red marker you drop by right-clicking the world map). The
-- companion reads it (a C_CheckpointMark) and pushes "x,y" here, or "" to clear it when removed.
function minimap_flag(blob)
   blob = tostring(blob or "")
   local xs, ys = string.match(blob, "([%-%d.]+),([%-%d.]+)")
   local x, y = tonumber(xs), tonumber(ys)
   if x and y then M.state.flag = { x = x, y = y }
   else            M.state.flag = nil end
end

-- Native POI feed: full region POI list. With baked data present this is no longer the
-- render source, but it still carries the real per-save discovered state, so we use it to
-- seed discovery (any POI the map shows discovered colours its matching baked POI).
function minimap_apply_poi(blob)
   M.EnsureStarted()
   if blob == nil then return end
   local list = parseMarkerBlob(blob)
   if #list >= 1 then
      _G.minimap_poi_markers = list
      _G.minimap_poi_dirty = true   -- Tick re-seeds discovery from this feed
   end
end

-- Native giver feed: quest-givers, activity-givers, tipsters, arenas and the rest of the game's live
-- entity marks. Blob is "x,y,markType;..." (markType = E_MarkType); the pak looks the icon up in
-- MinimapMarkIcons and draws it. Pushed each scan (empty clears it), so it always reflects the givers near
-- you right now. NB: its own 3-field parser - parseMarkerBlob needs the full x,y,type,icon,letter shape and
-- silently drops a bare "x,y,type" record (that was the "givers never rendered" bug: native emit=12, gv=0).
function minimap_apply_giver(blob)
   local list = {}
   if blob and blob ~= "" then
      for rec in string.gmatch(blob, "[^;]+") do
         local xs, ys, ts = string.match(rec, "([%-%d.]+),([%-%d.]+),([%-%d.]+)")
         local x, y = tonumber(xs), tonumber(ys)
         if x and y then list[#list + 1] = { x = x, y = y, type = tonumber(ts) or 0 } end
      end
   end
   _G.minimap_giver_markers = list
end

-- Seed discovery from the native map feed: each POI the map reports as *discovered*
-- (icon without the "_undiscovered" suffix) marks the nearest baked POI (within 6 m)
-- discovered. Cheap-guarded by _G.minimap_poi_dirty so it only runs when the feed changes.
function M.SeedDiscoveryFromNative(level)
   local pm = _G.minimap_poi_markers
   local baked = type(MinimapPOIData) == "table" and MinimapPOIData[level]
   if type(pm) ~= "table" or type(baked) ~= "table" then return end
   for i = 1, #pm do
      local p = pm[i]
      if p and p.x and not string.find(p.icon or "", "undiscovered", 1, true) then
         local bx, by, best = nil, nil, 36   -- 6 m^2 threshold
         for j = 1, #baked do
            local r = baked[j]
            local dx, dy = r[1] - p.x, r[2] - p.y
            local d2 = dx * dx + dy * dy
            if d2 < best then best = d2; bx, by = r[1], r[2] end
         end
         if bx then markDiscovered(level, bx, by) end
      end
   end
end

-- teleport the player (devmode). minimap_tp <x> <y> [z]   (z defaults to current)
function M.CmdTp(line)
   local xs, ys, zs = string.match(cleanArgs(line), "([%-%d%.]+)%s+([%-%d%.]+)%s*([%-%d%.]*)")
   local x, y = tonumber(xs), tonumber(ys)
   if not x or not y then log("usage: minimap_tp <x> <y> [z]"); return end
   local p = getPlayer()
   if not p or not p.SetWorldPos then log("tp: no player / SetWorldPos"); return end
   local cx, cy, cz = playerPos()
   local z = tonumber(zs) or cz or 0
   pcall(function() p:SetWorldPos({ x = x, y = y, z = z }) end)
   log(string.format("teleported to %.1f, %.1f, %.1f", x, y, z))
end

function M.CmdCatalog()
   M.cfg.showCatalog = (M.cfg.showCatalog == 1) and 0 or 1; M.SaveCfg()
   log("showCatalog = " .. M.cfg.showCatalog .. " (needs global calibration; see docs)")
end

-- calibrate the catalog's global->entity transform for the current level
function M.CmdSetCal(line)
   local offx, offy, scale = string.match(cleanArgs(line), "(%S+)%s+(%S+)%s*(%S*)")
   if not offx then log("usage: minimap_setcal <offx> <offy> [scale]   (offx = global_x - world_x)"); return end
   if not (MinimapData and MinimapData.globalCal) then log("minimap_data.lua not loaded"); return end
   local gc = MinimapData.globalCal[M.state.level]
   if not gc then gc = { scale = 1.0, offx = 0, offy = 0 }; MinimapData.globalCal[M.state.level] = gc end
   gc.offx = tonumber(offx) or gc.offx
   gc.offy = tonumber(offy) or gc.offy
   local s = tonumber(scale); if s and s ~= 0 then gc.scale = s end
   log(string.format("globalCal[%s] offx=%g offy=%g scale=%g", M.state.level, gc.offx, gc.offy, gc.scale))
end

function M.CmdEntities()
   M.cfg.showEntities = (M.cfg.showEntities == 1) and 0 or 1; M.SaveCfg()
   log("showEntities = " .. M.cfg.showEntities)
end

function M.CmdStatus()
   log("---- minimap status v" .. M.VERSION .. " ----")
   log("running=" .. tostring(M.state.running) .. " ingame=" .. tostring(M.state.inGame) ..
       " shown=" .. tostring(M.state.shown) .. " level=" .. M.state.level .. " enabled=" .. M.cfg.enabled)
   log("size=" .. M.cfg.size .. " radius=" .. M.cfg.radius .. "m shape=" .. M.cfg.shape ..
       " rotate=" .. M.cfg.rotateMap .. " corner=" .. M.cfg.corner)
   log("UIAction=" .. tostring(UIAction ~= nil) .. " waypoints=" .. #M.state.waypoints .. " uiKey=" .. tostring(M.cfg.uiKey))
   log("companion=" .. (M.state.asiSeen and "loaded" or "NOT loaded — required for markers + F6"))
end

-- diagnostic: dump every level-name source so we can see which one actually updates on an in-session
-- region change (the "map didn't update after travelling between regions, only a restart fixed it"
-- reports). Run it in one region, travel to the other, run it again, and compare which value moved.
function M.CmdLevelDump()
   log("---- minimap leveldump ----")
   local cands = { "mapname", "sv_map", "cl_levelname", "g_levelName", "e_levelName", "sys_game_folder" }
   if System and System.GetCVar then
      for _, cv in ipairs(cands) do
         local ok, v = pcall(function() return System.GetCVar(cv) end)
         log("  cvar " .. cv .. " = " .. (ok and tostring(v) or "err"))
      end
   end
   if GameToken and GameToken.GetToken then
      for _, tk in ipairs({ "Game.Global.Previous_Level", "Game.Global.Current_Level" }) do
         local ok, v = pcall(function() return GameToken.GetToken(tk) end)
         log("  token " .. tk .. " = " .. (ok and tostring(v) or "n/a"))
      end
   end
   local lv, raw, src = detectLevel()
   log("  detectLevel => " .. tostring(lv) .. " (raw='" .. tostring(raw) .. "' src=" .. tostring(src) .. ")")
   log("  M.state.level = " .. tostring(M.state.level) .. "  inGame=" .. tostring(M.state.inGame))
   local x, y = playerPos()
   log("  playerPos = " .. tostring(x) .. "," .. tostring(y))
end

-- diagnostic: is the player's mounted state reachable in Lua (for an "only show on horseback" option)?
-- Run it on foot and again on horseback and compare. Tries the human bind first (libKCD2:
-- C_ScriptBindHuman::IsMounted), then the horse-id fallback.
function M.CmdMountTest()
   log("---- minimap mounttest ----")
   local p = getPlayer()
   if not p then log("  no player"); return end
   local function try(desc, fn)
      local ok, v = pcall(fn)
      log("  " .. desc .. " = " .. (ok and tostring(v) or ("err: " .. tostring(v))))
   end
   if p.human and p.human.IsMounted then try("human:IsMounted()", function() return p.human:IsMounted() end)
   else log("  human:IsMounted -> method absent") end
   if p.player and p.player.GetHorseId then try("player:GetHorseId()", function() return p.player:GetHorseId() end) end
   if p.actor and p.actor.IsMounted then try("actor:IsMounted()", function() return p.actor:IsMounted() end) end
end

-- restart loop (handy after editing)
function M.CmdReload()
   M.Stop(); M.state.running = false; M.Start()
end

-- ---------------------------------------------------------------------------
-- settings panel (Scaleform overlay drawn by fc_uiRender; navigated by the
-- native plugin relaying the toggle hotkey + arrow keys through _G.minimap_ui)
-- ---------------------------------------------------------------------------
M.ui = { open = false, sel = 1, menu = "main", stack = {} }
_G.minimap_ui_open = "0"   -- mirrored by the .asi; keep in sync with M.ui.open (see M.UiOpen)

local function onoff(v) return (v == 1) and "On" or "Off" end
local function tgl(key) return function() M.cfg[key] = (M.cfg[key] == 1) and 0 or 1 end end
local function stepv(key, s, lo, hi) return function(dir) M.cfg[key] = clamp((M.cfg[key] or lo) + dir * s, lo, hi) end end
local CORNER = { [0] = "Top-Left", [1] = "Top-Right", [2] = "Bottom-Left", [3] = "Bottom-Right" }
local FRAME_STYLE = { [0] = "Ornate", [1] = "Thin", [2] = "Off" }

-- POI types grouped for the filter submenu: { iconBasename, friendly label }. Keyed on the icon
-- so "fast-travel + blacksmiths only" is expressible; a fold collapses several icons into one row.
M.poiGroups = {
   { id = "travel", label = "Travel", icons = {
      { "fastTravel", "Fast-travel" }, { "fastTravelLevel", "Fast-travel (region)" }, { "fastTravelSedlec", "Fast-travel (Sedlec)" } } },
   { id = "craft", label = "Craftsmen & vendors", icons = {
      { "blacksmith", "Blacksmith" }, { "smithy", "Smithy" }, { "weaponsmiths", "Weaponsmith" }, { "armourer", "Armourer" },
      { "gunsmith", "Gunsmith" }, { "tailor", "Tailor" }, { "shoemaker", "Cobbler" }, { "tanner", "Tanner" },
      { "saddler", "Saddler" }, { "herbalist", "Herbalist" }, { "apothecary", "Apothecary" }, { "alchemy", "Alchemy bench" },
      { "bakery", "Baker" }, { "butchery", "Butcher" }, { "hunter", "Hunter" }, { "vegetableShop", "Greengrocer" },
      { "shop", "Trader / shop" }, { "horseTrader", "Horse trader" }, { "scribe", "Scribe" }, { "sharpeningWheel", "Grindstone" },
      { "sellingChest", "Selling chest" }, { "fishingSpot", "Fishing spot" } } },
   { id = "amenity", label = "Amenities & leisure", icons = {
      { "pub", "Tavern" }, { "hotel", "Inn" }, { "baths", "Bathhouse" }, { "indulgences", "Indulgences" },
      { "shrine", "Shrine" }, { "arena", "Combat arena" }, { "archeryArena", "Archery range" }, { "DiceTable", "Dice table" },
      { "washing", "Laundry" }, { "dryingFood", "Food dryer" }, { "smokingFood", "Smokehouse" } } },
   { id = "world", label = "World & nature",
     icons = {
      { "generalPoi", "Point of interest" }, { "camp", "Camp" }, { "campEnemy", "Enemy camp" }, { "grave", "Grave" },
      { "mineEnrtrance", "Mine entrance" }, { "forestGarden", "Herb garden" }, { "bed", "Bed" } },
     folds = { { "Hunting spots", { "huntingSpot", "huntingSpotRoe", "huntingSpotBoar", "huntingSpotWolf" } } } },
   -- live entity marks (see minimap_markicons.lua); filtered by the same poiOff icon keys as the POIs above
   { id = "givers", label = "Givers & tipsters", icons = {
      { "questGiver", "Quest-giver" }, { "activityGiver", "Activity-giver" }, { "poiTipster", "POI tipster" },
      { "skillTeacher", "Trainer" }, { "barber", "Barber" }, { "ShieldPainter", "Shield painter" },
      { "fightArena", "Fight arena" }, { "fistFightArena", "Fist-fight arena" }, { "hub", "Settlement" },
      { "dog", "Dog" } },
     folds = { { "DLC activity-givers", { "DLC0", "DLC1", "DLC2", "DLC3", "DLC2_smithing", "DLC2_dice",
      "DLC2_acquiringPackages", "DLC2_archery", "DLC2_donations", "DLC2_duels", "DLC2_stealingPackages",
      "DLC2_activities" } } } },
}

local function poiOn(icon) return not (M.cfg.poiOff and M.cfg.poiOff[icon]) end
local function poiItem(icon, label)
   return { label = label,
      get = function() return onoff(poiOn(icon) and 1 or 0) end,
      change = function() M.cfg.poiOff[icon] = poiOn(icon) and true or nil end }
end
local function poiFold(label, icons)   -- one toggle driving several icons at once
   return { label = label,
      get = function() return onoff(poiOn(icons[1]) and 1 or 0) end,
      change = function() local off = poiOn(icons[1]); for _, ic in ipairs(icons) do M.cfg.poiOff[ic] = off and true or nil end end }
end
local function groupSetAll(icons, show)   -- explicit if: "x and nil or true" always yields true
   return function()
      for _, ic in ipairs(icons) do
         if show then M.cfg.poiOff[ic] = nil else M.cfg.poiOff[ic] = true end
      end
   end
end

-- Build the settings menu tree. Item kinds: value (get + change), submenu link (goto_),
-- back (back), action (action). The Flash panel just renders whatever rows we hand it, so the
-- whole submenu system lives here with no gfx change.
function M.BuildMenus()
   -- Grouped into three categories so the panel stays short and scannable (the flat list had grown to
   -- ~25 rows). Each category is its own submenu, reached from the main menu; the panel's submenu/back
   -- stack already handles the depth (same mechanism the POI filters use).
   local appearance = {
      { label = "< Back", back = true, desc = "Back to settings." },
      { label = "Size", get = function() return M.cfg.size .. " px" end, change = stepv("size", 16, 128, 512),
        desc = "Diameter of the minimap on screen, in pixels." },
      { label = "Zoom (radius)", get = function() return M.cfg.radius .. " m" end, change = stepv("radius", 20, 60, 400),
        desc = "How many metres from the centre to the rim - lower is more zoomed in." },
      { label = "Corner", get = function() return CORNER[M.cfg.corner] or "?" end, change = function(dir) M.cfg.corner = (M.cfg.corner + dir) % 4 end,
        desc = "Which screen corner the minimap sits in." },
      { label = "Screen margin", get = function() return (M.cfg.margin or 0) .. " px" end, change = stepv("margin", 4, 0, 200),
        desc = "Gap between the minimap and the screen edges, in pixels." },
      { label = "Border style", get = function() return FRAME_STYLE[M.cfg.frameStyle] or "Ornate" end,
        change = function(dir) M.cfg.frameStyle = ((M.cfg.frameStyle or 0) + dir) % 3 end,
        desc = "The ornate carved-gold ring, a fine gold rim, or no border." },
      { label = "North marker", get = function() return onoff(M.cfg.showNorth) end, change = tgl("showNorth"),
        desc = "Show or hide the north marker. It matches the border style." },
      { label = "Rotate with player", get = function() return onoff(M.cfg.rotateMap) end, change = tgl("rotateMap"),
        desc = "On: the map rotates so your facing is always up. Off: the map stays north-up." },
      { label = "Player marker", get = function() return onoff(M.cfg.showPlayer) end, change = tgl("showPlayer"),
        desc = "Show the arrow at the centre. Off for a hardcore feel - navigate by POIs instead." },
      { label = "Map opacity", get = function() return M.cfg.mapAlpha .. "%" end, change = stepv("mapAlpha", 10, 0, 100),
        desc = "Opacity of the map image under the markers." },
      { label = "Dim at night", get = function() return onoff(M.cfg.autoDim) end, change = tgl("autoDim"),
        desc = "Automatically fade the whole minimap by the in-game time of day, so markers and the border don't glare at night." },
      { label = "Night brightness", get = function() return M.cfg.dimNight .. "%" end, change = stepv("dimNight", 5, 10, 100),
        desc = "How bright the minimap stays at deep night when 'Dim at night' is on (lower = darker)." },
      { label = "Clock", get = function() return onoff(M.cfg.showClock) end,
        change = function() M.cfg.showClock = (M.cfg.showClock == 1) and 0 or 1; M.PushClock(true) end,
        desc = "Show the in-game time (HH:MM) on a plaque on the minimap frame." },
      { label = "Auto-fit aspect", get = function() return onoff(M.cfg.aspectAuto) end, change = tgl("aspectAuto"),
        desc = "Automatically keep the minimap round on ultrawide/stretched displays (needs the companion). Turn off to set the width by hand." },
      { label = "Aspect (manual)", get = function() return (M.cfg.aspectAuto == 1) and "Auto" or ((M.cfg.aspect or 100) .. " %") end,
        change = function(dir) M.cfg.aspectAuto = 0; M.cfg.aspect = clamp((M.cfg.aspect or 100) + dir * 2, 40, 200) end,
        desc = "Manual horizontal width, for when auto-fit isn't right. Lower it until the map is a perfect circle (about 50 on 32:9). Switches auto-fit off." },
   }
   local markers = {
      { label = "< Back", back = true, desc = "Back to settings." },
      { label = "Quest markers", get = function() return onoff(M.cfg.showLive) end, change = tgl("showLive"),
        desc = "Show active quest and objective markers on the minimap." },
      { label = "Show untracked quests", get = function() return onoff(M.cfg.showUntracked) end, change = tgl("showUntracked"),
        desc = "Also show quests you haven't tracked in the journal, not just the tracked ones." },
      { label = "Objective distance", get = function() return onoff(M.cfg.showObjDist) end,
        change = function() M.cfg.showObjDist = (M.cfg.showObjDist == 1) and 0 or 1 end,
        desc = "Show the distance in metres on each tracked quest/objective icon." },
      { label = "Distance from", get = function() return (M.cfg.objDistMin or 0) == 0 and "Any" or (M.cfg.objDistMin .. " m") end, change = stepv("objDistMin", 25, 0, 2000),
        desc = "Only label objectives at least this far away (Any = no minimum). Needs 'Objective distance' on." },
      { label = "Distance up to", get = function() return (M.cfg.objDistMax or 0) == 0 and "No limit" or (M.cfg.objDistMax .. " m") end, change = stepv("objDistMax", 50, 0, 5000),
        desc = "Only label objectives within this range (No limit = no maximum). Needs 'Objective distance' on." },
      { label = "Givers & tipsters", get = function() return onoff(M.cfg.showGivers) end, change = tgl("showGivers"),
        desc = "Show quest-givers, activity-givers and tipsters near you. Pick which types in POI filters." },
      { label = "POI icon size", get = function() return (M.cfg.iconSize == 0) and "Dots" or (M.cfg.iconSize .. " px") end, change = stepv("iconSize", 2, 0, 40),
        desc = "Size of POI icons in pixels (0 shows plain dots instead of icons)." },
      { label = "POI range", get = function() return (M.cfg.poiRange or 240) .. " m" end, change = stepv("poiRange", 20, 40, 1000),
        desc = "How far out POIs show, in metres. Higher shows more of the region, lower declutters." },
      { label = "Grey undiscovered", get = function() return onoff(M.cfg.grayUndisc) end, change = tgl("grayUndisc"),
        desc = "Draw POIs you haven't discovered yet greyed out, like on the world map." },
      { label = "Hide undiscovered", get = function() return onoff(M.cfg.hideUndisc) end, change = tgl("hideUndisc"),
        desc = "Hide undiscovered POIs entirely - only show what you've actually found." },
      { label = "Treasures", get = function() return ({ [0] = "Off", [1] = "Discovered", [2] = "Reveal all" })[M.cfg.treasure or 0] or "?" end,
        change = function(dir) M.cfg.treasure = ((M.cfg.treasure or 0) + dir) % 3 end,
        desc = "Buried-treasure marks (chest icon), for treasures we can tie to a map. Off: hidden. Discovered: only sites you have the map for. Reveal all: all of them (greyed = you don't have its map)." },
      { label = "Edge: quests", get = function() return onoff(M.cfg.edgeQuests) end, change = tgl("edgeQuests"),
        desc = "Pin off-range quest, objective and waypoint markers to the rim, pointing the way." },
      { label = "Edge: POIs", get = function() return onoff(M.cfg.edgePois) end, change = tgl("edgePois"),
        desc = "Pin off-range POIs to the rim too (only out to the POI range, so it stays readable)." },
      { label = "Edge: givers", get = function() return onoff(M.cfg.edgeGivers) end, change = tgl("edgeGivers"),
        desc = "Pin off-range giver and tipster icons to the rim. Turn off to keep them off the edge in busy areas." },
      { label = "Giver rim range", get = function() return (M.cfg.giverRange or 0) == 0 and "All" or (M.cfg.giverRange .. " m") end, change = stepv("giverRange", 250, 0, 2000),
        desc = "How far a giver can be and still ride the rim (All = no limit). Lower it to declutter the edge." },
      { label = "POI filters", goto_ = "poi",
        desc = "Choose exactly which POI types show, on the map and the rim. Press right to open." },
   }
   local visibility = {
      { label = "< Back", back = true, desc = "Back to settings." },
      { label = "Only on horseback", get = function() return onoff(M.cfg.showOnHorse) end, change = tgl("showOnHorse"),
        desc = "Only show the minimap while you're riding - it hides automatically when you're on foot." },
      { label = "Hide in menus", get = function() return onoff(M.cfg.hideOnMenu) end, change = tgl("hideOnMenu"),
        desc = "Hide the minimap while a full-screen menu or trade screen is open." },
      { label = "Hide in dialogue", get = function() return onoff(M.cfg.hideInDialog) end, change = tgl("hideInDialog"),
        desc = "Also hide the minimap during dialogues and cutscenes (the letterbox bars)." },
      { label = "Hide in combat", get = function() return onoff(M.cfg.hideInCombat) end, change = tgl("hideInCombat"),
        desc = "Hide the minimap while you're in combat, to declutter fights." },
      { label = "Hide with game HUD", get = function() return onoff(M.cfg.hideWithHud) end, change = tgl("hideWithHud"),
        desc = "Also hide the minimap when the game HUD is off. Off by default so it still shows in Hardcore, where the HUD is disabled." },
      { label = "Hide game compass", get = function() return onoff(M.cfg.hideCompass) end, change = tgl("hideCompass"),
        desc = "Hide the vanilla compass bar - the minimap rim shows quest directions instead." },
   }
   local main = {
      { label = "Appearance",     goto_ = "appearance", desc = "Size, position, border, opacity and night dimming." },
      { label = "Markers & POIs", goto_ = "markers",    desc = "Quest markers, POI icons and per-type filters." },
      { label = "Visibility",     goto_ = "visibility", desc = "When the minimap shows or hides: menus, combat, horseback." },
   }
   local menus = { main = main, appearance = appearance, markers = markers, visibility = visibility }
   local poi = { { label = "< Back", back = true, desc = "Back to markers." } }
   for _, g in ipairs(M.poiGroups) do
      poi[#poi + 1] = { label = g.label, goto_ = "poi_" .. g.id, desc = "Pick which " .. g.label .. " POIs show." }
   end
   menus.poi = poi
   for _, g in ipairs(M.poiGroups) do
      local all = {}
      for _, ic in ipairs(g.icons) do all[#all + 1] = ic[1] end
      if g.folds then for _, f in ipairs(g.folds) do for _, ic in ipairs(f[2]) do all[#all + 1] = ic end end end
      local m = { { label = "< Back", back = true, desc = "Back to POI filters." },
                  { label = "[ Show all ]", action = groupSetAll(all, true), desc = "Show every type in this group." },
                  { label = "[ Hide all ]", action = groupSetAll(all, false), desc = "Hide every type in this group." } }
      for _, ic in ipairs(g.icons) do m[#m + 1] = poiItem(ic[1], ic[2]) end
      if g.folds then for _, f in ipairs(g.folds) do m[#m + 1] = poiFold(f[1], f[2]) end end
      menus["poi_" .. g.id] = m
   end
   M.menus = menus
end
M.BuildMenus()

function M.UiRender()
   local items = (M.menus and M.menus[M.ui.menu]) or M.menus.main
   if M.ui.sel > #items then M.ui.sel = #items end
   if M.ui.sel < 1 then M.ui.sel = 1 end
   local parts = {}
   for i, it in ipairs(items) do
      local val = it.get and tostring(it.get()) or (it.goto_ and ">" or "")
      parts[i] = it.label .. "=" .. val
   end
   local desc = (items[M.ui.sel] and items[M.ui.sel].desc) or ""
   ui_call("UiRender", M.ui.sel - 1, table.concat(parts, "|"), desc)
end

-- Apply the show/hide decision right now, mirroring the tick's gates (enabled -> in-game -> menu ->
-- combat). UiApply calls this so a visibility setting (Hide in menus / Hide in combat / Enabled)
-- takes effect the instant you toggle it: the F6 panel runs on the .asi poll, which keeps firing while
-- a full menu holds the main tick timer, so without this the change waited for the next tick / a panel
-- reopen.
function M.RefreshVisibility()
   if M.cfg.enabled ~= 1 or not M.state.inGame or not M.state.px then M.PushShow(false); return end
   if M.cfg.hideOnMenu == 1 and M.IsBlockingUIOpen() then M.PushShow(false); return end
   if M.cfg.hideInCombat == 1 and inCombat() then M.PushShow(false); return end
   if M.cfg.showOnHorse == 1 and not isMounted() then M.PushShow(false); return end
   M.PushShow(true)
end

function M.UiApply()               -- apply a changed setting live + persist
   M.state.mapSent = nil           -- force map re-send (covers hires toggle)
   M.PushConfig(); M.SaveCfg()
   M.RefreshVisibility()           -- reflect Hide-in-menus/combat/enabled at once, not on the next tick
end

-- freeze the player while the panel is open (arrow keys would otherwise walk you around). The
-- .asi polls F6 + arrows via GetAsyncKeyState, which isn't gated by action maps, so panel
-- navigation keeps working even with the player map disabled. Tick re-enables as a watchdog.
function M.LockPlayer(lock)
   if not (ActionMapManager and ActionMapManager.EnableActionMap) then return end
   pcall(function() ActionMapManager.EnableActionMap("player", not lock) end)
   M.state.playerLocked = lock and true or false
end

function M.UiEnter(menuId)
   M.ui.stack = M.ui.stack or {}
   M.ui.stack[#M.ui.stack + 1] = { menu = M.ui.menu, sel = M.ui.sel }
   M.ui.menu = menuId; M.ui.sel = 1
end
function M.UiBack()
   local st = M.ui.stack and M.ui.stack[#M.ui.stack]
   if st then M.ui.stack[#M.ui.stack] = nil; M.ui.menu = st.menu; M.ui.sel = st.sel
   else M.ui.menu = "main"; M.ui.sel = 1 end
end

function M.UiOpen(v)
   M.ui.open = (v ~= false)
   _G.minimap_ui_open = M.ui.open and "1" or "0"   -- authoritative panel state; the .asi mirrors this so F6 can't desync
   if not M.ui.open then M.ui.menu = "main"; M.ui.sel = 1; M.ui.stack = {} end
   -- make sure the element is actually composited before we show the panel. ShowElement normally
   -- runs in PushConfig (loop only), so without this the F6 panel is invisible whenever the loop
   -- hasn't started yet (opens at the Lua level but the movie is never drawn to screen).
   if M.ui.open and UIAction and UIAction.ShowElement then
      pcall(function() UIAction.ShowElement(M.ELEMENT, M.INSTANCE) end)
   end
   ui_call("UiShow", M.ui.open and 1 or 0)
   M.LockPlayer(M.ui.open)
   if M.ui.open then M.UiRender() end
   M.PushDiag()   -- refresh so the diag the companion logs on this F6 reflects the new panel state
   log("settings panel " .. (M.ui.open and "opened" or "closed"))
end

function M.UiNav(cmd)
   if cmd == "toggle" then M.UiOpen(not M.ui.open); return end
   if cmd == "close"  then M.UiOpen(false); return end
   if cmd == "open"   then M.UiOpen(true); return end
   if not M.ui.open then return end
   local items = (M.menus and M.menus[M.ui.menu]) or M.menus.main
   local n = #items
   local it = items[M.ui.sel]
   if     cmd == "up"    then M.ui.sel = ((M.ui.sel - 2) % n) + 1
   elseif cmd == "down"  then M.ui.sel = (M.ui.sel % n) + 1
   elseif cmd == "right" then
      if     it and it.goto_  then M.UiEnter(it.goto_)
      elseif it and it.back   then M.UiBack()
      elseif it and it.action then it.action(); M.UiApply()
      elseif it and it.change then it.change(1); M.UiApply() end
   elseif cmd == "left" then
      if it and it.change then it.change(-1); M.UiApply()
      else M.UiBack() end        -- left = step out of a submenu for non-value rows
   end
   M.UiRender()
end

-- native-plugin entry point: the ASI relays the settings hotkey + nav keys here. Doesn't start the
-- loop (F6 is relayed even at the menu; the panel shows via UiOpen's own ShowElement) and doesn't
-- confirm gameplay, so the map can't be summoned to the menu by pressing F6 there.
function minimap_ui(cmd) M.UiNav(tostring(cmd)) end
-- native-plugin entry point: the ASI relays a HOLD of the panel key here to toggle the whole minimap
-- on/off (session-only, same as the minimap_toggle console command). RefreshVisibility applies it at
-- once so it doesn't wait for the next tick.
function minimap_togglevis()
   M.CmdToggle()
   pcall(function() M.RefreshVisibility() end)
end
-- native-plugin entry point: the ASI relays menu open/close (detected from the game's UI
-- feeds) here, since KCD2's real-time inventory can't be seen from the pak's own signals.
function minimap_menu(v) M.state.apseOpen = (tostring(v) == "1") end
-- native-plugin entry point: letterbox bars up = cinematic dialogue/cutscene (the E_HudElements
-- RatioStrips bit, read natively). Honoured by IsBlockingUIOpen under hideInDialog. The old pak-only
-- IsInDialog/IsWaitingForDialogueReply binds don't fire on 1.5.6, so this is the real dialogue signal.
function minimap_letterbox(v) M.state.letterbox = (tostring(v) == "1") end
-- native-plugin entry point: the ASI calls this once when it loads (at bridge-verify, which can be at
-- the main menu). Only records that the companion is present - must NOT confirm gameplay or start the
-- loop, or the map would appear over the menu backdrop.
function minimap_asi(v) M.state.asiSeen = true end
-- native-plugin entry point: the ASI acknowledges the fresh-load signal once it has reset.
function minimap_ack_load() _G.minimap_freshload = nil end
-- native-plugin entry point: the ASI reports the game's output resolution ("W,H") so auto-fit can
-- keep the UI round on any display aspect (see M.EffAspect). Stored; the tick re-pushes on change.
function minimap_screen(blob)
   local w, h = tostring(blob):match("(%d+)%s*,%s*(%d+)")
   w, h = tonumber(w), tonumber(h)
   if w and h and w > 0 and h > 0 and (w ~= M.state.screenW or h ~= M.state.screenH) then
      M.state.screenW, M.state.screenH = w, h
      if M.state.running then pcall(function() M.PushConfig() end) end   -- apply the new aspect at once
   end
end
function M.CmdUi(line) M.UiNav(cleanArgs(line)) end

-- ---------------------------------------------------------------------------
-- registration
-- ---------------------------------------------------------------------------
local function addCmd(name, expr, help)
   if System and System.AddCCommand then
      pcall(function() System.AddCCommand(name, expr, help) end)
   end
end

function M.RegisterCommands()
   addCmd("minimap_toggle",    "Minimap.CmdToggle()",            "Toggle the minimap on/off")
   addCmd("minimap_zoom",      "Minimap.CmdZoom([[%line]])",     "Set view radius in metres")
   addCmd("minimap_size",      "Minimap.CmdSize([[%line]])",     "Set viewport size in px")
   addCmd("minimap_aspect",    "Minimap.CmdAspect([[%line]])",   "Horizontal width: <percent> or auto (ultrawide oval fix)")
   addCmd("minimap_rotate",    "Minimap.CmdRotate()",            "Toggle rotate-map / north-up")
   addCmd("minimap_corner",    "Minimap.CmdCorner([[%line]])",   "Screen corner 0..3")
   addCmd("minimap_level",     "Minimap.CmdLevel([[%line]])",    "Force level id")
   addCmd("minimap_detect",    "Minimap.CmdDetect()",            "Diagnose level auto-detection")
   addCmd("minimap_autocal",   "Minimap.CmdAutoCal()",           "Read calibration from game map data")
   addCmd("minimap_dumpmap",   "Minimap.CmdDumpMap()",           "Dump the engine GlobalMap array")
   addCmd("minimap_set",       "Minimap.CmdSet([[%line]])",      "Calibrate: minimap_set <key> <value>")
   addCmd("minimap_calibrate", "Minimap.CmdCalibrate()",         "Print player world pos + UV")
   addCmd("minimap_interiortest", "Minimap.CmdInteriorTest()",   "Test the interior-area signal at your spot")
   addCmd("minimap_here",      "Minimap.CmdHere([[%line]])",     "Calibrate (offset only): I am at image u v")
   addCmd("minimap_p1",        "Minimap.CmdP1([[%line]])",       "2-point calibrate: point 1 at u v")
   addCmd("minimap_p2",        "Minimap.CmdP2([[%line]])",       "2-point calibrate: point 2 at u v")
   addCmd("minimap_p3",        "Minimap.CmdP3([[%line]])",       "3rd calibrate point (full affine, fixes mirror)")
   addCmd("minimap_pan",       "Minimap.CmdPan([[%line]])",      "Shift map: du dv")
   addCmd("minimap_head",      "Minimap.CmdHead([[%line]])",     "Rotate heading/arrow: deg")
   addCmd("minimap_calinfo",   "Minimap.CmdCalInfo()",           "Show rot/scale/mirror/pan + adjust help")
   addCmd("minimap_north",     "Minimap.CmdNorth()",             "Set heading: I am facing north now")
   addCmd("minimap_reset",     "Minimap.CmdReset()",             "Reset all calibration to defaults")
   addCmd("minimap_mark",      "Minimap.CmdMark([[%line]])",     "Drop a waypoint at the player")
   addCmd("minimap_clearmarks","Minimap.CmdClearMarks()",        "Clear all waypoints")
   addCmd("minimap_testlive",  "Minimap.CmdTestLive()",          "Inject test live markers (bridge test)")
   addCmd("minimap_live",      "Minimap.CmdLive()",              "Toggle live (native-plugin) quest markers")
   addCmd("minimap_poi",       "Minimap.CmdPoi()",               "Toggle live POI markers (distance-filtered)")
   addCmd("minimap_baked",     "Minimap.CmdBaked()",             "Toggle baked static POI database (markers on spawn)")
   addCmd("minimap_givers",    "Minimap.CmdGivers()",            "Toggle quest-giver / activity-giver / tipster marks")
   addCmd("minimap_clock",     "Minimap.CmdClock()",             "Toggle the in-game clock (HH:MM)")
   addCmd("minimap_objdist",   "Minimap.CmdObjDist()",           "Toggle the distance-to-objective readout")
   addCmd("minimap_grayundisc","Minimap.CmdGrayUndisc()",        "Toggle greying of undiscovered POIs")
   addCmd("minimap_hideundisc","Minimap.CmdHideUndisc()",        "Toggle hiding undiscovered POIs entirely")
   addCmd("minimap_treasure",  "Minimap.CmdTreasure()",          "Treasure marks: cycle off / discovered / reveal all")
   addCmd("minimap_treasurediag","Minimap.CmdTreasureDiag()",     "Log the map-ownership check for each known treasure site")
   addCmd("minimap_discoverall","Minimap.CmdDiscoverAll()",      "Reveal all POIs in this region")
   addCmd("minimap_discreset", "Minimap.CmdDiscoverReset()",     "Re-grey all POIs in this region")
   addCmd("minimap_iconsize",  "Minimap.CmdIconSize([[%line]])",  "POI icon size in px (0 = dots)")
   addCmd("minimap_tp",        "Minimap.CmdTp([[%line]])",       "Teleport player to x y [z]")
   addCmd("minimap_catalog",   "Minimap.CmdCatalog()",           "Toggle static POI catalog")
   addCmd("minimap_setcal",    "Minimap.CmdSetCal([[%line]])",   "Calibrate catalog: <offx> <offy> [scale]")
   addCmd("minimap_entities",  "Minimap.CmdEntities()",          "Toggle nearby-entity markers")
   addCmd("minimap_status",    "Minimap.CmdStatus()",            "Print status")
   addCmd("minimap_menuhide",  "Minimap.CmdMenuHide()",          "Toggle auto-hide while menus are open")
   addCmd("minimap_hidewithhud","Minimap.CmdHideWithHud()",      "Toggle hiding the minimap when the game HUD is off (Hardcore)")
   addCmd("minimap_hidecombat","Minimap.CmdHideCombat()",       "Toggle hiding the minimap while in combat")
   addCmd("minimap_compass",   "Minimap.CmdCompass()",           "Toggle hiding the vanilla HUD compass")
   addCmd("minimap_player",    "Minimap.CmdPlayer()",            "Toggle the centre player marker")
   addCmd("minimap_unstick",   "Minimap.CmdUnstick()",           "Force-unlock + close the panel if it gets stuck")
   addCmd("minimap_uistate",   "Minimap.CmdUiState()",           "Diagnose menu/UI detection signals")
   addCmd("minimap_leveldump", "Minimap.CmdLevelDump()",         "Dump every level-name source (region-change debug)")
   addCmd("minimap_mounttest", "Minimap.CmdMountTest()",         "Test whether the player's mounted state is readable")
   addCmd("minimap_reload",    "Minimap.CmdReload()",            "Restart the minimap loop")
   addCmd("minimap_ui",        "Minimap.CmdUi([[%line]])",       "Settings panel: toggle|up|down|left|right|close")
end

-- ---------------------------------------------------------------------------
-- diagnostics: a compact state line the companion pulls into its own log. Users send the .asi log,
-- which otherwise goes silent past the point it hands off to the pak - this surfaces where the render
-- pipeline actually broke (loop not running / not in game / element not reached) without kcd.log.
-- ---------------------------------------------------------------------------
-- why the minimap is hidden right now, surfaced in the companion status line (a hidden minimap could be
-- any of the gates below, and pak log() doesn't reach the companion log - so we were guessing). Mirrors
-- tickBody's order.
local function hideReason()
   if M.cfg.enabled ~= 1 then return "disabled" end
   if not M.state.inGame then return "notingame" end
   if M.cfg.hideOnMenu == 1 and M.IsBlockingUIOpen() then
      if M.state.apseOpen then return "menu" end
      if not M.state.asiSeen and worldTimePaused() == true then return "worldpaused" end
      if tryGame("IsPaused") == true then return "paused" end
      if tryGame("IsGameplayStarted") == false then return "notstarted" end
      if M.cfg.hideWithHud == 1 and hudHiddenByCvar() then return "hudoff" end
      return "dialog"
   end
   if M.cfg.hideInCombat == 1 and inCombat() then return "combat" end
   if M.cfg.showOnHorse == 1 and not isMounted() then return "onfoot" end
   return "ok"
end
function M.Diag()
   -- hb is the tick heartbeat: if it advances between log lines the poll loop is alive; frozen hb
   -- with ingame=1 is the stall this build now self-heals. wd is the watchdog's healthy-gap estimate
   -- (feeds per tick); it must stay small/bounded - a large wd was the recovery-slows-every-load bug.
   -- tickErr surfaces a caught body error.
   -- hide=<reason> says why shown=0 (combat/menu/hudoff/onfoot/disabled/...) so we're not guessing.
   -- gv = live giver/tipster markers received from the companion feed (like mk, but for the giver source).
   local gm = _G.minimap_giver_markers
   return string.format(
      "v%s run=%d ingame=%d shown=%d hb=%d wd=%d panel=%d ui=%d lvl=%s en=%d mk=%d gv=%d hide=%s%s",
      M.VERSION,
      M.state.running and 1 or 0,
      M.state.inGame and 1 or 0,
      M.state.shown and 1 or 0,
      M.state.hb or 0,
      M.state.hbMaxGap or 0,
      (M.ui and M.ui.open) and 1 or 0,
      (UIAction ~= nil) and 1 or 0,
      tostring(M.state.level),
      M.cfg.enabled or 0,
      M.state.markerN or 0,
      (type(gm) == "table") and #gm or -1,
      hideReason(),
      M.state.tickErr and (" err=" .. tostring(M.state.tickErr)) or "")
end
function M.PushDiag() _G.minimap_diag = M.Diag() end

-- ---------------------------------------------------------------------------
-- boot
-- ---------------------------------------------------------------------------
M.RegisterCommands()

-- Register for the gameplay events. UIAction can still be absent this early in boot; if so, retry on
-- a timer until it's there, so the registration is never silently skipped (this is one of the ways we
-- start). registerEvents only registers once - it reschedules itself only while UIAction is missing.
local function registerEvents()
   if not (UIAction and UIAction.RegisterEventSystemListener) then
      Script.SetTimer(1000, registerEvents); return
   end
   pcall(function()
      UIAction.RegisterEventSystemListener(Minimap, "", "OnGameplayStarted", "OnGameLoaded")
      UIAction.RegisterEventSystemListener(Minimap, "", "OnGameplayEnded",   "OnGameplayEndedEvt")
      UIAction.RegisterEventSystemListener(Minimap, "", "OnGamePause",       "OnGamePauseEvt")
      UIAction.RegisterEventSystemListener(Minimap, "", "OnGameResume",      "OnGameResumeEvt")
   end)
   -- NB: do NOT register an element listener ("minimap") here. This runs in the Startup-script window,
   -- before the engine has registered the UIElement, and UIAction.RegisterElementListener then
   -- null-derefs inside WHGame.dll -> hard crash before the menu (pcall can't catch a C access
   -- violation). The Flash-log relay it fed is dropped; if revived, register it after gameplay starts.
end
registerEvents()

-- The loop has three independent start triggers, because no single one covers every load path:
--   1. the OnGameplayStarted event (registered above) - also sets the gameplay latch,
--   2. the companion's live marker feeds via M.EnsureStarted - covers load paths the event misses
--      (e.g. auto-continue straight into the exit save, where the minimap otherwise loads but never
--      runs: running=false in minimap_status) - also sets the gameplay latch,
--   3. this poll, as a pak-only safety net when the companion isn't installed (on normal loads the
--      event sets the latch; the poll only ensures the loop itself is running).
-- Start() is guarded by M.state.running. The minimap only SHOWS once M.state.inGame is set, so a loop
-- that happens to start on the main-menu backdrop (which can expose a player) stays hidden until real
-- gameplay is confirmed.
local function startWhenReady()
   if M.state.running then return end
   if getPlayer() ~= nil then M.Start() else Script.SetTimer(1000, startWhenReady) end
end
Script.SetTimer(1500, startWhenReady)

M.PushDiag()   -- seed the diag line immediately so the companion has something to read at boot
_G.minimap_ui_key = M.cfg.uiKey or "F6"   -- seed the panel hotkey before the config file loads over it
log("loaded v" .. M.VERSION .. " (awaiting game load)")
