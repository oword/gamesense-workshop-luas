-- nyaahook! for Counter-Strike: Global Offensive, by nicole

-- Localized functions
-- gamesense
local ui_get, ui_set, entity_get_player_weapon, entity_get_players, entity_get_local_player, entity_get_prop, entity_hitbox_position, entity_is_alive, entity_is_dormant, globals_chokedcommands, globals_curtime, globals_tickcount, globals_tickinterval, globals_mapname, plist_get, plist_set, client_trace_line, client_latency, client_set_clan_tag, client_screen_size, client_eye_position, entity_get_all, renderer_world_to_screen, renderer_indicator, string_format, string_sub = ui.get, ui.set, entity.get_player_weapon, entity.get_players, entity.get_local_player, entity.get_prop, entity.hitbox_position, entity.is_alive, entity.is_dormant, globals.chokedcommands, globals.curtime, globals.tickcount, globals.tickinterval, globals.mapname, plist.get, plist.set, client.trace_line, client.latency, client.set_clan_tag, client.screen_size, client.eye_position, entity.get_all, renderer.world_to_screen, renderer.indicator, string.format, string.sub
-- Lua
local bit_band, math_abs, math_floor, math_min, math_max, math_sqrt, math_pow, string_rep, string_sub = bit.band, math.abs, math.floor, math.min, math.max, math.sqrt, math.pow, string.rep, string.sub

-- Libraries
local csgo_weapons = require "gamesense/csgo_weapons"
local ffi = require "ffi"
local vector = require "vector"

-- Game definitions
local hitbox_e =
{
	head = 0,
	pelvis = 2,
	body = 3,
	thorax = 4,
	chest = 5,
	left_thigh = 7,
	right_thigh = 8,
	left_foot = 11,
	right_foot = 12,
	left_hand = 13,
	right_hand = 14,
	left_upper_arm = 15,
	left_forearm = 16,
	right_upper_arm = 17,
	right_forearm = 18
}

local flags_e =
{
	fakeclient = bit.lshift(1, 9)
}

local weapon_e =
{
	awp = 9,
	r8_revolver = 64
}

-- Other definitions
local virtual_key_e =
{
	xbutton2 = 6,
	f3 = 114
}

local MAX_CLAN_TAG_LENGTH = 15 -- 15 + null terminator

-- https://i.imgur.com/iewrwSh.png
local g_pfnLineGoesThroughSmoke = ffi.cast(ffi.typeof("bool(__cdecl*)(float flFromX, float flFromY, float flFromZ, float flToX, float flToY, float flToZ)"),
	client.find_signature("client.dll", "\x55\x8B\xEC\x83\xEC\x08\x8B\x15\xCC\xCC\xCC\xCC\x0F") or error("client.dll!::LineGoesThroughSmoke could not be found. Signature is outdated."))

-- Constants
local CLANTAG_TEXT = "nyaahook!"
local CLANTAG_LOOP_SIZE = 32
local CLANTAG_UPDATE_SPEED = 3.3
local CLANTAG_UPDATE_INTERVAL = 0.03

local DYNAMIC_FOV_DISTANCE_SCALE = 4000.0
local DYNAMIC_FOV_UPDATE_INTERVAL = 4 -- Tick interval per dynamic fov updates
local DYNAMIC_FOV_MIN_DISTANCE = 1500.0
local DYNAMIC_FOV_MAX_DISTANCE = 100.0

local SMOKE_HITBOXES = { hitbox_e.head, hitbox_e.left_foot, hitbox_e.right_foot, hitbox_e.left_hand, hitbox_e.right_hand }
local SMOKE_PERSISTANCE_TIMER = 17.0 -- Beyond this point, enemies inside the smoke will fade out of it

local VISIBILE_PENETRATION_HITBOXES = { hitbox_e.left_hand, hitbox_e.right_hand, hitbox_e.left_foot, hitbox_e.right_foot, hitbox_e.head, hitbox_e.left_thigh, hitbox_e.right_thigh,
	hitbox_e.left_upper_arm, hitbox_e.right_upper_arm, hitbox_e.left_forearm, hitbox_e.right_forearm, hitbox_e.pelvis, hitbox_e.body, hitbox_e.chest, hitbox_e.thorax }
