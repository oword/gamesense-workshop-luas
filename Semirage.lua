local client_camera_angles, client_create_interface, client_delay_call, client_eye_position, client_find_signature, client_latency, client_register_esp_flag, client_reload_active_scripts, client_screen_size, client_set_event_callback, client_trace_line, client_update_player_list, client_userid_to_entindex, database_read, database_write, entity_get_classname, entity_get_local_player, entity_get_player_name, entity_get_player_weapon, entity_get_players, entity_get_prop, entity_hitbox_position, entity_is_alive, entity_is_enemy, error, globals_absoluteframetime, globals_curtime, math_abs, math_atan2, math_cos, math_floor, math_pow, math_rad, math_sin, math_sqrt, plist_get, renderer_indicator, renderer_text, renderer_world_to_screen, string_format, ui_get, ui_new_color_picker, ui_new_combobox, ui_new_hotkey, ui_new_label, ui_new_multiselect, ui_new_slider, ui_reference, ui_set, require, ui_set_callback, ui_set_visible, pairs, print = client.camera_angles, client.create_interface, client.delay_call, client.eye_position, client.find_signature, client.latency, client.register_esp_flag, client.reload_active_scripts, client.screen_size, client.set_event_callback, client.trace_line, client.update_player_list, client.userid_to_entindex, database.read, database.write, entity.get_classname, entity.get_local_player, entity.get_player_name, entity.get_player_weapon, entity.get_players, entity.get_prop, entity.hitbox_position, entity.is_alive, entity.is_enemy, error, globals.absoluteframetime, globals.curtime, math.abs, math.atan2, math.cos, math.floor, math.pow, math.rad, math.sin, math.sqrt, plist.get, renderer.indicator, renderer.text, renderer.world_to_screen, string.format, ui.get, ui.new_color_picker, ui.new_combobox, ui.new_hotkey, ui.new_label, ui.new_multiselect, ui.new_slider, ui.reference, ui.set, require, ui.set_callback, ui.set_visible, pairs, print

local uix = require "gamesense/uix" or error("You need to subscribe to this library: https://gamesense.pub/forums/viewtopic.php?id=18881")

local location = database_read("location") or "LUA - A"

local refs = {
	["rage"] = {
		["enabled"] = { ui_reference("RAGE", "Aimbot", "Enabled") },
		["fire"] = ui_reference("RAGE", "Aimbot", "Automatic fire"),
		["penetration"] = ui_reference("RAGE", "Aimbot", "Automatic penetration"),
		["fov"] = ui_reference("RAGE", "Aimbot", "Maximum FOV"),
		["baim"] = ui_reference("RAGE", "Other", "Force body aim"),
		["logs"] = ui_reference("RAGE", "Aimbot", "Log misses due to spread"),
		["fake_duck"] = ui_reference("RAGE", "Other", "Duck peek assist")
	},

	["aa"] = {
		["enabled"] = ui_reference("AA", "Anti-aimbot angles", "Enabled"),
		["pitch"] = ui_reference("AA", "Anti-aimbot angles", "Pitch"),
		["yaw_base"] = ui_reference("AA", "Anti-aimbot angles", "Yaw base"),
		["yaw"] = { ui_reference("AA", "Anti-aimbot angles", "Yaw") },
		["yaw_jitter"] = { ui_reference("AA", "Anti-aimbot angles", "Yaw jitter") },
		["body_yaw"] = { ui_reference("AA", "Anti-aimbot angles", "Body yaw") },
		["fs_body_yaw"] = ui_reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
		-- ["lby_target"] = ui_reference("AA", "Anti-aimbot angles", "Lower body yaw target"),
		["fake_yaw_limit"] = ui_reference("AA", "Anti-aimbot angles", "Fake yaw limit"),
		["edge_yaw"] = ui_reference("AA", "Anti-aimbot angles", "Edge yaw"),
		["fs"] = { ui_reference("AA", "Anti-aimbot angles", "Freestanding") },
		["slow_motion"] = { ui_reference("AA", "Other", "Slow motion") }
	},

	["players"] = {
		["body_yaw"] = ui_reference("PLAYERS", "Adjustments", "Force body yaw"),
		["body_yaw_value"] = ui_reference("PLAYERS", "Adjustments", "Force body yaw value"),
		["whitelist"] = ui_reference("PLAYERS", "Adjustments", "Add to whitelist"),
		["apply_all"] = ui_reference("PLAYERS", "Adjustments", "Apply to all"),
		["reset_all"] = ui_reference("PLAYERS", "Players", "Reset all"),
		["lists"] = ui_reference("PLAYERS", "Players", "Player list")
	},

	["useless_features"] = {
		["double_tap"] = { ui_reference("RAGE", "Other", "Double tap") },
		["double_tap_mode"] = ui_reference("RAGE", "Other", "Double tap mode"),
		["double_tap_hitchance"] = ui_reference("RAGE", "Other", "Double tap hit chance"),
		["double_tap_fl_limit"] = ui_reference("RAGE", "Other", "Double tap fake lag limit"),
		["double_tap_options"] = ui_reference("RAGE", "Other", "Double tap quick stop"),
		["on_shot_aa"] = { ui_reference("AA", "Other", "On shot anti-aim") },
		["fake_peek"] = { ui_reference("AA", "Other", "Fake peek") }
	},

	["location"] = ui_new_combobox("MISC", "Miscellaneous", "Location ui semirage", "RAGE - Other", "LUA - A", "LUA - B")
}

if location == "RAGE - Other" then
	tab, container = "RAGE", "Other"
	ui_set(refs.location, "RAGE - Other")
elseif location == "LUA - A" then
	tab, container = "LUA", "A"
	ui_set(refs.location, "LUA - A")
elseif location == "LUA - B" then
	tab, container = "LUA", "B"
	ui_set(refs.location, "LUA - B")
end

