local surface = require "gamesense/surface" or error('gamesense/surface library is required')
local http = require "gamesense/http" or error('gamesense/http library is required')
local images = require "gamesense/images" or error('gamesense/images library is required')
local inspect = require "gamesense/inspect"
local ffi = require "ffi"

local database_read = database.read
local database_write = database.write
local package_searchpath = package.searchpath
local ui_set_callback = ui.set_callback
local ui_set_visible = ui.set_visible
local ui_get = ui.get
local ui_set = ui.set
local ui_new_label = ui.new_label
local ui_new_button = ui.new_button
local ui_new_checkbox = ui.new_checkbox
local ui_new_combobox = ui.new_combobox
local ui_new_slider = ui.new_slider
local ui_new_color_picker = ui.new_color_picker
local ui_new_hotkey = ui.new_hotkey
local ui_new_multiselect = ui.new_multiselect
local ui_menu_position = ui.menu_position
local entity_get_local_player = entity.get_local_player
local entity_get_prop = entity.get_prop
local last_update = client.unix_time()
local last_update_controls = client.unix_time()
local last_update_error = client.unix_time()
local last_update_volume = globals.tickcount()
local last_update_volume_press = globals.tickcount()
local last_update_volume_set = globals.tickcount()
local last_update_server = client.unix_time()
local last_tick = globals.tickcount()
local sx, sy = client.screen_size()

MenuScaleX = 4.8
MenuScaleY = 10.8
ScaleTitle = 41.54
ScaleArtist = 63.53
ScaleDuration = 57

local TitleFont = surface.create_font("GothamBookItalic", sy/ScaleTitle, 900, 0x010)
local ArtistFont = surface.create_font("GothamBookItalic", sy/ScaleArtist, 600, 0x010)
local TitleFontHUD = surface.create_font("GothamBookItalic", 25, 900, 0x010)
local ArtistFontHUD = surface.create_font("GothamBookItalic", 20, 600, 0x010)
local DurationFont = surface.create_font("GothamBookItalic", sy/ScaleDuration, 600, 0x010)
local DurationFontHUD = surface.create_font("GothamBookItalic", 12, 900, 0x010)
local MainElementFontHUD = surface.create_font("GothamBookItalic", 18, 600, 0x010)
local PlayListFontHUD = surface.create_font("GothamBookItalic", 18, 500, 0x010)
local SubtabTitleHUD = surface.create_font("GothamBookItalic", 30, 500, 0x010)
local SubtabRowFontHUD = surface.create_font("GothamBookItalic", 23, 500, 0x010)
local SubtabRowFontHUD2 = surface.create_font("GothamBookItalic", 17, 500, 0x010)
local SubtabTrackFontHUD2 = surface.create_font("GothamBookItalic", 19, 800, 0x010)
local SubtabArtistFontHUD2 = surface.create_font("GothamBookItalic", 12, 500, 0x010)
local SubtabRowFontHUD3 = surface.create_font("GothamBookItalic", 24, 500, 0x010)

local VolumeFont = surface.create_font("GothamBookItalic", sy/ScaleTitle, 900, 0x010)

local MainCheckbox = ui.new_checkbox("MISC", "Miscellaneous", "Spotify")
local MenukeyReference = ui.reference("MISC", "Settings", "Menu key")

local SpotifyIndicX = database_read("previous_posX") or 0
local SpotifyIndicY = database_read("previous_posY") or 1020
local SizePerc = database_read("previous_size") or 30
local apikey = database_read("StoredKey") or nil
local refreshkey = database_read("StoredKey2") or nil

ffi.cdef[[
	typedef bool (__thiscall *IsButtonDown_t)(void*, int);
	typedef int (__thiscall *GetAnalogValue_t)(void*, int);
	typedef int (__thiscall *GetAnalogDelta_t)(void*, int);
	typedef void***(__thiscall* FindHudElement_t)(void*, const char*);
	typedef void(__cdecl* ChatPrintf_t)(void*, int, int, const char*, ...);
]]

local native_GetClipboardTextCount = vtable_bind("vgui2.dll", "VGUI_System010", 7, "int(__thiscall*)(void*)")
local native_GetClipboardText = vtable_bind("vgui2.dll", "VGUI_System010", 11, "int(__thiscall*)(void*, int, const char*, int)")
local new_char_arr = ffi.typeof("char[?]")
local interface_ptr = ffi.typeof('void***')
local raw_inputsystem = client.create_interface('inputsystem.dll', 'InputSystemVersion001')
local inputsystem = ffi.cast(interface_ptr, raw_inputsystem)
local input_vmt = inputsystem[0]
local raw_IsButtonDown = input_vmt[15]
local raw_GetAnalogValue = input_vmt[18]
local raw_GetAnalogDelta = input_vmt[19]
local IsButtonDown = ffi.cast('IsButtonDown_t', raw_IsButtonDown)
local GetAnalogValue = ffi.cast('GetAnalogValue_t', raw_GetAnalogValue)
local GetAnalogDelta = ffi.cast('GetAnalogDelta_t', raw_GetAnalogDelta)
local signature_gHud = "\xB9\xCC\xCC\xCC\xCC\x88\x46\x09"
local signature_FindElement = "\x55\x8B\xEC\x53\x8B\x5D\x08\x56\x57\x8B\xF9\x33\xF6\x39\x77\x28"
local match = client.find_signature("client_panorama.dll", signature_gHud) or error("sig1 not found")
local hud = ffi.cast("void**", ffi.cast("char*", match) + 1)[0] or error("hud is nil")
match = client.find_signature("client_panorama.dll", signature_FindElement) or error("FindHudElement not found")
local find_hud_element = ffi.cast("FindHudElement_t", match)
local hudchat = find_hud_element(hud, "CHudChat") or error("CHudChat not found")
local chudchat_vtbl = hudchat[0] or error("CHudChat instance vtable is nil")
local print_to_chat = ffi.cast("ChatPrintf_t", chudchat_vtbl[27])

local function print_chat(text)
	print_to_chat(hudchat, 0, 0, text)
end

local mouse_state = {}

retardedJpg = false
dragging = false
Authed = false
CornerReady = false
ControlCheck = false
AuthClicked = false
SongChanged = false
VolumeMax = false
VolumeMin = false
VolumeCheck = false
FirstPress = false
RunOnceCheck = false
StopSpamming = false
SetCheck = true
forkinCock = true
bool = true
gropeTits = true
animCheck = false
ShuffleState = false
UpdateWaitCheck = false
kanker = false
MenuBarExtended = false
SearchSelected = false
PlaylistSelected = false
PlaylistLimitReached = false
scrollmin = true
scrollmax = false
SongTooLong = false

SpotifyScaleX = sx/4.8
SpotifyScaleY = sy/10.8
SpotifyIndicX2 = 1
adaptivesize = 400
ArtScaleX, ArtScaleY = SpotifyScaleY, SpotifyScaleY
UpdateCount = 0
ClickSpree = 0
ClickSpreeTime = 1
TotalErrors = 0
ErrorSpree = 0
NewApiKeyRequest = 0
AlteredVolume = 0
NewVolume = 0
AnimSizePerc = 100
ProgressBarCache = 0
PlayListCount = 0
TrackCount = 0
scrollvalue = 0
last_analogvalue = 0

CurrentSong = "-"
AuthStatus = "> Not connected"
deviceid = ""
UserName = "-"
SongName = "-"
ArtistName = "-"
SongNameHUD = "-"
ArtistNameHUD = "-"
SongProgression = "-"
SongLength = "-"
ProgressDuration = "-"
TotalDuration = "-"
LeftDuration = "-"
SongNameBack = "-"
HoveringOver = "none"
RepeatState = "off"
loadanim = "."
AuthURL = "https://spotify.stbrouwers.cc/"

local LoopUrl = "https://i.imgur.com/wREhluX.png"
local LoopActiveUrl = "https://i.imgur.com/rEEvjzM.png"
local ShuffleUrl = "https://i.imgur.com/8hjJTCO.png"
local ShuffleActiveUrl = "https://i.imgur.com/HNVpf4j.png"
local VolumeSpeakerUrl = "https://i.imgur.com/rj2IJfJ.png"

local function CP()
	local len = native_GetClipboardTextCount()
	if len > 0 then
	  local char_arr = new_char_arr(len)
	  native_GetClipboardText(0, char_arr, len)
	  return ffi.string(char_arr, len-1)
	end
end