local VISIBILITY_SCALE = 30.0 -- Add N units to each horizontal direction of a hitbox
local VISIBILITY_DIRECTIONS = { { 0.0, 0.0 }, { VISIBILITY_SCALE, 0.0 }, { -VISIBILITY_SCALE, 0.0 }, { 0.0, VISIBILITY_SCALE }, { 0.0, -VISIBILITY_SCALE } } -- ugly.... center, north, east, south, west

local EYE_ANGLES_PITCH_ANTIAIM = 75.0 -- If your pitch is above that, you're probably not using legit anti-aim

-- Menu references
local g_pAimbotEnabled, g_pAimbotHotkey = ui.reference("RAGE", "Aimbot", "Enabled")
local g_pAimbotAvoidUnsafeHitboxes = ui.reference("RAGE", "Aimbot", "Avoid unsafe hitboxes")
local g_pAimbotAutomaticFire = ui.reference("RAGE", "Aimbot", "Automatic fire")
local g_pAimbotAutomaticPenetration = ui.reference("RAGE", "Aimbot", "Automatic penetration")
local g_pAimbotFieldOfView = ui.reference("RAGE", "Aimbot", "Maximum FOV")
local g_pDefaultClantagSpammer = ui.reference("MISC", "Miscellaneous", "Clan tag spammer")
local g_pMaxUserCMDProcessTicks = ui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks")

-- Menu items
local g_pMasterSwitch = ui.new_checkbox("LUA", "A", "nyaahook!")
local g_pDynamicFOV = ui.new_checkbox("LUA", "A", "Dynamic FOV")
local g_pFOVIndicator = ui.new_color_picker("LUA", "A", "Dynamic FOV", 255, 255, 255, 0) -- increase alpha to enable
local g_pMinimumFOV = ui.new_slider("LUA", "A", "Minimum FOV", 1, 30, 3, true, "°", 1)
local g_pMaximumFOV = ui.new_slider("LUA", "A", "Maximum FOV", 1, 30, 15, true, "°", 1)
local g_pAutomaticFireEnabled = ui.new_checkbox("LUA", "A", "Automatic fire") -- When enabled, automatic fire will be enabled/disabled according to the hotkey's state
local g_pAutomaticFireHotkey = ui.new_hotkey("LUA", "A", "Automatic fire", true, virtual_key_e.xbutton2)
local g_pAutomaticPenetrationEnabled = ui.new_checkbox("LUA", "A", "Automatic penetration") -- When enabled, automatic penetration will be enabled/disabled according to the hotkey's state.. or the extended "on visible hotkeys"
local g_pAutomaticPenetrationHotkey = ui.new_hotkey("LUA", "A", "Automatic penetration", true, virtual_key_e.f3)
local g_pAutomaticPenetrationHotkeyIndicator = ui.new_color_picker("LUA", "A", "Automatic penetration", 255, 255, 255, 0) -- increase alpha to enable
local g_pAutomaticPenetrationHitboxCount = ui.new_slider("LUA", "A", "Minimum visible hitboxes", 0, 4, 0, true, "", 1, { [ 0 ] = "Disabled", [ 1 ] = "1+/hotkey", [ 2 ] = "2+/hotkey", [ 3 ] = "3+/hotkey", [ 4 ] = "4+/hotkey" }) -- hardcoded text because suffix is limited to 2 characters
local g_pPrioritizeAWPUsers = ui.new_checkbox("LUA", "A", "Prioritize AWP users") -- Sets high priotity on player list for awp users
local g_pIgnoreBehindSmoke = ui.new_checkbox("LUA", "A", "Ignore enemies behind smokes")
local g_pHonorFlashbangs = ui.new_checkbox("LUA", "A", "Do not fire while blind")
local g_pBlindnessThreshold = ui.new_slider("LUA", "A", "Blindness duration threshold", 1.0, 100.0, 44.0, true, "s", 0.05, { [ 100.0 ] = "∞" }) -- 2.2 prevents killfeed showing the flashed icon
local g_pForceHeadSafety = ui.new_checkbox("LUA", "A", "Force head safety on legit anti-aim users")
local g_pExtraRageAimbotHotkeys = ui.new_checkbox("LUA", "A", "Extra rage aimbot hotkeys")
local g_pRageAimbotHotkeyCount = ui.new_slider("LUA", "A", "Rage aimbot hotkey count", 1, 5, 2, true)
local g_pRageAimbotHotkeys = {}