local table = {
	["improvements_modes"] = {
		"Snipers",
		"Deagle", 
		"Pistols",
		"Others"
	},

	["improvements_nades"] = {
		"Smoke",
		"Flash"
	},

	["penetration"] = {
		"On hotkey",
		"Visible"
	},

	["dynamicfov"] = {
		"Snipers",
		"Deagle", 
		"Pistols",
		"Others"
	},

	["aa_type"] = {
		"Manual",
		"Dynamic"
	},

	["aa_mode"] = {
		"Safe",
		"Unsafe"
	},

	["aa_lby"] = {
		"Off",
		"Sway",
		"Opposite",
		"Eye yaw"
	},

	["aa_security"] = {
		"Minimized",
		"Velocity",
		"Fake duck",
		"FPS",
		"Ping",
		"Choke",
		"Loss",
		"Hide sliders"
	},

	["aa_indicators"] = {
		"Crosshair",
		"Arrow"
	},

	["indicators_types"] = {
		"Default",
		"Crosshair"
	},

	["indicators"] = {
		"Bruteforce",
		"FOV",
		"Automatic fire",
		"Automatic penetration",
		"Force body aim"
	},

	["flags"] = {
		"FAKE",
		"Bruteforce"
	}
}

local menu = {
	["rage"] = {
		["enabled"] = uix.new_checkbox(tab, container, "Semirage"),
		["improvements"] = uix.new_checkbox(tab, container, "Improvements"),
		["improvements_mode"] = { ui_new_multiselect(tab, container, "Aimbot improvements", table.improvements_modes) },
		["improvements_hotkey"] = ui_new_hotkey(tab, container, "\naimbot_improvements_modes", true, 0x01),
		["improvements_nades"] = { ui_new_multiselect(tab, container, "Disable aimbot", table.improvements_nades) },
		["fire"] = uix.new_checkbox(tab, container, "Automatic fire"),
		["fire_hotkey"] = ui_new_hotkey(tab, container, "Automatic fire", true),
		["penetration"] = uix.new_checkbox(tab, container, "Automatic penetration"),
		["penetration_hotkey"] = ui_new_hotkey(tab, container, "Automatic penetration", true),
		["penetration_mode"] = { ui_new_multiselect(tab, container, "\npenetration_modes", table.penetration) },
		["penetreation_slider"] = ui_new_slider(tab, container, "when X hitboxes visible", 0, 12, 2, true),
		["dynamicfov"] = uix.new_checkbox(tab, container, "Dynamic FOV"),
		["dynamicfov_mode"] = ui_new_combobox(tab, container, "\ndynamic_fov_modes", table.dynamicfov),
		["dynamicfov_autofactor"] = ui_new_slider(tab, container, "Dynamic FOV auto factor", 0, 250, 100, true, "x", 0.01),
		["dynamicfov_min_snipers"] = ui_new_slider(tab, container, "Snipers Dynamic FOV min", 1, 180, 3, true, "°", 1),
		["dynamicfov_max_snipers"] = ui_new_slider(tab, container, "Snipers Dynamic FOV max", 1, 180, 10, true, "°", 1),
		["dynamicfov_min_deagle"] = ui_new_slider(tab, container, "Deagle Dynamic FOV min", 1, 180, 3, true, "°", 1),
		["dynamicfov_max_deagle"] = ui_new_slider(tab, container, "Deagle Dynamic FOV max", 1, 180, 10, true, "°", 1),
		["dynamicfov_min_pistols"] = ui_new_slider(tab, container, "Pistols Dynamic FOV min", 1, 180, 3, true, "°", 1),
		["dynamicfov_max_pistols"] = ui_new_slider(tab, container, "Pistols Dynamic FOV max", 1, 180, 10, true, "°", 1),
		["dynamicfov_min_others"] = ui_new_slider(tab, container, "Others Dynamic FOV min", 1, 180, 3, true, "°", 1),
		["dynamicfov_max_others"] = ui_new_slider(tab, container, "Others Dynamic FOV max", 1, 180, 10, true, "°", 1),
		["bruteforce"] = uix.new_checkbox(tab, container, "Bruteforce"),
		["bruteforce_hotkey"] = ui_new_hotkey(tab, container, "\bbuteforce_hotkey", true),
		["advanced_logs"] = uix.new_checkbox(tab, container, "Advanced logs")
	},

	["aa"] = {
		["enabled"] = uix.new_checkbox("AA", "Anti-aimbot angles", "Legit AA"),
		["type"] = ui_new_combobox("AA", "Anti-aimbot angles", "\naa_type", table.aa_type),
		["hotkey"] = ui_new_hotkey("AA", "Anti-aimbot angles", "\naa_hotkey", true),
		["mode"] = ui_new_combobox("AA", "Anti-aimbot angles", "Freestanding mode", table.aa_mode),
		["mode_hotkey"] = ui_new_hotkey("AA", "Anti-aimbot angles", "\nfreestanding_mode_hotkey", true),
		["lby_target"] = ui_new_combobox("AA", "Anti-aimbot angles", "Lower body yaw target", table.aa_lby),
		["fake_yaw_limit"] = ui_new_slider("AA", "Anti-aimbot angles", "Fake yaw limit", 0, 60, 60, true, "°"),
		["security"] = { ui_new_multiselect("AA", "Anti-aimbot angles", "Security", table.aa_security) },
		["velocity"] = ui_new_slider("AA", "Anti-aimbot angles", "Velocity max", 1, 250, 150, true, "u"),
		["fps"] = ui_new_slider("AA", "Anti-aimbot angles", "FPS min", 0, 300, 60),
		["ping"] = ui_new_slider("AA", "Anti-aimbot angles", "Ping min", 1, 200, 80, true, "ms"),
		["choke"] = ui_new_slider("AA", "Anti-aimbot angles", "Choke min", 1, 10, 2, true, "%"),
		["loss"] = ui_new_slider("AA", "Anti-aimbot angles", "Loss min", 1, 10, 2, true, "%"),
		["indicators"] = ui_new_combobox("AA", "Anti-aimbot angles", "Indicators", table.aa_indicators),
		["label_text"] = ui_new_label("AA", "Anti-aimbot angles", "Color for the text"),
		["color_text"] = ui_new_color_picker("AA", "Anti-aimbot angles", "\ncolor_for_the_text", 180, 238, 0, 255),
		["label_real"] = ui_new_label("AA", "Anti-aimbot angles", "Color for your real"),
		["color_arrow_real"] = ui_new_color_picker("AA", "Anti-aimbot angles", "\ncolor_for_the_real", 180, 238, 0, 255),
		["label_fake"] = ui_new_label("AA", "Anti-aimbot angles", "Color for your fake"),
		["color_arrow_fake"] = ui_new_color_picker("AA", "Anti-aimbot angles", "\ncolor_for_the_fake", 255, 0, 0, 255),
		["fake_yaw_slow"] = uix.new_checkbox("AA", "Other", "Fake yaw limit on slow motion"),
		["fake_yaw_slider"] = ui_new_slider("AA", "Other", "\nfake_yaw_limit_on_slow_motion", 0, 60, 20, true, "°")
	},

	["visuals"] = {
		["indicators"] = uix.new_checkbox(tab, container, "Indicators"),
		["indicators_type"] = ui_new_combobox(tab, container, "\nindicators_types", table.indicators_types),
		["indicaotrs_color"] = ui_new_color_picker(tab, container, "\nindicators_color", 180, 238, 0, 255),
		["indicators_mode"] = { ui_new_multiselect(tab, container, "Indicators modes", table.indicators) },
		["flags"] = uix.new_checkbox(tab, container, "Flags"),
		["flags_mode"] = { ui_new_multiselect(tab, container, "\nflags_modes", table.flags) }
	}
}

