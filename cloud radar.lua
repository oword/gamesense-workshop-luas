-- HTTP Libary from workshop
local http = require 'gamesense/http'
local ffi = require('ffi')

local client_userid_to_entindex = client.userid_to_entindex
local client_color_log = client.color_log
local client_trace_line = client.trace_line

local entity_get_all = entity.get_all
local entity_get_local_player = entity.get_local_player
local entity_get_player_resource = entity.get_player_resource
local entity_get_player_name = entity.get_player_name
local entity_get_steam64 = entity.get_steam64
local entity_get_classname = entity.get_classname
local entity_is_dormant = entity.is_dormant
local entity_get_prop = entity.get_prop
local entity_get_origin = entity.get_origin

local globals_tickcount = globals.tickcount
local globals_mapname = globals.mapname

local json_stringify = json.stringify

local math_rad = math.rad
local math_sin = math.sin
local math_cos = math.cos 
local math_tan = math.tan

local renderer_indicator = renderer.indicator

local ui_get = ui.get

--------------------------------------------------

local script_name = _NAME:upper()

local function lua_log(...) --inspired by sapphyrus' multicolorlog
	client_color_log(64, 224, 208, "[" .. script_name .. "]\0")
	local argIndex = 1
	while select(argIndex, ...) ~= nil do
		client_color_log(217, 217, 217, " ", select(argIndex, ...), "\0")
		argIndex = argIndex + 1
	end
	client_color_log(217, 217, 217, " ") -- this is needed to end the line
end

-------------------------------------------this block prints text to the csgo chat, fully pasted from duk <3

ffi.cdef [[
	typedef void***(__thiscall* FindHudElement_t_c_r)(void*, const char*);
	typedef void(__cdecl* ChatPrintf_t_c_r)(void*, int, int, const char*, ...);
]]

local gHud = '\xB9\xCC\xCC\xCC\xCC\x88\x46\x09'
local FindElement =
	'\x55\x8B\xEC\x53\x8B\x5D\x08\x56\x57\x8B\xF9\x33\xF6\x39\x77\x28'

local gHud_found = client.find_signature("client.dll", gHud) or
					   error("gHud not found")
local hud = ffi.cast("void**", ffi.cast("char*", gHud_found) + 1)[0] or
				error("hud is nil")

gHud_found = client.find_signature("client.dll", FindElement) or
				 error("FindHudElement not found")
local find_hud_element = ffi.cast("FindHudElement_t_c_r", gHud_found)
local hudchat = find_hud_element(hud, "CHudChat") or error("CHudChat not found")

local chudchat_vtbl = hudchat[0] or error("CHudChat instance vtable is nil")
local print_to_chat = ffi.cast("ChatPrintf_t_c_r", chudchat_vtbl[27])

local colors = {}
colors.white = "\x01"
colors.red = "\x02"
colors.green = "\x04"

local function print_chat(color, text)
	print_to_chat(hudchat, 0, 0, ' \x08[ \x0b' .. script_name .. ' \x08] ' .. color .. text)
	lua_log(text)
end

------------------------------------------------------------------------------------


local url = "http://dook.ws/"
--this will be used as some kind of auth to make sure noone takes over another radar
local userAgentInfo = "gs_cloud_radar"
--stores the shareLink once a radar has been created
local shareLink = ""
--i like this, could be done with client_set_event_callback and unset, but i like this way
local running = false


--creates a new cloud radar instance on the server and prints out the share link
ui.new_button("LUA", "A", "Create cloud radar", function()
	if shareLink == "" then
		http.get(url .. "create", {user_agent_info = userAgentInfo},
		function(success, response)
				if success and response and response.body then
					shareLink = url .. "?auth=" .. response.body:sub(1, 16)
					print_chat(colors.green, "Created cloud radar. Link: " .. shareLink)
					userAgentInfo = response.body:sub(17, 32)
					running = true
				else
					if response.timed_out then
						print_chat(colors.red,
								"Timed out while trying to create a cloud radar.")
					else
						print_chat(colors.red,
								"An unknown error accoured while creating the cloud radar.")
					end
				end
		end)
	else
		print_chat(colors.white, "You already created a cloud radar. Link: " .. shareLink)
	end
end)

--destroys the cloud radar which also disables the link from getting updated
ui.new_button("LUA", "A", "Destroy cloud radar", function()
	http.get(url .. "destroy", {user_agent_info = userAgentInfo},
			 function(success, response)
		if success and response and response.body then
			print_chat(colors.green, "Destroyed cloud radar.")
			userAgentInfo = "gs_cloud_radar"
			shareLink = ""
			running = false
		else
			if response.timed_out then
				print_chat(colors.red,
						   "Timed out while trying to destroy a cloud radar.")
			else
				print_chat(colors.red,
						   "An unknown error accoured while destroying the cloud radar.")
			end
		end
	end)
end)

