local steamworks = require "gamesense/steamworks"
local ffi = require "ffi"

--
-- grab the interfaces and enums we want to use from the steamworks lib. this is not required, just cleans up the code a bit
--

local ISteamUserStats = steamworks.ISteamUserStats
local EResult = steamworks.EResult

--
-- use panorama js to format the unix timestamps
--

local format_unix_timestamp = panorama.loadstring([[
	return [(timestamp) => {
		var date = new Date(timestamp * 1000);
		return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${date.getMinutes()}:${date.getSeconds()}`
	}]
]])()[0]

--
-- collect all achievements
--

local all_achievements = {}

local count = ISteamUserStats.GetNumAchievements()
for i=0, count-1 do
	local name = ISteamUserStats.GetAchievementName(i)
	table.insert(all_achievements, {
		id = name,
		name = ISteamUserStats.GetAchievementDisplayAttribute(name, "name"),
		desc = ISteamUserStats.GetAchievementDisplayAttribute(name, "desc"),
		hidden = ISteamUserStats.GetAchievementDisplayAttribute(name, "hidden")
	})
end

-- our func to update the ui, defined below
local update_ui

-- called when we want to update the unlock data from steam, so on load and on UserStatsReceived_t / UserStatsStored_t events
local function update()
	for i, achievement in ipairs(all_achievements) do
		local success, achieved, unlock_time = ISteamUserStats.GetAchievementAndUnlockTime(achievement.id)

		if success then
			achievement.achieved = achieved
			achievement.unlock_time = unlock_time
			achievement.unlock_time_formatted = format_unix_timestamp(unlock_time)
		end
	end

	update_ui()
end

--
-- set steam callbacks: https://partner.steamgames.com/doc/api/ISteamUserStats#UserStatsReceived_t
--

steamworks.set_callback("UserStatsReceived_t", update)
steamworks.set_callback("UserStatsStored_t", update)

--
-- ui stuff
--

local achievement_list = {}
for i, achievement in ipairs(all_achievements) do
	achievement_list[i] = achievement.name
end

local enabled_reference = ui.new_checkbox("LUA", "B", "Steam Achievement Manager")
local achievement_reference = ui.new_listbox("LUA", "B", "Achievements", achievement_list)
local desc_reference = ui.new_label("LUA", "B", "No description")
local global_unlock_reference = ui.new_label("LUA", "B", "No global unlock percentage")
local unlocked_reference = ui.new_checkbox("LUA", "B", "Achievement unlocked")
local unlocked_at_reference = ui.new_label("LUA", "B", "Unlocked at")

ui.set_callback(enabled_reference, function()
	update_ui()

	if ui.get(enabled_reference) then
		-- grab data from steam on enable
		update()

		-- get global achievement stats (unlocked by x%)
		ISteamUserStats.RequestGlobalAchievementPercentages(function(res)
			-- this function is executed when the RequestGlobalAchievementPercentages completes. first check if it was successful
			if res.m_eResult == EResult.OK then
				local achievements_by_id, longest_id = {}, 0

				-- allocate a buffer long enough to hold the longest achievement id (+1 for the null byte at the end)
				-- also create a table mapping achievement id to the achievement
				for i, achievement in ipairs(all_achievements) do
					achievements_by_id[achievement.id] = achievement
					longest_id = math.max(longest_id, achievement.id:len()+1)
				end

				-- create our id buffer
				local id_buf = ffi.new("char[?]", longest_id)

				-- get first global unlock percentage achievement from steam. this func also returns the next id (for use with GetNextMostAchievedAchievementInfo)
				-- it also returns global unlock percentage and if we unlocked it (which we ignore)
				local i, percent, achieved = ISteamUserStats.GetMostAchievedAchievementInfo(id_buf, longest_id)

				while i ~= -1 do
					-- read ID buffer into a lua string
					local id = ffi.string(id_buf)

					-- update achievement
					if achievements_by_id[id] ~= nil then
						achievements_by_id[id].global_percent = percent
					end

					-- clear our id buffer (fill with 0)
					ffi.fill(id_buf, longest_id)

					-- grab next id and global % from steam
					i, percent, achieved = ISteamUserStats.GetNextMostAchievedAchievementInfo(i, id_buf, longest_id)
				end

				update_ui()
			end
		end)
	end
end)

local in_update = false
ui.set_callback(unlocked_reference, function()
	if in_update or not ui.get(enabled_reference) then
		return
	end

	local i = (ui.get(achievement_reference) or 0) + 1
	local achievement = all_achievements[i]

	if achievement ~= nil then
		local unlock = ui.get(unlocked_reference)

		-- either unlock or lock the achievement
		if unlock then
			ISteamUserStats.SetAchievement(achievement.id)
		else
			ISteamUserStats.ClearAchievement(achievement.id)
		end

		-- send stats to steam (and show unlock notification)
		ISteamUserStats.StoreStats()

		-- reset and wait for update by UserStatsReceived_t / UserStatsStored_t
		in_update = true
		ui.set(unlocked_reference, not unlock)
		in_update = false
	end
end)

local unlock_all_reference = ui.new_button("LUA", "B", "Unlock all", function()
	for i, achievement in ipairs(all_achievements) do
		if not achievement.achieved then
			ISteamUserStats.SetAchievement(achievement.id)
		end
	end

	ISteamUserStats.StoreStats()
end)

local lock_all_reference = ui.new_button("LUA", "B", "Lock all", function()
	for i, achievement in ipairs(all_achievements) do
		if achievement.achieved then
			ISteamUserStats.ClearAchievement(achievement.id)
		end
	end

	ISteamUserStats.StoreStats()
end)

function update_ui()
	in_update = true

	local enabled = ui.get(enabled_reference)

	if enabled then
		ui.set_visible(achievement_reference, true)
		ui.set_visible(desc_reference, true)
		ui.set_visible(unlocked_reference, true)
		ui.set_visible(unlock_all_reference, true)
		ui.set_visible(lock_all_reference, true)

		local i = (ui.get(achievement_reference) or 0) + 1
		local achievement = all_achievements[i]

		if achievement ~= nil then
			ui.set(unlocked_reference, achievement.achieved == true)
			ui.set(desc_reference, achievement.desc)

			ui.set_visible(global_unlock_reference, achievement.global_percent ~= nil)
			if achievement.global_percent ~= nil then
				ui.set(global_unlock_reference, string.format("Unlocked by %.1f%% of players", achievement.global_percent))
			end

			ui.set_visible(unlocked_at_reference, achievement.achieved and achievement.unlock_time_formatted ~= nil)
			if achievement.achieved and achievement.unlock_time_formatted ~= nil then
				ui.set(unlocked_at_reference, "Unlocked at " .. achievement.unlock_time_formatted)
			end
		else
			ui.set_visible(global_unlock_reference, false)
			ui.set_visible(unlocked_at_reference, false)
		end
	else
		ui.set_visible(achievement_reference, enabled)
		ui.set_visible(desc_reference, enabled)
		ui.set_visible(global_unlock_reference, enabled)
		ui.set_visible(unlocked_reference, enabled)
		ui.set_visible(unlocked_at_reference, enabled)

		ui.set_visible(unlock_all_reference, enabled)
		ui.set_visible(lock_all_reference, enabled)
	end

	in_update = false
end
ui.set_callback(achievement_reference, update_ui)

-- update ui on load
update_ui()