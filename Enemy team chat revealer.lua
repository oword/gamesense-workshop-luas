local chat = require "gamesense/chat"
local localize = require "gamesense/localize"

local main = ui.new_checkbox("MISC", "Miscellaneous", "Reveal enemy teamchat")

local GameStateAPI = panorama.open().GameStateAPI

local lastChatMessage = {}

local function onPlaySay(e)
	local sender = client.userid_to_entindex(e.userid)
	if not entity.is_enemy(sender) then return end

	if GameStateAPI.IsSelectedPlayerMuted(GameStateAPI.GetPlayerXuidStringFromEntIndex(sender)) then return end

	client.delay_call(0.2, function()
		if lastChatMessage[sender] ~= nil and math.abs(globals.realtime() - lastChatMessage[sender]) < 0.4 then
			return
		end


		local enemyTeamName = entity.get_prop(entity.get_player_resource(), "m_iTeam", sender) == 2 and "T" or "CT"

		local placeName = entity.get_prop(sender, "m_szLastPlaceName")
		local enemyName = entity.get_player_name(sender)
		
		local localizeStr = ("Cstrike_Chat_%s_%s"):format(enemyTeamName, entity.is_alive(sender) and "Loc" or "Dead")
		local msg = localize(localizeStr, {
			s1 = enemyName,
			s2 = e.text,
			s3 = localize(placeName ~= "" and placeName or "UI_Unknown")
		})

		chat.print_player(sender, msg)
	end)
end

local function onPlayChat(e)
	if not entity.is_enemy(e.entity) then return end
	lastChatMessage[e.entity] = globals.realtime()
end

ui.set_callback(main, function()
	local update_callback = ui.get(main) and client.set_event_callback or client.unset_event_callback
	update_callback("player_say", onPlaySay)
	update_callback("player_chat", onPlayChat)
end)

-- peace
-- love
-- unity
-- respect