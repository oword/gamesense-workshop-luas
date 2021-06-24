--> init gs libraries
local vector, images, js, ffi = require "vector",  require "gamesense/images", panorama.open(), require("ffi")

--> function cache
local c = {
	["ent"] = {
		get_local = entity.get_local_player,
		get_prop = entity.get_prop,
		get_weapon = entity.get_player_weapon,
		is_alive = entity.is_alive,
		is_enemy = entity.is_enemy,
		get_all = entity.get_all,
		get_classname = entity.get_classname
	},
	["render"] = {
		polygon = renderer.triangle,
		line = renderer.line,
		circle = renderer.circle,
		circle_out = renderer.circle_outline,
		rectangle = renderer.rectangle,
		gradient = renderer.gradient,
		measure = renderer.measure_text,
		text = renderer.text,
		world_to_screen = renderer.world_to_screen
	},
	["math"] = {
		rad = math.rad,
		pi = math.pi,
		cos = math.cos,
		sin = math.sin,
		min = math.min,
		max = math.max
	},
	["data"] = { read = database.read, write = database.write },
	["globals"] = {
		tickcount = globals.tickcount,
		frametime = globals.frametime,
		realtime = globals.realtime
	},
	["client"] = {
		screen_size = client.screen_size,
		set_event_callback = client.set_event_callback,
		userid_to_idx = client.userid_to_entindex,
		color_log = client.color_log,
		find_sig = client.find_signature,
		key_state = client.key_state,
		exec = client.exec
	},
	["table"] = {
		insert = table.insert,
		remove = table.remove
	},
	["ffi"] = {
		cast = ffi.cast
	}
}

--> local variables
local my_steamid = js.MyPersonaAPI.GetXuid()
local w, h = c["client"].screen_size()
local xp_table, money_table, logs = {}, {}, {}
local active_quest = 0
local w_alp, shoot_a, res_a, hit_a = 0, 0, 0, 0
local has_shot, has_hit = 0, 0
local shots = {missed=0}
local auto_save = globals.realtime()+600
local mouse = {}
local kill_time = c["data"].read("rpg/kill_times") or {}
local active_weapon = ""
local data = {
	username = c["data"].read("rpg/nickname_") or "unknown",
	avatar = c["data"].read("rpg/avatar") or images.get_steam_avatar(my_steamid, 65) or nil,
	status = "",
	lvl = c["data"].read("rpg/level_") or 1,
	xp = {
		c["data"].read("rpg/xp/current_") or 0,
		c["data"].read("rpg/xp/needed_") or 100,
		c["data"].read("rpg/xp/reached_") or 0,
		c["data"].read("rpg/xp/prev_reached_") or 0,
	},
	balance = c["data"].read("rpg/balance_") or 0,
	disable_original = c["data"].read("rpg/hud/disable_orig") or 0,
	force_weapon = c["data"].read("rpg/hud/force_weap") or 0
}
local quests = {
	{"Kill someone with a knife", "kill_knife", {300, 400}, "rpg/quests/3/kill_knife", c["data"].read("rpg/quests/3/kill_knife") or 0},
	{"Kill someone without missing a single shot", "kill_miss", {400, 1000}, "rpg/quests/3/kill_miss", c["data"].read("rpg/quests/3/kill_miss") or 0}
}
local imgs = {
	helmet = images.get_weapon_icon("helmet"),
	armor = images.get_weapon_icon("kevlar")
}
local shop_items = {
	{"On-shot", "os", "Helps you to not get onshotted.", 200, "cheat_feature", {"aa", "other", "on shot anti-aim"}, "rpg/shop/os_", database.read("rpg/shop/os_")},
}
local pos = {
	x = c["data"].read("rpg/hud/pos.x") or 854, y = c["data"].read("rpg/hud/pos.y") or 110
}

if data.username == "unknown" then
	c["client"].color_log(255, 0, 0, "Please select your username. [.nick]")
end