--this will most likely be removed
local updateInterval = ui.new_slider("LUA", "A", "[CR] Update rate", 1, 255, 63, true, "", 1, nil)

--spoofes the steamid of every entity to look like a bot to make sure i don't know which steamaccouns use my lua
local spoofSteamId = ui.new_checkbox("LUA", "A", "[CR] Spoof steamid")

--spoofes the player name
local spoofPlayerName = ui.new_checkbox("LUA", "A", "[CR] Spoof player name")

--shows the current state with an indicator
local showStatus = ui.new_checkbox("LUA", "A", "[CR] Show status")

local restoreRadar = ui.new_checkbox("LUA", "A", "[CR] Restore last radar")

local experimentalFeatures = ui.new_checkbox("LUA", "A", "[CR] buggy stuff")

--updates the entity-get_steam function
ui.set_callback(spoofSteamId, function()
	if ui_get(spoofSteamId) then 
		entity_get_steam64 = function(...)
			return "0"
		end
		print_chat(colors.white, "Enabled steamid spoofing")
	else
		entity_get_steam64 = entity.get_steam64
		print_chat(colors.white, "Disabled steamid spoofing")
	end
end)

--updates the entity-get-player-name function
ui.set_callback(spoofPlayerName, function()
	if ui_get(spoofPlayerName) then 
		entity_get_player_name = function(entIndex)
			return "player " .. entIndex
		end
		print_chat(colors.white, "Enabled name spoofing")
	else
		entity_get_player_name = entity.get_player_name
		print_chat(colors.white, "Disabled name spoofing")
	end
end)


--this makes sure the client never sends a new packet while waiting for the server response.
--this is important as this could lead to a very annoying delay on updates and has no gain at all imo
local sending = false
--stores the last tick we sent data to the server, this might get limited in the future
local last_sent_tick = 0
local last_sent_data = {}

