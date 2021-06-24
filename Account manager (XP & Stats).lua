local js = panorama.open()
local MyPersonaAPI = js.MyPersonaAPI
local PartyListAPI = js.PartyListAPI
local FriendsListAPI = js.FriendsListAPI
local MY_ID64 = MyPersonaAPI.GetXuid()
local table_gen = require "gamesense/table_gen"
local http = require 'gamesense/http'
local panorama_events = require "gamesense/panorama_events"
local hide_obs = ui.reference("MISC", "Settings", "Hide from OBS")
local accounts = {}
local headings = {"Name", "XP earned", "Bonus", "Level", "Rank", "Wins", "Prime", "Invite code", "Last seen", "Banned"}
local ranks = {"Silver 1", "Silver 2", "Silver 3", "Silver 4", "Silver Elite", "Silver Elite Master", "Gold Nova 1", "Gold Nova 2", "Gold Nova 3", "Gold Nova 4", "Master Guardian 1", "Master Guardian 2",
"Master Guardian Elite", "Distinguished Master Guardian", "Legendary Eagle", "Legendary Eagle Master", "Supreme Master First Class", "The Global Elite"
}
ranks[0] = "Unranked"

local js_api = panorama.loadstring([[
	function timeago(date) {
		var minute = 60;
		var hour   = minute * 60;
		var day    = hour   * 24;
		var date_n = new Date()
		var date_utc = Date.UTC(date_n.getUTCFullYear(), date_n.getUTCMonth(), date_n.getUTCDate(),date_n.getUTCHours(), date_n.getUTCMinutes(), date_n.getUTCSeconds());
		var elapsed = Math.floor((date_utc - date) / 1000);
		if (elapsed > 7*day) return true;
		else return false;
	}
	
	var _GetTimestamp = function() {
		return Date.now();
	}

	var _FormatTimestamp = function(timestamp) {
		var date = new Date(timestamp);
		return `${date.getMonth() + 1}/${date.getDate()}/${date.getFullYear()} ${date.getHours()}:${date.getMinutes()}`;
	}

	var _GetEvenLastWednesday = function() {
		var date = new Date();
		var new_date = new Date(date.setDate(date.getUTCDate()-date.getUTCDay()-4));
		return {year: new_date.getFullYear(), month: new_date.getMonth(), day: new_date.getDate()};
	}
	
	var _GetLastWednesday = function() {
		var date = new Date();
		var new_date = new Date(date.setDate(date.getUTCDate()-date.getUTCDay() + 3));
		return { year: new_date.getFullYear(), month: new_date.getMonth(), day: new_date.getDate()};
	}

	var _GetTodayUTC = function() {
		var date = new Date();
		return date.getUTCDay();
	}
	
	var _GetUTC = function(){
		var date = new Date()
		return {hours: date.getUTCHours(), minutes: date.getUTCMinutes()}
	}
	
	var _TimeAgo = function(year, month, day) {
		var date_received = new Date(year, month, day, 1, 0, 0)
		return timeago(date_received)
	}
	
	return {
		get_timestamp: _GetTimestamp,
		format_timestamp: _FormatTimestamp,
		get_day_of_the_week_UTC: _GetTodayUTC,
		get_last_wednesday: _GetLastWednesday,
		get_even_last_wednesday: _GetEvenLastWednesday,
		get_utc: _GetUTC,
		a_week_went_by: _TimeAgo
	}
]])()

-- Reset accounts function.
local function reset_xp_all()
	for ID64, _ in pairs(accounts) do
		accounts[ID64].bonus = "2x"
		accounts[ID64].initial_xp = accounts[ID64].actual_xp
		accounts[ID64].initial_level = accounts[ID64].actual_level
	end
	database.write("manager_reworked", accounts)
end

-- Check XP bonus.
local function bonus_check()
	if string.find(MyPersonaAPI.GetActiveXpBonuses(), "2") then
		return "2x"
	elseif string.find(MyPersonaAPI.GetActiveXpBonuses(), "1") then
		return "1x"
	elseif string.find(MyPersonaAPI.GetActiveXpBonuses(), "3") then
		return "REDUCED"
	else
		return "NO"
	end
end