--> local functions
local function rpg_log(r, g, b, log)
	c["table"].insert(logs, {1, c["globals"].tickcount(), {r, g, b, log}})
	c["client"].color_log(r, g, b, log)
end

local function intersect(x, y, width, height)
	local cx, cy = ui.mouse_position()
	return cx >= x and cx <= x + width and cy >= y and cy <= y + height
end

local function draw_circle_3d(x, y, z, radius, degrees, start_at, r, g, b, a, filled, fill_r, fill_g, fill_b, fill_a)
	local old = { x, y }
	local center = {}; center.x, center.y = c["render"].world_to_screen(x, y, z)
	for rot=start_at, degrees+start_at, c["math"].min(25, radius/5) do
		local rot_t = c["math"].rad(rot)
		local point = vector(radius * c["math"].cos(rot_t) + x, radius * c["math"].sin(rot_t) + y, z)
		local current = {}; current.x, current.y = c["render"].world_to_screen(point.x, point.y, point.z)
		if current.x ~= nil and old.x ~= nil then
			if filled then c["render"].polygon(center.x, center.y, old.x, old.y, current.x, current.y, fill_r, fill_g, fill_b, fill_a) end
			c["render"].line(current.x, current.y, old.x, old.y, r, g, b, a)
		end
		old.x, old.y = current.x, current.y
	end
end

local function rotate_around_c(angle, center, point, point_)
	local s = c["math"].sin(angle)
	local c_ = c["math"].cos(angle)

	point.x = point.x-center.x
	point.y = point.y-center.y
	point_.x = point_.x-center.x
	point_.y = point_.y-center.y

	local xn, yn = point.x * c_ - point.y * s, point.x * s + point.y * c_
	local x_n, y_n = point_.x * c_ - point_.y * s, point_.x * s + point_.y * c_ 

	return xn+center.x, yn+center.y, x_n+center.x, y_n+center.y
end

local function clamp(b, c, d)
	local e=b; e=e<c and c or e;e=e>d and d or e
	return e
end

local function save(auto)
	c["data"].write("rpg/level_", data.lvl)
	c["data"].write("rpg/xp/current_", data.xp[1])
	c["data"].write("rpg/xp/needed_", data.xp[2])
	c["data"].write("rpg/xp/reached_", data.xp[3])
	c["data"].write("rpg/xp/prev_reached_", data.xp[4])
	c["data"].write("rpg/balance_", data.balance)
	c["data"].write("rpg/has_save_", true)

	rpg_log(220, 220, 220, auto and "Automatically saved progress." or "Successfully saved progress.")
end

local function load()
	if c["data"].read("rpg/has_save_") == nil or c["data"].read("rpg/has_save_") == false or c["data"].read("rpg/level_") == nil then
		c["client"].color_log(255, 0, 0, "Couldn't find any save, sorry!")
		return
	end
	data.lvl = c["data"].read("rpg/level_")
	data.xp[1] = c["data"].read("rpg/xp/current_")
	data.xp[2] = c["data"].read("rpg/xp/needed_")
	data.xp[3] = c["data"].read("rpg/xp/reached_")
	data.xp[4] = c["data"].read("rpg/xp/prev_reached_")
	data.balance = c["data"].read("rpg/balance_")

	rpg_log(220, 220, 220, "Loaded latest save.")
end

local function reset(save)
	if save then
		if c["data"].read("rpg/has_save_") then
			c["data"].write("rpg/level_", nil)
			c["data"].write("rpg/xp/current_", nil)
			c["data"].write("rpg/xp/needed_", nil)
			c["data"].write("rpg/xp/reached_", nil)
			c["data"].write("rpg/xp/prev_reached_", nil)
			c["data"].write("rpg/balance_", nil)
			c["data"].write("rpg/has_save_", false)
			c["client"].color_log(220, 220, 220, "Successfully reset your save")
		else
			c["client"].color_log(255, 0, 0, "Couldn't find any save to reset.")
		end
	else
		c["client"].color_log(220, 220, 220, "Successfully reset your progress.")
	end
	data.lvl = 1; data.xp[1] = 0; data.xp[2] = 100; data.xp[3] = 0; data.xp[4] = 0; data.balance = 0