--stores data of events for all entities
local event_data = {}
--used to prevent errors without much writing
local function insert_event_data(entIndex, event) 
	if event_data[entIndex] == nil then 
		event_data[entIndex] = {}
	end
	event_data[entIndex][#event_data[entIndex] + 1] = event
end

--i first thought about using paint_ui but there's no reason to do that
client.set_event_callback("paint", function()

	if ui_get(showStatus) then 
		renderer_indicator(64, 224, 208, 255, sending and "sending" or "waiting")
	end

	if running then
		-- Skipping ticks to reduce post requests
		if last_sent_tick + ui_get(updateInterval) < globals_tickcount() and not sending then
			last_sent_tick = globals_tickcount()

			local CCSPlayerResource = entity_get_player_resource()

			--this will get sent to the server
			local data = {}
			data[65] = globals_mapname()

			--bombInfo
			data[66] = {}
			local bomb_ent = nil
			if entity_get_all("CPlantedC4")[1] ~= nil then 
				data[66][1] = true
				data[66][2], data[66][3] = entity_get_prop(entity_get_all("CPlantedC4")[1], "m_vecOrigin")
			elseif entity_get_all("CC4")[1] ~= nil then 
				data[66][1] = false
				data[66][2], data[66][3] = entity_get_prop(entity_get_all("CC4")[1], "m_vecOrigin")

			else 
				data[66] = ""
			end

			--i'm using this way to loop through all players, even dormant ones
			for i = 1, 64 do 
				if entity_get_classname(i) == "CCSPlayer" then 
					player = {}
					--name
					player[1] = entity_get_player_name(i)
					--steam
					player[2] = entity_get_steam64(i)

					local x, y, z = entity_get_origin(i)

					--this stuff tries to get the worldPos where the player is looking at, this will fail on target we don't know the location of
					if (x ~= nil) then 
						z = z + 64 - entity_get_prop(i, "m_flDuckAmount")
						local pitch, yaw = entity_get_prop(i, "m_angEyeAngles")
						player[3] = x
						player[4] = y
						player[5] = z 

						do --i'm using this instead of just going for the 5000 in the first try due to it causing lag if people look into weird locations
							--this will probably decrease the overall performance as it causes way more trace line calls but reduces the lag spikes as it never tries to trace thourgh a lot of weird stuff
							local distance = 0
							local fraction = 1

							while fraction == 1 and distance < 5000 do 
								distance = distance + 100
								local facingX = x - math_cos(math_rad(yaw + 180)) * distance
								local facingY = y - math_sin(math_rad(yaw + 180)) * distance
								local facingZ = z - math_tan(math_rad(pitch)) * distance
		
								fraction = client_trace_line(i, x, y, z, facingX, facingY, facingZ)
							end

							player[6] = x - math_cos(math_rad(yaw + 180)) * distance * fraction
							player[7] = y - math_sin(math_rad(yaw + 180)) * distance * fraction
							--player[8] = z - math_tan(math_rad(pitch)) * distance * fraction
						end
					else
						player[3] = ""
						player[4] = ""
						player[5] = ""

						player[6] = ""
						player[7] = ""
						--player[8] = ""
					end
					
					player[8] = entity_is_dormant(i)

					player[9] = entity_get_prop(CCSPlayerResource, "m_iTeam", i)

					player[10] = entity_get_prop(CCSPlayerResource, "m_bAlive", i) == 1
					player[11] = entity_get_prop(CCSPlayerResource, "m_iHealth", i)
					player[12] = entity_get_prop(CCSPlayerResource, "m_iArmor", i) > 0
					player[13] = entity_get_prop(CCSPlayerResource, "m_bHasHelmet", i) == 1

					player[14] = entity_get_prop(CCSPlayerResource, "m_iPlayerC4") == i
					player[15] = entity_get_prop(CCSPlayerResource, "m_bHasDefuser", i) == 1

					if event_data[i] ~= nil then 
						player[16] = event_data[i]
					else
						player[16] = ""
					end

					data[i] = player
				else
					data[i] = ""
				end
			end

			if (data ~= last_sent_data) then
				last_sent_data = data
				sending = true
				http.post(url .. "update", {params = {["data"] = json_stringify(data)}, user_agent_info = userAgentInfo}, 
					function(success, response) 
						sending = false
					end
				)
				event_data = {}
			end

		else
			-- just making sure that the last tick is never greater than the actuall tick. This could happen after switching server as an example
			if last_sent_tick > globals_tickcount() then
				last_sent_tick = globals_tickcount()
			end
		end
	end
end)

client.set_event_callback("bullet_impact", function(e) 
	
	insert_event_data(client_userid_to_entindex(e.userid), 
		{
			0,
			e.x,
			e.y,
			e.z
		}
	)
end)

client.set_event_callback("player_hurt", function(e) 
	if ui_get(experimentalFeatures) then 
		insert_event_data(client_userid_to_entindex(e.userid), 
			{
				1,
				client_userid_to_entindex(e.attacker) or "",
				e.health,
				e.weapon or "",
				e.dmg_health
			}
		)
	end
end)

client.set_event_callback("item_purchase", function(e) 
	insert_event_data(client_userid_to_entindex(e.userid), 
		{
			2,
			e.weapon,
		}
	)
end)

client.set_event_callback("shutdown", function()
	if ui_get(restoreRadar) then 
		if userAgentInfo ~= "gs_cloud_radar" then 
			writefile("cr.lastRadar", client.unix_time() .. " " .. shareLink:sub(-16) .. " " .. userAgentInfo)
		end
	else
		writefile("cr.lastRadar", 0)
	end
end)

print_chat(colors.green, "Loaded successfully")


local times_called = 0

ui.set_callback(restoreRadar, function() 

	if ui_get(restoreRadar) then 
		print_chat(colors.white, "Enabled cloud radar restoring")
	else
		print_chat(colors.white, "Disabled cloud radar restoring")
	end

	if times_called == 0 then 
		if ui_get(restoreRadar) then 
			local lastRadar = readfile("cr.lastRadar")
			if lastRadar ~= nil then 
				if lastRadar == "0" then 
					return
				end
				local index = 1
				for i in lastRadar:gmatch("%S+") do 
					print("lastRadar " .. index)
					if index == 1 then --timestamp
						print(i)
						if client.unix_time() - i > 600 then --if it's older then 600s the radar got deleted anyway
							print_chat(colors.red, "Could not restore old cloud radar as it's too old.")
							return
						end
					elseif index == 2 then --link
						print(i)
						shareLink = url .. "?auth=" .. i
					elseif index == 3 then --uAI
						print(i)
						userAgentInfo = i
						print_chat(colors.white, "Found recent cloud radar data, will try to restore session.")
						http.get(url .. "restore", {user_agent_info = userAgentInfo}, 
							function(success, response) 
								if success then 
									if response and response.body then 
										if response.body == "Restored radar." then 
											print_chat(colors.green, "Restored your cloud radar. Link: " .. shareLink)
											running = true
										elseif response.body == "Couldn't find the requested radar." then 
											print_chat(colors.white, "Couldn't restore your cloud radar. It may got deleted.")
											shareLink = ""
											userAgentInfo = "gs_cloud_radar"
										else
											print(response.body)
											print_chat(colors.red, "An unknown error occurred white trying to restore the cloud radar.")
											shareLink = ""
											userAgentInfo = "gs_cloud_radar"
										end
									end
								else
									print_chat(colors.red, "Your request to restore the cloud radar timed out.")
									shareLink = ""
									userAgentInfo = "gs_cloud_radar"
								end
							end
						)
					end
					index = index + 1
				end
			end
		end
	end
	times_called = times_called + 1
end)