-- Create account table.
local function create_tbl(update)
	if not update then
		accounts[MY_ID64] = { 
			actual_xp = MyPersonaAPI.GetCurrentXp(),
			actual_level = MyPersonaAPI.GetCurrentLevel(),
			initial_level = MyPersonaAPI.GetCurrentLevel(),
			initial_xp = MyPersonaAPI.GetCurrentXp(),
			rank = MyPersonaAPI.GetCompetitiveRank(),
			wins = MyPersonaAPI.GetCompetitiveWins(),
			invite_code = MyPersonaAPI.GetFriendCode(),
			banned = FriendsListAPI.GetFriendIsVacBanned(MY_ID64) and "YES" or "NO",
			last_seen = js_api.format_timestamp(js_api.get_timestamp()),
			prime = PartyListAPI.GetFriendPrimeEligible(MY_ID64) and "YES" or "NO",
			bonus = bonus_check(),
			custom_name = false,
			xp = 0
		}
	elseif accounts[MY_ID64] then
		accounts[MY_ID64].name = MyPersonaAPI.GetName()
		accounts[MY_ID64].actual_xp = MyPersonaAPI.GetCurrentXp()
		accounts[MY_ID64].actual_level = MyPersonaAPI.GetCurrentLevel()
		accounts[MY_ID64].rank = MyPersonaAPI.GetCompetitiveRank()
		accounts[MY_ID64].wins = MyPersonaAPI.GetCompetitiveWins()
		accounts[MY_ID64].bonus = bonus_check()
		accounts[MY_ID64].last_seen = js_api.format_timestamp(js_api.get_timestamp())
		accounts[MY_ID64].prime = PartyListAPI.GetFriendPrimeEligible(MY_ID64) and "YES" or "NO"
		accounts[MY_ID64].banned = FriendsListAPI.GetFriendIsVacBanned(MY_ID64) and "YES" or "NO"
	end
	database.write("manager_reworked", accounts)
end

-- Check database on load.
local function check()
	if database.read("manager_reworked") == nil then
		create_tbl(false)
	else
		accounts = database.read("manager_reworked")
		for ID64, _ in pairs(accounts) do
			if ID64 == MY_ID64 then
				return
			end
		end
		create_tbl(false)
	end
end
check()

-- Check banned players.
local function check_banned()
	for ID64, _ in pairs(accounts) do
		http.get("https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key=E9EA79BB465366C98E5BAF31EC8A6F31&steamids=" .. ID64, function(success, response)
			if not success or response.status ~= 200 then return end
			local jsonData = json.parse(response.body)
			if jsonData and #jsonData.players > 0 then
				local player = jsonData.players[1]
				accounts[ID64].banned = (player.NumberOfVACBans > 0 and player.NumberOfGameBans > 0) and "YES" or "NO"
			end
		end)
	end
	database.write("manager_reworked", accounts)
end
check_banned()

-- Calculate XP earned function.
local function calculate_xp(initial_level, initial_xp, actual_level, actual_xp, ID64)
	if initial_level == actual_level then
		return actual_xp - initial_xp
	elseif initial_level < actual_level then
		return (5000*(actual_level - initial_level) - initial_xp) + actual_xp
	elseif initial_level > actual_level then
		accounts[ID64].initial_level = accounts[ID64].actual_level
		accounts[ID64].initial_xp = accounts[ID64].actual_xp
		database.write("manager_reworked", accounts)
		return 0
	end
end

