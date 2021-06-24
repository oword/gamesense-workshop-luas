-- VALORANT kill effects for Counter-Strike: Global Offensive, by nicole

-- Localized functions
local globals_realtime, globals_mapname = globals.realtime, globals.mapname

-- Libraries
local ffi = require "ffi"
local gif_decoder = require "gamesense/gif_decoder"
local http = require "gamesense/http"

-- Game definitions
local vftable_e =
{
	surface =
	{
		playsound = 82
	}
}

-- General enums
local http_status_code_e =
{
	ok = 200
}

-- FFI
-- https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/public/vgui/ISurface.h#L272
local ISurface__PlaySound = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", vftable_e.surface.playsound, "void (__thiscall*)(void* ecx, const char* sPath)")

-- Menu
local g_pMenuKillEffectsEnabled = ui.new_checkbox("VISUALS", "Effects", "VALORANT kill effects")

-- Constants
local ASSET_CDN = "https://aether.moe/gamesense"
local MAX_KILLS = 6

-- Globals
local g_nMissingFiles = 0
local g_nKills = 0
local g_flPlaybackStart = 0.0
local g_flPlayUntil = 0.0
local g_aBanners = nil
local g_anDisplayAtX = nil
local g_anDisplayAtY = nil

function on_player_death(e)
	local nLocalPlayer = entity.get_local_player()
	
	if client.userid_to_entindex(e.attacker) ~= nLocalPlayer or e.attacker == e.userid or g_nKills >= MAX_KILLS then
		return
	end

	g_nKills = g_nKills + 1

	-- Plays the sound
	ISurface__PlaySound(string.format("valorant_%d.wav", g_nKills))

	-- Displays the kill banner
	g_flPlaybackStart = globals.realtime()
	g_flPlayUntil = g_flPlaybackStart + g_aBanners[g_nKills].duration

	-- Specify where to play the kill banner
	g_anDisplayAtX, g_anDisplayAtY = client.screen_size()
	g_anDisplayAtX = g_anDisplayAtX / 2 -- Center
	g_anDisplayAtX = g_anDisplayAtX - g_aBanners[g_nKills].width / 2

	g_anDisplayAtY = g_anDisplayAtY * 0.9 -- 90%-ish of screen height
	g_anDisplayAtY = g_anDisplayAtY - g_aBanners[g_nKills].height
end

function on_player_spawn(e)
	local nLocalPlayer = entity.get_local_player()
	
	if client.userid_to_entindex(e.userid) ~= nLocalPlayer then
		return
	end

	reset_vars()
end

function on_paint_ui()
	local flRealTime = globals_realtime()

	if flRealTime < g_flPlayUntil and globals_mapname() ~= nil then
		local pBanner = g_aBanners[g_nKills]
		pBanner:draw(flRealTime - g_flPlaybackStart, g_anDisplayAtX, g_anDisplayAtY, pBanner.width, pBanner.height, 255, 255, 255, 255)
	end
end

function reset_vars()
	g_nKills = 0
	g_flPlaybackStart = 0.0
	g_flPlayUntil = 0.0
end

function set_callbacks(enable)
	local pFunc = enable and client.set_event_callback or client.unset_event_callback
	pFunc("player_death", on_player_death)
	pFunc("player_spawn", on_player_spawn)
	pFunc("paint_ui", on_paint_ui)

	if enable and g_aBanners == nil then
		if not load_files() then
			g_aBanners = nil
			ui.set(g_pMenuKillEffectsEnabled, false)
			client.error_log("Some assets could not be found. Attempting to retrieve them...")
		else
			client.log("VALORANT assets loaded.")
		end
	end
end

function on_menu_kill_effects_enabled_callback(ref)
	set_callbacks(ui.get(ref))
end

function download_file(path)
	http.get(string.format("%s/%s", ASSET_CDN, path), function(success, response)
		if not success or response.status ~= http_status_code_e.ok then
			client.error_log(string.format("Could not retrieve asset \"%s\" from server. Error code: %d", path, response.status))
	
			return
		end
	
		writefile(path, response.body)
		g_nMissingFiles = g_nMissingFiles - 1
		client.log(string.format("Successfully installed asset at path \"%s\".", path))

		-- Finished downloading everything, re-enable the checkbox for a smooth first-time installation..
		if g_nMissingFiles == 0 then
			client.log("VALORANT assets downloaded. Loading them.. this might take a while.")
			client.delay_call(globals.tickinterval(), ui.set, g_pMenuKillEffectsEnabled, true)
		end
	end)
end

function check_and_download(path)
	if not readfile(path) then
		g_nMissingFiles = g_nMissingFiles + 1
		download_file(path)
	end
end

function load_files()
	g_aBanners = {}
	g_nMissingFiles = 0

	for i = 1, MAX_KILLS do
		check_and_download(string.format("csgo/sound/valorant_%d.wav", i))
		check_and_download(string.format("csgo/materials/valorant_%d.gif", i))
	end

	if g_nMissingFiles == 0 then
		for i = 1, MAX_KILLS do
			g_aBanners[i] = gif_decoder.load_gif(readfile(string.format("csgo/materials/valorant_%d.gif", i)))
		end
	end

	return g_nMissingFiles == 0
end

ui.set_callback(g_pMenuKillEffectsEnabled, on_menu_kill_effects_enabled_callback)