local function splitByChunk(text, chunkSize)
	local s = {}
	for i=1, #text, chunkSize do
		s[#s+1] = text:sub(i,i+chunkSize - 1)
	end
	return s
end

function mouse_state.new()
	return setmetatable({tape = 0, laststate = 0, initd = false, events = {}}, {__index = mouse_state})
end
local scrollstate = mouse_state.new()

function mouse_state:init()
	if not self.init then
		self.tape = 0
		self.laststate = GetAnalogDelta(inputsystem, 0x03)
		self.initd = true
	end
	if GetAnalogDelta(inputsystem, 0x03) == 0 and self.tape ~= 0 then
		self.tape = 0
		return
	end
	local currentTape = GetAnalogValue(inputsystem, 0x03)
	if currentTape > self.tape then
		for index, value in ipairs(self.events) do
			value({state = "Up", pos = currentTape})
		end
		self.tape = currentTape
	elseif currentTape < self.tape then
		for index, value in ipairs(self.events) do
			value({state = "Down", pos = currentTape})
		end
		self.tape = currentTape
	end

	if GetAnalogValue(inputsystem, 0x03) >= last_analogvalue + 1 and not scrollmin then
		scrollvalue = scrollvalue + 1
	elseif GetAnalogValue(inputsystem, 0x03) <= last_analogvalue - 1 and not scrollmax then
		scrollvalue = scrollvalue - 1
	end
	last_analogvalue = GetAnalogValue(inputsystem, 0x03)
end


http.get(LoopUrl, function(success, response)
	if not success or response.status ~= 200 then
	  return
	end
	Loop = images.load_png(response.body)
end)

http.get(LoopActiveUrl, function(success, response)
	if not success or response.status ~= 200 then
	  return
	end
	LoopA = images.load_png(response.body)
end)

http.get(ShuffleUrl, function(success, response)
	if not success or response.status ~= 200 then
	  return
	end
	Shuffle = images.load_png(response.body)
end)

http.get(ShuffleActiveUrl, function(success, response)
	if not success or response.status ~= 200 then
	  return
	end
	ShuffleA = images.load_png(response.body)
end)

http.get(VolumeSpeakerUrl, function(success, response)
	if not success or response.status ~= 200 then
	  return
	end
	VolumeSpeaker = images.load_png(response.body)
end)

currplaylist = {}

if database_read("previous_posX") == nil then
	database_write("previous_posX", SpotifyIndicX)
	database_write("previous_posY", SpotifyIndicY)
else
	if database_read("previous_posX") >= sx + 3 then
		SpotifyIndicX = 0
		SpotifyIndicY = 1020
	end
end

Playlistcache = database_read("playlistcache")

if database_read("savedplaylists") == nil then
	Playlists = {}
	Playlistcache = ""
else
	Playlists = database_read("savedplaylists")
	for i, id in ipairs(Playlists) do
		PlayListCount = PlayListCount + 1
	end
end

switch = function(check)										
	return function(cases)
		if type(cases[check]) == "function" then
			return cases[check]()
		elseif type(cases["default"] == "function") then
			return cases["default"]()
		end
	end
end

local msConversion = function(b)
	local c=math.floor(b/1000)
	local d=math.floor(c/3600)
	local c=c-d*3600;
	local e=math.floor(c/60)
	local c='00'..c-e*60;
	local c=c:sub(#c-1)
	if d>0 then 
		local e=''..e;
		local e=('00'..e):sub(#e+1)
		return d..':'..e..':'..c 
	else 
		return e..':'..c 
	end 
end

function round(n)
	return n % 1 >= 0.5 and math.ceil(n) or math.floor(n)
end

local function GetRefreshToken() 
	if AuthClicked == false then return end
	local js = panorama.loadstring([[
		return {
		  open_url: function(url){
			SteamOverlayAPI.OpenURL(url)
		  }
		}
		]])()
	  js.open_url(AuthURL) 
end

function GetApiToken() 
	if NewApiKeyRequest <= 5 then
		if PendingRequest then return end
		PendingRequest = true
		if AuthClicked == true then
			AuthStatus = "TRYING"
		end
		http.get("https://spotify.stbrouwers.cc/refresh_token?refresh_token="..refreshkey, function(s, r)
			if r.status ~= 200 then
				AuthStatus = "WRONGKEY"
				PendingRequest = false
				GetRefreshToken()
				NewApiKeyRequest = NewApiKeyRequest + 1
			return
			else
				PendingRequest = false
				NewApiKeyRequest = 0
				parsed = json.parse(r.body)
				apikey = parsed.access_token
				Auth()
			end
		end)
	else
		return
	end
end

function Auth()
	if AuthClicked == true then refreshkey = CP() end
	if refreshkey == nil then GetRefreshToken() return end
	if refreshkey ~= nil and apikey == nil then
		GetApiToken()
		return end
	if refreshkey ~= nil and apikey ~= nil then
		http.get("https://api.spotify.com/v1/me?&access_token=" .. apikey, function(success, response)
			ConnectionStatus = response.status
			if not success or response.status ~= 200 then
				ConnectionStatus = response.status
				Authed = false
				AuthStatus = "FAILED"
				GetApiToken()
				ShowMenuElements()
				UpdateElements()
			return end
				UpdateCount = UpdateCount + 1
				spotidata = json.parse(response.body)
				UserName = spotidata.display_name
				Authed = true
				AuthStatus = "SUCCESS"
				ShowMenuElements()
				UpdateElements()
		end)
	end
end
Auth()

function DAuth() 
		if not ConnectionStatus then return end
		if ConnectionStatus == 202 then
			AuthStatus = "SUCCESS"
		end

		if ConnectionStatus == 403 then
			AuthStatus = "FORBIDDEN"
			ErrorSpree = ErrorSpree + 1
			TotalErrors = TotalErrors + 1
		end

		if ConnectionStatus == 429 then
			AuthStatus = "RATE"
			ErrorSpree = ErrorSpree + 1
			TotalErrors = TotalErrors + 1
		end

		if ConnectionStatus == 503 then
			AuthStatus = "APIFAIL"
			ErrorSpree = ErrorSpree + 1
			TotalErrors = TotalErrors + 1
		end

	ShowMenuElements()
	UpdateElements()
end

function UpdateInf()
	SongNameBack = SongName
	if UpdateWaitCheck == false then
		DAuth() 
		http.get("https://api.spotify.com/v1/me/player?access_token=" .. apikey, function(success, response)
			if not success or response.status ~= 200 then
				AuthStatus = "TOKEN"
				ErrorSpree = ErrorSpree + 1
				TotalErrors = TotalErrors + 1
				UpdateWaitCheck = true
				return 
			end
			CurrentDataSpotify = json.parse(response.body)
			if CurrentDataSpotify == nil then return end
			deviceid = CurrentDataSpotify.device.id

			if RunOnceCheck == false then
				NewVolume = CurrentDataSpotify.device.volume_percent
				RunOnceCheck = true
			end

			if CurrentDataSpotify.is_playing and CurrentDataSpotify.currently_playing_type == "episode"  then
				SongName = "Podcast"
				ArtistName = ""
				PlayState = "Playing"
			elseif CurrentDataSpotify.is_playing then
				SongName = CurrentDataSpotify.item.name
				SongNameHUD = CurrentDataSpotify.item.name
				ArtistName = CurrentDataSpotify.item.artists[1].name
				ArtistNameHUD = CurrentDataSpotify.item.artists[1].name
				Currenturi = CurrentDataSpotify.item.uri
				PlayState = "Playing"
			else
				SongName = "Music paused"
				PlayState = "Paused"
				ArtistName = ""
			end
			
			SongLength = CurrentDataSpotify.item.duration_ms / 1000
			SongProgression = CurrentDataSpotify.progress_ms / 1000
			ShuffleState = CurrentDataSpotify.shuffle_state
			RepeatState = CurrentDataSpotify.repeat_state
			ProgressBarCache = CurrentDataSpotify.progress_ms
			VolumeBarCache = CurrentDataSpotify.device.volume_percent

			TotalDuration = msConversion(CurrentDataSpotify.item.duration_ms)
			ProgressDuration = msConversion(CurrentDataSpotify.progress_ms)
			LeftDuration = msConversion(CurrentDataSpotify.item.duration_ms - CurrentDataSpotify.progress_ms)
			if not CurrentDataSpotify.item.is_local then
				ThumbnailUrl = CurrentDataSpotify.item.album.images[1].url
				http.get(ThumbnailUrl, function(success, response)
					if not success or response.status ~= 200 then
					  return
					end
				Thumbnail = images.load_jpg(response.body)
				end)
			end
			if SongNameBack ~= SongName and SongNameBack ~= nil then
				SpotifyIndicX2 = SpotifyIndicX+adaptivesize
				SongChanged = true
			end
		end)
	end
	UpdateWaitCheck = false
end

function PlayPause()

	local options = {
		headers = {
			["Accept"] = "application/json",
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. apikey,
			["Content-length"] = 0
		}
	}

	if CurrentDataSpotify.is_playing then
		PlayState = "Paused"

		http.put("https://api.spotify.com/v1/me/player/pause?device_id=" .. deviceid, options, function(s, r)
			UpdateCount = UpdateCount + 1
			
		end)
	else
		PlayState = "Playing"

		http.put("https://api.spotify.com/v1/me/player/play?device_id=" .. deviceid, options, function(s, r)
			UpdateCount = UpdateCount + 1
			UpdateWaitCheck = true
		end)   
	end
end

function NextTrack()

	local options = {
		headers = {
			["Accept"] = "application/json",
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. apikey,
			["Content-length"] = 0
		}
	}

	http.post("https://api.spotify.com/v1/me/player/next?device_id=" .. deviceid, options, function(s, r)
		UpdateCount = UpdateCount + 1
	end)   
end

function PreviousTrack()

	local options = {
		headers = {
			["Accept"] = "application/json",
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. apikey,
			["Content-length"] = 0
		}
	}

	http.post("https://api.spotify.com/v1/me/player/previous?device_id=" .. deviceid, options, function(s, r)
		UpdateCount = UpdateCount + 1
	end)   
end

function ShuffleToggle()
	if ShuffleState == true then
		ShuffleState = false
	else
		ShuffleState = true
	end

	local options = {
		headers = {
			["Accept"] = "application/json",
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. apikey,
			["Content-length"] = 0
		}
	}
	http.put("https://api.spotify.com/v1/me/player/shuffle?device_id=" .. deviceid .. "&state=" .. tostring(ShuffleState), options, function(s, r)
		UpdateCount = UpdateCount + 1
		UpdateWaitCheck = true
	end)
end

function LoopToggle()
	if RepeatState == "off" then
		RepeatState = "context"
	elseif RepeatState == "context" then
		RepeatState = "track"
	elseif RepeatState == "track" then
		RepeatState = "off"
	end

	local options = {
		headers = {
			["Accept"] = "application/json",
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. apikey,
			["Content-length"] = 0
		}
	} 

	http.put("https://api.spotify.com/v1/me/player/repeat?device_id=" .. deviceid .. "&state=" .. RepeatState, options, function(s, r)
		UpdateCount = UpdateCount + 1
		UpdateWaitCheck = true
	end)
end

local elements = {
	Connected = ui_new_label("MISC", "Miscellaneous", AuthStatus),
	AuthButton = ui_new_button("MISC", "Miscellaneous", "Authorize", function() AuthClicked = true Auth() end),
	IndicType = ui_new_combobox("MISC", "Miscellaneous", "Type", "Spotify", "Minimal"),
	Additions = ui_new_multiselect("MISC", "Miscellaneous", "Additions", "Cover art", "Duration", "Vitals", "Fixed width"),
	CustomLayoutType = ui_new_combobox("MISC", "Miscellaneous", "Art location", "Left", "Right"),
	MenuSize = ui_new_slider("MISC", "Miscellaneous", "Scale", 50, 150, 100, true, "%"),
	WidthLock = ui_new_label("MISC", "Miscellaneous", "⭥						[LINKED]						 ⭥"),
	MinimumWidth = ui_new_slider("MISC", "Miscellaneous", "Minimum box width", 199, 600, 400, true, "px", 1, { [199] = "Auto"}),
	FixedWidth = ui_new_slider("MISC", "Miscellaneous", "Box width", 200, 600, 400, true, "px", 1),
	
	DebugInfo = ui_new_checkbox("MISC", "Miscellaneous", "Debug info"),
		NowPlaying = ui_new_label("MISC", "Miscellaneous", "Now playing:" .. SongName),
		Artist = ui_new_label("MISC", "Miscellaneous", "By:" .. ArtistName),
		SongDuration = ui_new_label("MISC", "Miscellaneous", SongProgression .. SongLength),
		VolumeLabel = ui_new_label("MISC", "Miscellaneous", "NewVolume: " .. NewVolume),
		UpdateRate = ui_new_slider("MISC", "Miscellaneous", "Update rate", 0.5, 5, 1, true, "s"),
		RateLimitWarning = ui_new_label("MISC", "Miscellaneous", "WARNING: using <1s updaterate might get you ratelimited"),
		SessionUpdates = ui_new_label("MISC", "Miscellaneous", "Total updates this session: " .. UpdateCount),
		TotalErrors = ui_new_label("MISC", "Miscellaneous", "Errors this session: " .. TotalErrors),
		SpreeErrors = ui_new_label("MISC", "Miscellaneous", "Errors this spree: " .. ErrorSpree),
		RecentError = ui_new_label("MISC", "Miscellaneous", "Most recent error: " .. "-"),
		MaxErrors = ui_new_slider("MISC", "Miscellaneous", "Max errors", 1, 20, 5, true, "x"),
		ErrorRate = ui_new_slider("MISC", "Miscellaneous", "within", 5, 300, 30, true, "s"),
		FirstPressAmount = ui_new_slider("MISC", "Miscellaneous", "First press amount", 1, 20, 5, true, "%"),
		VolumeTickSpeed = ui_new_slider("MISC", "Miscellaneous", "Volume tick speed", 1, 64, 2, true, "tc"),
		VolumeTickAmount = ui_new_slider("MISC", "Miscellaneous", "Volume tick amount", 1, 10, 1, true, "%"),
		SpotifyPosition = ui_new_label("MISC", "Miscellaneous", "Position(x - x2(width), y): " .. SpotifyIndicX .. " - " .. SpotifyIndicX2 .. "(" .. adaptivesize .. "), " .. SpotifyIndicY .. "y"),
		AddError = ui_new_button("MISC", "Miscellaneous", "Add an error", function() AuthStatus = "TOKEN" ErrorSpree = ErrorSpree + 1 TotalErrors = TotalErrors + 1 end),
		ForceReflowButton = ui_new_button("MISC", "Miscellaneous", "Force element reflow", function() ForceReflow() end),

	MenuBarEnable = ui_new_checkbox("MISC", "Miscellaneous", "Menu bar"),
		HideOriginIndic = ui_new_checkbox("MISC", "Miscellaneous", "Hide indicator while in menu"),
	
	CustomColors = ui_new_checkbox("MISC", "Miscellaneous", "Custom colors"),
		ProgressGradientSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Gradient progress bar"),
		BackgroundGradientSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Gradient background"),
			LabelProgressGradient1 = ui_new_label("MISC", "Miscellaneous", "  - Progress gradient L"),
			ProgressGradient1 = ui_new_color_picker("MISC", "Miscellaneous", "progressbar gradient 1", 0, 255, 0, 255),
			LabelProgressGradient2 = ui_new_label("MISC", "Miscellaneous", "  - Progress gradient R"),
			ProgressGradient2 = ui_new_color_picker("MISC", "Miscellaneous", "progressbar gradient 2", 0, 255, 0, 255),
		LabelGradientColour = ui_new_label("MISC", "Miscellaneous", "  - Progress bar color"),
		GradientColour = ui.new_color_picker("MISC", "Miscellaneous", "progress bar Colourpicker", 0, 255, 0, 255),
		LabelBackgroundColor = ui_new_label("MISC", "Miscellaneous", "  - Background color"),
		BackgroundColour = ui_new_color_picker("MISC", "Miscellaneous", "Background colourrpicker", 25, 25, 25, 255),
			LabelBackgroundColorGradient1 = ui_new_label("MISC", "Miscellaneous", "  - Background gradient L"),
			BackgroundColorGradient1 = ui_new_color_picker("MISC", "Miscellaneous", "Background Gradient colourpicker1", 25, 25, 25, 50),
			LabelBackgroundColorGradient2 = ui_new_label("MISC", "Miscellaneous", "  - Background gradient R"),
			BackgroundColorGradient2 = ui_new_color_picker("MISC", "Miscellaneous", "Background Gradient colourpicker2", 25, 25, 25, 255),
		LabelTextColorPrimary = ui_new_label("MISC", "Miscellaneous", "  - Primary text color"),
		TextColorPrimary = ui_new_color_picker("MISC", "Miscellaneous", "Primary text clr", 255, 255, 255, 255),
		LabelTextColorSecondary = ui_new_label("MISC", "Miscellaneous", "  - Secondary text color"),
		TextColorSecondary = ui_new_color_picker("MISC", "Miscellaneous", "Secondary text clr", 159, 159, 159, 255),
		
	ControlSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Controls"),
		SmartControlSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Smart controls"),
		SmartVolumeSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Smart volume"),
			SmartControls = ui_new_hotkey("MISC", "Miscellaneous", "  - Smart Controls", true),
			

		PlayPause = ui_new_hotkey("MISC", "Miscellaneous", "  - Play/Pause", false),
		SkipSong = ui_new_hotkey("MISC", "Miscellaneous", "  - Skip song", false),
		PreviousSong = ui_new_hotkey("MISC", "Miscellaneous", "  - Previous song", false),
		IncreaseVolume = ui_new_hotkey("MISC", "Miscellaneous", "  - Volume up", false),
		DecreaseVolume = ui_new_hotkey("MISC", "Miscellaneous", "  - Volume down", false),
		AdaptiveVolume = ui_new_slider("MISC", "Miscellaneous", "Decrease volume by % on voicechat", 0, 100, "off", true, "%", 1, { [0] = "off", [100] = "mute"}),

	ExtrasBox = ui_new_multiselect("MISC", "Miscellaneous", "Extras", "Print song changes in chat", "Now playing clantag", "Higher update rate (experimental)"),
	ResetAuth = ui_new_button("MISC", "Miscellaneous", "Reset authorization", function() ResetAPI() end),
	KankerOp = ui_new_button("MISC", "Miscellaneous", "Reset playlists", function() database_write("savedplaylists", nil) Playlists = {} PlayListCount = 0 PlaylistLimitReached = false currplaylist = {} currplaylisturi = "" currplaylistname = "" TrackCount = 0 Playlistcache = "" database_write("playlistcache", Playlistcache) PlaylistSelected = false end),
}

function ChangeVolume(Svol) 
	if kanker then 
		kanker = false
		local options = {
			headers = {
				["Accept"] = "application/json",
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. apikey,
				["Content-length"] = 0
			}
		}

		http.put("https://api.spotify.com/v1/me/player/volume?volume_percent=" .. round(Svol) .. "&device_id=" .. deviceid, options, function(s, r)
			UpdateCount = UpdateCount + 1
		end)
		VolumeBarCache = ScrolledVolume
	else

		if stopRequest then return end

		local options = {
			headers = {
				["Accept"] = "application/json",
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. apikey,
				["Content-length"] = 0
			}
		}

		http.put("https://api.spotify.com/v1/me/player/volume?volume_percent=" .. NewVolume .. "&device_id=" .. deviceid, options, function(s, r)
			UpdateCount = UpdateCount + 1
		end)
		stopRequest = true
		StopSpamming = false
		SetCheck = true
		UpdateInf()
	end
end 

function Seek(seekms) 
	local options = {
		headers = {
			["Accept"] = "application/json",
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. apikey,
			["Content-length"] = 0
		}
	}

	http.put("https://api.spotify.com/v1/me/player/seek?position_ms=" .. round(seekms) .. "&device_id=" .. deviceid, options, function(s, r)
		UpdateCount = UpdateCount + 1
	end)
	ProgressBarCache = CurrentDataSpotify.item.duration_ms/404*MouseHudPosXprgs
	ProgressDuration = msConversion(SeekedTime)
	LeftDuration = msConversion(CurrentDataSpotify.item.duration_ms-SeekedTime)
end

function PlaySong(n, k, y, s)

	local niggers = json.stringify({context_uri = "spotify:playlist:" .. currplaylisturi, offset = {position = n-1}, position_ms = 0})

	local options = {
		headers = {
			["Accept"] = "application/json",
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. apikey,
		},
		body = niggers
	}
	
	http.put("https://api.spotify.com/v1/me/player/play", options, function(s, r)
		UpdateCount = UpdateCount + 1
		if not success or response.status ~= 200 then return end
		SongNameHUD = k
		ArtistNameHUD = y
		ThumbnailUrl = s

		http.get(ThumbnailUrl, function(success, response)
			if not success or response.status ~= 200 then
			  return
			end
		Thumbnail = images.load_jpg(response.body)
		end)
	end)
end

function QueueSong(uri)
	local options = {
		headers = {
			["Accept"] = "application/json",
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. apikey,
			["Content-length"] = 0
		}
	}

	http.post("https://api.spotify.com/v1/me/player/queue?uri=" .. uri .. "&device_id=" .. deviceid, options, function(s, r)
		UpdateCount = UpdateCount + 1
	end)
end

function InitPlaylist(id)
	if id == nil then client.color_log(255, 0, 0, "Failed to add playlist. Make sure that you have your Playlist link in your clipboard, and that the formatting is correct. (https://open.spotify.com/playlist/6piHLVTmzq8nTix2wIlM8x?si=10c8288bd6fc4f94)") return end
	if string.find(Playlistcache, id) ~= nil then client.color_log(255, 0, 0, "You have already added this playlist!") return end
	UpdateWaitCheck = true
	http.get("https://api.spotify.com/v1/playlists/" .. id .. "?access_token=" .. apikey .. "&fields=name", function(s, r) -- tracks.items(track(name%2C%20uri%2C%20images%2C%20album.artists%2C%20duration_ms))%2C%20
		if not s or r.status ~= 200 then
			client.color_log(255, 0, 0, "Failed to add playlist. Make sure that you have your Playlist link in your clipboard, and that the formatting is correct. (https://open.spotify.com/playlist/6piHLVTmzq8nTix2wIlM8x?si=10c8288bd6fc4f94)")
			return
		end
		PlayListCount = PlayListCount + 1
		local temp = json.parse(r.body)
		table.insert(Playlists, {id = PlayListCount, PlaylistName = temp.name .. "," .. id})
		Playlistcache = Playlistcache .. id
		UpdateCount = UpdateCount + 1
	end)
end

function LoadPlaylist(uri)
	local jekanker, moeder = string.match(uri, "(.*),(.*)")
	TrackCount = 0
	UpdateWaitCheck = true
	http.get("https://api.spotify.com/v1/playlists/".. moeder .."/tracks?market=US&limit=100&offset=0" .. "&access_token=" .. apikey, function(s, r)
		if not s or r.status ~= 200 then return end
		currplaylist = {}
		currplaylistname = jekanker
		currplaylisturi = moeder
		local temp = json.parse(r.body)
		for i, track in ipairs(temp.items) do
			TrackCount = TrackCount + 1
			table.insert(currplaylist, {id = TrackCount, SongDetails = temp.items[i].track.name .. "^" .. temp.items[i].track.artists[1].name .. "^" .. temp.items[i].track.duration_ms .. "^" .. temp.items[i].track.uri .. "^" .. temp.items[i].track.album.images[3].url})
			PlaylistSelected = true
			UpdateCount = UpdateCount + 1
		end
	end)
end

function AddPlaylist(uri)
	UpdateWaitCheck = true
	http.get("https://api.spotify.com/v1/playlists/".. uri .."/tracks?market=US&limit=100&offset=".. TrackCount .. "&access_token=" .. apikey, function(s, r)
		if not s or r.status ~= 200 then return end
		local temp = json.parse(r.body)
		for i, track in ipairs(temp.items) do
			TrackCount = TrackCount + 1
			table.insert(currplaylist, {id = TrackCount, SongDetails = temp.items[i].track.name .. "^" .. temp.items[i].track.artists[1].name .. "^" .. temp.items[i].track.duration_ms .. "^" .. temp.items[i].track.uri .. "^" .. temp.items[i].track.album.images[3].url})
			UpdateCount = UpdateCount + 1
		end
	end)
end

function setConnected(value)
	ui_set(elements.Connected, value)
end

local startpos = {
	DRegionx = 0, DRegiony = 0,
}

local endpos = {
	DRegionx = SpotifyScaleX, DRegiony = SpotifyScaleY,
}

local function intersect(x, y, w, h, debug) 
	local mousepos = { ui.mouse_position() }
	rawmouseposX = mousepos[1]
	rawmouseposY = mousepos[2]
	debug = debug or false
	if debug then 
		surface.draw_filled_rect(x, y, w, h, 255, 0, 0, 50)
	end

	return rawmouseposX >= x and rawmouseposX <= x + w and rawmouseposY >= y and rawmouseposY <= y + h
end

local function contains(table, value)

	if table == nil then
		return false
	end

	table = ui_get(table)
	for i=0, #table do
		if table[i] == value then
			return true
		end
	end
	return false
end

function ShowMenuElements() 
	if ui_get(MainCheckbox) and Authed then
		ui_set_visible(elements.Connected, true)
		ui_set_visible(elements.AuthButton, false)
		ui_set_visible(elements.NowPlaying, true)
		ui_set_visible(elements.Artist, true)
		ui_set_visible(elements.SongDuration, true)
		ui_set_visible(elements.IndicType, true)
		ui_set_visible(elements.GradientColour, true)
		ui_set_visible(elements.LabelGradientColour, true)
		ui_set_visible(elements.CustomColors, true)
		ui_set_visible(elements.ControlSwitch, true)
		ui_set_visible(elements.MenuSize, true)
		ui_set_visible(elements.ResetAuth, true)
		ui_set_visible(elements.MenuBarEnable, true)
		ui_set_visible(elements.ExtrasBox, true)

		if ui_get(elements.IndicType) == "Spotify" then
			ui_set_visible(elements.WidthLock, ShiftClick)
			ui_set_visible(elements.MinimumWidth, not contains(elements.Additions, "Fixed width"))
			ui_set_visible(elements.CustomLayoutType, contains(elements.Additions, "Cover art"))
			ui_set_visible(elements.FixedWidth, contains(elements.Additions, "Fixed width"))
			ui_set_visible(elements.Additions, true)


			if ui_get(elements.CustomColors) then
				ui_set_visible(elements.ProgressGradientSwitch, true)
				ui_set_visible(elements.BackgroundGradientSwitch, true)
				ui_set_visible(elements.LabelTextColorPrimary, true)
				ui_set_visible(elements.TextColorPrimary, true)
				ui_set_visible(elements.LabelTextColorSecondary, true)
				ui_set_visible(elements.TextColorSecondary, true)
				ui_set_visible(elements.BackgroundColour, true)
				ui_set_visible(elements.LabelBackgroundColor, true)

				if ui_get(elements.ProgressGradientSwitch) then
					ui_set_visible(elements.LabelProgressGradient1, true)
					ui_set_visible(elements.ProgressGradient1, true)
					ui_set_visible(elements.LabelProgressGradient2, true)
					ui_set_visible(elements.ProgressGradient2, true)
					ui_set_visible(elements.GradientColour, false)
					ui_set_visible(elements.LabelGradientColour, false) 
				else
					ui_set_visible(elements.GradientColour, true)
					ui_set_visible(elements.LabelGradientColour, true)
					ui_set_visible(elements.LabelProgressGradient1, false)
					ui_set_visible(elements.ProgressGradient1, false)
					ui_set_visible(elements.LabelProgressGradient2, false)
					ui_set_visible(elements.ProgressGradient2, false)
				end

				if ui_get(elements.BackgroundGradientSwitch) then
					ui_set_visible(elements.BackgroundColorGradient1, true)
					ui_set_visible(elements.LabelBackgroundColorGradient1, true)
					ui_set_visible(elements.BackgroundColorGradient2, true)
					ui_set_visible(elements.LabelBackgroundColorGradient2, true)
				else
					ui_set_visible(elements.BackgroundColorGradient1, false)
					ui_set_visible(elements.LabelBackgroundColorGradient1, false)
					ui_set_visible(elements.BackgroundColorGradient2, false)
					ui_set_visible(elements.LabelBackgroundColorGradient2, false)
				end
				
			else
				ui_set_visible(elements.ProgressGradientSwitch, false)
				ui_set_visible(elements.BackgroundGradientSwitch, false)
				ui_set_visible(elements.BackgroundColour, false)
				ui_set_visible(elements.LabelBackgroundColor, false)
				ui_set_visible(elements.LabelTextColorPrimary, false)
				ui_set_visible(elements.TextColorPrimary, false)
				ui_set_visible(elements.LabelTextColorSecondary, false)
				ui_set_visible(elements.TextColorSecondary, false)
				ui_set_visible(elements.BackgroundColorGradient1, false)
				ui_set_visible(elements.LabelBackgroundColorGradient1, false)
				ui_set_visible(elements.BackgroundColorGradient2, false)
				ui_set_visible(elements.LabelBackgroundColorGradient2, false)
				ui_set_visible(elements.LabelProgressGradient1, false)
				ui_set_visible(elements.ProgressGradient1, false)
				ui_set_visible(elements.LabelProgressGradient2, false)
				ui_set_visible(elements.ProgressGradient2, false)
				ui_set_visible(elements.GradientColour, false)
				ui_set_visible(elements.LabelGradientColour, false)
			end
			
		elseif ui_get(elements.IndicType) == "Minimal" then
			ui_set_visible(elements.MinimumWidth, false)
			ui_set_visible(elements.ProgressGradientSwitch, false)
			ui_set_visible(elements.BackgroundGradientSwitch, false)
			ui_set_visible(elements.BackgroundColour, false)
			ui_set_visible(elements.LabelBackgroundColor, false)
			ui_set_visible(elements.LabelTextColorPrimary, false)
			ui_set_visible(elements.TextColorPrimary, false)
			ui_set_visible(elements.LabelTextColorSecondary, false)
			ui_set_visible(elements.TextColorSecondary, false)
			ui_set_visible(elements.BackgroundColorGradient1, false)
			ui_set_visible(elements.LabelBackgroundColorGradient1, false)
			ui_set_visible(elements.BackgroundColorGradient2, false)
			ui_set_visible(elements.LabelBackgroundColorGradient2, false)
			ui_set_visible(elements.LabelProgressGradient1, false)
			ui_set_visible(elements.ProgressGradient1, false)
			ui_set_visible(elements.LabelProgressGradient2, false)
			ui_set_visible(elements.ProgressGradient2, false)
			ui_set_visible(elements.GradientColour, false)
			ui_set_visible(elements.LabelGradientColour, false)
			ui_set_visible(elements.MenuSize, false)
			ui_set_visible(elements.CustomLayoutType, false)
			ui_set_visible(elements.Additions, false)
			ui_set_visible(elements.FixedWidth, false)



			if ui_get(elements.CustomColors) then
				ui_set_visible(elements.GradientColour, true)
				ui_set_visible(elements.LabelGradientColour, true)
			else
				ui_set_visible(elements.GradientColour, false)
				ui_set_visible(elements.LabelGradientColour, false)
			end

		else
			ui_set_visible(elements.MinimumWidth, false)
			ui_set_visible(elements.CustomLayoutType, false)
			ui_set_visible(elements.ProgressGradientSwitch, false)
			ui_set_visible(elements.BackgroundColour, false)
			ui_set_visible(elements.LabelBackgroundColor, false)
			ui_set_visible(elements.LabelTextColorPrimary, false)
			ui_set_visible(elements.TextColorPrimary, false)
			ui_set_visible(elements.LabelTextColorSecondary, false)
			ui_set_visible(elements.TextColorSecondary, false)
			ui_set_visible(elements.BackgroundColorGradient1, false)
			ui_set_visible(elements.LabelBackgroundColorGradient1, false)
			ui_set_visible(elements.BackgroundColorGradient2, false)
			ui_set_visible(elements.LabelBackgroundColorGradient2, false)
			ui_set_visible(elements.LabelProgressGradient1, false)
			ui_set_visible(elements.ProgressGradient1, false)
			ui_set_visible(elements.LabelProgressGradient2, false)
			ui_set_visible(elements.ProgressGradient2, false)
			ui_set_visible(elements.GradientColour, false)
			ui_set_visible(elements.LabelGradientColour, false)
		end

		if ui_get(elements.MenuBarEnable) then
			ui_set_visible(elements.HideOriginIndic, true)
			ui_set_visible(elements.KankerOp, true)
		else
			ui_set_visible(elements.HideOriginIndic, false)
			ui_set_visible(elements.KankerOp, false)
		end
																					
		if ui_get(elements.ControlSwitch) then
			ui_set_visible(elements.SmartControlSwitch, true)
			ui_set_visible(elements.SmartVolumeSwitch, false)
			ui_set_visible(elements.IncreaseVolume, true)
			ui_set_visible(elements.DecreaseVolume, true)
			if ui_get(elements.SmartControlSwitch) then
				ui_set_visible(elements.SmartControls, true)
				ui_set_visible(elements.SkipSong, false)
				ui_set_visible(elements.PreviousSong, false)
				ui_set_visible(elements.PlayPause, false)
			else
				ui_set_visible(elements.SmartControls, false)
				ui_set_visible(elements.SkipSong, true)
				ui_set_visible(elements.PreviousSong, true)
				ui_set_visible(elements.PlayPause, true)
			end

			if ui_get(elements.SmartVolumeSwitch) then
				ui_set_visible(elements.AdaptiveVolume, false)
			else
				ui_set_visible(elements.AdaptiveVolume, false)
			end

		else
			ui_set_visible(elements.SmartControlSwitch, false)
			ui_set_visible(elements.SmartVolumeSwitch, false)
			ui_set_visible(elements.SmartControls, false)
			ui_set_visible(elements.SkipSong, false)
			ui_set_visible(elements.PreviousSong, false)
			ui_set_visible(elements.PlayPause, false)
			ui_set_visible(elements.IncreaseVolume, false)
			ui_set_visible(elements.DecreaseVolume, false)
			ui_set_visible(elements.AdaptiveVolume, false)
		end

		ui_set_visible(elements.DebugInfo, Authed and UserName == "stbrouwers" or Authed and UserName == "slxyx" or Authed and UserName == "Encoded" or Authed and UserName == "22fzreq5auy5njejk6fzp7nhy")

		if ui_get(elements.DebugInfo) then
			ui_set_visible(elements.NowPlaying, true)
			ui_set_visible(elements.Artist, true)
			ui_set_visible(elements.SongDuration, true)
			ui_set_visible(elements.UpdateRate, true)
			ui_set_visible(elements.RateLimitWarning, ui_get(elements.UpdateRate) <= 0.9)
			ui_set_visible(elements.SessionUpdates, true)
			ui_set_visible(elements.TotalErrors, true)
			ui_set_visible(elements.SpreeErrors, true)
			ui_set_visible(elements.RecentError, true)
			ui_set_visible(elements.ErrorRate, true)
			ui_set_visible(elements.MaxErrors, true)
			ui_set_visible(elements.AddError, true)
			ui_set_visible(elements.SpotifyPosition, true)
			ui_set_visible(elements.ForceReflowButton, true)
			ui_set_visible(elements.VolumeTickSpeed, true)
			ui_set_visible(elements.VolumeTickAmount, true)
			ui_set_visible(elements.FirstPressAmount, true)
			ui_set_visible(elements.VolumeLabel, true)
		else
			ui_set_visible(elements.NowPlaying, false)
			ui_set_visible(elements.Artist, false)
			ui_set_visible(elements.SongDuration, false)
			ui_set_visible(elements.UpdateRate, false)
			ui_set_visible(elements.RateLimitWarning, false)
			ui_set_visible(elements.SessionUpdates, false)
			ui_set_visible(elements.TotalErrors, false)
			ui_set_visible(elements.SpreeErrors, false)
			ui_set_visible(elements.RecentError, false)
			ui_set_visible(elements.ErrorRate, false)
			ui_set_visible(elements.MaxErrors, false)
			ui_set_visible(elements.AddError, false)
			ui_set_visible(elements.SpotifyPosition, false)
			ui_set_visible(elements.ForceReflowButton, false)
			ui_set_visible(elements.VolumeTickSpeed, false)
			ui_set_visible(elements.VolumeTickAmount, false)
			ui_set_visible(elements.FirstPressAmount, false)
			ui_set_visible(elements.VolumeLabel, false)
		end

	elseif ui_get(MainCheckbox) and not Authed then
		ui_set_visible(elements.Connected, true)
		ui_set_visible(elements.AuthButton, true)
		ui_set_visible(elements.ResetAuth, true)

		
	elseif not ui_get(MainCheckbox) then
		for k,v in pairs(elements) do
			for m,w in pairs(elements) do
				if k ~= m then
					if w == v then
						elements[m] = nil
						elements[k] = nil
					end
				end
			end
		end
		for k,v in pairs(elements) do
			ui.set_visible(v, false)
		end
	end
end

function ForceReflow()
	for k,v in pairs(elements) do
		for m,w in pairs(elements) do
			if k ~= m then
				if w == v then
					elements[m] = nil
					elements[k] = nil
				end
			end
		end
	end
	for k,v in pairs(elements) do
		ui.set_visible(v, false)
	end
	ShowMenuElements()
end

function ResetAPI() 
	Authed = false
	ConnectionStatus = "NoConnection"
	apikey = nil
	refreshkey = nil
	database_write("StoredKey", nil)
	database_write("StoredKey2", nil)
	ForceReflow()
	client.reload_active_scripts()
end

function MusicControls()
	if ControlCheck == false then  
		if not ui_get(elements.SmartControlSwitch) then
			if ui_get(elements.PlayPause) then
				PlayPause()
			elseif ui_get(elements.SkipSong) then
				NextTrack()
			elseif ui_get(elements.PreviousSong) then
				PreviousTrack()
			end
		elseif ui_get(elements.SmartControls) then
			ClickSpree = ClickSpree + 1
			ClickSpreeTime = ClickSpreeTime + 0.45
			ControlCheck = true
		end
	end

	if client.unix_time() > last_update_controls + ClickSpreeTime and ui_get(elements.SmartControlSwitch) then
		if ClickSpree == 0 then ClickSpree = 0 end
		if ClickSpree == 1 then ClickSpree = 0 PlayPause() end
		if ClickSpree == 2 then ClickSpree = 0 NextTrack() end
		if ClickSpree == 3 then ClickSpree = 0 PreviousTrack() end
		if ClickSpree >= 3.1 then ClickSpree = 0 PreviousTrack() end
		last_update_controls = client.unix_time()
		ClickSpreeTime = 0.5
	end
end

function gaySexgamer()
	if forkinCock then
		analBuggery = globals.tickcount() % 64
		analGaping = globals.tickcount() % 64
		forkinCock = false
	end
	if globals.tickcount() % 64 == analGaping and bool then
		gropeTits = true
	end
	if gropeTits then
		analBuggery = globals.tickcount() % 64
	end
	if ui_get(elements.IncreaseVolume) or ui_get(elements.DecreaseVolume) then bool = false else bool = true end
	if not bool then
		molestingInfants = true
		gropeTits = false
		analGaping = (globals.tickcount() % 64)-2
	end
end

function VolumeHandler() 
	if ui_get(elements.IncreaseVolume) or ui_get(elements.DecreaseVolume) then
		if FirstPress then
			if VolumeCheck == false then 
				if ui_get(elements.IncreaseVolume) and not ui_get(elements.DecreaseVolume) then
					NewVolume = NewVolume + ui_get(elements.FirstPressAmount)
				elseif not ui_get(elements.IncreaseVolume) and ui_get(elements.DecreaseVolume) then
					NewVolume = NewVolume - ui_get(elements.FirstPressAmount)
				end
			end
		end
		if NewVolume >= 100 then 
			NewVolume = 100
		elseif NewVolume <= 0 then
			NewVolume = 0
		end 
	end
	if globals.tickcount() % 64 == analBuggery and not ui_get(elements.IncreaseVolume) and not ui_get(elements.DecreaseVolume) and molestingInfants then
		molestingInfants = false
		stopRequest = false
		NiggerSex = false
		groomingNiglets = true
		ChangeVolume() 
	end
end

function UpdateElements()
	
	switch(AuthStatus) {

		SUCCESS = function()
			ui_set(elements.Connected, "> " .. "Connected to " .. UserName)
		end,

		FAILED = function()
			ui_set(elements.Connected, "> Please put your API key into your clipboard (Invalid token)")
		end,

		TOKEN = function()
			if ui_get(elements.Connected) == "> Please put your API key into your clipboard (Invalid token)" then return end
			ui_set(elements.RecentError, "Most recent error: " .. "000, REJECTED")
		end,

		FORBIDDEN = function()
			ui_set(elements.Connected, "> The server has dropped your request. Reason unknown")
			ui_set(elements.RecentError, "Most recent error: " .. "403, FORBIDDEN")
		end,

		RATE = function()
			ui_set(elements.Connected, "> You've reached the hourly limit of requests. Contact the lua dev")
			ui_set(elements.RecentError, "Most recent error: " .. "429, RATELIMIT")
		end,

		APIFAIL = function()
			ui_set(elements.Connected, "> An issue on Spotify's end has occurred. Check their status page")
			ui_set(elements.RecentError, "Most recent error: " .. "503, APIFAIL")
		end,

		TRYING = function()
			ui_set(elements.Connected, "> Trying the refresh key")
		end,

		WRONGKEY = function() 
			ui_set(elements.Connected, "> The supplied refresh key was invalid, please try again.")
			ui_set(elements.RecentError, "Most recent error: " .. "XXX, WRONGKEY")
		end
	}

	ui_set(elements.NowPlaying, "Now playing: " .. SongName)
	ui_set(elements.Artist, "By: " .. ArtistName)
	ui_set(elements.SongDuration, SongProgression .. "/" .. SongLength)
	ShowMenuElements()
end

local function Dragging()
	local mousepos = { ui.mouse_position() }
	rawmouseposX = mousepos[1]
	rawmouseposY = mousepos[2]

	if dragging and not LClick then
		dragging = false
	end

	if dragging and LClick then
		if SpotifyIndicX <= -0.1 and not contains(elements.Additions, "Cover art") then
			SpotifyIndicX = 0
		elseif SpotifyIndicX + adaptivesize >= sx+0.1 and not contains(elements.Additions, "Cover art") then
			SpotifyIndicX = sx - adaptivesize
		elseif SpotifyIndicX - ArtScaleX <= -0.1 and contains(elements.Additions, "Cover art") and ui_get(elements.CustomLayoutType) == "Left" and not ui_get(elements.IndicType) == "Minimal" then
			SpotifyIndicX = ArtScaleX
		elseif SpotifyIndicX + adaptivesize >= sx+0.1 and contains(elements.Additions, "Cover art") and ui_get(elements.CustomLayoutType) == "Left" and not ui_get(elements.IndicType) == "Minimal" then
			SpotifyIndicX = sx - adaptivesize	
		elseif SpotifyIndicX + adaptivesize + ArtScaleX >= sx+0.1 and contains(elements.Additions, "Cover art") and ui_get(elements.CustomLayoutType) == "Right" and not ui_get(elements.IndicType) == "Minimal" then
			SpotifyIndicX = sx - adaptivesize - ArtScaleX
		elseif SpotifyIndicX <= -0.1 and contains(elements.Additions, "Cover art") and ui_get(elements.CustomLayoutType) == "Right" and not ui_get(elements.IndicType) == "Minimal" then
			SpotifyIndicX = 0
		else
			SpotifyIndicX = rawmouseposX - xdrag
		end

		if SpotifyIndicY <= -0.1 then
			SpotifyIndicY = 0
		elseif SpotifyIndicY + SpotifyScaleY >= sy+0.1 then
			SpotifyIndicY = sy - SpotifyScaleY
		else	
			SpotifyIndicY = rawmouseposY - ydrag
		end
	end

	if intersect(SpotifyIndicX - startpos.DRegionx, SpotifyIndicY - startpos.DRegiony, adaptivesize, SpotifyScaleY, false) and LClick then 
		dragging = true
		xdrag = rawmouseposX - SpotifyIndicX
		ydrag = rawmouseposY - SpotifyIndicY
	end
end

local function AdjustSize() 
	if not Authed then return end

	titlex, titley = surface.get_text_size(TitleFont, SongName)+50
	artistx, artisty = surface.get_text_size(ArtistFont, ArtistName)+50

	if contains(elements.Additions, "Fixed width") then
		adaptivesize = ui_get(elements.FixedWidth)
		if ui_get(elements.MenuSize) >= 100 then
			ui_set(elements.MenuSize, 100) 
		end

		if titlex > adaptivesize then
			if ui_get(elements.MenuSize) > 75 then
				videogaming2021 = splitByChunk(SongName, round(adaptivesize/11))
			else
				videogaming2021 = splitByChunk(SongName, round(adaptivesize/8))
			end
			FixedSongName = tostring(videogaming2021[1])
			SongTooLong = true
		else
			SongTooLong = false
		end

	else
		SongTooLong = false
		if titlex > artistx then
			adaptivesize = titlex
		else
			adaptivesize = artistx
		end


		if ui_get(elements.MinimumWidth) > 199 and adaptivesize < ui_get(elements.MinimumWidth) then
			adaptivesize = ui_get(elements.MinimumWidth)
		end

		if SongChanged and ui_get(elements.CustomLayoutType) == "Right" and ui_get(elements.IndicType) == "Spotify" then
			SpotifyIndicX = SpotifyIndicX2 - adaptivesize
			SongChanged = false
		end
	end

	if ui_get(elements.IndicType) == "Minimal" then
		if SpotifyIndicX <= -0.1 then
			SpotifyIndicX = 0
		elseif SpotifyIndicX >= sx+0.1 then
			SpotifyIndicX = sx - adaptivesize
		end
	end

	if ui_get(elements.IndicType) == "Spotify" then
		if SpotifyIndicX <= -0.1 and not contains(elements.Additions, "Cover art") then
			SpotifyIndicX = 0
		elseif SpotifyIndicX + adaptivesize >= sx+0.1 and not contains(elements.Additions, "Cover art") then
			SpotifyIndicX = sx - adaptivesize
		elseif SpotifyIndicX - ArtScaleX <= -0.1 and contains(elements.Additions, "Cover art") and ui_get(elements.CustomLayoutType) == "Left" then
			SpotifyIndicX = ArtScaleX
		elseif SpotifyIndicX + adaptivesize >= sx+0.1 and contains(elements.Additions, "Cover art") and ui_get(elements.CustomLayoutType) == "Left" then
			SpotifyIndicX = sx - adaptivesize	
		elseif SpotifyIndicX + adaptivesize + ArtScaleX >= sx+0.1 and contains(elements.Additions, "Cover art") and ui_get(elements.CustomLayoutType) == "Right" then
			SpotifyIndicX = sx - adaptivesize - ArtScaleX
		elseif SpotifyIndicX <= -0.1 and contains(elements.Additions, "Cover art") and ui_get(elements.CustomLayoutType) == "Right" then
			SpotifyIndicX = 0
		end
	end

	if SpotifyIndicY <= -0.01 then
		SpotifyIndicY = 0
	elseif SpotifyIndicY + SpotifyScaleY >= sy+0.1 then
		SpotifyIndicY = sy - SpotifyScaleY
	end
	SpotifyIndicX2 = SpotifyIndicX + adaptivesize
end
		
local c = {130, 130, 130}
local g, h = 255, 0
local l = {30, 150}

local function CustomLayout()
	if ui_get(elements.MenuBarEnable) and ui_get(elements.HideOriginIndic) and ui.is_menu_open() then return end
	ArtScaleX, ArtScaleY = SpotifyScaleY, SpotifyScaleY
	if ui_get(elements.CustomColors) then
		tr1, tg1, tb1, ta1 = ui_get(elements.TextColorPrimary)
		tr2, tg2, tb2, ta2 = ui_get(elements.TextColorSecondary)
	else
		tr1, tg1, tb1, ta1 = 255,255,255,255
		tr2, tg2, tb2, ta2 = 159,159,159,255
	end
	
	if contains(elements.Additions, "Cover art") then
		switch(ui_get(elements.CustomLayoutType)) {
		
			Left = function()
				if contains(elements.Additions, "Cover art") and Thumbnail ~= nil and not CurrentDataSpotify.item.is_local then
					local function drawLeft()
						Thumbnail:draw(SpotifyIndicX-ArtScaleX, SpotifyIndicY, ArtScaleX, ArtScaleY)
					end
					status, retval = pcall(drawLeft)
					if status == false or CurrentDataSpotify.item.is_local then
						retardedJpg = true
					end
				else end
				if SongTooLong then
					surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*22, tr1, tg1, tb1, ta1, TitleFont, FixedSongName)
				else
					surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*22, tr1, tg1, tb1, ta1, TitleFont, SongName)
				end
				surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
				if contains(elements.Additions, "Duration") then
					surface.draw_text(SpotifyIndicX+adaptivesize-(SpotifyScaleY/100)*85, SpotifyIndicY+(SpotifyScaleY/100)*67, tr2, tg2, tb2, ta2, DurationFont, ProgressDuration .. "/" .. TotalDuration)
				end
			end,

			Right = function()
				if contains(elements.Additions, "Cover art") and Thumbnail ~= nil then
					local function drawRight()
						Thumbnail:draw(SpotifyIndicX+adaptivesize, SpotifyIndicY, ArtScaleX, ArtScaleY)
					end
					status, retval = pcall(drawRight)
					if status == false then
						retardedJpg = true
					end
					else end
				if SongTooLong then
					surface.draw_text(SpotifyIndicX + adaptivesize - titlex +40, SpotifyIndicY+(SpotifyScaleY/100)*22, tr1, tg1, tb1, ta1, TitleFont, FixedSongName)
				else
					surface.draw_text(SpotifyIndicX + adaptivesize - titlex +40, SpotifyIndicY+(SpotifyScaleY/100)*22, tr1, tg1, tb1, ta1, TitleFont, SongName)
				end
				surface.draw_text(SpotifyIndicX + adaptivesize - artistx +40, SpotifyIndicY+(SpotifyScaleY/100)*52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
				if contains(elements.Additions, "Duration") then
					surface.draw_text(SpotifyIndicX+8, SpotifyIndicY+(SpotifyScaleY/100)*67, tr2, tg2, tb2, ta2, DurationFont, ProgressDuration .. "/" .. TotalDuration)
				end
			end
		}
	else 
		if SongTooLong then
			surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*22, tr1, tg1, tb1, ta1, TitleFont, FixedSongName)
		else
			surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*22, tr1, tg1, tb1, ta1, TitleFont, SongName)
		end

		surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)

		if contains(elements.Additions, "Duration") then
			surface.draw_text(SpotifyIndicX+adaptivesize-(SpotifyScaleY/100)*85, SpotifyIndicY+(SpotifyScaleY/100)*67, tr2, tg2, tb2, ta2, DurationFont, ProgressDuration .. "/" .. TotalDuration)
		end
	end