-- Table printing function
local function manager_printing(output)
	create_tbl(true)
	local array = {}
	for ID64, _ in pairs(accounts) do
		local acc = accounts[ID64]
		acc.xp = calculate_xp(acc.initial_level, acc.initial_xp, acc.actual_level, acc.actual_xp, ID64)
		array[#array+1] = {acc.custom_name or acc.name, tostring(acc.xp) .. " XP", acc.bonus, acc.actual_level, ranks[acc.rank], acc.wins, acc.prime, acc.invite_code, acc.last_seen, acc.banned}
	end
	local table_out = table_gen(array, headings, {style = "Unicode (Single Line)"})
	if database.read("manager_output") then
		writefile("acc_manager.txt", table_out)
	end
	if ui.get(hide_obs) then return end
	if output then return end
	client.color_log(20, 255, 20, "[Account manager]")
	client.color_log(255, 255, 255, table_out)
end

-- Table printing button.
local print_accs = ui.new_button("MISC", "Settings", "Account manager", function()
	manager_printing(false)
end)

-- Create output if enabled.
if database.read("manager_output") then
	manager_printing(true)
end

-- Date checking function.
local function check_reset_xp_bonus()
	if type(database.read("reset_day")) ~= "table" then
		local day_of_week = js_api.get_day_of_the_week_UTC()
		if day_of_week >= 3 then
			local date_tbl = js_api.get_last_wednesday()
			database.write("reset_day", {year = date_tbl.year, month = date_tbl.month, day = date_tbl.day})
			reset_xp_all()
		else
			local date_tbl = js_api.get_even_last_wednesday()
			database.write("reset_day", {year = date_tbl.year, month = date_tbl.month, day = date_tbl.day})
			reset_xp_all()
		end
	else
		local date_tbl = database.read("reset_day")
		if js_api.a_week_went_by(date_tbl.year, date_tbl.month, date_tbl.day) then
			local day_of_week = js_api.get_day_of_the_week_UTC()
			if day_of_week >= 3 then
				local last_wednesday = js_api.get_last_wednesday()
				database.write("reset_day", {year = last_wednesday.year, month = last_wednesday.month, day = last_wednesday.day})
				reset_xp_all()
			else
				local last_wednesday = js_api.get_even_last_wednesday()
				database.write("reset_day", {year = last_wednesday.year, month = last_wednesday.month, day = last_wednesday.day})
				reset_xp_all()
			end
			if ui.get(hide_obs) then return end
			client.color_log(20, 255, 20, "[Account manager] XP bonus is back boys!")
		end
	end
end
check_reset_xp_bonus()

-- Console commands
client.set_event_callback("console_input", function(input)
	if not ui.get(hide_obs) then
		if input:sub(1, 14) == "manager_delete" then
			if #input:sub(16, #input) > 15 then
				local received_ID64 = input:sub(16, #input)
				for ID64, _ in pairs(accounts) do
					if ID64 == received_ID64 then
						accounts[ID64] = nil
						client.color_log(20, 255, 20, "[Account manager] Account deleted.")
					end
				end
				client.color_log(240, 20, 20, "[Account manager] ID64 not found.")
			end
			return true
		elseif input:sub(1, 14) == "manager_rename" then
			if input:sub(16, #input) ~= "" then
				if accounts[input:sub(16, 32)] then
					if input:sub(34, #input) ~= "" then
						accounts[input:sub(16, 32)].custom_name = input:sub(34, #input)
						client.color_log(20, 255, 20, "[Account manager] Custom name set for " .. input:sub(16, 32))
						create_tbl(true)
					else
						client.color_log(240, 20, 20, "[Account manager] Please define a name for " .. input:sub(16, 32))
					end
				elseif accounts[MY_ID64] then
					accounts[MY_ID64].custom_name = input:sub(16, #input)
					create_tbl(true)
					client.color_log(20, 255, 20, "[Account manager] Custom name set.")
				end
			elseif accounts[MY_ID64] then
				client.color_log(240, 20, 20, "[Account manager] Please define a name for this account.")
			else
				client.color_log(240, 20, 20, "[Account manager] Account doesn't exist in your database.")
			end
			return true
		elseif input:sub(1, 12) == "manager_list" then
			local ids_array = {}
			for ID64, _ in pairs(accounts) do
				local acc = accounts[ID64]
				ids_array[#ids_array+1] = {ID64, acc.custom_name or acc.name}
			end
			local table_out = table_gen(ids_array, {"ID64", "Name"}, {style = "Unicode (Single Line)"})
			client.color_log(20, 255, 20, "[Account manager]")
			client.color_log(255, 255, 255, table_out)
			return true
		elseif input:sub(1, 14) == "manager_output" then
			if not database.read("manager_output") then
				database.write("manager_output", true)
				client.color_log(20, 255, 20, "[Account manager] Output enabled.")
				return true
			else
				database.write("manager_output", false)
				client.color_log(20, 255, 20, "[Account manager] Output disabled.")
				return true
			end
		elseif input:sub(1, 13) == "manager_print" then
			manager_printing(false)
			return true
		end
	end
end)

-- Update on main menu.
panorama_events.register_event("CSGOShowMainMenu", function()
	check_reset_xp_bonus()
	create_tbl(true)
end)

-- Update on show content panel.
panorama_events.register_event("ShowContentPanel", function()
	check_reset_xp_bonus()
	create_tbl(true)
end)

-- Update on player updated.
panorama_events.register_event("PanoramaComponent_Lobby_PlayerUpdated", function()
	check_reset_xp_bonus()
	create_tbl(true)
end)

-- Update on match end.
client.set_event_callback("cs_win_panel_match", function()
	check_reset_xp_bonus()
	create_tbl(true)
end)

-- Update on shutdown.
client.set_event_callback("shutdown", function()
	create_tbl(true)
end)