for i = 1, 5 do
	g_pRageAimbotHotkeys[i] = ui.new_hotkey("LUA", "A", string_format("Rage aimbot hotkey #%d", i), false)
end

local g_pCustomClantagSpammer = ui.new_checkbox("LUA", "A", "Clan tag spammer")

-- Cache
local g_bMaster = nil
local g_flFlashDurationCache = 0.0
local g_flLastFlashUpdate = 0.0
local g_aflLastSimulationTime = {}
local g_anUserWhitelisted = {}
local g_abLegitAntiaiming = {}
local g_nBestTarget = nil
local g_nLastTargetTick = nil
local g_bDisplayEntireTag = false
local g_flLastClanTagUpdate = 0.0
local g_sClantag = nil
local g_bForceTag = false

-- Are we loaded in a map?
local function is_in_game()
	return globals_mapname() ~= nil
end

-- Returns item definition index for the weapon used by `ent`, or nil if none
local function get_weapon_definition_index(ent)
	local nWeapon = entity_get_player_weapon(ent)

	if nWeapon ~= nil then
		return entity_get_prop(nWeapon, "m_iItemDefinitionIndex")
	end

	return nil
end

local function distance_to_dynamic_fov(min, max, dist)
	if dist >= DYNAMIC_FOV_MIN_DISTANCE then
		return min
	elseif dist <= DYNAMIC_FOV_MAX_DISTANCE then
		return max
	end
	
	return math_min(max, math_max(min, DYNAMIC_FOV_DISTANCE_SCALE / dist))
end

-- Iterates over all valid targets
local function iter_enemies(lambda)
	local anEnemies = entity_get_players(true)

	for i = 1, #anEnemies do
		lambda(anEnemies[i])
	end
end

local function get_closest_enemy_distance()
	local nLocalPlayer = entity_get_local_player()
	local flaLocalHead = vector(client_eye_position())
	local flMinimumDistance = DYNAMIC_FOV_DISTANCE_SCALE

	iter_enemies(function(target)
		local flaEnemyHead = vector(entity_hitbox_position(target, hitbox_e.head))
		local flDist = flaLocalHead:dist(flaEnemyHead)
		
		if flDist < flMinimumDistance then
			flMinimumDistance = flDist
		end
	end)
	
	return flMinimumDistance
end

local function is_rage_aimbot_running()
	return ui_get(g_pAimbotEnabled) and ui_get(g_pAimbotHotkey)
end

local function get_screen_center()
	local width, height = client_screen_size()

	return { width / 2, height / 2 }
end

local function get_distance_2d(pos1, pos2)
	return math_sqrt(math_pow((pos1[1] - pos2[1]), 2) + math_pow((pos1[2] - pos2[2]), 2))
end

-- HACK: I can only call renderer.world_to_screen from the "paint" callback. Therefore, we call this once per tick in "paint" and cache the value globally.
local function get_closest_target_crosshair()
	local anCenter = get_screen_center()
	local nTarget = nil
	local flClosest = 8192.0

	iter_enemies(function(target)
		local flX, flY, flZ = entity_hitbox_position(target, hitbox_e.head)
		local nX, nY = renderer_world_to_screen(flX, flY, flZ)

		-- Not on screen..
		if nX == nil then
			return
		end

		local flDistance = get_distance_2d(anCenter, { nX, nY })

		if flDistance < flClosest then
			flClosest = flDistance
			nTarget = target
		end
	end)

	return nTarget
end

function get_clantag(index)
	if index >= #CLANTAG_TEXT then
		index = CLANTAG_LOOP_SIZE - index
	end

	return string_sub(CLANTAG_TEXT, 1, index)
end