end

local function setup(item, value, save_)
	if item == "xp" then
		data.xp[1] = data.xp[1] + value
		c["table"].insert(xp_table, {1, c["globals"].tickcount(), value})
		if save_ then save(true) end
	elseif item == "level" then
		data.lvl = data.lvl + value
		if value > 0 then
			--client.exec("playvol \\rpg\\challenge_complete.mp3 1")
		end
		if save_ then save(true) end
	elseif item == "balance" then
		data.balance = data.balance + value
		c["table"].insert(money_table, {1, c["globals"].tickcount(), value})
		if save_ then save(true) end
	end
end

--> rpg system / callbacks / main functions
local function count_miss(e)
	if e.reason ~= "spread" then
		shots.missed = shots.missed + 1
	end
end

local function draw_player_hud()
	local player = c["ent"].get_local()
	if player == nil then return end
	if data.avatar == nil or my_steamid == nil then
		my_steamid = js.MyPersonaAPI.GetXuid()
		data.avatar = images.get_steam_avatar(my_steamid, 65)
	end
	if data.disable_original == 1 then
		if cvar.cl_drawhud:get_int() == 1 then cvar.cl_drawhud:set_int(0) end
		if cvar.cl_drawhud_force_radar:get_int() <= 0 then cvar.cl_drawhud_force_radar:set_int(1) end
	elseif data.disable_original == 2 then
		if cvar.cl_drawhud_force_radar:get_int() >= 0 then cvar.cl_drawhud_force_radar:set_int(-1) end
		if cvar.cl_drawhud:get_int() == 1 then cvar.cl_drawhud:set_int(0) end
	else
		if cvar.cl_drawhud_force_radar:get_int() <= 0 then cvar.cl_drawhud_force_radar:set_int(1) end
		if cvar.cl_drawhud:get_int() == 0 then cvar.cl_drawhud:set_int(1) end
	end
	local text = data.username:sub(0, 24) .. " • level " .. data.lvl .. " (+" .. data.xp[2] - data.xp[1] .. "xp)"
	local info = {
		health = c["ent"].get_prop(player, "m_iHealth"),
		armor = c["ent"].get_prop(player, "m_ArmorValue"),
		has_helmet = c["ent"].get_prop(player, "m_bHasHelmet"),
		text_size = {c["render"].measure("", text)},
		status_size = {c["render"].measure("", data.status)},
		balance_size = {c["render"].measure("", "$" .. data.balance)},
		is_scoped = c["ent"].get_prop(player, "m_bIsScoped")
	}
	local health_size = {c["render"].measure("", info.health .. "hp")}
	local hp_cap, xp_cap = c["math"].min(1, info.health/100), c["math"].min(1, data.xp[1]/data.xp[2])
	local weapon = c["ent"].get_weapon(player)
	local weapon_ico = images.get_weapon_icon("weapon_knife")
	local speed = c["globals"].frametime() * 8
	local weap_enabled = data.disable_original > 0 or data.force_weapon > 0
	mouse.left = c["client"].key_state(0x01); mouse.pos = {ui.mouse_position()}

	if c["ent"].is_alive(player) then
		active_weapon = c["ent"].get_classname(c["ent"].get_weapon(c["ent"].get_local()))
	end

	if res_a > 0.00 then
		if pos.drag and not mouse.left then pos.drag = false end

		if pos.drag and mouse.left then
			pos.x = mouse.pos[1] - pos.drag_x
			pos.y = mouse.pos[2] - pos.drag_y
			c["data"].write("rpg/hud/pos.x", pos.x)
			c["data"].write("rpg/hud/pos.y", pos.y)
		end

		if intersect(pos.x, pos.y, 30, 17) and mouse.left then
			pos.drag = true
			pos.drag_x = mouse.pos[1] - pos.x
			pos.drag_y = mouse.pos[2] - pos.y
		end
		c["render"].rectangle(pos.x, pos.y, 30, 20, 30, 30, 30, 255*res_a)
		c["render"].text(pos.x+10, pos.y, 180, 180, 180, 255*res_a, "-", 0, "▼")
	end

	--135, 90
	data.avatar:draw(pos.x-23, pos.y+32, 75, 75, 255, 255, 255, 255, true)
	c["render"].circle(pos.x+15, pos.y+105, 0, 150, 255, 190, 13, 0, 1)
	c["render"].text(pos.x+15, pos.y+100, 255, 255, 255, 255, "c", 0, data.lvl)
	c["render"].circle_out(pos.x+15, pos.y+70, 30, 30, 30, 255, 55, 0, 1, 18)
	c["render"].circle_out(pos.x+15, pos.y+70, 0, 150, 255, 255, 40, 90, xp_cap, 1)

	c["render"].rectangle(pos.x+55, pos.y+70, info.status_size[1]+info.balance_size[1]+40, 20, 30, 30, 30, 255)
	c["render"].gradient(pos.x+55+info.status_size[1]+info.balance_size[1]+40, pos.y+70, 30, 20, 30, 30, 30, 255, 30, 30, 30, 0, true)
	c["render"].text(pos.x+77, pos.y+73, 255, 190, 00, 255, "", 0, data.status)
	c["render"].text(pos.x+77+info.status_size[1], pos.y+73, 220, 220, 220, 255, "", 0, " • $" .. data.balance)

	c["render"].rectangle(pos.x-25, pos.y+55, -health_size[1]-30, 20, 30, 30, 30, 255)
	c["render"].text(pos.x-45-health_size[1], pos.y+58, 255-(108*hp_cap), 220*hp_cap, 50*hp_cap, 255, "", 0, info.health .. "hp")
	c["render"].gradient(pos.x-25-health_size[1]-60, pos.y+55, 30, 20, 30, 30, 30, 0, 30, 30, 30, 255, true)

	c["render"].circle_out(pos.x+15, pos.y+70, 255-(108*hp_cap), 220*hp_cap, 50*hp_cap, 255, 55, 355, (hp_cap)*0.92, 1)
	c["render"].gradient(pos.x+55+info.text_size[1]+30, pos.y+40, 30, 25, 30, 30, 30, 255, 30, 30, 30, 0, true)
	c["render"].rectangle(pos.x+55, pos.y+40, info.text_size[1]+30, 25, 30, 30, 30, 255)
	c["render"].text(pos.x+75, pos.y+45, 220, 220, 220, 255, "", 0, text)

	if w_alp > 0.00 then
		imgs.helmet:draw(pos.x+65, pos.y+15, 15, 25, 220, 220, 220, info.has_helmet == 1 and 255*w_alp or 60*w_alp, true)
		imgs.armor:draw(pos.x+85, pos.y+20, 15, 15, 220, 220, 220, info.armor > 1 and 255*w_alp or 60*w_alp, true)
	end

	--> current weapon
	if w_alp > 0.00 and c["ent"].is_alive(player) then
		weapon_ico = images.get_weapon_icon(c["ent"].get_prop(weapon, "m_iItemDefinitionIndex"))
		shoot_a = math.max(0, has_shot-c["globals"].tickcount())/20
		hit_a = math.max(0, has_hit-c["globals"].tickcount())/13
		local measure = {weapon_ico:measure()+10}
		local ammo = {c["ent"].get_prop(weapon, "m_iClip1"), c["ent"].get_prop(weapon, "m_iPrimaryReserveAmmoCount")}
		weapon_ico:draw(w/2-measure[1]/2, h-180, measure[1], measure[2], 220, 220, 220, 120*w_alp+135*shoot_a, true)
		if hit_a > 0 then
			weapon_ico:draw(w/2-measure[1]/2, h-180, measure[1], measure[2], 220, 0, 0, 120*hit_a, true)
		end
		if ammo and ammo[1] > -1 then
			c["render"].text(w/2, h-120, 220, 220, 220, 255*w_alp, "c+", 0, ammo[1] .. " / " .. ammo[2])
		end
	end
	w_alp = clamp(w_alp+(weap_enabled and speed/2 or -speed), 0, 1)
	res_a = clamp(res_a+(ui.is_menu_open() and speed/2 or -speed), 0, 1)