local weapon_classes = {
	["CWeaponG3SG1"] = "Snipers",
	["CWeaponSCAR20"] = "Snipers",
	["CWeaponAWP"] = "Snipers",
	["CWeaponSSG08"] = "Snipers",
	["CDEagle"] = "Deagle",
	["CWeaponFiveSeven"] = "Pistols",
	["CWeaponHKP2000"] = "Pistols",
	["CWeaponP250"] = "Pistols",
	["CWeaponGlock"] = "Pistols",
	["CWeaponElite"] = "Pistols",
	["CWeaponTec9"] = "Pistols",
	["CAK47"] = "Others",
	["CWeaponAug"] = "Others",
	["CWeaponFamas"] = "Others",
	["CWeaponGalilAR"] = "Others",
	["CWeaponM4A1"] = "Others",
	["CWeaponSG556"] = "Others",
	["CWeaponMP7"] = "Others",
	["CWeaponMP9"] = "Others",
	["CWeaponBizon"] = "Others",
	["CWeaponP90"] = "Others",
	["CWeaponUMP45"] = "Others",
	["CWeaponM249"] = "Others",
	["CWeaponNegev"] = "Others",
	["CWeaponMag7"] = "Others",
	["CWeaponNOVA"] = "Others",
	["CWeaponSawedoff"] = "Others",
	["CWeaponXM1014"] = "Others",
	["CKnife"] = "Others"
}

local vars = {
	["hitgroup_names"] = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear"},
	["bruteforce"] = false,
	["closest_enemy"] = nil,
	["in_fov"] = false,
	["DEG_TO_RAD"] = math.pi / 180,
	["RAD_TO_DEG"] = 180 / math.pi,
	["fire"] = false,
	["fire_improvements"] = false,
	["visible_hitboxes"] = 0,
	["side"] = 1,
	["last_side"] = 0,
	["last_hit"] = 0,
	["hit_side"] = 0,
	["ft_prev"] = 0
}

local ffi = require("ffi")

local signature = "\x55\x8B\xEC\x83\xEC\x08\x8B\x15\xCC\xCC\xCC\xCC\x0F\x57"
local match = client_find_signature("client.dll", signature) or error("client_find_signature problem")
local through_smoke = ffi.cast(ffi.typeof("bool(__thiscall*)(float, float, float, float, float, float, short)"), match) or error("ffi.cast problem")
local native_IsActiveApp = vtable_bind("engine.dll", "VEngineClient014", 196, "bool(__thiscall*)(void*)")

local FLOW_OUTGOING, FLOW_INCOMING = 0, 1

local native_GetNetChannelInfo = vtable_bind("engine.dll", "VEngineClient014", 78, "void*(__thiscall*)(void*)")
local native_GetAvgLoss = vtable_thunk(11, "float(__thiscall*)(void*, int)")
local native_GetAvgChoke = vtable_thunk(12, "float(__thiscall*)(void*, int)")

local table_contains = function(tbl, val)
	for i = 1, #tbl do
		if tbl[i] == val then
			return true
		end
	end
	return false
end

local get_velocity = function(ent)
	local x, y, z = entity_get_prop(ent, "m_vecVelocity")
	return math_floor(math_sqrt((x * x) + (y * y) + (z * z)) + 0.5)
end