function get_padded_clantag(index)
	local sClanTag = get_clantag(index)

	return sClanTag .. string_rep(' ', MAX_CLAN_TAG_LENGTH - #sClanTag)
end

function get_compensated_curtime()
	return globals_curtime() + client_latency()
end

function get_synced_clantag()
	local nIndex = #CLANTAG_TEXT

	if not g_bDisplayEntireTag then
		nIndex = math_floor(get_compensated_curtime() * CLANTAG_UPDATE_SPEED) % CLANTAG_LOOP_SIZE
	end
	
	return get_padded_clantag(nIndex)
end

local function reset_globals()
	g_flFlashDurationCache = 0.0
	g_flLastFlashUpdate = 0.0
	g_abLegitAntiaiming = {}
	g_nBestTarget = nil
	g_aflLastSimulationTime = {}
	g_bDisplayEntireTag = {}
	g_flLastClanTagUpdate = 0.0
	g_bDisplayEntireTag = false
end

local function update_dynamic_fov()
	if not is_rage_aimbot_running() or globals_tickcount() % DYNAMIC_FOV_UPDATE_INTERVAL ~= 0 then
		return
	end

	local nMinimumFOV = ui_get(g_pMinimumFOV)
	local nMaximumFOV = ui_get(g_pMaximumFOV)
	local nDesiredFOV = nMinimumFOV

	-- Don't run distance checks if minimum is maximum. Spare CPU cycles ma'am?
	if nMinimumFOV ~= nMaximumFOV then
		nDesiredFOV = distance_to_dynamic_fov(nMinimumFOV, nMaximumFOV, get_closest_enemy_distance())
	end

	ui_set(g_pAimbotFieldOfView, nDesiredFOV)
end

local function update_automatic_fire()
	ui_set(g_pAimbotAutomaticFire, ui_get(g_pAutomaticFireHotkey))
end

local function update_automatic_penetration()
	local bPenetrate = ui_get(g_pAutomaticPenetrationHotkey)
	local nAutomaticPenetrationHitboxCount = ui_get(g_pAutomaticPenetrationHitboxCount)

	if not bPenetrate and nAutomaticPenetrationHitboxCount > 0 and g_nBestTarget ~= nil then
		local nLocalPlayer = entity_get_local_player()
		local flLocalX, flLocalY, flLocalZ = client_eye_position()
		local nHitboxesVisible = 0

		for i = 1, #VISIBILE_PENETRATION_HITBOXES do
			local flEnemyX, flEnemyY, flEnemyZ = entity_hitbox_position(g_nBestTarget, VISIBILE_PENETRATION_HITBOXES[i])
			local flFraction, nEntity = client_trace_line(nLocalPlayer, flLocalX, flLocalY, flLocalZ, flEnemyX, flEnemyY, flEnemyZ)

			if nEntity == g_nBestTarget then
				nHitboxesVisible = nHitboxesVisible + 1
			end

			if nHitboxesVisible >= nAutomaticPenetrationHitboxCount then
				bPenetrate = true

				break
			end
		end
	end

	ui_set(g_pAimbotAutomaticPenetration, bPenetrate)
end

local function update_extra_rage_aimbot_hotkeys()
	local bHeldDown = false

	for i = 1, #g_pRageAimbotHotkeys do
		if ui_get(g_pRageAimbotHotkeys[i]) then
			bHeldDown = true

			break
		end
	end

	ui_set(g_pAimbotHotkey, bHeldDown and "Always on" or "On hotkey")
end

local function update_prioritize_awp_users()
	iter_enemies(function(target)
		plist_set(target, "High priority", get_weapon_definition_index(target) == weapon_e.awp)
	end)
end

local function update_ignore_behind_smokes()
	-- Optimization: Check for smoke grenades. If there's none, do not whitelist any enemy and skip all checks.
	local bSmokeExists = false
	local anSmokeGrenadeProjectiles = entity_get_all("CSmokeGrenadeProjectile")
	local nTickCount = globals_tickcount()
	local flTickInterval = globals_tickinterval()

	for i = 1, #anSmokeGrenadeProjectiles do
		if entity_get_prop(anSmokeGrenadeProjectiles[i], "m_bDidSmokeEffect") == 1 and nTickCount < entity_get_prop(anSmokeGrenadeProjectiles[i], "m_nSmokeEffectTickBegin") + SMOKE_PERSISTANCE_TIMER / flTickInterval then
			bSmokeExists = true
		end
	end

	if not bSmokeExists then
		return
	end

	local flLocalX, flLocalY, flLocalZ = client_eye_position()

	iter_enemies(function(target)
		-- Don't run the code on anyone if enemy is already whitelisted..
		if g_anUserWhitelisted[target] then
			return
		end

		local bWhitelist = true

		for i = 1, #SMOKE_HITBOXES do
			-- If we already know that the target is visible, there is no reason to run more checks. Break out of the loop, and move on to the next target
			if not bWhitelist then
				break
			end

			-- "multipoints" XD. It works though! :)
			local flaEnemyHitbox = vector(entity_hitbox_position(target, SMOKE_HITBOXES[i]))

			for j = 1, #VISIBILITY_DIRECTIONS do
				if not g_pfnLineGoesThroughSmoke(flLocalX, flLocalY, flLocalZ, flaEnemyHitbox.x + VISIBILITY_DIRECTIONS[j][1], flaEnemyHitbox.y + VISIBILITY_DIRECTIONS[j][2], flaEnemyHitbox.z) then
					bWhitelist = false
	
					break
				end
			end
		end

		if bWhitelist then
			g_anUserWhitelisted[target] = true
		end
	end)