end

-- not stolen
local volume_drawer=(function()local a={callback_registered=false,maximum_count=7,data={}}function a:register_callback()if self.callback_registered then return end;client.set_event_callback('paint_ui',function()local b={30,150}local c={13,13,13}local d=5;local e=self.data;for f=#e,1,-1 do self.data[f].time=self.data[f].time-globals.frametime()local g,h=255,0;local i=e[f]if i.time<0 then table.remove(self.data,f)else local j=i.def_time-i.time;local j=j>1 and 1 or j;if i.time<0.5 or j<0.5 then h=(j<1 and j or i.time)/0.5;g=h*255;if h<0.2 then d=d+15*(1.0-h/0.2)end end;local k={renderer.measure_text(nil,i.draw)}local l={b[1],b[2]}renderer.circle(l[1],l[2],c[1],c[2],c[3],g,20,90,0.5)renderer.circle(l[1],l[2]+100,c[1],c[2],c[3],g,19,270,0.5)renderer.rectangle(l[1]-19.3,l[2],39,100,c[1],c[2],c[3],g)renderer.circle(l[1],l[2],130,130,130,g,19,270,0.5)renderer.rectangle(l[1]-19.3,l[2],39,NewVolume,130,130,130,g)d=d-50 end end;self.callback_registered=true end)end;function a:paint(m,n)local o=tonumber(m)+1;for f=self.maximum_count,2,-1 do self.data[f]=self.data[f-1]end;self.data[1]={time=o,def_time=o,draw=n}self:register_callback()end;return a end)()
		
local function DrawNowPlaying()
	if ui_get(elements.CustomColors) then
		r, g, b, a = ui_get(elements.GradientColour)
		br, bg, bb, ba = ui_get(elements.BackgroundColour)
		gr1, gg1, gb1, ga1 = ui_get(elements.ProgressGradient1)
		gr2, gg2, gb2, ga2 = ui_get(elements.ProgressGradient2)
		br1, bg1, bb1, ba1 = ui_get(elements.BackgroundColorGradient1)
		br2, bg2, bb2, ba2 = ui_get(elements.BackgroundColorGradient2)
	else
		r, g, b, a =  0, 255, 0, 255
		br, bg, bb, ba = 25, 25, 25, 255
		gr1, gg1, gb1, ga1 = 0, 255, 0, 255
		gr2, gg2, gb2, ga2 = 0, 255, 0, 255
		br1, bg1, bb1, ba1 = 25, 25, 25, 100
		br2, bg2, bb2, ba2 = 25, 25, 25, 255
	end

	if CurrentDataSpotify == nil then return end

	if NiggerSex then
		renderer.rectangle(l[1]-10, l[2], 5, 100, 64, 64, 64, 255)
		renderer.rectangle(l[1]-10, l[2]+100, 5, -NewVolume, 29, 185, 84, 255)
		renderer.circle(l[1]-7, l[2]+100-NewVolume, 255, 255, 255, 255, 6, 0, 1)
	end

	switch(ui_get(elements.IndicType)) {

		Spotify = function()
			if ui_get(elements.MenuBarEnable) and ui_get(elements.HideOriginIndic) and ui.is_menu_open() then return end
			SpotifyScaleX = sx/MenuScaleX
			SpotifyScaleY = sy/MenuScaleY
			if ui_get(elements.CustomLayoutType) == "Left" and contains(elements.Additions, "Cover art") then
				surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, SpotifyScaleY, br, bg, bb, ba)
				surface.draw_filled_rect(SpotifyIndicX-ArtScaleX, SpotifyIndicY, SpotifyScaleY, SpotifyScaleY, 18, 18, 18, 255)
				renderer.circle_outline(SpotifyIndicX-ArtScaleX/2, SpotifyIndicY+SpotifyScaleY/2, 64, 64, 64, 255, SpotifyScaleY/10, 0, 1, 3)
				renderer.circle_outline(SpotifyIndicX-ArtScaleX/2, SpotifyIndicY+SpotifyScaleY/2, 64, 64, 64, 255, (SpotifyScaleY/100)*35, 0, 1, 3)
			elseif ui_get(elements.CustomLayoutType) == "Right" and contains(elements.Additions, "Cover art") then 
				surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, SpotifyScaleY, br, bg, bb, ba) 
				surface.draw_filled_rect(SpotifyIndicX+adaptivesize, SpotifyIndicY, ArtScaleX, ArtScaleX, 18, 18, 18, 255)
				renderer.circle_outline(SpotifyIndicX+adaptivesize+ArtScaleX/2, SpotifyIndicY+SpotifyScaleY/2, 64, 64, 64, 255, SpotifyScaleY/10, 0, 1, 3)
				renderer.circle_outline(SpotifyIndicX+adaptivesize+ArtScaleX/2, SpotifyIndicY+SpotifyScaleY/2, 64, 64, 64, 255, (SpotifyScaleY/100)*35, 0, 1, 3)
			else 
				surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, SpotifyScaleY, br, bg, bb, ba) 
			end

			if ui_get(elements.BackgroundGradientSwitch) then
				surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, (SpotifyScaleY/20*19), br1, bg1, bb1, ba1, br2, bg2, bb2, ba2, true)
			end
			if not ui_get(elements.ProgressGradientSwitch) then
				surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY+(SpotifyScaleY/20*19), CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*adaptivesize, (SpotifyScaleY/20*1), r, g, b, a)
			else
				surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY+(SpotifyScaleY/20*19), CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*adaptivesize, (SpotifyScaleY/20*1), gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
			end
		end,

		Minimal = function()
			local dpiscaling = ui_get(ui.reference("MISC", "Settings", "DPI Scale"))
			songartist, cbtanalcock = renderer.measure_text("b", "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)+10
			if dpiscaling == "100%" then
				SpotifyScaleX = 150
				SpotifyScaleY = 15
			elseif dpiscaling == "125%" then
				SpotifyScaleX = 150
				SpotifyScaleY = 17
			elseif dpiscaling == "150%" then
				SpotifyScaleX = 150
				SpotifyScaleY = 20
			elseif dpiscaling == "175%" then
				SpotifyScaleX = 150
				SpotifyScaleY = 22
			elseif dpiscaling == "200%" then
				SpotifyScaleX = 150
				SpotifyScaleY = 25
			end
			textmeasurement = renderer.measure_text("b", "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)+10

			renderer.gradient(SpotifyIndicX, SpotifyIndicY, textmeasurement, SpotifyScaleY+2, 22, 22, 22, 255, 22, 22, 22, 10, true)
			renderer.rectangle(SpotifyIndicX, SpotifyIndicY, 2, SpotifyScaleY+2, r, g, b, a)
			renderer.gradient(SpotifyIndicX, SpotifyIndicY, CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*textmeasurement, 2, r, g, b, a, r, g, b, 0, true)
			renderer.gradient(SpotifyIndicX, SpotifyIndicY+SpotifyScaleY, CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*textmeasurement, 2, r, g, b, a, r, g, b, 0, true)
			if CurrentDataSpotify.is_playing then
				renderer.text(SpotifyIndicX+5, SpotifyIndicY+2, 255, 255, 255, 255, "bd", 0, "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)
			else
				renderer.text(SpotifyIndicX+5, SpotifyIndicY+2, 255, 255, 255, 255, "bd", 0, "Paused")
			end
		end
	}
end

function DrawIngame()
	if ui_get(elements.IndicType) ~= "Spotify" or not Authed then return end
	if ui_get(elements.MenuBarEnable) and ui_get(elements.HideOriginIndic) and ui.is_menu_open() then return end
	local local_player = entity_get_local_player()
	if local_player == nil then return end



	if contains(elements.Additions, "Vitals") then
		local health = math.min(100, entity_get_prop(local_player, 'm_iHealth'))
		local hpclr = 255

		if health > 20 then
			hpclr = 255
		else
			hpclr = 20
		end

		if contains(elements.Additions, "Cover art") then
			switch(ui_get(elements.CustomLayoutType)) {
			
				Left = function()
					surface.draw_filled_rect(SpotifyIndicX+(adaptivesize), SpotifyIndicY+SpotifyScaleY-(SpotifyScaleY/100*health), 5, SpotifyScaleY/100*health, 255, hpclr, hpclr, 255)
					surface.draw_text(SpotifyIndicX+(adaptivesize)+10, SpotifyIndicY+SpotifyScaleY-(SpotifyScaleY/100*health)-SpotifyScaleY/6, 255, hpclr, hpclr, 255, TitleFont, "+" .. tostring(health))
				end,
	
				Right = function()
					surface.draw_filled_rect(SpotifyIndicX-5, SpotifyIndicY+SpotifyScaleY-(SpotifyScaleY/100*health), 5, SpotifyScaleY/100*health, 255, hpclr, hpclr, 255)
				end
			}
		else 
			surface.draw_filled_rect(SpotifyIndicX+(adaptivesize), SpotifyIndicY+SpotifyScaleY-(SpotifyScaleY/100*health), 5, SpotifyScaleY/100*health, 255, hpclr, hpclr, 255)
			surface.draw_text(SpotifyIndicX+(adaptivesize)+10, SpotifyIndicY+SpotifyScaleY-(SpotifyScaleY/100*health)-SpotifyScaleY/6, 255, hpclr, hpclr, 255, TitleFont, "+" .. tostring(health))
		end
	end
end

function ChangeMenuSize()
	MenuScaleChange = 2 - ui_get(elements.MenuSize)/100
	MenuScaleX = 4.8 * MenuScaleChange
	MenuScaleY = 10.8 * MenuScaleChange
	ScaleTitle = 41.54 * MenuScaleChange
	ScaleArtist = 63.53 * MenuScaleChange
	ScaleDuration = 54 * MenuScaleChange
	TitleFont = surface.create_font("GothamBookItalic", sy/ScaleTitle, 900, 0x010)
	ArtistFont = surface.create_font("GothamBookItalic", sy/ScaleArtist, 600, 0x010)
	DurationFont = surface.create_font("GothamBookItalic", sy/ScaleDuration, 600, 0x010)
	if ShiftClick and not contains(elements.Additions, "Fixed width") then 
		ui_set(elements.MinimumWidth, ui_get(elements.MenuSize)/100 * 400) 
	elseif ShiftClick then
		ui_set(elements.FixedWidth, ui_get(elements.MenuSize)/100 * 400) 
	end
end

function HoveringOverElement() 
	if LClick == true and ClickCheck == true then return end
	if LClick == true then
		ClickCheck = true
		switch(HoveringOver) {
			shuffle = function()
				ShuffleToggle()
			end,

			previous = function()
				PreviousTrack()
			end,

			playpause = function()
				PlayPause()
			end,

			skip = function()
				NextTrack()
			end,

			loop = function()
				LoopToggle()
			end,

			none = function ()
				return
			end
		}
	else
		ClickCheck = false
	end
end

function seekHandler()
	MouseHudPosXprgs = rawmouseposX - menuX - (menuW / 2) + 202
	if MouseHudPosXprgs >= 404 then
		MouseHudPosXprgs = 404
	elseif MouseHudPosXprgs <= 0 then
		MouseHudPosXprgs = 0
	end

	if UnlockReg then
		UpdateWaitCheck = true
		surface.draw_filled_rect(menuX + (menuW / 2) - 200, menuY + menuH + 72, MouseHudPosXprgs, 6, 30, 215, 96, 255)
		renderer.circle(menuX + (menuW / 2) - 200, menuY + menuH + 75, 30, 215, 96, 255, 3, 0, 1)
		renderer.circle(MouseHudPosXprgs + menuX + (menuW / 2) - 200, menuY + menuH + 75, 255, 255, 255, 255, 7, 0, 1)
		renderer.circle(MouseHudPosXprgs + menuX + (menuW / 2) - 200, menuY + menuH + 75, 20, 20, 20, 100, 4, 0, 1)
		SeekedTime = CurrentDataSpotify.item.duration_ms/404*MouseHudPosXprgs
		surface.draw_text(menuX + (menuW / 2) - 243, menuY + menuH + 69, 159, 159, 159, 255, DurationFontHUD, msConversion(SeekedTime))
		surface.draw_text(menuX + (menuW / 2) + 218, menuY + menuH + 69, 159, 159, 159, 255, DurationFontHUD, "-"..msConversion(CurrentDataSpotify.item.duration_ms-SeekedTime))
	end
end

function volumeHandler()
	MouseHudvolX = rawmouseposX*-1 + menuX + menuW -24
	if MouseHudvolX >= 82 then
		MouseHudvolX = 82 
	elseif MouseHudvolX <= 0 then
		MouseHudvolX = 0
	end
	Iwanttodie = (MouseHudvolX -82)*-1
	if UnlockReg2 then
		UpdateWaitCheck = true
		renderer.circle(menuX + menuW - 105, menuY + menuH + 48, 30, 215, 96, 255, 3, 0, 1)
		renderer.circle(Iwanttodie + menuX + menuW - 105, menuY + menuH + 48, 255, 255, 255, 255, 6, 0, 1)
		surface.draw_filled_rect(menuX + menuW - 106, menuY + menuH + 45, Iwanttodie, 6, 30, 215, 96, 255)
		renderer.circle(Iwanttodie + menuX + menuW - 105, menuY + menuH + 48, 20, 20, 20, 100, 3, 0, 1)
		VolumeSpeaker:draw(menuX + menuW - 140, menuY + menuH + 38, 20, 20, 255, 255, 255, 150)
		ScrolledVolume = 100/82*(Iwanttodie)
	end
end

function drawHUD()
	if not ui_get(elements.MenuBarEnable) then return end
	if CurrentDataSpotify == nil then return end
	menuX, menuY = ui.menu_position()
	menuW, menuH = ui.menu_size()
	MouseHudPosX = rawmouseposX - menuX - (menuW / 2) 
	MouseHudPosY = rawmouseposY - menuY - menuH
	MouseHudrightPosX = rawmouseposX - menuX - menuW
	MouseHudPosLeftX = rawmouseposX - menuX
	
	local startpos = {
		ShflX =  -140, ShflY = 30,
		PrvX = -75, PrvY = 28,
		PlpsX = -18, PlpsY = 22,
		SkpX = 51, SkpY = 28,
		RptX = 108, RptY = 30,

		prgsbrX = -202, prgsbrY = 64,
		vlmvbrhX = -141, vlmvbrhY = 40,
	}

	local endpos = {
		ShflX = -112, ShflY = 45,
		PrvX = -55, PrvY = 47,
		PlpsX = 18, PlpsY = 54,
		SkpX = 72, SkpY = 45,
		RptX = 135, RptY = 45,

		prgsbrX = 202, prgsbrY = 85,
		vlmvbrhX = -20, vlmvbrhY = 55,
	}

	if menuW <= 1500 and menuW >= 1150 then
		TitleFontHUD = surface.create_font("GothamBookItalic", menuW/50, 900, 0x010)
		ArtistFontHUD = surface.create_font("GothamBookItalic", menuW/75, 600, 0x010)
	elseif menuW <= 1150 and menuW >= 810 then
		TitleFontHUD = surface.create_font("GothamBookItalic", menuW/40, 900, 0x010)
		ArtistFontHUD = surface.create_font("GothamBookItalic", menuW/55, 600, 0x010)
	elseif menuW <= 810 then 
		TitleFontHUD = surface.create_font("GothamBookItalic", menuW/35, 900, 0x010)
		ArtistFontHUD = surface.create_font("GothamBookItalic", menuW/45, 600, 0x010)
	end

		-- Main Layout
	surface.draw_filled_rect(menuX, menuY + menuH - 3, menuW, 100, 25, 25, 25, 255)
	if not MenuBarExtended then 
		surface.draw_text(menuX + 100, menuY + menuH + 20, 255, 255, 255, 255, TitleFontHUD, SongNameHUD)
		surface.draw_text(menuX + 100, menuY + menuH + 50, 159, 159, 159, 255, ArtistFontHUD, ArtistNameHUD)
	end
	surface.draw_filled_rect(menuX + (menuW / 2) - 150, menuY + menuH - 3, (menuW / 2) + 140, 100, 25, 25, 25, 255)


		--Onscreen controls
		--Play/Pause
	renderer.circle_outline(menuX + (menuW / 2), menuY + menuH + 40, 255, 255, 255, 150, 16, 0, 1, 1)
	if PlayState == "Playing" then
		surface.draw_filled_rect(menuX + (menuW / 2) - 5, menuY + menuH + 34, 3, 12, 255, 255, 255, 150)
		surface.draw_filled_rect(menuX + (menuW / 2) + 2, menuY + menuH + 34, 3, 12, 255, 255, 255, 150)
	elseif PlayState == "Paused" then
		renderer.triangle(menuX + (menuW / 2) - 4, menuY + menuH + 34, menuX + (menuW / 2) - 4, menuY + menuH + 46,menuX + (menuW / 2) + 7, menuY + menuH + 40, 255, 255, 255, 150)
	end
		--Skip/Previous
	renderer.triangle(menuX + (menuW / 2) + 68, menuY + menuH + 39, menuX + (menuW / 2) + 55, menuY + menuH + 31,menuX + (menuW / 2) + 55, menuY + menuH + 47, 255, 255, 255, 150)
	renderer.rectangle(menuX + (menuW / 2) + 68, menuY + menuH + 31, 3, 16, 255, 255, 255, 150)
	renderer.triangle(menuX + (menuW / 2) - 68, menuY + menuH + 39, menuX + (menuW / 2) - 55, menuY + menuH + 31,menuX + (menuW / 2) - 55, menuY + menuH + 47, 255, 255, 255, 150)
	renderer.rectangle(menuX + (menuW / 2) - 71, menuY + menuH + 31, 3, 16, 255, 255, 255, 150)

		--shuffle/loop
	if ShuffleState == false then
		Shuffle:draw(menuX + (menuW / 2) - 140, menuY + menuH + 24, 30, 30, 255, 255, 255, 150)
	else
		ShuffleA:draw(menuX + (menuW / 2) - 140, menuY + menuH + 24, 30, 30, 255, 255, 255, 150)
		renderer.circle(menuX + (menuW / 2) - 126, menuY + menuH + 55, 30, 215, 96, 190, 2, 0, 1)
	end

	if RepeatState == "off" then
		Loop:draw(menuX + (menuW / 2) + 110, menuY + menuH + 26, 25, 25, 255, 255, 255, 150)
	elseif RepeatState == "context" then
		LoopA:draw(menuX + (menuW / 2) + 110, menuY + menuH + 26, 25, 25, 255, 255, 255, 150)
	elseif RepeatState == "track" then
		LoopA:draw(menuX + (menuW / 2) + 110, menuY + menuH + 26, 25, 25, 255, 255, 255, 150)
		renderer.circle(menuX + (menuW / 2) + 122, menuY + menuH + 55, 30, 215, 96, 190, 2, 0, 1)
	end

		--progressbar
	if not UnlockReg then
		surface.draw_text(menuX + (menuW / 2) - 243, menuY + menuH + 69, 159, 159, 159, 255, DurationFontHUD, ProgressDuration)
		surface.draw_text(menuX + (menuW / 2) + 218, menuY + menuH + 69, 159, 159, 159, 255, DurationFontHUD, "-"..LeftDuration)
	end

	renderer.circle(menuX + (menuW / 2) - 200, menuY + menuH + 75, 50, 50, 50, 255, 3, 0, 1)
	renderer.circle(menuX + (menuW / 2) + 201, menuY + menuH + 75, 50, 50, 50, 255, 3, 0, 1)
	surface.draw_filled_rect(menuX + (menuW / 2) - 200, menuY + menuH + 72, 400, 6, 53, 53, 53, 255)

		--VolumeSlider
	renderer.circle(menuX + menuW - 105, menuY + menuH + 48, 50, 50, 50, 255, 3, 0, 1)
	renderer.circle(menuX + menuW - 26, menuY + menuH + 48, 50, 50, 50, 255, 3, 0, 1)
	surface.draw_filled_rect(menuX + menuW - 106, menuY + menuH + 45, 80, 6, 53, 53, 53, 255)

		--hovering
	if not LClick then
		if MouseHudPosX >= startpos.ShflX and MouseHudPosX <= endpos.ShflX and MouseHudPosY >= startpos.ShflY and MouseHudPosY <= endpos.ShflY then
			if ShuffleState == false then
				Shuffle:draw(menuX + (menuW / 2) - 140, menuY + menuH + 24, 30, 30, 255, 255, 255, 255)
			else
				ShuffleA:draw(menuX + (menuW / 2) - 140, menuY + menuH + 24, 30, 30, 255, 255, 255, 255)
			end
			HoveringOver = "shuffle"
		elseif MouseHudPosX >= startpos.PrvX and MouseHudPosX <= endpos.PrvX and MouseHudPosY >= startpos.PrvY and MouseHudPosY <= endpos.PrvY then
			renderer.triangle(menuX + (menuW / 2) - 68, menuY + menuH + 39, menuX + (menuW / 2) - 55, menuY + menuH + 31,menuX + (menuW / 2) - 55, menuY + menuH + 47, 255, 255, 255, 255)
			renderer.rectangle(menuX + (menuW / 2) - 71, menuY + menuH + 31, 3, 16, 255, 255, 255, 255)
			HoveringOver = "previous"
		elseif MouseHudPosX >= startpos.PlpsX and MouseHudPosX <= endpos.PlpsX and MouseHudPosY >= startpos.PlpsY and MouseHudPosY <= endpos.PlpsY then
			renderer.circle_outline(menuX + (menuW / 2), menuY + menuH + 40, 255, 255, 255, 255, 16, 0, 1, 1)
			if PlayState == "Playing" then
				surface.draw_filled_rect(menuX + (menuW / 2) - 5, menuY + menuH + 34, 3, 12, 255, 255, 255, 255)
				surface.draw_filled_rect(menuX + (menuW / 2) + 2, menuY + menuH + 34, 3, 12, 255, 255, 255, 255)
			elseif PlayState == "Paused" then
				renderer.triangle(menuX + (menuW / 2) - 4, menuY + menuH + 34, menuX + (menuW / 2) - 4, menuY + menuH + 46,menuX + (menuW / 2) + 7, menuY + menuH + 40, 255, 255, 255, 255)
			end
			HoveringOver = "playpause"
		elseif MouseHudPosX >= startpos.SkpX and MouseHudPosX <= endpos.SkpX and MouseHudPosY >= startpos.SkpY and MouseHudPosY <= endpos.SkpY then
			renderer.triangle(menuX + (menuW / 2) + 68, menuY + menuH + 39, menuX + (menuW / 2) + 55, menuY + menuH + 31,menuX + (menuW / 2) + 55, menuY + menuH + 47, 255, 255, 255, 255)
			renderer.rectangle(menuX + (menuW / 2) + 68, menuY + menuH + 31, 3, 16, 255, 255, 255, 255)
			HoveringOver = "skip"
		elseif MouseHudPosX >= startpos.RptX and MouseHudPosX <= endpos.RptX and MouseHudPosY >= startpos.RptY and MouseHudPosY <= endpos.RptY then
			if RepeatState == "off" then
				Loop:draw(menuX + (menuW / 2) + 110, menuY + menuH + 26, 25, 25, 255, 255, 255, 255)
			else
				LoopA:draw(menuX + (menuW / 2) + 110, menuY + menuH + 26, 25, 25, 255, 255, 255, 255)
			end
			HoveringOver = "loop"
		else
			HoveringOver = "none"
		end
	end
	HoveringOverElement()

	if MouseHudPosX >= startpos.prgsbrX and MouseHudPosX <= endpos.prgsbrX and MouseHudPosY >= startpos.prgsbrY and MouseHudPosY <= endpos.prgsbrY or UnlockReg then
		if LClick then
			UnlockReg = true
			seekHandler()
		else
			if ProgressBarCache >= 0 then
				renderer.circle(menuX + (menuW / 2) - 200, menuY + menuH + 75, 30, 215, 96, 255, 3, 0, 1)
			end	
			renderer.circle(ProgressBarCache/CurrentDataSpotify.item.duration_ms*402 + menuX + (menuW / 2) - 200, menuY + menuH + 75, 255, 255, 255, 255, 7, 0, 1)
			surface.draw_filled_rect(menuX + (menuW / 2) - 200, menuY + menuH + 72, ProgressBarCache/CurrentDataSpotify.item.duration_ms*402, 6, 30, 215, 96, 255)
		end
	else
		if ProgressBarCache >= 0 then
			renderer.circle(menuX + (menuW / 2) - 200, menuY + menuH + 75, 150, 150, 150, 255, 3, 0, 1)
		end
		renderer.circle(ProgressBarCache/CurrentDataSpotify.item.duration_ms*402 + menuX + (menuW / 2) - 200, menuY + menuH + 75, 150, 150, 150, 255, 3, 0, 1)
		surface.draw_filled_rect(menuX + (menuW / 2) - 200, menuY + menuH + 72, ProgressBarCache/CurrentDataSpotify.item.duration_ms*402, 6, 150, 150, 150, 255)
	end

	if MouseHudrightPosX >= startpos.vlmvbrhX and MouseHudrightPosX <= endpos.vlmvbrhX and MouseHudPosY >= startpos.vlmvbrhY and MouseHudPosY <= endpos.vlmvbrhY or UnlockReg2 then
		if LClick then
			UnlockReg2 = true
			volumeHandler()
		else
			if VolumeBarCache >= 1 then
				renderer.circle(menuX + menuW - 105, menuY + menuH + 48, 30, 215, 96, 255, 3, 0, 1)
			end	
			renderer.circle(menuX + menuW - 105, menuY + menuH + 48, 30, 215, 96, 255, 3, 0, 1)
			renderer.circle(VolumeBarCache/100*80 + menuX + menuW - 105, menuY + menuH + 48, 255, 255, 255, 255, 6, 0, 1)
			surface.draw_filled_rect(menuX + menuW - 106, menuY + menuH + 45, 80/100*VolumeBarCache, 6, 30, 215, 96, 255)
			VolumeSpeaker:draw(menuX + menuW - 140, menuY + menuH + 38, 20, 20, 255, 255, 255, 255)
		end
	else
		if VolumeBarCache >= 1 then
			renderer.circle(menuX + menuW - 105, menuY + menuH + 48, 150, 150, 150, 255, 3, 0, 1)
		end	
		if VolumeBarCache == 100 then
			renderer.circle(VolumeBarCache/100*80 + menuX + menuW - 106, menuY + menuH + 48, 150, 150, 150, 255, 3, 0, 1)
		else
			renderer.circle(VolumeBarCache/100*80 + menuX + menuW - 105, menuY + menuH + 48, 150, 150, 150, 255, 3, 0, 1)
		end
		surface.draw_filled_rect(menuX + menuW - 106, menuY + menuH + 45, 80/100*VolumeBarCache, 6, 150, 150, 150, 255)
		VolumeSpeaker:draw(menuX + menuW - 140, menuY + menuH + 38, 20, 20, 255, 255, 255, 150)
	end

	if OnGoingAnim then
		MenuBarAnimHandler()
	else
		if MenuBarExtended == false then

			function drawmenuImg()
				if Thumbnail ~= nil and not CurrentDataSpotify.item.is_local then
					renderer.rectangle(menuX + 10, menuY + menuH + 10, 75, 75, 10, 10, 10, 255)
					renderer.circle_outline(menuX + 47, menuY + menuH + 47, 64, 64, 64, 255, 30, 0, 1, 3)
					renderer.circle_outline(menuX + 47, menuY + menuH + 47, 64, 64, 64, 255, 10, 0, 1, 3)
					Thumbnail:draw(menuX + 10, menuY + menuH + 10, 75, 75)
				end
			end

			st, rt = pcall(drawmenuImg)
	
			local startposxtr = {
				cvrtX = 10, cvrtY = 10,
				xtbtnX = 15, xtbtnY = 35
			}
	
			local endposxtr = {
				cvrtX = 85, cvrtY = 85,
				xtbtnX = 36, xtbtnY = 58
			}
	
			if MouseHudPosLeftX >= startposxtr.xtbtnX and MouseHudPosLeftX <= endposxtr.xtbtnX and MouseHudPosY >= startposxtr.xtbtnY and MouseHudPosY <= endposxtr.xtbtnY then
				if LClick then
					julliekankermoeders = true
				elseif julliekankermoeders == true then
					julliekankermoeders = false
					MenuBarExtended = true
					OnGoingAnim = true
					MenuBarAnimHandler()
				end
				renderer.gradient(menuX + 10, menuY + menuH + 10, 75, 75, 0, 0, 0, 100, 0, 0, 0, 0, true)
				renderer.circle(menuX + 26, menuY + menuH + 48, 0, 0, 0, 190, 13, 0, 1)
				renderer.line(menuX + 28, menuY + menuH + 40, menuX + 19, menuY + menuH + 48, 255, 255, 255, 255)
				renderer.line(menuX + 28, menuY + menuH + 57, menuX + 19, menuY + menuH + 48, 255, 255, 255, 255)
			elseif MouseHudPosLeftX >= startposxtr.cvrtX and MouseHudPosLeftX <= endposxtr.cvrtX and MouseHudPosY >= startposxtr.cvrtY and MouseHudPosY <= endposxtr.cvrtY then
				renderer.circle(menuX + 26, menuY + menuH + 48, 0, 0, 0, 170, 12, 0, 1)
				renderer.line(menuX + 28, menuY + menuH + 41, menuX + 20, menuY + menuH + 48, 255, 255, 255, 150)
				renderer.line(menuX + 28, menuY + menuH + 56, menuX + 20, menuY + menuH + 48, 255, 255, 255, 150)
			end
		else
			ExtendedMousePosX = rawmouseposX - menuX + 225
			ExtendedMousePosY = rawmouseposY - menuY
			local startposxtr = {
				cvrtX = 0, cvrtY = -225,
				xtbtnX = 192, xtbtnY = -217,
				srchbrX = 20, srchbrY = 12,
				nwplylstX = 21, nwplylstY = 60 + (PlayListCount*30),
				plylstfstX = 15, plylstfstY = 69
			}
	
			local endposxtr = {
				cvrtX = 225, cvrtY = 0,
				xtbtnX = 215, xtbtnY = -195,
				srchbrX = 200, srchbrY = 40,
				nwplylstX = 145, nwplylstY = 80 + (PlayListCount*30),
				plylstfstX = 196, plylstfstY = 80
			}

			function drawbigBalls()
				if Thumbnail ~= nil and not CurrentDataSpotify.item.is_local then
					renderer.rectangle(menuX - 225, menuY + menuH - 225, 225, 225, 10, 10, 10, 255)
					renderer.circle_outline(menuX - 113, menuY + menuH - 113, 64, 64, 64, 255, 100, 0, 1, 5)
					renderer.circle_outline(menuX - 113, menuY + menuH - 113, 64, 64, 64, 255, 20, 0, 1, 5)
					Thumbnail:draw(menuX - 225, menuY + menuH - 225, 225, 225)
				end
			end

			stb, rtb = pcall(drawbigBalls)

			surface.draw_filled_rect(menuX - 225, menuY + menuH - 3, 225, 100, 25, 25, 25, 255)
			surface.draw_text(menuX - 210, menuY + menuH + 23, 255, 255, 255, 255, TitleFontHUD, SongNameHUD)
			surface.draw_text(menuX - 210, menuY + menuH + 53, 159, 159, 159, 255, ArtistFontHUD, ArtistNameHUD)

			if ExtendedMousePosX >= startposxtr.xtbtnX and ExtendedMousePosX <= endposxtr.xtbtnX and MouseHudPosY >= startposxtr.xtbtnY and MouseHudPosY <= endposxtr.xtbtnY then
				if LClick then
					julliekankermoeders = true
				elseif julliekankermoeders == true then
					julliekankermoeders = false
					MenuBarExtended = false
					OnGoingAnim = true
					MenuBarAnimHandler()
				end
				renderer.gradient(menuX - 225 , menuY + menuH - 225, 225, 225, 0, 0, 0, 100, 0, 0, 0, 0, false)
				renderer.circle(menuX - 20, menuY + menuH - 205, 0, 0, 0, 190, 13, 0, 1)
				renderer.line(menuX - 20, menuY + menuH - 199, menuX - 11, menuY + menuH - 209, 255, 255, 255, 255)
				renderer.line(menuX - 20, menuY + menuH - 199, menuX - 29, menuY + menuH - 209, 255, 255, 255, 255)
			elseif ExtendedMousePosX >= startposxtr.cvrtX and ExtendedMousePosX <= endposxtr.cvrtX and MouseHudPosY >= startposxtr.cvrtY and MouseHudPosY <= endposxtr.cvrtY then
				renderer.circle(menuX - 20, menuY + menuH - 205, 0, 0, 0, 170, 12, 0, 1)
				renderer.line(menuX - 20, menuY + menuH - 200, menuX - 12, menuY + menuH - 209, 255, 255, 255, 150)
				renderer.line(menuX - 20, menuY + menuH - 200, menuX - 28, menuY + menuH - 209, 255, 255, 255, 150)
			end
			--Playlist layout
			surface.draw_filled_rect(menuX - 225, menuY, 225, menuH - 225, 19, 19, 19, 255)
			surface.draw_line(menuX - 210, menuY + 50, menuX - 25, menuY + 50, 50, 50, 50, 255)

			--Searchbar
			if SearchSelected then
				if ExtendedMousePosX >= startposxtr.srchbrX and ExtendedMousePosX <= endposxtr.srchbrX and ExtendedMousePosY >= startposxtr.srchbrY and ExtendedMousePosY <= endposxtr.srchbrY then

					if LClick then
						julliekankermoeders = true
					elseif julliekankermoeders == true then
						julliekankermoeders = false
						SearchSelected = false
					end
				end

				surface.draw_filled_rect(menuX - 210, menuY + 11, 185, 30, 50, 50, 50, 255)
				surface.draw_text(menuX - 180, menuY + 17, 255, 255, 255, 255, MainElementFontHUD, "Search")
				renderer.circle_outline(menuX - 197, menuY + 24, 255, 255, 255, 255, 7, 0, 1, 2)
				renderer.line(menuX - 194, menuY + 28, menuX - 188, menuY + 35, 255, 255, 255, 255)
				DrawSubtab("search")
			else
				if ExtendedMousePosX >= startposxtr.srchbrX and ExtendedMousePosX <= endposxtr.srchbrX and ExtendedMousePosY >= startposxtr.srchbrY and ExtendedMousePosY <= endposxtr.srchbrY then
					surface.draw_text(menuX - 180, menuY + 17, 255, 255, 255, 255, MainElementFontHUD, "Search")
					renderer.circle_outline(menuX - 197, menuY + 24, 255, 255, 255, 255, 7, 0, 1, 2)
					renderer.line(menuX - 194, menuY + 28, menuX - 188, menuY + 35, 255, 255, 255, 255)

					if LClick then
						julliekankermoeders = true
					elseif julliekankermoeders == true then
						julliekankermoeders = false
						SearchSelected = true
						PlaylistSelected = false
					end
				else
					surface.draw_text(menuX - 180, menuY + 17, 150, 150, 150, 255, MainElementFontHUD, "Search")
					renderer.circle_outline(menuX - 197, menuY + 24, 150, 150, 150, 255, 7, 0, 1, 2)
					renderer.line(menuX - 194, menuY + 28, menuX - 188, menuY + 35, 150, 150, 150, 255)
				end
			end

			if PlaylistSelected then
				DrawSubtab("playlist")
				surface.draw_text(menuX - 180, menuY + 17, 150, 150, 150, 255, MainElementFontHUD, "Search")
				renderer.circle_outline(menuX - 197, menuY + 24, 150, 150, 150, 255, 7, 0, 1, 2)
				renderer.line(menuX - 194, menuY + 28, menuX - 188, menuY + 35, 150, 150, 150, 255)
			end

			--add playlist button
			if PlaylistLimitReached == false then
				if ExtendedMousePosX >= startposxtr.nwplylstX and ExtendedMousePosX <= endposxtr.nwplylstX and ExtendedMousePosY >= startposxtr.nwplylstY and ExtendedMousePosY <= endposxtr.nwplylstY then
					if LClick then
						julliekankermoeders = true
						surface.draw_text(menuX - 200, menuY + 65 + (30*PlayListCount), 150, 150, 150, 150, MainElementFontHUD, "+  Add Playlist")
					elseif julliekankermoeders == true then
						julliekankermoeders = false
						local CopiedId = CP()
						local ParsedId = string.gsub(CopiedId, "https://open.spotify.com/playlist/", "")
						local jekanker, moeder = string.match(ParsedId, "(.*)?(.*)")
						InitPlaylist(jekanker)
					else
						surface.draw_text(menuX - 200, menuY + 65 + (30*PlayListCount), 255, 255, 255, 255, MainElementFontHUD, "+  Add Playlist")
					end
				else
					surface.draw_text(menuX - 200, menuY + 65 + (30*PlayListCount), 150, 150, 150, 255, MainElementFontHUD, "+  Add Playlist")
				end
			end

			local DrawnPlaylist = 0
			for i, id in ipairs(Playlists) do
				local jekanker, moeder = string.match(Playlists[i].PlaylistName, "(.*),(.*)")
				if ExtendedMousePosX >= startposxtr.plylstfstX and ExtendedMousePosX <= endposxtr.plylstfstX and ExtendedMousePosY >= (startposxtr.plylstfstY + (30*(i-1))) and ExtendedMousePosY <= (endposxtr.plylstfstY + (30*(i-1))) then
					if LClick then
						julliekankermoeders = true
						surface.draw_text(menuX - 210, menuY + 65 + (30*(i-1)), 150, 150, 150, 255, PlayListFontHUD, "> " .. jekanker)
					elseif julliekankermoeders == true then
						julliekankermoeders = false
						SearchSelected = false
						scrollvalue = 0
						LoadPlaylist(Playlists[i].PlaylistName)
					else
						surface.draw_text(menuX - 210, menuY + 65 + (30*(i-1)), 255, 255, 255, 255, PlayListFontHUD, "> " .. jekanker)
					end
				else
					surface.draw_text(menuX - 210, menuY + 65 + (30*(i-1)), 150, 150, 150, 255, PlayListFontHUD, "> " .. jekanker)
				end
				local DrawnPlaylist = DrawnPlaylist + 1
			end
		end
	end
end

function MenuBarAnimHandler()
	
	if MenuBarExtended and AnimSizePerc ~= 200 then
		AnimSizePerc = AnimSizePerc + 4
	elseif not MenuBarExtended and AnimSizePerc ~= 100 then
		AnimSizePerc = AnimSizePerc - 4
	elseif MenuBarExtended and AnimSizePerc == 200 then
		OnGoingAnim = false
	elseif not MenuBarExtended and AnimSizePerc == 100 then
		OnGoingAnim = false
	end
	local tempsize = AnimSizePerc - 175
	local kaasje = AnimSizePerc - 100

	if AnimSizePerc <= 140 then
			if Thumbnail ~= nil and not CurrentDataSpotify.item.is_local then
				Thumbnail:draw(menuX + 10 - (85/40*kaasje), menuY + menuH + 10, 75, 75)
			end
		renderer.rectangle(menuX - (225/40*kaasje), menuY + menuH - 3, 226/40*kaasje, 100, 18, 18, 18, 255)
	elseif AnimSizePerc == 150 then
			if Thumbnail ~= nil and not CurrentDataSpotify.item.is_local then
				Thumbnail:draw(menuX - 225, menuY + menuH + 10, 225, 5)
			end
		renderer.rectangle(menuX - 225, menuY + menuH - 3, 226, 100, 18, 18, 18, 255)
	elseif AnimSizePerc >= 175 then
			if Thumbnail ~= nil and not CurrentDataSpotify.item.is_local then
				Thumbnail:draw(menuX - 225, menuY + menuH + 0 - (225/25*tempsize), 225, 225/25*tempsize)
			end
		renderer.rectangle(menuX - 225, menuY + menuH - 3, 226, 100, 18, 18, 18, 255)
	else
		renderer.rectangle(menuX - 225, menuY + menuH - 3, 226, 100, 18, 18, 18, 255)
	end
	surface.draw_filled_rect(menuX - 225, menuY, 225, menuH - 225, 19, 19, 19, 255/200*AnimSizePerc)
end

function DrawSubtab(subtype) 

	local startposxtr = {
		xtbtnX = 320, xtbtnY = 0,
		scrlX = 10, scrlY = 121,
		sngbtnX = 0, sngbtnY = 120,
		lmbtnX = 118, lmbtnY = menuH
	}

	local endposxtr = {
		xtbtnX = 350, xtbtnY = 30,
		scrlX = 340, scrlY = menuH,
		sngbtnX = 350, sngbtnY = 120,
		lmbtnX = 235, lmbtnY = menuH+23
	}

	surface.draw_filled_rect(menuX + menuW, menuY, 350, menuH+97, 25, 25, 25, 255)
	if MouseHudrightPosX >= startposxtr.xtbtnX and MouseHudrightPosX <= endposxtr.xtbtnX and ExtendedMousePosY >= startposxtr.xtbtnY and ExtendedMousePosY <= endposxtr.xtbtnY then
		if LClick then
			julliekankermoeders = true
			renderer.line(menuX + menuW + 325, menuY + 10, menuX + menuW + 340, menuY + 25, 90, 10, 10, 255)
			renderer.line(menuX + menuW + 325, menuY + 25, menuX + menuW + 340, menuY + 10, 90, 10, 10, 255)
		elseif julliekankermoeders == true then
			julliekankermoeders = false
			SearchSelected = false
			PlaylistSelected = false
		else
			renderer.line(menuX + menuW + 325, menuY + 10, menuX + menuW + 340, menuY + 25, 200, 20, 20, 255)
			renderer.line(menuX + menuW + 325, menuY + 25, menuX + menuW + 340, menuY + 10, 200, 20, 20, 255)
		end
	else
		renderer.line(menuX + menuW + 325, menuY + 10, menuX + menuW + 340, menuY + 25, 90, 90, 90, 255)
		renderer.line(menuX + menuW + 325, menuY + 25, menuX + menuW + 340, menuY + 10, 90, 90, 90, 255)
	end

	switch(subtype) {
		search = function()
			surface.draw_text(menuX + menuW + 15, menuY + 35, 210, 210, 210, 255, SubtabTitleHUD, "Search") 
			surface.draw_filled_gradient_rect(menuX + menuW, menuY + 15, 350, 60, 25, 25, 25, 0, 25, 25, 25, 210, false)
			surface.draw_text(menuX + menuW + 15, menuY + 100, 210, 210, 210, 255, SubtabRowFontHUD, "This feature is still in development :)") 
		end,

		playlist = function()

			local maxvisibletracks = round((menuH-120)/45-1)

			if MouseHudrightPosX >= startposxtr.scrlX and MouseHudrightPosX <= endposxtr.scrlX and ExtendedMousePosY >= startposxtr.scrlY and ExtendedMousePosY <= endposxtr.scrlY then
				if scrollvalue >= 0 then
					scrollmin = true
				else
					scrollmin = false
				end
				if scrollvalue <= (TrackCount*-1+maxvisibletracks) then
					scrollmax = true
				else
					scrollmax = false
				end
				scrollstate:init()
			end

			local fartball2021 = splitByChunk(currplaylistname, 25)
			surface.draw_text(menuX + menuW + 15, menuY + 35, 210, 210, 210, 255, SubtabTitleHUD, fartball2021[1])
			surface.draw_filled_gradient_rect(menuX + menuW, menuY + 15, 350, 60, 25, 25, 25, 0, 25, 25, 25, 210, false)
			surface.draw_filled_gradient_rect(menuX + menuW + 250, menuY + 20, 70, 60, 25, 25, 25, 0, 25, 25, 25, 255, true)
			surface.draw_filled_rect(menuX + menuW + 320, menuY + 20, 30, 60, 25, 25, 25, 255)
			renderer.line(menuX + menuW + 10, menuY + 120, menuX + menuW + 340, menuY + 120, 45, 45, 45, 255)
			surface.draw_text(menuX + menuW + 20, menuY + 95, 100, 100, 100, 255, SubtabRowFontHUD, "#")
			surface.draw_text(menuX + menuW + 48, menuY + 98, 100, 100, 100, 255, SubtabRowFontHUD2, "TITLE")
			renderer.circle_outline(menuX + menuW + 320, menuY + 106, 97, 97, 97, 255, 7, 0, 100, 1)
			renderer.line(menuX + menuW + 320, menuY + 107, menuX + menuW + 320, menuY + 102, 97, 97, 97, 255)
			renderer.line(menuX + menuW + 321, menuY + 106, menuX + menuW + 323, menuY + 106, 97, 97, 97, 255)

			local fart = 1
			for i = maxvisibletracks, 1, -1 do
				if scrollvalue*-1+fart <= TrackCount then
					local n, a, d, u, img = string.match(currplaylist[scrollvalue*-1+fart].SongDetails, "(.*)^(.*)^(.*)^(.*)^(.*)")
					local sussypissyretard = splitByChunk(n, 29)

					if scrollvalue*-1+fart >= 100 then
						surface.draw_text(menuX + menuW + 12, menuY + 95 + (45 * fart), 180, 180, 180, 255, SubtabRowFontHUD2, tostring(scrollvalue*-1+fart))
					elseif scrollvalue*-1+fart >= 10 then
						surface.draw_text(menuX + menuW + 16, menuY + 95 + (45 * fart), 180, 180, 180, 255, SubtabRowFontHUD2, tostring(scrollvalue*-1+fart))
					else
						surface.draw_text(menuX + menuW + 20, menuY + 95 + (45 * fart), 180, 180, 180, 255, SubtabRowFontHUD2, tostring(scrollvalue*-1+fart))
					end

					if Currenturi == u then
						surface.draw_text(menuX + menuW + 48, menuY + 95 + (45 * fart-8), 30, 215, 96, 255, SubtabTrackFontHUD2, sussypissyretard[1])
						surface.draw_filled_rect(menuX + menuW, menuY + 95 + (45 * fart-8), 43, 45, 25, 25, 25, 255)
						surface.draw_text(menuX + menuW + 16, menuY + 91 + (45 * fart), 30, 215, 96, 255, SubtabRowFontHUD3, "►")
					else
						surface.draw_text(menuX + menuW + 48, menuY + 95 + (45 * fart-8), 255, 255, 255, 255, SubtabTrackFontHUD2, sussypissyretard[1])
					end
					
					surface.draw_text(menuX + menuW + 48, menuY + 95 + (45 * fart+12), 150, 150, 150, 255, SubtabArtistFontHUD2, a)
					surface.draw_filled_gradient_rect(menuX + menuW + 270, menuY + 120, 40, menuH, 25, 25, 25, 0, 25, 25, 25, 255, true)

					if MouseHudrightPosX >= startposxtr.sngbtnX and MouseHudrightPosX <= endposxtr.sngbtnX and ExtendedMousePosY >= (startposxtr.sngbtnY + (45*(fart-1))) and ExtendedMousePosY <= (endposxtr.sngbtnY + (45*fart)) then
						if MouseHudrightPosX >= startposxtr.sngbtnX + 300 and MouseHudrightPosX <= endposxtr.sngbtnX and ExtendedMousePosY >= (startposxtr.sngbtnY + (45*(fart-1))) and ExtendedMousePosY <= (endposxtr.sngbtnY + (45*fart)) then
							queuecheck = true
							if LClick then
								julliekankermoeders = true
								surface.draw_text(menuX + menuW + 314, menuY + 89 + (45 * fart), 90, 90, 90, 255, SubtabTitleHUD, "+")
							elseif julliekankermoeders == true then
								julliekankermoeders = false
								queueselected = true
								QueueSong(u)
							else
								surface.draw_text(menuX + menuW + 314, menuY + 89 + (45 * fart), 255, 255, 255, 255, SubtabTitleHUD, "+")
							end
						else
							surface.draw_text(menuX + menuW + 314, menuY + 89 + (45 * fart), 180, 180, 180, 255, SubtabTitleHUD, "+")
							queuecheck = false
						end

						if LClick and not queuecheck then
							julliekankermoeders = true
							renderer.rectangle(menuX + menuW, menuY + 125 + (45 * (fart-1)), 350, 45, 150, 150, 150, 20)
						elseif julliekankermoeders == true and not queuecheck then
							julliekankermoeders = false
							PlaySong(scrollvalue*-1+fart, n, a, img)
						else
							renderer.rectangle(menuX + menuW, menuY + 125 + (45 * (fart-1)), 350, 45, 150, 150, 150, 50)
						end
					else
						surface.draw_text(menuX + menuW + 310, menuY + 96 + (45 * fart), 150, 150, 150, 255, SubtabArtistFontHUD2, msConversion(d))
					end
					fart = fart + 1
				end
			end

			if scrollmax and TrackCount >= 100 then 
				if MouseHudrightPosX >= startposxtr.lmbtnX and MouseHudrightPosX <= endposxtr.lmbtnX and ExtendedMousePosY >= startposxtr.lmbtnY and ExtendedMousePosY <= endposxtr.lmbtnY then
					if LClick and not queuecheck then
						julliekankermoeders = true
						surface.draw_text(menuX + menuW + 118, menuY + menuH, 150, 150, 150, 255, SubtabRowFontHUD3, "LOAD MORE")
					elseif julliekankermoeders == true and not queuecheck then
						julliekankermoeders = false
						AddPlaylist(currplaylisturi)
					else
						surface.draw_text(menuX + menuW + 118, menuY + menuH, 255, 255, 255, 255, SubtabRowFontHUD3, "LOAD MORE")
					end
				else
					surface.draw_text(menuX + menuW + 118, menuY + menuH, 150, 150, 150, 255, SubtabRowFontHUD3, "LOAD MORE")
				end
			end

			if TrackCount > maxvisibletracks then
				renderer.rectangle(menuX + menuW + 342, menuY + 120 + ((maxvisibletracks*44)/(TrackCount-maxvisibletracks))*(scrollvalue)*-1, 3, 10, 90, 90, 90, 255)
			end
		end
	}
end
  
function SpotifyClantag()
	if contains(elements.ExtrasBox, "Print song changes in chat") then
		if CurrentSong ~= SongName then
			print_chat(" \x06[spotify.lua] ♫ \x01Changed song to "..SongName.." by "..ArtistName)
			CurrentSong = SongName
		end
	end

	if not contains(elements.ExtrasBox, "Now playing clantag") then return end
	local splitClantagName = splitByChunk(SongName, 15)
	local splitClantagArtist = splitByChunk(ArtistName, 15)
	if SongName:len() > 15 and ArtistName:len() < 15 then
	  clantagGlizzySweat = {"Listening to", splitClantagName[1], splitClantagName[2], "by", ArtistName, ArtistName}
	elseif SongName:len() > 15 and ArtistName:len() > 15 then 
	  clantagGlizzySweat = {"Listening to", splitClantagName[1], splitClantagName[2], "by", splitClantagArtist[1], splitClantagArtist[2]}
	elseif SongName:len() < 15 and ArtistName:len() > 15 then
		clantagGlizzySweat = {"Listening to", SongName, SongName, "by", splitClantagArtist[1], splitClantagArtist[2]}
	elseif SongName:len() < 15 and ArtistName:len() < 15 then
		clantagGlizzySweat = {"Listening to", SongName, SongName, "by", ArtistName, ArtistName}
	end
	local cur = math.floor(globals.tickcount() / 70) % #clantagGlizzySweat
	local clantag = clantagGlizzySweat[cur+1]
  
	if clantag ~= clantag_prev then
		clantag_prev = clantag
		client.set_clan_tag(clantag)
	end
end

function OnFrame()
	if not apikey then return end 
	
	if client.unix_time() > last_update + ui_get(elements.UpdateRate) then
		loadanim = loadanim .. "."
		UpdateInf()
		UpdateCount = UpdateCount + 1
		last_update = client.unix_time()

		ui_set(elements.SessionUpdates, "Total updates this session: " .. UpdateCount)
		ui_set(elements.TotalErrors, "Errors this session: " .. TotalErrors)
		ui_set(elements.SpreeErrors, "Errors this spree: " .. ErrorSpree)

		if ErrorSpree == ui_get(elements.MaxErrors) or ErrorSpree >= ui_get(elements.MaxErrors) then
			Authed = false
			ErrorSpree = 0
			ShowMenuElements()
			GetApiToken()

			if AuthStatus == "TOKEN" then
				ui_set(elements.Connected, "Connecting".. loadanim)
			end
		end
	end

	if client.unix_time() > last_update_error + ui_get(elements.ErrorRate) then
		ErrorSpree = 0
		ui_set(elements.SpreeErrors,  "Errors this spree: " .. ErrorSpree)
		last_update_error = client.unix_time()
	end

	ShiftClick = client.key_state(0x10)
	if ui_get(MainCheckbox) and Authed then
		LClick = client.key_state(0x01)
		local mousepos = { ui.mouse_position() }
		rawmouseposX = mousepos[1]
		rawmouseposY = mousepos[2]
		
		AdjustSize()
		DrawNowPlaying()
		ShowMenuElements()

		if ui_get(elements.DebugInfo) then
			ui_set(elements.VolumeLabel, "NewVolume: " .. NewVolume)
			ui_set(elements.SpotifyPosition, "Position(x - x2(width), y): " .. SpotifyIndicX .. " - " .. SpotifyIndicX2 .. "(" .. adaptivesize .. "), " .. SpotifyIndicY .. "y")
		end

		if ui_get(elements.IndicType) == "Spotify" then CustomLayout() end
		SpotifyClantag()

		mouseposX = mousepos[1] - SpotifyIndicX
		mouseposY = mousepos[2] - SpotifyIndicY
		if ui.is_menu_open() then
			
			Dragging(); 
			UpdateElements()

			if ui_get(elements.MenuBarEnable) then
				if UnlockReg == true and LClick then
					seekHandler()
				elseif LClick == false and UnlockReg == true then
					UpdateWaitCheck = true
					Seek(SeekedTime)
					UnlockReg = false
				end

				if UnlockReg2 == true and LClick then
					volumeHandler()
				elseif LClick == false and UnlockReg2 == true then
					UpdateWaitCheck = true
					kanker = true
					ChangeVolume(ScrolledVolume)
					UnlockReg2 = false
				end
				if PlayListCount >= 8 then PlaylistLimitReached = true end
				drawHUD()
			end
		end

		if ui_get(elements.ControlSwitch) then
			if NewVolume >= 100 then 
				NewVolume = 100
			elseif NewVolume <= 0 then
				NewVolume = 0
			end 
			MusicControls()
			gaySexgamer()
			VolumeHandler()
			if ui_get(elements.PlayPause) or ui_get(elements.SkipSong) or ui_get(elements.PreviousSong) or ui_get(elements.SmartControls) then
				ControlCheck = true
			else
				ControlCheck = false
			end
			
			if ui_get(elements.IncreaseVolume) or ui_get(elements.DecreaseVolume) then

				NiggerSex = true
				VolumeCheck = true
				SetCheck = false	   

				if globals.tickcount() > last_update_volume_press + 64 then
					FirstPress = false
				end
			else
				last_update_volume_press = globals.tickcount()
				FirstPress = true
				VolumeCheck = false
				StopSpamming = true
			end

			if StopSpamming == false then
				last_update_volume_set = globals.tickcount()
			end

			if FirstPress == false then
				if globals.tickcount() > last_update_volume + ui_get(elements.VolumeTickSpeed) then
					if ui_get(elements.IncreaseVolume) then
						NewVolume = NewVolume + ui_get(elements.VolumeTickAmount)
					elseif ui_get(elements.DecreaseVolume) then
						NewVolume = NewVolume - ui_get(elements.VolumeTickAmount)
					end
					last_update_volume = globals.tickcount()
				end
			end  
		end
	end
end

ShowMenuElements()
ui_set_callback(MainCheckbox, ShowMenuElements)
ui_set_callback(elements.DebugInfo, ShowMenuElements)
ui_set_callback(elements.CustomColors, ShowMenuElements)
ui_set_callback(elements.MenuSize, ChangeMenuSize)
ui_set_callback(elements.ExtrasBox, function() 
	if contains(elements.ExtrasBox, "Higher update rate (experimental)") then 
		ui_set(elements.UpdateRate, 0)
	else
		ui_set(elements.UpdateRate, 1)
	end
end)

local qwq = mouse_state.new()
qwq:init()

client.set_event_callback("paint_ui", OnFrame)
client.set_event_callback("paint", DrawIngame)

client.set_event_callback('shutdown', function()
	database_write("previous_posX", SpotifyIndicX)
	database_write("previous_posY", SpotifyIndicY)
	database_write("previous_size", SelectedSize)
	database_write("StoredKey", apikey)
	database_write("StoredKey2", refreshkey)
	database_write("savedplaylists", Playlists)
	database_write("playlistcache", Playlistcache)
end)