local round = function(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math_floor(num * mult + 0.5) / mult
end

local get_fps = function()
	vars.ft_prev = vars.ft_prev * 0.9 + globals_absoluteframetime() * 0.1
	return round(1 / vars.ft_prev)
end

local config_aa = function()
	local enabled = menu.aa.enabled:get()

	if enabled then
		ui_set(refs.aa.pitch, "Off")
		ui_set(refs.aa.yaw_base, "Local view")
		ui_set(refs.aa.yaw[1], "Off")
		ui_set(refs.aa.yaw_jitter[1], "Off")
		ui_set(refs.aa.body_yaw[1], "Static")
		ui_set(refs.aa.fs_body_yaw, false)
		ui_set(refs.aa.edge_yaw, false)
		ui_set(refs.aa.fs[1], "-")
	else
		ui_set(refs.aa.pitch, "Off")
		ui_set(refs.aa.yaw_base, "Local view")
		ui_set(refs.aa.yaw[1], "Off")
		ui_set(refs.aa.yaw_jitter[1], "Off")
		ui_set(refs.aa.body_yaw[1], "Off")
		ui_set(refs.aa.fs_body_yaw, false)
		ui_set(refs.aa.edge_yaw, false)
		ui_set(refs.aa.fs[1], "-")
	end
end

local hide_useless_features = function(value)
	if (value == false) then
		ui_set_visible(refs.useless_features.double_tap[1], value)
		ui_set_visible(refs.useless_features.double_tap[2], value)
		ui_set_visible(refs.useless_features.double_tap_mode, value)
		ui_set_visible(refs.useless_features.double_tap_hitchance, value)
		ui_set_visible(refs.useless_features.double_tap_fl_limit, value)
		ui_set_visible(refs.useless_features.double_tap_options, value)
		ui_set_visible(refs.useless_features.on_shot_aa[1], value)
		ui_set_visible(refs.useless_features.on_shot_aa[1], value)
		ui_set_visible(refs.useless_features.on_shot_aa[2], value)
		ui_set_visible(refs.useless_features.fake_peek[1], value)
		ui_set_visible(refs.useless_features.fake_peek[2], value)
	else
		ui_set_visible(refs.useless_features.double_tap[1], value)
		ui_set_visible(refs.useless_features.double_tap[2], value)
		ui_set_visible(refs.useless_features.on_shot_aa[1], value)
		ui_set_visible(refs.useless_features.on_shot_aa[1], value)
		ui_set_visible(refs.useless_features.on_shot_aa[2], value)
		ui_set_visible(refs.useless_features.fake_peek[1], value)
		ui_set_visible(refs.useless_features.fake_peek[2], value)
	end
end

local hide_aa = function(value)
	ui_set_visible(refs.aa.enabled, value)
	ui_set_visible(refs.aa.pitch, value)
	ui_set_visible(refs.aa.yaw_base, value)
	ui_set_visible(refs.aa.yaw[1], value)
	ui_set_visible(refs.aa.yaw[2], false)
	ui_set_visible(refs.aa.yaw_jitter[1], value)
	ui_set_visible(refs.aa.yaw_jitter[2], false)
	ui_set_visible(refs.aa.body_yaw[1], value)
	ui_set_visible(refs.aa.body_yaw[2], false)
	ui_set_visible(refs.aa.fs_body_yaw, false)
	-- ui_set_visible(refs.aa.lby_target, value)
	ui_set_visible(refs.aa.fake_yaw_limit, false)
	ui_set_visible(refs.aa.edge_yaw, value)
	ui_set_visible(refs.aa.fs[1], value)
	ui_set_visible(refs.aa.fs[2], value)
end

local on_location_change = function(self)
	local value = ui_get(self)
	database_write("location", value)
	client_reload_active_scripts()
end
ui_set_callback(refs.location, on_location_change)

local on_improvements_event = function(cmd)
	local hotkey = ui_get(menu.rage.improvements_hotkey)
	local mode = ui_get(menu.rage.improvements_mode[1])
	local weapon = weapon_classes[entity_get_classname(entity_get_player_weapon(entity_get_local_player()))]

	if (hotkey and table_contains(mode, weapon)) then
		vars.fire_improvements = true
	else
		vars.fire_improvements = false
	end
end

local on_improvements_smoke_event = function()
	local nades = ui_get(menu.rage.improvements_nades[1])
	local smoke = table_contains(nades, "Smoke")

	if smoke then
		client_update_player_list()
		local local_player = entity_get_local_player()
		local local_head = { entity_hitbox_position(local_player, 0) }
		for _, v in pairs(entity_get_players(true)) do
			ui_set(refs.players.lists, v)
			local entity_head = { entity_hitbox_position(v, 0) }
			ui_set(refs.players.whitelist, through_smoke(local_head[1], local_head[2], local_head[3], entity_head[1], entity_head[2], entity_head[3], 1))
		end
	end
end

local on_improvements_blind_event = function(e)
	local nades = ui_get(menu.rage.improvements_nades[1])
	local flash = table_contains(nades, "Flash")

	local player = entity_get_local_player()
	local idEnt = (client_userid_to_entindex(e.userid))
	
	if idEnt == player and flash then
		client_delay_call(0.1, function()
			local duration = entity_get_prop(player, "m_flFlashDuration")

			if duration >= 1 then
				ui_set(refs.rage.enabled[1], false)
				client_delay_call(duration, function()
					ui_set(refs.rage.enabled[1], true)
				end)
			end
		end)
	end
end

local on_improvements_change = function(ref, value)
	ui_set_visible(menu.rage.improvements_mode[1], value)
	ui_set_visible(menu.rage.improvements_hotkey, value)
	ui_set_visible(menu.rage.improvements_nades[1], value)
end

local on_fire_event = function(cmd)
	local hotkey = ui_get(menu.rage.fire_hotkey)

	if hotkey then
		vars.fire = true
	else
		vars.fire = false
	end
end

local on_fire_change = function(ref, value)
	ui_set_visible(menu.rage.fire_hotkey, value)
end

local enemies_visible = function()
	local enemies = entity_get_players(true)
	local local_player = entity_get_local_player()
	local lx, ly, lz = client_eye_position()

	local visible_hitboxes = vars.visible_hitboxes
	local visible_hitboxes_value = ui_get(menu.rage.penetreation_slider)

	for e = 1, #enemies do
		local ent = enemies[e]
		local visible_hitboxes = 0

		for i = 0, 18 do
			local ex, ey, ez = entity_hitbox_position(ent, i)
			local _, ent_hit = client_trace_line(local_player, lx, ly, lz, ex, ey, ez)

			if ent_hit == ent then
				local x = renderer_world_to_screen(ex, ey, ez)

				if x then
					visible_hitboxes = visible_hitboxes + 1
				end
			end
		end

		if visible_hitboxes >= visible_hitboxes_value then
			return true
		end
	end

	return false
end

local on_penetration_event = function()
	local local_player = entity_get_local_player()
	local alive = entity_is_alive(local_player)

	if not alive then
		return
	end

	local mode = ui_get(menu.rage.penetration_mode[1])
	local on_hotkey = table_contains(mode, "On hotkey")
	local visible = table_contains(mode, "Visible")

	local hotkey = ui_get(menu.rage.penetration_hotkey)

	if (on_hotkey and hotkey) or (visible and enemies_visible()) then
		ui_set(refs.rage.penetration, true)
	else
		ui_set(refs.rage.penetration, false)
	end
end

local on_penetration_mode_change = function(self)
	local value = menu.rage.penetration:get() and ui_get(self) or ""
	local on_hotkey = table_contains(value, "On hotkey")
	local visible = table_contains(value, "Visible")

	ui_set_visible(menu.rage.penetration_hotkey, on_hotkey)
	ui_set_visible(menu.rage.penetreation_slider, visible)
end

local on_penetration_change = function(ref, value)
	ui_set_visible(menu.rage.penetration_mode[1], value)
	ui_set_visible(menu.rage.penetreation_slider, value)

	on_penetration_mode_change(menu.rage.penetration_mode[1])
end

local on_dynamicfov_event = function()
	local mode = ui_get(menu.rage.dynamicfov_mode)
	local auto_factor = ui_get(menu.rage.dynamicfov_autofactor)
	local max_fov
	local min_fov

	if mode == "Snipers" then
		max_fov = ui_get(menu.rage.dynamicfov_max_snipers)
		min_fov = ui_get(menu.rage.dynamicfov_min_snipers)
	elseif mode == "Deagle" then
		max_fov = ui_get(menu.rage.dynamicfov_max_deagle)
		min_fov = ui_get(menu.rage.dynamicfov_min_deagle)
	elseif mode == "Pistols" then
		max_fov = ui_get(menu.rage.dynamicfov_max_pistols)
		min_fov = ui_get(menu.rage.dynamicfov_min_pistols)
	elseif mode == "Others" then
		max_fov = ui_get(menu.rage.dynamicfov_max_others)
		min_fov = ui_get(menu.rage.dynamicfov_min_others)
	end

	if auto_factor == nil or max_fov == nil or min_fov == nil then
		return
	end

	local old_fov = ui_get(refs.rage.fov)
	local new_fov = old_fov
	local enemies = entity_get_players(true)

	if min_fov > max_fov then
		local store_min_fov = min_fov
		min_fov = max_fov
		max_fov = store_min_fov
	end

	if #enemies ~= 0 then
		local own_x, own_y, own_z = client_eye_position()
		local own_pitch, own_yaw = client_camera_angles()
		vars.closest_enemy = nil
		local closest_distance = 999999999

		for i = 1, #enemies do
			local enemy = enemies[i]
			local enemy_x, enemy_y, enemy_z = entity_hitbox_position(enemy, 0)

			local x = enemy_x - own_x
			local y = enemy_y - own_y
			local z = enemy_z - own_z

			local yaw = ((math_atan2(y, x) * 180 / math.pi))
			local pitch = -(math_atan2(z, math_sqrt(math_pow(x, 2) + math_pow(y, 2))) * 180 / math.pi)

			local yaw_dif = math_abs(own_yaw % 360 - yaw % 360) % 360
			local pitch_dif = math_abs(own_pitch - pitch ) % 360
			
			if yaw_dif > 180 then
				yaw_dif = 360 - yaw_dif
			end

			local real_dif = math_sqrt(math_pow(yaw_dif, 2) + math_pow(pitch_dif, 2))

			if closest_distance > real_dif then
				closest_distance = real_dif
				vars.closest_enemy = enemy
			end
		end

		if vars.closest_enemy ~= nil then
			local closest_enemy_x, closest_enemy_y, closest_enemy_z = entity_hitbox_position(vars.closest_enemy, 0)
			local real_distance = math_sqrt(math_pow(own_x - closest_enemy_x, 2) + math_pow(own_y - closest_enemy_y, 2) + math_pow(own_z - closest_enemy_z, 2))

			new_fov = (3800 / real_distance) * (ui_get(menu.rage.dynamicfov_autofactor) * 0.01)

			if (new_fov > max_fov) then
				new_fov = max_fov
			elseif new_fov < min_fov then
				new_fov = min_fov
			end
		end

		new_fov = math_floor(new_fov + 0.5)

		if (new_fov > closest_distance)  then
			vars.in_fov = true
		else
			vars.in_fov = false
		end
	else
		new_fov = min_fov
		vars.in_fov = false
	end

	if (new_fov ~= old_fov and (mode == "Snipers" or mode == "Deagle" or mode == "Pistols" or mode == "Others")) then
		ui_set(refs.rage.fov, new_fov)
	end
end

local on_dynamicfov_setup_event = function(cmd)
	local local_player = entity_get_local_player()
	local weapon = entity_get_player_weapon(local_player)
	local weapon_class = entity_get_classname(weapon)

	if weapon_classes[weapon_class] then
		ui_set(menu.rage.dynamicfov_mode, weapon_classes[weapon_class])
	end
end

local on_dynamicfov_mode_change = function(self)
	local value = menu.rage.dynamicfov:get() and ui_get(self) or ""

	ui_set_visible(menu.rage.dynamicfov_min_snipers, value == "Snipers")
	ui_set_visible(menu.rage.dynamicfov_max_snipers, value == "Snipers")

	ui_set_visible(menu.rage.dynamicfov_min_deagle, value == "Deagle")
	ui_set_visible(menu.rage.dynamicfov_max_deagle, value == "Deagle")

	ui_set_visible(menu.rage.dynamicfov_min_pistols, value == "Pistols")
	ui_set_visible(menu.rage.dynamicfov_max_pistols, value == "Pistols")

	ui_set_visible(menu.rage.dynamicfov_min_others, value == "Others")
	ui_set_visible(menu.rage.dynamicfov_max_others, value == "Others")
end

local on_dynamicfov_change = function(ref, value)
	ui_set_visible(menu.rage.dynamicfov_mode, value)
	ui_set_visible(menu.rage.dynamicfov_autofactor, value)

	on_dynamicfov_mode_change(menu.rage.dynamicfov_mode)
end

local bruteforce_body_yaw = function()
	local body_yaw_value = ui_get(refs.players.body_yaw_value)

	client_update_player_list()

	if body_yaw_value == 0 then
		ui_set(refs.players.body_yaw, true)
		ui_set(refs.players.body_yaw_value, 60)
		ui_set(refs.players.apply_all, true)
		vars.bruteforce = false
	elseif body_yaw_value == 60 then
		ui_set(refs.players.body_yaw, true)
		ui_set(refs.players.body_yaw_value, -60)
		ui_set(refs.players.apply_all, true)
		vars.bruteforce = false
	elseif body_yaw_value == -60 then
		ui_set(refs.players.reset_all, true)   
		vars.bruteforce = false
	end
end

local on_bruteforce_event = function(cmd)
	local hotkey = ui_get(menu.rage.bruteforce_hotkey)

	if hotkey then
		if vars.bruteforce then
			bruteforce_body_yaw()
			vars.bruteforce = false
		end
	else
		vars.bruteforce = true
	end
end

local on_bruteforce_change = function(ref, value)
	ui_set_visible(menu.rage.bruteforce_hotkey, value)
end

local on_miss_event = function(e)
	local group = vars.hitgroup_names[e.hitgroup + 1] or "?"
	print(string_format("Missed %s (%s) due to %s", entity_get_player_name(e.target), group, e.reason))
end

local on_advanced_logs_change = function(ref, value)
	ui_set_visible(refs.rage.logs, not value)
	ui_set(refs.rage.logs, false)
end

local on_indicators_event = function()
	local local_player = entity_get_local_player()
	local alive = entity_is_alive(local_player)

	if not alive then
		return
	end

	local type = ui_get(menu.visuals.indicators_type)
	local mode = ui_get(menu.visuals.indicators_mode[1])
	local mode_bruteforce = table_contains(mode, "Bruteforce")
	local mode_fov = table_contains(mode, "FOV")
	local mode_fire = table_contains(mode, "Automatic fire")
	local mode_penetration = table_contains(mode, "Automatic penetration")
	local mode_force_body_aim = table_contains(mode, "Force body aim")

	local fov = ui_get(refs.rage.fov)
	local body_yaw = ui_get(refs.players.body_yaw_value)
	local fire = ui_get(refs.rage.fire)
	local penetration = ui_get(refs.rage.penetration)
	local force_body_aim = ui_get(refs.rage.baim)
	local r, g, b, a = ui_get(menu.visuals.indicaotrs_color)

	local w, h = client_screen_size()
	local x, y = w / 2, h / 2

	if type == "Default" then
		if mode_bruteforce then
			if body_yaw == 60 then
				renderer_indicator(r, g, b, a, "B:RIGHT")
			elseif body_yaw == -60 then
				renderer_indicator(r, g, b, a, "B:LEFT")
			elseif body_yaw == 0 then	
				renderer_indicator(r, g, b, a, "B:OFF")
			end
		end
		if mode_fov then
			renderer_indicator(r, g, b, a, "FOV: ", fov, "°")
		end
		if mode_fire and fire then
			renderer_indicator(r, g, b, a, "TM")
		end
		if mode_penetration and penetration then
			renderer_indicator(r, g, b, a, "AW")
		end
		if mode_force_body_aim and force_body_aim then
			renderer_indicator(r, g, b, a, "BAIM")
		end
	elseif type == "Crosshair" then
		if mode_bruteforce then
			if body_yaw == 60 then
				renderer_text(x, y + 60, r, g, b, a, "dcb", 0, "B:RIGHT")
			elseif body_yaw == -60 then
				renderer_text(x, y + 60, r, g, b, a, "dcb", 0, "B:LEFT")
			elseif body_yaw == 0 then	
				renderer_text(x, y + 60, r, g, b, a, "dcb", 0, "B:OFF")
			end
		end
		if mode_fov then
			renderer_indicator(r, g, b, a, "FOV: ", fov, "°")
		end
		if mode_fire and fire then
			renderer_text(x, y + 30, r, g, b, a, "dcb", 0, "TM")
		else
			renderer_text(x, y + 30, 0, 0, 0, 50, "dcb", 0, "TM")
		end
		if mode_penetration and penetration then
			renderer_text(x, y + 40, r, g, b, a, "dcb", 0, "AW")
		else
			renderer_text(x, y + 40, 0, 0, 0, 50, "dcb", 0, "AW")
		end
		if mode_force_body_aim and force_body_aim then
			renderer_text(x, y + 50, r, g, b, a, "dcb", 0, "BAIM")
		else
			renderer_text(x, y + 50, 0, 0, 0, 50, "dcb", 0, "BAIM")
		end
	end
end

local on_indicators_change = function(ref, value)
	ui_set_visible(menu.visuals.indicaotrs_color, value)
	ui_set_visible(menu.visuals.indicators_type, value)
	ui_set_visible(menu.visuals.indicators_mode[1], value)
end

local on_flags_change = function(ref, value)
	ui_set_visible(menu.visuals.flags_mode[1], value)
end

local on_aa_security_change = function(self)
	local value = menu.aa.enabled:get() and ui_get(self) or ""
	local hide = table_contains(value, "Hide sliders")
	local velocity = table_contains(value, "Velocity") and not hide
	local fps = table_contains(value, "FPS") and not hide
	local ping = table_contains(value, "Ping") and not hide
	local choke = table_contains(value, "Choke") and not hide
	local loss = table_contains(value, "Loss") and not hide

	ui_set_visible(menu.aa.velocity, velocity)
	ui_set_visible(menu.aa.fps, fps)
	ui_set_visible(menu.aa.ping, ping)
	ui_set_visible(menu.aa.choke, choke)
	ui_set_visible(menu.aa.loss, loss)
end

local on_aa_indicators_change = function(self)
	local value = menu.aa.enabled:get() and ui_get(self)

	if value == "Crosshair" then
		ui_set_visible(menu.aa.label_text, true)
		ui_set_visible(menu.aa.color_text, true)
		ui_set_visible(menu.aa.label_real, false)
		ui_set_visible(menu.aa.color_arrow_real, false)
		ui_set_visible(menu.aa.label_fake, false)
		ui_set_visible(menu.aa.color_arrow_fake, false)
	elseif value == "Arrow" then
		ui_set_visible(menu.aa.label_text, false)
		ui_set_visible(menu.aa.color_text, false)
		ui_set_visible(menu.aa.label_real, true)
		ui_set_visible(menu.aa.color_arrow_real, true)
		ui_set_visible(menu.aa.label_fake, true)
		ui_set_visible(menu.aa.color_arrow_fake, true)
	else
		ui_set_visible(menu.aa.label_text, false)
		ui_set_visible(menu.aa.color_text, false)
		ui_set_visible(menu.aa.label_real, false)
		ui_set_visible(menu.aa.color_arrow_real, false)
		ui_set_visible(menu.aa.label_fake, false)
		ui_set_visible(menu.aa.color_arrow_fake, false)
	end
end

local on_aa_type_change = function(self)
	local value = menu.aa.enabled:get() and ui_get(self)

	if value == "Manual" then
		ui_set_visible(menu.aa.hotkey, true)
		ui_set_visible(menu.aa.mode, false)
		ui_set_visible(menu.aa.mode_hotkey, false)
	elseif value == "Dynamic" then
		ui_set_visible(menu.aa.hotkey, false)
		ui_set_visible(menu.aa.mode, true)
		ui_set_visible(menu.aa.mode_hotkey, true)
	else
		ui_set_visible(menu.aa.hotkey, false)
		ui_set_visible(menu.aa.mode, false)
		ui_set_visible(menu.aa.mode_hotkey, false)
	end
end

local on_fake_yaw_slow_setup_command = function()
	local enabled = menu.rage.enabled:get() and menu.aa.enabled:get() and menu.aa.fake_yaw_slow:get()

	if not enabled then
		return
	end

	local IsSlow = ui_get(refs.aa.slow_motion[1]) and ui_get(refs.aa.slow_motion[2])

	local slow_motion_slow = ui_get(menu.aa.fake_yaw_slider)
	local slow_motion_limit = ui_get(menu.aa.fake_yaw_limit)

	if IsSlow then
		ui_set(refs.aa.fake_yaw_limit, slow_motion_slow)
	else
		ui_set(menu.aa.fake_yaw_limit, slow_motion_limit)
	end
end

local on_fake_yaw_slow_change = function(ref, value)
	local enabled = menu.rage.enabled:get() and menu.aa.enabled:get() and menu.aa.fake_yaw_slow:get()

	ui.set_visible(menu.aa.fake_yaw_slider, enabled)
end

local on_aa_paint_event = function()
	local local_player = entity_get_local_player()
	local alive = entity_is_alive(local_player)

	if not alive then
		return
	end

	local indicators = ui_get(menu.aa.indicators)
	local body_yaw = ui_get(refs.aa.body_yaw[2])
	local fs_mode = ui_get(menu.aa.mode)

	local w, h = client_screen_size()
	local x, y = w / 2, h / 2

	if fs_mode == "Unsafe" then
		renderer_text(x, y - 30, 255, 0, 0, 255, "dcb", 0, "⚠ UNSAFE ⚠")
	end

	if indicators == "Crosshair" then
		local r, g, b, a = ui_get(menu.aa.color_text)

		if body_yaw > 0 then
			renderer_text(x, y + 70, r, g, b, a, "dcb", 0, "RIGHT")
		elseif body_yaw < 0 then
			renderer_text(x, y + 70, r, g, b, a, "dcb", 0, "LEFT")
		end
	elseif indicators == "Arrow" then
		local r, g, b, a = ui_get(menu.aa.color_arrow_real)
		local r2, g2, b2, a2 = ui_get(menu.aa.color_arrow_fake)

		if body_yaw > 0 then
			renderer_text(x - 60, y, r2, g2, b2, a2, "+dcb", 0, "‹")
			renderer_text(x + 60, y, r, g, b, a, "+dcb", 0, "›")
		elseif body_yaw < 0 then
			renderer_text(x - 60, y, r, g, b, a, "+dcb", 0, "‹")
			renderer_text(x + 60, y, r2, g2, b2, a2, "+dcb", 0, "›")
		end
	end
end

local on_aa_setup_event = function(cmd)
	local enabled = menu.aa.enabled:get()

	if not enabled then
		return
	end

	hide_aa(not enabled)

	local net_channel_info = native_GetNetChannelInfo()
	local avg_loss = native_GetAvgLoss(net_channel_info, FLOW_INCOMING) * 10
	local avg_choke = native_GetAvgChoke(net_channel_info, FLOW_INCOMING) * 10

	local security = ui_get(menu.aa.security[1])
	local security_active_app = table_contains(security, "Minimized")
	local security_velocity = table_contains(security, "Velocity")
	local security_fake_duck = table_contains(security, "Fake duck")
	local security_fps = table_contains(security, "FPS")
	local security_ping = table_contains(security, "Ping")
	local security_choke = table_contains(security, "Choke")
	local security_loss = table_contains(security, "Loss")

	local fake_duck_hk = ui_get(refs.rage.fake_duck)
	local fps_value = ui_get(menu.aa.fps)
	local ping_value = ui_get(menu.aa.ping)
	local choke_value = ui_get(menu.aa.choke)
	local loss_value = ui_get(menu.aa.loss)
	local velocity_value = ui_get(menu.aa.velocity)

	local local_player = entity.get_local_player()
	local velocity = get_velocity(local_player)

	if (security_velocity and velocity > velocity_value) or ((cmd.in_use or cmd.in_attack or cmd.in_attack2) == 1) then
		vars.disable_aa = true
	else
		if vars.disable_aa then
			ui_set(refs.aa.enabled, true)
			vars.disable_aa = false
		end
	end

	local _mode_hotkey = ui_get(menu.aa.mode_hotkey)

	if _mode_hotkey then
		ui_set(menu.aa.mode, "Unsafe")
		vars.last_side = 0
	else
		ui_set(menu.aa.mode, "Safe")
		vars.last_side = 0
	end

	if (security_active_app and not native_IsActiveApp()) or (security_fake_duck and fake_duck_hk) or (security_fps and get_fps() < fps_value) or (security_ping and round(client_latency()*1000) > ping_value) or (security_choke and avg_choke > choke_value) or (security_loss and avg_loss > loss_value) or vars.disable_aa then
		return ui_set(refs.aa.enabled, false)
	else
		ui_set(refs.aa.enabled, true)
	end

	local type = ui_get(menu.aa.type)
	local hotkey = ui_get(menu.aa.hotkey)
	local lby = ui_get(menu.aa.lby_target)
	local fake_yaw = ui_get(menu.aa.fake_yaw_limit)

	-- ui_set(refs.aa.lby_target, lby)
	ui_set(refs.aa.fake_yaw_limit, fake_yaw)

	if not vars.disable_aa and type == "Manual" then
		if hotkey then
			ui_set(refs.aa.body_yaw[2], 60)
		else
			ui_set(refs.aa.body_yaw[2], -60)
		end
	elseif not vars.disabled_aa and type == "Dynamic" then
		local game_time = globals_curtime()

		if vars.hit_side ~= 0 and game_time - vars.last_hit > 5 then
			vars.last_side = 0
			vars.last_hit = 0
			vars.last_side = 0
		end

		local _mode = ui_get(menu.aa.mode)

		local x, y, z = client_eye_position()
		local _, yaw = client_camera_angles()

		local trace_data = { left = 0, right = 0 }

		for i = yaw - 90, yaw + 90, 30 do
			if i ~= yaw then
				local rad = math_rad(i)

				local px, py, pz = x + 256 * math_cos(rad), y + 256 * math_sin(rad), z
				local fraction = client_trace_line(local_player, x, y, z, px, py, pz)
				local side = i < yaw and "left" or "right"
				trace_data[side] = trace_data[side] + fraction
			end
		end

		vars.side = trace_data.left < trace_data.right and 1 or 2
		
		if vars.side == vars.last_side then
			return
		end

		vars.last_side = vars.side

		if vars.hit_side ~= 0 then
			vars.side = vars.hit_side == 1 and 2 or 1
		end

		local limit = ui_get(refs.aa.fake_yaw_limit)
		local lby = _mode == "Safe" and (vars.side == 1 and limit or -limit) or (vars.side == 1 and -limit or limit)

		ui_set(refs.aa.body_yaw[2], lby)
	end
end

local on_aa_change = function(ref, value)
	local enabled = menu.rage.enabled:get() and menu.aa.enabled:get()

	ui_set_visible(menu.aa.type, value)
	ui_set_visible(menu.aa.lby_target, value)
	ui_set_visible(menu.aa.fake_yaw_limit, value)
	ui_set_visible(menu.aa.indicators, value)
	ui_set_visible(menu.aa.security[1], value)
	ui_set_visible(menu.aa.velocity, value)

	if enabled then
		menu.aa.fake_yaw_slow:show()
	else
		menu.aa.fake_yaw_slow:set(false)
		menu.aa.fake_yaw_slow:hide()
	end

	on_aa_type_change(menu.aa.type)
	on_aa_indicators_change(menu.aa.indicators)
	on_aa_security_change(menu.aa.security[1])
end

local on_enable_change = function(ref, value)
	local enabled = menu.rage.enabled:get()

	menu.rage.improvements:show()
	menu.rage.fire:show()
	menu.rage.penetration:show()
	menu.rage.dynamicfov:show()
	menu.rage.bruteforce:show()
	menu.rage.advanced_logs:show()
	menu.visuals.indicators:show()
	menu.visuals.flags:show()
	menu.aa.enabled:show()

	hide_useless_features(not enabled)
	hide_aa(not enabled)

	if not enabled then
		menu.rage.improvements:set(false)
		menu.rage.improvements:hide()
		menu.rage.fire:set(false)
		menu.rage.fire:hide()
		menu.rage.penetration:set(false)
		menu.rage.penetration:hide()
		menu.rage.dynamicfov:set(false)
		menu.rage.dynamicfov:hide()
		menu.rage.bruteforce:set(false)
		menu.rage.bruteforce:hide()
		menu.rage.advanced_logs:set(false)
		menu.rage.advanced_logs:hide()
		menu.visuals.indicators:set(false)
		menu.visuals.indicators:hide()
		menu.visuals.flags:set(false)
		menu.visuals.flags:hide()
		menu.aa.enabled:set(false)
		menu.aa.enabled:hide()
	end
end

local handle_callbacks = function()
	on_penetration_mode_change(menu.rage.penetration_mode[1])
	ui_set_callback(menu.rage.penetration_mode[1], on_penetration_mode_change)

	on_dynamicfov_mode_change(menu.rage.dynamicfov_mode)
	ui_set_callback(menu.rage.dynamicfov_mode, on_dynamicfov_mode_change)

	on_aa_type_change(menu.aa.type)
	ui_set_callback(menu.aa.type, on_aa_type_change)

	on_aa_indicators_change(menu.aa.indicators)
	ui_set_callback(menu.aa.indicators, on_aa_indicators_change)

	on_aa_security_change(menu.aa.security[1])
	ui_set_callback(menu.aa.security[1], on_aa_security_change)

	menu.rage.enabled:on("change", on_enable_change)
	menu.rage.improvements:on("change", on_improvements_change)
	menu.rage.improvements:on("player_blind", on_improvements_blind_event)
	menu.rage.improvements:on("run_command", on_improvements_smoke_event)
	menu.rage.improvements:on("setup_command", on_improvements_event)
	menu.rage.fire:on("change", on_fire_change)
	menu.rage.fire:on("setup_command", on_fire_event)
	menu.rage.penetration:on("change", on_penetration_change)
	menu.rage.penetration:on("paint", on_penetration_event)
	menu.rage.dynamicfov:on("change", on_dynamicfov_change)
	menu.rage.dynamicfov:on("run_command", on_dynamicfov_event)
	menu.rage.dynamicfov:on("setup_command", on_dynamicfov_setup_event)
	menu.rage.bruteforce:on("change", on_bruteforce_change)
	menu.rage.bruteforce:on("setup_command", on_bruteforce_event)
	menu.rage.advanced_logs:on("change", on_advanced_logs_change)
	menu.rage.advanced_logs:on("aim_miss", on_miss_event)
	menu.visuals.indicators:on("change", on_indicators_change)
	menu.visuals.indicators:on("paint", on_indicators_event)
	menu.visuals.flags:on("change", on_flags_change)
	menu.aa.enabled:on("change", on_aa_change)
	menu.aa.enabled:on("setup_command", on_aa_setup_event)
	menu.aa.enabled:on("paint", on_aa_paint_event)
	menu.aa.fake_yaw_slow:on("change", on_fake_yaw_slow_change)
	menu.aa.fake_yaw_slow:on("setup_command", on_fake_yaw_slow_setup_command)

	client_set_event_callback("run_command", function()
		local enabled = menu.rage.enabled:get()

		if not enabled then
			return
		end

		config_aa()

		if (vars.fire or vars.fire_improvements) then
			ui_set(refs.rage.fire, true)
			ui_set(refs.rage.enabled[2], "Always on")
		else
			ui_set(refs.rage.fire, false)
			ui_set(refs.rage.enabled[2], "On hotkey")
		end
	end)

	client_set_event_callback("shutdown", function()
		ui_set_visible(refs.rage.logs, true)
		ui_set(refs.players.reset_all, true)

		hide_useless_features(true)
		hide_aa(true)
	end)

	client_register_esp_flag("FAKE", 255, 0, 0, function(c)
		local flags = menu.visuals.flags:get()
		local flags_mode = ui_get(menu.visuals.flags_mode[1])
		local flags_fake = table_contains(flags_mode, "FAKE")

		if entity_is_enemy(c) and flags and flags_fake then
			return plist_get(c, "Correction active")
		end
	end)

	client_register_esp_flag("RIGHT", 255, 0, 0, function(c)
		local body_yaw = ui_get(refs.players.body_yaw_value)

		local flags = menu.visuals.flags:get()
		local flags_mode = ui_get(menu.visuals.flags_mode[1])
		local flags_bruteforce = table_contains(flags_mode, "Bruteforce")

		if body_yaw == 60 and flags and flags_bruteforce then
			if entity_is_enemy(c) then
				return plist_get(c, "Force body yaw value")
			end
		end
	end)
	
	client_register_esp_flag("LEFT", 255, 0, 0, function(c) 
		local body_yaw = ui_get(refs.players.body_yaw_value)

		local flags = menu.visuals.flags:get()
		local flags_mode = ui_get(menu.visuals.flags_mode[1])
		local flags_bruteforce = table_contains(flags_mode, "Bruteforce")
		
		if body_yaw == -60 and flags and flags_bruteforce then
			if entity_is_enemy(c) then
				return plist_get(c, "Force body yaw value")
			end
		end
	end)
end
handle_callbacks()