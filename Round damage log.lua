local chat = require "gamesense/chat"
local ui_get = ui.get

local colorList = {
	"Red",
	"Dark Red",
	"Light Red",
	"Violet",
	"Purple",
	"Blue",
	"Dark Blue",
	"Blue-Grey",
	"Green",
	"Light Green",
	"Lime",
	"Yellow",
	"Orange",
	"White",
	"Grey"
}


local colors = {}
for i, v in pairs(colorList) do
	colors[v] = "{" .. v:gsub("[ %-]", ""):lower() .. "}"
end

local main = ui.new_checkbox("MISC", "Miscellaneous", "Chat damage logging")
local prefix = ui.new_textbox("MISC", "Miscellaneous", "Custom prefix")
local primaryColor = ui.new_combobox("MISC", "Miscellaneous", "Custom colors", colorList)
local secondaryColor = ui.new_combobox("MISC", "Miscellaneous", "\nCustom color 2", colorList)

ui.set(primaryColor, "Green")
ui.set(secondaryColor, "Green")
ui.set(prefix, database.read("roundDamageLogJessica") or "FACEIT^")

ui.set_visible(prefix, false)
ui.set_visible(primaryColor, false)
ui.set_visible(secondaryColor, false)

local damage_taken = {}
local damage_given = {}

local function getEnemies()
	local player_resource = entity.get_player_resource()
	local list = {}
	for player=1, globals.maxplayers() do
		if entity.get_prop(player_resource, "m_bConnected", player) == 1 and entity.is_enemy(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function reset()
	table.clear(damage_taken)
	table.clear(damage_given)
end

local function hurt(e)
    local attacker = client.userid_to_entindex(e.attacker)
    local player = client.userid_to_entindex(e.userid)
    local local_player = entity.get_local_player()

    local taken = player == local_player
    local other = taken and attacker or player

    if entity.is_enemy(other) and (taken and player or attacker) == local_player then
        local tbl = taken and damage_taken or damage_given
        tbl[other] = tbl[other] or {}

        tbl[other].damage = (tbl[other].damage or 0) + e.dmg_health
        tbl[other].count = (tbl[other].count or 0) + 1
    end
end


local function fmtPart(name, tbl, pc, sc)
	return string.format("%s%s: [%s%d / %d hits%s]", sc, name, pc, tbl.damage or 0, tbl.count or 0, sc)
end

local function printData()
	client.delay_call(0.2, function()
		local prefix = ui.get(prefix)

		for _, player in ipairs(getEnemies()) do
			local hp = (entity.get_esp_data(player) or {}).health or 0

			local pc = colors[ui.get(primaryColor)]
			local sc = colors[ui.get(secondaryColor)]

			local str = string.format("%s[%s%s%s] %s %s %s- %s%s %s(%s%d hp%s)",
				sc, pc, prefix, sc,
				fmtPart("To", damage_given[player] or {}, pc, sc),
				fmtPart("From", damage_taken[player] or {}, pc, sc),
				sc, sc, entity.get_player_name(player),
				sc, pc, hp, sc)

			chat.print(str)
		end

		reset()
	end)
end

local function onShutDown()
	database.write("roundDamageLogJessica", ui_get(prefix))
end

ui.set_callback(main, function()
	local enabled = ui.get(main)

	local update_callback = enabled and client.set_event_callback or client.unset_event_callback
	update_callback("player_hurt", hurt)
	update_callback("round_end", printData)
	update_callback("level_init", reset)
	update_callback("shutdown", onShutDown)

	ui.set_visible(prefix, enabled)
	ui.set_visible(primaryColor, enabled)
	ui.set_visible(secondaryColor, enabled)

	if not enabled then
		reset()
	end
end)

-- peace
-- love
-- unity
-- respect