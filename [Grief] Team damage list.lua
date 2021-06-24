local key_state, userid_to_entindex, read, write, get_local_player, get_player_name, get_prop, get_steam64, rectangle, text, get, is_menu_open, mouse_position, new_hotkey, new_checkbox, new_combobox, pairs, set_callback, mp_td_dmgtokick, get_player_resource, _set, _unset, min, remove = client.key_state, client.userid_to_entindex, database.read, database.write, entity.get_local_player, entity.get_player_name, entity.get_prop, entity.get_steam64, renderer.rectangle, renderer.text, ui.get, ui.is_menu_open, ui.mouse_position, ui.new_hotkey, ui.new_checkbox, ui.new_combobox, pairs, ui.set_callback, cvar.mp_td_dmgtokick, entity.get_player_resource, client.set_event_callback, client.unset_event_callback, math.min, table.remove
local is_inside = function(a, b, x, y, w, h) return a >= x and a <= w and b >= y and b <= h end
local tbl_len = function(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
local pos = read('teamdmg_pos')or{300,30} local tX,tY=pos[1],pos[2] local oX,oY,_d local drag_menu=function(x,y,w,h)if not is_menu_open()then return tX,tY end local mouse_down=key_state(0x01)if mouse_down then local X,Y=mouse_position()if not _d then local w,h=x+w,y+h if is_inside(X,Y,x,y,w,h)then oX,oY,_d=X-x,Y-y,true end else tX,tY=X-oX,Y-oY end else _d=false end return tX,tY end

local mode = new_combobox('lua', 'a', 'Show Teammates Damage/Kills', 'Off', 'Without Colors', 'Matchmaking Colors', 'Matchmaking Color Names')
local key = new_hotkey('lua', 'a', 'hotkey', true)
local rem = new_checkbox('lua', 'a', 'Remove from list when over amount')
local last_p = read('teamdmg_pos_last') or {}
local h, m, s = client.system_time()
local players = last_p[h .. m] or {}
local num_of_players = tbl_len(players)

local white, color_mode = {255,255,255,255}
local colors = {
	{200, 200, 200, 255, 'BOT'},
	{200, 200, 200, 255, 'Gray'},
	{255, 255, 0, 255, 	 'Yellow'},
	{110, 0, 255, 255, 	 'Purple'},
	{0, 200, 0, 255, 	 'Green'},
	{0, 75, 255, 255, 	 'Blue'},
	{255, 145, 0, 255, 	 'Orange'}
}

local function on_player_stuff(e)
	local attacker, victim, local_player = userid_to_entindex(e.attacker), userid_to_entindex(e.userid), get_local_player()

	if attacker == victim then
		return
	end

	local player_resource = get_player_resource()
	local local_player_team = get_prop(player_resource, 'm_iTeam', local_player)
	local attacker_team = get_prop(player_resource, 'm_iTeam', attacker)
	local victim_team = get_prop(player_resource, 'm_iTeam', victim)
	if attacker_team ~= local_player_team or victim_team ~= local_player_team then
		return
	end

	local steamID3 = get_steam64(attacker)
	if steamID3 == 0 then
		return
	end

	if not players[steamID3] then
		players[steamID3] = {0, 0, get_player_name(attacker), white, colors[get_prop(player_resource, 'm_iCompTeammateColor', attacker) + 3], attacker}
		num_of_players = num_of_players + 1
	end

	if not e.health then
		players[steamID3][1] = players[steamID3][1] + 1
	else
		players[steamID3][2] = players[steamID3][2] + e.dmg_health
	end

	players[steamID3][4] = color_mode == 'Without Colors' and white or players[steamID3][5]
	players[steamID3][3] = color_mode == 'Matchmaking Color Names' and players[steamID3][5][5] or get_player_name(attacker)
end

local function on_paint()
	if not get(key) then
		return
	end

	local x, y = drag_menu(tX, tY, 200, 20)

	rectangle(x, y, 200, 20, 37, 37, 37, 250)
	text(x + 100, y + 10, 255,255,255,255, 'cd', 0, 'Player List')
	rectangle(x, y + 20, 200, (num_of_players * 10) + 10, 33, 33, 33, 180)

	local y = y + 25
	local dmg_to_kick = mp_td_dmgtokick:get_int()
	local list_clear = get(rem)
	local gap = 0

	local player_resource = get_player_resource()
	local local_player_team = get_prop( player_resource, 'm_iTeam', get_local_player() )

	for steamid, stuff in pairs(players) do
		local m = min(stuff[2] / dmg_to_kick, 1)
		local c = stuff[4]

		text(x + 5, y + gap, c[1], c[2], c[3], c[4] , 'ld', 42, stuff[3])

		rectangle(x + 50, (y + gap - 3) + 7, 100, 6, 13, 13, 13, 230)
		rectangle(x + 51, (y + gap - 2) + 7, 98*m, 4, 49, 233, 93, 255)

		text(x + 100, y + gap + 7, 255,255,255,255, 'c-d', 0, stuff[2]..'/'..dmg_to_kick)

		text(x + 195, y + gap, 255,255,255,255, 'rd', 0, stuff[1].. ' Kills')

		gap = gap + 11

		if list_clear then
			if stuff[1] >= 3 or stuff[2] >= dmg_to_kick then
				remove(players, steamid)
			end
		end

		if get_prop(player_resource, 'm_iTeam', stuff[6]) ~= local_player_team then
			remove(players, steamid)
		end
	end
end

local function reset_list(e) players,num_of_players={},0 end
local function on_shutdown()
	write('teamdmg_pos', {tX, tY})
	local h, m = client.system_time()
	write('teamdmg_pos_last', {[h .. m] = players})
end

local function on_change(s)
	local e = get(s)
	local callback = e ~= 'Off' and _set or _unset
	color_mode = e

	callback('player_hurt', on_player_stuff)
	callback('player_death', on_player_stuff)
	callback('paint', on_paint)
	callback('cs_win_panel_match', reset_list)
	callback('shutdown', on_shutdown)
end

on_change(mode)
set_callback(mode, on_change)
ui.new_button('lua', 'a', 'Reset List', reset_list)