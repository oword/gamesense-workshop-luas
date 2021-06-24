--------------------------------------------------------------------------------
-- Caching common functions
--------------------------------------------------------------------------------
local uix = require 'gamesense/uix'
local client_exec, client_system_time, client_userid_to_entindex, entity_get_local_player, entity_get_player_name, entity_get_prop, string_format, ui_get, ui_new_checkbox, ui_new_textbox, ui_set_callback, ui_set_visible = client.exec, client.system_time, client.userid_to_entindex, entity.get_local_player, entity.get_player_name, entity.get_prop, string.format, ui.get, ui.new_checkbox, ui.new_textbox, ui.set_callback, ui.set_visible

--------------------------------------------------------------------------------
-- Constants and variables
--------------------------------------------------------------------------------
local enable_ref
local message_ref

local message_tokens = {}
--------------------------------------------------------------------------------
-- Callback functions
--------------------------------------------------------------------------------
local function on_player_death(e)
	if client_userid_to_entindex(e.attacker) == entity_get_local_player() then
		local kill_message = ui_get(message_ref)
		for token, handler in pairs(message_tokens) do
			if kill_message:find(token) then
				kill_message = kill_message:gsub(token, handler(e))
			end
		end
		client_exec("say ", kill_message)
	end
end

local function on_kill_message_toggle(ref)
	local script_state = ui_get(ref)
	ui_set_visible(message_ref, script_state)
end

--------------------------------------------------------------------------------
-- Initilization code
--------------------------------------------------------------------------------
local function init_token(token, handler)
	message_tokens[token] = handler
end

local function init()
	init_token("$victim",   function(e) return entity_get_player_name(client_userid_to_entindex(e.userid)) end)
	init_token("$attacker", function(e) return entity_get_player_name(client_userid_to_entindex(e.attacker)) end)
	init_token("$weapon",   function(e) return e.weapon end)
	init_token("$location", function(e) return entity_get_prop(client_userid_to_entindex(e.userid), "m_szLastPlaceName") end)
	init_token("$time",	 function() return string_format("%d:%02d:%02d", client_system_time()) end)

	enable_ref  = uix.new_checkbox("LUA", "B", "Kill message")
	message_ref = ui_new_textbox("LUA", "B", "Message text")

	enable_ref:on("change", on_kill_message_toggle)
	enable_ref:on("player_death", on_player_death)
end

init()