end

local function update_honor_flashbangs()
	if not is_rage_aimbot_running() then
		return
	end

	local nLocalPlayer = entity_get_local_player()
	local nWeapon = get_weapon_definition_index(nLocalPlayer)
	local cPrefix = string_sub(csgo_weapons[nWeapon].type, 1, 1)
	
	if cPrefix ~= 'p' and -- pistol
		cPrefix ~= 's' and -- smg, shotgun, sniperrifle
		cPrefix ~= 'r' and -- rifle
		cPrefix ~= 'm' then -- machinegun
		return
	end

	local flFlashDuration = entity_get_prop(nLocalPlayer, "m_flFlashDuration")
	local flBlindnessThreshold = ui_get(g_pBlindnessThreshold) * 0.05 -- Scale with the menu item's 0.05s scaling
	local flCurtime = globals_curtime()

	if flFlashDuration > 0.0 then
		if g_flFlashDurationCache == 0.0 then
			g_flLastFlashUpdate = flCurtime
		end

		if flCurtime - g_flLastFlashUpdate < flFlashDuration - flBlindnessThreshold then
			iter_enemies(function(target)
				g_anUserWhitelisted[target] = true
			end)
		end
	end

	g_flFlashDurationCache = flFlashDuration
end

local function update_force_head_safety()
	local flTickInterval = globals_tickinterval()
	local nMaxUserCMDProcessTicks = ui_get(g_pMaxUserCMDProcessTicks)

	iter_enemies(function(target)
		-- Filter bots. Not relevant for matchmaking because there's no bots anymore, but in case anyone uses this in unofficial servers
		if bit_band(entity_get_prop(target, "m_fFlags"), flags_e.fakeclient) > 0 then
			return
		end

		-- "Correction active" seems to be inaccurate sometimes, and the cheat won't turn it off after it gets turned on. A user must be choking at least every other tick to maintain desync anyway.
		-- Checking for less than `sv_maxusrcmdprocessticks` also ensures dormancy is respected. Not 100% accurate because the UI slider for it remains 16 on Valve servers regardless.
		local flSimulationTime = entity_get_prop(target, "m_flSimulationTime")
		
		-- And.. we obviously have to check their pitch to know if they're using legit antiaim or not.
		local flPitch = entity_get_prop(target, "m_angEyeAngles[0]")

		-- goto shenanigans.. we can't goto a scope without nTicksSinceSimulation being defined
		local nTicksSinceSimulation

		if g_aflLastSimulationTime[target] == nil or not plist_get(target, "Correction active") then
			goto continue
		end

		nTicksSinceSimulation = (flSimulationTime - g_aflLastSimulationTime[target]) / flTickInterval

		if nTicksSinceSimulation <= 1 or nTicksSinceSimulation > nMaxUserCMDProcessTicks then
			goto continue
		end

		if math_abs(flPitch) <= EYE_ANGLES_PITCH_ANTIAIM then
			g_abLegitAntiaiming[target] = true
			-- I keep iterating to not lose track of the enemies' simulation times
		end
		
		::continue::
		g_aflLastSimulationTime[target] = flSimulationTime
	end)

	local asAvoidHitboxes = ui_get(g_pAimbotAvoidUnsafeHitboxes)

	if g_abLegitAntiaiming[g_nBestTarget] then
		if asAvoidHitboxes[1] ~= "Head" then
			asAvoidHitboxes[#asAvoidHitboxes + 1] = "Head"
		end
	elseif asAvoidHitboxes[1] == "Head" then
		asAvoidHitboxes[1] = "" -- Setting this to nil instead seems to throw errors at times, so I'd rather avoid it.
	end

	ui_set(g_pAimbotAvoidUnsafeHitboxes, asAvoidHitboxes)
end

local function update_whitelist()
	iter_enemies(function(target)
		plist_set(target, "Add to whitelist", g_anUserWhitelisted[target])
	end)

	g_anUserWhitelisted = {}
end

local function update_custom_clan_tag_spammer()
	local flCurtime = get_compensated_curtime()
	
	if not g_bForceTag and (flCurtime - g_flLastClanTagUpdate < CLANTAG_UPDATE_INTERVAL or globals_chokedcommands() > 0) then
		return
	end

	local sClantag = get_synced_clantag()
	
	if sClantag ~= g_sClantag or g_bForceTag then
		client_set_clan_tag(sClantag)
		g_sClantag = sClantag
		g_bForceTag = false
	end
	
	g_flLastClanTagUpdate = flCurtime
end

local function on_net_update_end()
	if ui_get(g_pCustomClantagSpammer) then
		update_custom_clan_tag_spammer()
	end
end

local function on_run_command()
	if ui_get(g_pDynamicFOV) then
		update_dynamic_fov()
	end

	if ui_get(g_pAutomaticFireEnabled) then
		update_automatic_fire()
	end

	if ui_get(g_pAutomaticPenetrationEnabled) then
		update_automatic_penetration()
	end

	if ui_get(g_pExtraRageAimbotHotkeys) then
		update_extra_rage_aimbot_hotkeys()
	end

	if ui_get(g_pPrioritizeAWPUsers) then
		update_prioritize_awp_users()
	end
	
	if ui_get(g_pHonorFlashbangs) then
		update_honor_flashbangs()
	end

	if ui_get(g_pIgnoreBehindSmoke) then
		update_ignore_behind_smokes()
	end

	if ui_get(g_pForceHeadSafety) then
		update_force_head_safety()
	end

	update_whitelist()
end

local function update_fov_indicator()
	local nRed, nGreen, nBlue, nAlpha = ui_get(g_pFOVIndicator)

	if nAlpha > 0 then
		renderer_indicator(nRed, nGreen, nBlue, nAlpha, string_format("FOV: %d°", ui_get(g_pAimbotFieldOfView)))
	end
end

local function update_automatic_penetration_indicator()
	if not ui_get(g_pAutomaticPenetrationHotkey) then
		return
	end

	local nRed, nGreen, nBlue, nAlpha = ui_get(g_pAutomaticPenetrationHotkeyIndicator)

	if nAlpha > 0 then
		renderer_indicator(nRed, nGreen, nBlue, nAlpha, "AWALL")
	end
end

local function on_paint()
	if not entity_is_alive(entity_get_local_player()) then
		return
	end

	if ui_get(g_pDynamicFOV) then
		update_fov_indicator()
	end

	if ui_get(g_pAutomaticPenetrationEnabled) then
		update_automatic_penetration_indicator()
	end

	local nTickCount = globals_tickcount()

	if nTickCount ~= g_nLastTargetTick then
		g_nBestTarget = get_closest_target_crosshair()
		g_nLastTargetTick = nTickCount
	end
end

local function on_player_spawn(e)
	if client.userid_to_entindex(e.userid) == entity_get_local_player() then
		reset_globals()
	end
end

local function on_round_start()
	reset_globals()
end

local function on_game_period()
	g_bDisplayEntireTag = true
end

local function add_menu_callbacks(list, func)
	-- First, add the callbacks
	for i = 1, #list do
		ui.set_callback(list[i], func)
	end

	-- Then execute them!
	for i = 1, #list do
		func(list[i])
	end
end

local function set_visible_on_condition(list, condition)
	for i = 1, #list do
		ui.set_visible(list[i], condition)
	end
end

local function set_hooks(enable)
	local pfnFunc = enable and client.set_event_callback or client.unset_event_callback

	-- gamesense events
	pfnFunc("net_update_end", on_net_update_end)
	pfnFunc("run_command", on_run_command)
	pfnFunc("paint", on_paint)

	-- Game events
	pfnFunc("player_spawn", on_player_spawn)
	pfnFunc("round_start", on_round_start)
	pfnFunc("cs_win_panel_match", on_game_period)
	pfnFunc("cs_win_panel_round", on_game_period)
	pfnFunc("cs_pre_restart", on_game_period)
end

local function on_ui_callback()
	local bMaster = ui_get(g_pMasterSwitch)
	set_visible_on_condition({ g_pDynamicFOV, g_pAutomaticFireEnabled, g_pAutomaticFireHotkey, g_pAutomaticPenetrationEnabled, g_pAutomaticPenetrationHotkey, g_pAutomaticPenetrationHitboxCount,
		g_pPrioritizeAWPUsers, g_pIgnoreBehindSmoke, g_pHonorFlashbangs, g_pForceHeadSafety, g_pExtraRageAimbotHotkeys, g_pRageAimbotHotkeyCount, g_pCustomClantagSpammer }, bMaster)

	local bDynamicFOV = ui_get(g_pDynamicFOV)
	set_visible_on_condition({ g_pFOVIndicator, g_pMinimumFOV, g_pMaximumFOV }, bMaster and bDynamicFOV)

	local bAutomaticPenetration = ui_get(g_pAutomaticPenetrationEnabled)
	set_visible_on_condition({ g_pAutomaticPenetrationHitboxCount, g_pAutomaticPenetrationHotkeyIndicator }, bMaster and bAutomaticPenetration)

	local bHonorFlashbangs = ui_get(g_pHonorFlashbangs)
	set_visible_on_condition({ g_pBlindnessThreshold }, bMaster and bHonorFlashbangs)

	local bExtraRageAimbotHotkeys = ui_get(g_pExtraRageAimbotHotkeys)
	set_visible_on_condition({ g_pRageAimbotHotkeyCount }, bMaster and bExtraRageAimbotHotkeys)

	local nRageAimbotHotkeyCount = ui_get(g_pRageAimbotHotkeyCount)

	for i = 1, #g_pRageAimbotHotkeys do
		set_visible_on_condition({ g_pRageAimbotHotkeys[i] }, bMaster and bExtraRageAimbotHotkeys and nRageAimbotHotkeyCount >= i)
	end

	if bMaster ~= g_bMaster then
		set_hooks(bMaster)
	end

	g_bMaster = bMaster
end

-- When minimum goes over maximum, this will update maximum as well
local function on_fov_changed(ref)
	local nValue = ui_get(ref)

	if ref == g_pMinimumFOV and ui_get(g_pMaximumFOV) < nValue then
		ui_set(g_pMaximumFOV, nValue)
	elseif ref == g_pMaximumFOV and ui_get(g_pMinimumFOV) > nValue then
		ui_set(g_pMinimumFOV, nValue)
	end
end

local function on_clan_tag_spammer(ref)
	if ref == g_pDefaultClantagSpammer and ui_get(ref) then
		ui_set(g_pCustomClantagSpammer, false)
	elseif ref == g_pCustomClantagSpammer then
		if ui_get(ref) then
			ui_set(g_pDefaultClantagSpammer, false)
		else
			-- Restore original clan tag from Counter-Strike: Global Offensive configuration after disabling our custom clan tag. I believe the cheat should be doing this for the defauit gamesense clan tag as well, but that's out of nyaahook!'s scope.
			client.delay_call(globals_tickinterval(), function()
				cvar.cl_clanid:invoke_callback()
			end)
		end
	end
end

add_menu_callbacks({ g_pMasterSwitch, g_pDynamicFOV, g_pAutomaticPenetrationEnabled, g_pHonorFlashbangs, g_pExtraRageAimbotHotkeys, g_pRageAimbotHotkeyCount }, on_ui_callback)
add_menu_callbacks({ g_pMinimumFOV, g_pMaximumFOV }, on_fov_changed)
add_menu_callbacks({ g_pDefaultClantagSpammer, g_pCustomClantagSpammer }, on_clan_tag_spammer)