end

local function handle_adds()
	local remove_xp, remove_money, remove_log = {}, {}, {}
	for i=1, #xp_table do
		xp = xp_table[i]
		local speed = c["globals"].frametime() * 8
		
		if xp[2]+160 < c["globals"].tickcount() or i > 5 then
			remove_xp[#remove_xp+1] = 1
		end
		if xp[3] > 0 then
			c["render"].text(pos.x+15, pos.y+20-15*i+10*xp[1], 0, 150, 255, 255*(1-xp[1]), "c", 0, "+" .. xp[3] .. "xp")
		else
			c["render"].text(pos.x+15, pos.y+20-15*i+10*xp[1], 255, 40, 0, 255*(1-xp[1]), "c", 0, xp[3] .. "xp")
		end
		xp[1] = clamp(xp[1]+(xp[2]+150 < c["globals"].tickcount() and speed/2 or -speed), 0, 1)
	end
	for i=1, #money_table do
		money = money_table[i]
		local speed = c["globals"].frametime() * 8
		
		if money[2]+160 < c["globals"].tickcount() or i > 5 then
			remove_money[#remove_money+1] = 1
		end
		if money[3] > 0 then
			c["render"].text(pos.x+65+c["render"].measure("", data.status .. " • $" .. data.balance), pos.y+80+15*i-10*money[1], 147, 220, 50, 255*(1-money[1]), "c", 0, "+$" .. money[3])
		else
			c["render"].text(pos.x+65+c["render"].measure("", data.status .. " • $" .. data.balance), pos.y+80+15*i-10*money[1], 255, 40, 0, 255*(1-money[1]), "c", 0, "-$" .. -money[3])
		end
		money[1] = clamp(money[1]+(money[2]+150 < c["globals"].tickcount() and speed/2 or -speed), 0, 1)
	end
	for i=1, #logs do
		log = logs[i]
		local speed = c["globals"].frametime() * 8
		local log_ = {width=c["render"].measure("", log[3][4])}
		local add = log[2]+300 > c["globals"].tickcount() and 15*log[1] or 0

		if log[2]+310 < c["globals"].tickcount() or i > 15 then
			remove_log[#remove_log+1] = 1
		end
		c["render"].circle(pos.x+80, pos.y+88+20*i-add, 30, 30, 30, 255*(1-log[1]), 7.8, 180, 0.5)
		c["render"].rectangle(pos.x+80, pos.y+80+20*i-add, log_.width, 16, 30, 30, 30, 255*(1-log[1]))
		c["render"].circle(pos.x+80+log_.width, pos.y+88+20*i-add, 30, 30, 30, 255*(1-log[1]), 7.8, 0, 0.5)
		c["render"].text(pos.x+80, pos.y+81+20*i-add, log[3][1], log[3][2], log[3][3], 255*(1-log[1]), "", 0, log[3][4])

		log[1] = clamp(log[1]+(log[2]+300 < c["globals"].tickcount() and speed/2 or -speed), 0, 1)
	end

	for i=1, #remove_xp do
		c["table"].remove(xp_table, remove_xp[i])
	end
	for i=1, #remove_money do
		c["table"].remove(money_table, remove_money[i])
	end
	for i=1, #remove_log do
		c["table"].remove(logs, remove_log[i])
	end
end

local function on_paint()
	draw_player_hud()
	if #xp_table > 0 or #money_table > 0 or #logs > 0 then
		handle_adds()
	end
	if data.balance < 0 then data.balance = 0 end; if data.balance > 9999 then data.balance = 9999 end
	if data.lvl == 1 and data.xp[1] < 0 then data.xp[1] = 0 end
end
c["client"].set_event_callback("paint", on_paint)

local function level_sys()
	if data.xp[1] >= data.xp[2] then
		data.xp[4] = data.xp[3]; data.xp[3] = data.xp[2]; setup("level", 1, false)
		data.xp[2] = data.lvl <= 10 and data.xp[2]*2 or data.xp[2]*3
		data.xp[1] = 0
		rpg_log(220, 220, 220, "Reached a new level! Level " .. data.lvl .. ", required xp for next level: " .. data.xp[2])
		save(true)
	end
	if data.xp[3]+data.xp[1] < data.xp[3] then
		data.xp[1] = data.xp[3]+data.xp[1]; data.xp[2] = data.xp[3]; data.xp[3] = data.xp[4]; setup("level", -1, true)
	end
	if data.lvl <= 5 then
		data.status = "Beginner"
	elseif data.lvl > 5 and data.lvl <= 15 then
		data.status = "Adventurer"
	elseif data.lvl > 15 and data.lvl <= 30 then
		data.status = "Master"
	elseif data.lvl > 30 and data.lvl <= 50 then
		data.status = "Legendary"
	end
	--> autosave
	if auto_save < c["globals"].realtime() then
		save(true)
		auto_save = c["globals"].realtime()+600
	end

	--> anti-farm cooldown
	for i in pairs(kill_time) do
		if c["globals"].realtime() >= kill_time[i] then
			kill_time[i] = nil
		end
	end
end

local function shop_sys()
end

local function run_all_systems()
	level_sys()
	shop_sys()
end
c["client"].set_event_callback("setup_command", run_all_systems)

local function commands(e)
	local msg = e
	if msg:sub(0, 1) == "." then
		if msg:sub(2, 5):lower() == "nick" then
			data.username = msg:sub(7, 32)
			database.write("rpg/nickname_", data.username)
			return true
		elseif msg:sub(2, 5):lower() == "help" then
			c["client"].color_log(255, 255, 255, "Hey, \0")
			c["client"].color_log(255, 0, 0, data.username .. " \0")
			c["client"].color_log(255, 255, 255, "Here's a list of all the current commands.")
			c["client"].color_log(255, 190, 0, ".nick [nickname] \0")
			c["client"].color_log(255, 255, 255, " - change your nickname.")
			c["client"].color_log(255, 190, 0, ".stats \0")
			c["client"].color_log(255, 255, 255, " - display your current statistics.")
			c["client"].color_log(255, 190, 0, ".save \0")
			c["client"].color_log(255, 255, 255, " - save your progress.")
			c["client"].color_log(255, 190, 0, ".load \0")
			c["client"].color_log(255, 255, 255, " - load the latest save.")
			c["client"].color_log(255, 190, 0, ".reset [1] \0")
			c["client"].color_log(255, 255, 255, " - reset your progress [save].")
			c["client"].color_log(255, 190, 0, ".shop [buy/refund] [item:id] \0")
			c["client"].color_log(255, 255, 255, " - view the shop/buy or refund an item.")
			c["client"].color_log(255, 190, 0, ".quest [list/take] [quest:id] \0")
			c["client"].color_log(255, 255, 255, " - view the quest list/take a quest.")
			c["client"].color_log(255, 190, 0, ".disable_hud [int] \0")
			c["client"].color_log(255, 255, 255, " - disable the original csgo hud.")
			c["client"].color_log(255, 190, 0, ".force_hud [int] \0")
			c["client"].color_log(255, 255, 255, " - force luas weapon hud.")
			return true
		elseif msg:sub(2, 6):lower() == "stats" then
			c["client"].color_log(255, 255, 255, data.username .. " • level \0")
			c["client"].color_log(255, 190, 0, data.lvl .. " \0")
			c["client"].color_log(255, 255, 255, "(\0")
			c["client"].color_log(0, 150, 255, data.xp[2] - data.xp[1] .. "xp\0")
			c["client"].color_log(255, 255, 255, ") • \0")
			c["client"].color_log(255, 190, 0, data.status .. " \0")
			c["client"].color_log(255, 255, 255, "• $" .. data.balance)
			return true
		elseif msg:sub(2, 5):lower() == "save" then
			save(false)
			return true
		elseif msg:sub(2, 5):lower() == "load" then
			load()
			return true
		elseif msg:sub(2, 6):lower() == "reset" then
			reset(msg:sub(8, 8) == "1")
			return true
		elseif msg:sub(2, 5):lower() == "shop" then
			if msg:len() > 6 then
				for i=1, #shop_items do
					item = shop_items[i]
					if msg:sub(7, 9):lower() == "buy" then
						if item[2] == msg:sub(11, -1):lower() then
							if item[8] then
								c["client"].color_log(255, 0, 0, "This item has already been purchased.")
							else
								if item[4] <= data.balance then
									setup("balance", -item[4], true)
									item[8] = true; database.write(item[7], true)
									c["client"].color_log(255, 255, 255, "Item successfully purchased.")
								else
									c["client"].color_log(255, 0, 0, "You don't have enough money.")
								end
							end
						end
						return true
					elseif msg:sub(7, 12):lower() == "refund" then
						if item[2] == "xp" then
							c["client"].color_log(255, 0, 0, "This item can not refunded.") return
						end
						if item[8] then
							setup("balance", item[4], true)
							item[8] = false; database.write(item[7], false)
							c["client"].color_log(255, 255, 255, "Item successfully refunded.")
						else
							c["client"].color_log(255, 0, 0, "This item has not been purchased yet.")
						end
						return true
					end
				end 
			else
				for i=1, #shop_items do
					item = shop_items[i]
					local r, g, b = 255, 190, 0
					if item[8] then r, g, b = 0, 150, 255 end
					c["client"].color_log(r, g, b, item[1] .. " (" .. item[2] .. ") \0")
					c["client"].color_log(255, 255, 255, "- " .. item[3] .. " \0")
					c["client"].color_log(255, 190, 0, "$" .. item[4])
				end
				return true
			end
		elseif msg:sub(2, 12):lower() == "disable_hud" then
			local translate = tonumber(msg:sub(14, 14))
			if translate and translate <= 2 then
				data.disable_original = translate
				database.write("rpg/hud/disable_orig", translate)
			end
			return true
		elseif msg:sub(2, 10):lower() == "force_hud" then
			local translate = tonumber(msg:sub(12, 12))
			if translate and translate <= 1 then
				data.force_weapon = translate
				database.write("rpg/hud/force_weap", translate)
			end
			return true
		elseif msg:sub(2, 6):lower() == "quest" then
			if msg:len() > 7 then
				if msg:sub(8, 11):lower() == "list" then
					for i=1, #quests do
						quest = quests[i]
						local r, g, b = 255, 255, 255
						if quest[5] < 0 then r, g, b = 255, 0, 0 elseif quest[5] == 1 then r, g, b = 0, 150, 255 elseif quest[5] == 2 then r, g, b = 255, 180, 0 end
						c["client"].color_log(r, g, b, quest[1] .. " (" .. quest[2] .. ") - " .. quest[3][1] .. "xp, $" .. quest[3][2])
					end
					return true
				elseif msg:sub(8, 11):lower() == "take" then
					local quest_name = msg:sub(13, -1):lower()
					active_quest = quest_name
					for i=1, #quests do
						quest = quests[i]
						if quest_name == quest[2] and quest[5] == 0 then
							rpg_log(220, 220, 220, "Successfully have taken a quest - " .. quest[1])
						end
						if active_quest == quest[2] then
							if quest[5] == 0 then quest[5] = 1 end
						else
							if quest[5] == 1 then quest[5] = 0 end
						end
					end
					return true
				end
			else
				c["client"].color_log(180, 180, 180, "Usage: .quest [list/take]")
				return true
			end
		--elseif msg:sub(2, ):lower() == "hud_size" then
		end
	end
end
c["client"].set_event_callback("console_input", commands)

c["client"].set_event_callback("player_death", function(e)
	local victim = c["client"].userid_to_idx(e.userid)
	local attacker = c["client"].userid_to_idx(e.attacker)
	local hs_reward = {
		["knife"] = {200, 100},
		["awp"] = {85, 25},
		["taser"] = {150, 50},
		["ssg08"] = {100, 50}
	}
	local reward = {
		["knife"] = {150, 50},
		["awp"] = {15, 5},
		["taser"] = {100, 50},
		["ssg08"] = {50, 35}
	}
	local loss = {
		["CKnife"] = {-20, -5},
		["CWeaponAWP"] = {-50, -100}
	}
	if hs_reward[e.weapon] == nil then
		hs_reward[e.weapon] = {80, 40}
		reward[e.weapon] = {40, 20}
	end

	if attacker == c["ent"].get_local() and c["ent"].is_enemy(victim) then
		if not kill_time[victim] then
			if e.headshot then
				setup("xp", hs_reward[e.weapon][1], false)
				setup("balance", hs_reward[e.weapon][2], false)
			else
				setup("xp", reward[e.weapon][1], false)
				setup("balance", reward[e.weapon][2], false)
			end
			kill_time[victim] = c["globals"].realtime()+20
		end
		if quests[2][5] == 1 then
			quests[2][5] = 2
			database.write(quests[2][5], 2)
			setup("xp", quests[2][3][1], true)
			setup("balance", quests[2][3][2], true)
		elseif quests[1][5] == 1 then
			if e.weapon == "knife" then
				quests[1][5] = 2
				database.write(quests[1][4], 2)
				setup("xp", quests[1][3][1], true)
				setup("balance", quests[1][3][2], true)
			end
		end
		has_hit = c["globals"].tickcount()+25
	end
	if victim == c["ent"].get_local() then
		if loss[active_weapon] == nil then
			loss[active_weapon] = {-30, -15}
		end
		setup("xp", loss[active_weapon][1], false)
		setup("balance", loss[active_weapon][2], false)
	end
end)
c["client"].set_event_callback("player_hurt", function(e)
	local victim = c["client"].userid_to_idx(e.userid)
	local attacker = c["client"].userid_to_idx(e.attacker)

	if attacker == c["ent"].get_local() and c["ent"].is_enemy(victim) then
		has_hit = c["globals"].tickcount()+13
	end
end)
c["client"].set_event_callback("weapon_fire", function(e)
	if c["client"].userid_to_idx(e.userid) == c["ent"].get_local() then
		has_shot = c["globals"].tickcount()+20
	end
end)
c["client"].set_event_callback("aim_miss", function(e)
	if quests[2][5] == 1 then
		quests[2][5] = -1
		database.write(quests[2][5], -1)
		client.exec("play bot\\aw_hell")
		rpg_log(255, 0, 0, "Quest failed. Missed a shot.")
	end
end)
c["client"].set_event_callback("player_connect_full", function(e)
	if c["client"].userid_to_idx(e.userid) == c["ent"].get_local() then
		kill_time = {}
		has_shot = globals.tickcount()
		has_hit = globals.tickcount()
	end
end)
c["client"].set_event_callback("round_end", function(e)
	if e.winner == c["ent"].get_prop(c["ent"].get_local(), "m_iTeamNum") then
		setup("xp", 50, false)
		setup("balance", 50, false)
	end
end)
c["client"].set_event_callback("shutdown", function()
	if cvar.cl_drawhud_force_radar:get_int() <= 0 then cvar.cl_drawhud_force_radar:set_int(1) end
	if cvar.cl_drawhud:get_int() <= 0 then cvar.cl_drawhud:set_int(1) end
	if #kill_time > 0 then
		database.write("rpg/kill_times", kill_time)
	else
		database.write("rpg/kill_times", {})
	end
end)