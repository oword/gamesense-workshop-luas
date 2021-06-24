local ui_get, globals_mapname = ui.get, globals.mapname

--
-- dependencies
--

local ffi = require "ffi"
local steamworks = require "gamesense/steamworks"
local http = require "gamesense/http"

--
-- read and init db
--

local db = database.read("server_picker")

if type(db) ~= "table" then
	db = {}
end

--
-- steam stuff
--

local ISteamNetworkingUtils = steamworks.ISteamNetworkingUtils

local function get_pop_name(id)
	local text = ffi.cast("const char*", ffi.new("unsigned int[1]", id))

	return ((string.char(text[2]) .. string.char(text[1]) .. string.char(text[0]) .. string.char(text[3])):gsub("%z", ""))
end

local function get_pops()
	local count = ISteamNetworkingUtils.GetPOPCount()
	local out_list_ptr = ffi.new("unsigned int[?]", count)
	ISteamNetworkingUtils.GetPOPList(out_list_ptr, count)

	return count, out_list_ptr
end

local function set_relay_cluster(relay)
	-- print("setting to ", relay, ": ", fakeping_str)

	local fakeping = {}

	if relay ~= "" then
		local count, pops = get_pops()
		for i=1, count do
			local pop = pops[i-1]

			local ping = ISteamNetworkingUtils.GetDirectPingToPOP(pop)

			if ping >= 0 then
				local name = get_pop_name(pop)

				if name == relay then
					table.insert(fakeping, string.format("%s=%d-%d/3+-1", name, client.random_int(8, 30), 2))
				else
					local p = client.random_int(900, 1500)
					table.insert(fakeping, string.format("%s=%d+%d", name, p, p*1.2+client.random_int(100, 200)))
				end
			end
		end

		if cvar.mm_dedicated_search_maxping:get_int() > 40 then
			cvar.mm_dedicated_search_maxping:set_raw_int(40)
			cvar.mm_dedicated_search_maxping:set_raw_float(40)
		end
	else
		cvar.mm_dedicated_search_maxping:set_string(cvar.mm_dedicated_search_maxping:get_string())
	end

	local fakeping_str = table.concat(fakeping, ",")
	local fakeping_ptr = ffi.cast("const char*", fakeping_str)

	if not ISteamNetworkingUtils.SetConfigValue("SDRClient_FakeClusterPing", "Global", 0, "String", fakeping_ptr) then
		error("Failed to set relay cluster!")
	end

	-- local relay_ptr = ffi.cast("const char*", relay)

	-- if not ISteamNetworkingUtils.SetConfigValue("SDRClient_ForceRelayCluster", "Global", 0, "String", relay_ptr) then
	-- 	print("failed to set SDRClient_ForceRelayCluster")
	-- end
end

--
-- js code
--

local js = panorama.loadstring([[
	var panel, panel_dropdown, panel_top_bar
	var update_visibility_callback
	var datacenters = {}
	var datacenters_arr = []
	var ping_measurement = false
	var popup_open = false

	var dropdown_layout, replacement_layout

	var _SetDatacenters = function(_datacenters, _ping_measurement, _datacenters_arr) {
		if(_datacenters != null) {
			datacenters = _datacenters

			if(panel_dropdown != null)
				_UpdateDropdownItems()
		}

		if(_datacenters_arr != null)
			datacenters_arr = _datacenters_arr

		if(_ping_measurement != null) {
			var update = ping_measurement != _ping_measurement
			ping_measurement = _ping_measurement

			if(update && panel_dropdown != null)
				_UpdateDropdownHeader()
		}

		if(popup_open)
			_UpdatePopup()
	}

	var _SetLayouts = function(_dropdown_layout, _replacement_layout) {
		dropdown_layout = _dropdown_layout
		replacement_layout = _replacement_layout
	}

	var _HandleScrollBar = function() {
		if(panel_top_bar == null || panel == null || !panel.IsValid())
			return

		if(panel.desiredlayoutwidth > panel.actuallayoutwidth)
			panel_top_bar.style.overflow = "scroll squish"
	}

	var _Create = function(){
		if(panel != null){
			return false
		}

		var panel_bot_difficulty = $.GetContextPanel().FindChildTraverse("BotDifficultyDropdown")
		if(panel_bot_difficulty != null){
			var panel_parent = panel_bot_difficulty.GetParent()

			if(panel_parent != null){
				panel_top_bar = panel_parent.GetParent()
				panel = $.CreatePanel("Panel", panel_parent, "")

				// debug
				// $.Msg(panel_top_bar.style.width = true ? "100%" : "600px")

				_HandleScrollBar()

				$.Schedule(0.05, _HandleScrollBar)
				$.Schedule(0.1, _HandleScrollBar)
				$.Schedule(0.2, _HandleScrollBar)

				panel_top_bar.SetPanelEvent("onmouseover", _HandleScrollBar)
				panel_top_bar.SetPanelEvent("onmouseout", _HandleScrollBar)

				if (panel != null) {
					panel.SetParent(panel_parent)

					if (panel.BLoadLayoutFromString(dropdown_layout, false, false)) {
						panel_dropdown = panel.FindChildTraverse("ServerPickerDropdown")

						if(panel_dropdown != null){
							update_visibility_callback = $.RegisterForUnhandledEvent("PanoramaComponent_Lobby_MatchmakingSessionUpdate", _UpdateVisibility)
							_UpdateVisibility()
							_UpdateDropdownHeader()

							datacenters_arr.forEach((id) => {
								var datacenter = datacenters[id]

								var panel_datacenter = $.CreatePanel("Label", panel_dropdown, datacenter.id, {
									text: "",
									style: "padding: 0px 0px 0px 0px; margin: 0px 0px 0px 0px; flow-children: right;"
								})

								var panel_img
								if(datacenter.country_code) {
									panel_img = $.CreatePanel("Image", panel_datacenter, "", {
										class: "fix-scale",
										style: "background-color: rgba(0, 0, 0, 0.0); margin: 0px 10px 0px 10px; width: 32px; height: 21px;"
									})

									panel_img.SetImage(`file://{images}/flags/${datacenter.country_code}.png`)
								}

								var panel_name = $.CreatePanel("Label", panel_datacenter, "name", {
									text: datacenter.name,
									style: "letter-spacing: 1px; background-color: rgba(0, 0, 0, 0.0); padding: 10px 5px 10px 0px; margin: 0;"
								})

								panel_datacenter.GetChild(0).style.marginLeft = "25px;"

								var panel_pings = $.CreatePanel("Panel", panel_datacenter, "pings", {
									class: "fix-scale",
									style: "flow-children: down; vertical-align: center; horizontal-align: right; padding: 0; margin: 0;"
								})

								// lines for extra info
								$.CreatePanel("Label", panel_pings, "line-1", {
									text: "500ms",
									style: "text-align: right; horizontal-align: right; margin: 0; padding: 0; font-size: 11; font-family: Stratum2 Regular; letter-spacing: 1px; background-color: rgba(0, 0, 0, 0.0); color: rgba(200, 200, 200, 0.5); margin-right: 18px;"
								})

								$.CreatePanel("Label", panel_pings, "line-2", {
									text: "500ms",
									style: "text-align: right; horizontal-align: right; margin: 0; padding: 0; font-size: 11; font-family: Stratum2 Regular; letter-spacing: 1px; background-color: rgba(0, 0, 0, 0.0); color: rgba(200, 200, 200, 0.6) padding-top: 1px; margin-right: 18px;"
								})

								panel_dropdown.AddOption(panel_datacenter)
							})

							_UpdateDropdownItems()

							panel_dropdown.SetPanelEvent("oninputsubmit", _UpdateDropdownHeader)

							panel_dropdown.SetPanelEvent("onmouseover", function(){
								popup_open = true
								_UpdatePopup()

								_UpdateDropdownItems()
							})

							panel_dropdown.SetPanelEvent("onmouseout", function(){
								popup_open = false
								UiToolkitAPI.HideTextTooltip()

								_UpdateDropdownItems()
							})
						}
					}
				}
			}
		} else {
			return false
		}

		return true
	}

	var _UpdateDropdownHeader = function(){
		var el = panel_dropdown.GetChild(0)
		if(el) {
			if(replacement_layout) {
				el.text = ""

				el.Children().forEach((child) => {
					child.visible = false
					child.DeleteAsync(0.0)
				})

				var container = $.CreatePanel("Panel", el, "", {
					class: "left-right-flow"
				})

				if(ping_measurement) {
					var spinner = $.CreatePanel("Panel", container, "", {
						class: "Spinner",
						style: "margin-right: 5px; max-height: 25px; opacity: 0.8;"
					})
				}

				var replacement = $.CreatePanel("Panel", container, "")
				replacement.BLoadLayoutFromString(replacement_layout, false, false)

				var datacenter = (el.id != "" && datacenters[el.id] != null) ? datacenters[el.id] : null
				if(datacenter != null) {
					replacement.FindChildTraverse("text").text = datacenter.name

					if(datacenter.country_code) {
						var img = replacement.FindChildTraverse("img")
						img.SetImage(`file://{images}/flags/${datacenter.country_code}.png`)
						img.style.visibility = "visible"
					}
				} else {
					replacement.FindChildTraverse("text").text = "Select matchmaking region"
				}

				panel_dropdown.style.opacity = datacenter == null ? 0.44 : 1
			}
		}
	}

	var _UpdateVisibility = function(){
		if(panel_dropdown != null){
			var settings = LobbyAPI.GetSessionSettings()
			panel_dropdown.visible = (settings && settings.options && settings.options.server == "official") == true
		}
	}

	var _UpdateDropdownItems = function(){
		var dropdown_menu = panel_dropdown.AccessDropDownMenu()

		if(!dropdown_menu)
			return

		var uiscale_def = `${(dropdown_menu.actualuiscale_x*100).toFixed(3)}%`
		var uiscale_inv = `${((1/dropdown_menu.actualuiscale_x)*100).toFixed(3)}%`

		dropdown_menu.Children().forEach((child) => {
			child.style.uiScaleX = uiscale_inv

			child.FindChildrenWithClassTraverse("fix-scale").forEach((child2) => {
				child2.style.uiScaleX = uiscale_def
			})

			if(datacenters[child.id]) {
				var dc = datacenters[child.id];

				var line1 = child.FindChildTraverse("line-1")
				var line2 = child.FindChildTraverse("line-2")

				if(dc.direct == null) {
					line1.visible = false
					line2.visible = false
				} else {
					line1.visible = true
					line1.text = `${dc.direct}ms`

					if(dc.relay != null && dc.relay != dc.id) {
						line2.text = `${dc.relay}: ${dc.indirect}ms`
						line2.visible = true
						line1.style.verticalAlign = "top"
					} else {
						line2.visible = false
						line1.style.verticalAlign = "center"
					}
				}
			}
		})
	}

	var _UpdatePopup = function() {
		var current = _GetRelayCluster()
		var text = ["Select matchmaking region"]

		if(current != null && datacenters[current] != null) {
			var datacenter = datacenters[current]

			text.push(`Current: ${datacenter.name} (${datacenter.id}, ${datacenter.direct}ms)`)
		}

		if(ping_measurement)
			text.push("Ping measurement in progress...")

		UiToolkitAPI.ShowTextTooltip("ServerPickerDropdown", text.join("\n"))
	}

	var _GetRelayCluster = function(){
		if(panel_dropdown != null){
			return panel_dropdown.GetSelected().id
		}
	}

	var _SetRelayCluster = function(relay_cluster){
		if(panel_dropdown != null){
			return panel_dropdown.SetSelected(relay_cluster)
			_UpdateDropdownHeader()
		}
	}

	var _Destroy = function(){
		if(panel_top_bar != null) {
			panel_top_bar.ClearPanelEvent("onmouseover")
			panel_top_bar.ClearPanelEvent("onmouseout")

			panel_top_bar.style.overflow = "squish squish"
		}
		if(panel != null) {
			// panel.GetParent().GetParent().style.overflow = "squish squish"

			panel.RemoveAndDeleteChildren()
			panel.DeleteAsync(0.0)
			panel = null
		}
		if(update_visibility_callback != null) {
			$.UnregisterForUnhandledEvent("PanoramaComponent_Lobby_MatchmakingSessionUpdate", update_visibility_callback)
			update_visibility_callback = null
		}
	}

	var _GetLauncherType = function(){
		return MyPersonaAPI.GetLauncherType()
	}

	var _SetVisible = function(visible){
		if(panel != null) {
			panel.visible = visible
		}
	}

	return {
		create: _Create,
		destroy: _Destroy,
		get_relay_cluster: _GetRelayCluster,
		set_relay_cluster: _SetRelayCluster,
		get_launcher_type: _GetLauncherType,
		set_datacenters: _SetDatacenters,
		set_layouts: _SetLayouts,
		set_visible: _SetVisible
	}
]], "CSGOMainMenu")()

-- all datacenters
local datacenters = {}

local active_datacenter_prev = ""
local function update_pings()
	local count, pops = get_pops()

	for i=1, count do
		local pop = pops[i-1]
		local id = get_pop_name(pop)

		if datacenters[id] ~= nil then
			local datacenter = datacenters[id]

			local direct = ISteamNetworkingUtils.GetDirectPingToPOP(pop)

			if direct < 0 then
				if active_datacenter_prev == "" then
					-- print("got negative ping to ", id, " but no forced relay cluster, forcing ping update")
					ISteamNetworkingUtils.CheckPingDataUpToDate(0)
				end
				return
			end

			if direct < 800 and active_datacenter_prev ~= id then
				datacenter.direct = direct
				datacenter.indirect, datacenter.relay = ISteamNetworkingUtils.GetPingToDataCenter(pop)

				datacenter.relay = get_pop_name(datacenter.relay)
			end
		end
	end
end

local function on_created()
	-- set callbacks
	local status_prev, last_update = {}, 0
	client.set_event_callback("paint_ui", function()
		local active_datacenter = js.get_relay_cluster()
		local is_ingame = globals.mapname() ~= nil

		if active_datacenter ~= nil and active_datacenter ~= active_datacenter_prev then
			local _, status = ISteamNetworkingUtils.GetRelayNetworkStatus()

			if datacenters[active_datacenter] ~= nil or active_datacenter == "" then
				-- print("setting to ", active_datacenter)
				db.active_datacenter = active_datacenter
				set_relay_cluster(active_datacenter)
				active_datacenter_prev = active_datacenter

				-- force ping update
				if status.m_bPingMeasurementInProgress == 0 then
					client.delay_call(0.4, function()
						ISteamNetworkingUtils.CheckPingDataUpToDate(0)
					end)
				end
			end
		end

		if not is_ingame then
			local _, status = ISteamNetworkingUtils.GetRelayNetworkStatus()

			if status_prev ~= nil then
				-- update dc info
				local realtime = globals.realtime()

				if status.m_bPingMeasurementInProgress ~= status_prev.m_bPingMeasurementInProgress or (status.m_bPingMeasurementInProgress == 1 and realtime - last_update > 0.2) then
					update_pings()
					js.set_datacenters(datacenters, status.m_bPingMeasurementInProgress == 1)

					last_update = realtime
				end
			end

			status_prev = status
		else
			status_prev = nil
		end
	end)

	client.set_event_callback("shutdown", function()
		js.destroy()

		if db.active_datacenter ~= "" then
			set_relay_cluster("")
			ISteamNetworkingUtils.CheckPingDataUpToDate(0)
		end

		database.write("server_picker", db)
	end)

	local hide_from_obs_reference = ui.reference("MISC", "Settings", "Hide from OBS")
	local function handle_hide_from_obs()
		js.set_visible(not ui.get(hide_from_obs_reference))
	end
	ui.set_callback(hide_from_obs_reference, handle_hide_from_obs)
	handle_hide_from_obs()
end

local function on_datacenters_initialized()
	-- make sure active_datacenter is a valid dc
	if type(db.active_datacenter) ~= "string" or datacenters[db.active_datacenter] == nil then
		db.active_datacenter = ""
	end

	-- create array
	local datacenters_arr = {}
	for id, datacenter in pairs(datacenters) do
		table.insert(datacenters_arr, {datacenter.name, id})
	end

	-- sort alphabetically
	table.sort(datacenters_arr, function(a, b)
		return a[1] < b[1]
	end)

	-- map down to id
	for i, val in ipairs(datacenters_arr) do
		datacenters_arr[i] = val[2]
	end

	js.set_datacenters(datacenters, nil, datacenters_arr)

	local js_layout = [[
	<root>
		<styles>
			<include src="file://{resources}/styles/csgostyles.css" />
		</styles>
		<Panel>
			<DropDown class="PopupButton White hidden" id="ServerPickerDropdown" menuclass="DropDownMenu" style="margin-right: -2px; text-align: right;">
				<Label text="No forced region" id=""/>
			</DropDown>
		</Panel>
	</root>
	]]

	local replacement_layout = [[
	<root>
		<Panel style="padding-top: 3px;" class="left-right-flow">
			<Image id="img" style="padding-right: 8px; visibility: collapse;" />
			<Label id="text" />
		</Panel>
	</root>
	]]

	js.set_layouts(js_layout, replacement_layout)

	local function try_create()
		local success = js.create()

		-- print("try_create: ", success)

		if success then
			js.set_relay_cluster("")

			if db.active_datacenter ~= "" then
				local function fn()
					local _, status = ISteamNetworkingUtils.GetRelayNetworkStatus()

					if status.m_bPingMeasurementInProgress == 0 or true then
						-- print("restored to ", db.active_datacenter)
						js.set_relay_cluster(db.active_datacenter or "")
					else
						-- print("delaying restore")
						client.delay_call(0.1, fn)
					end
				end
				fn()
			end

			on_created()
		else
			client.delay_call(0.1, try_create)
		end
	end

	try_create()
end

local function on_http_response(success, response)
	if not success or response.status ~= 200 then
		return
	end

	-- parse response
	local response_json = json.parse(response.body)

	if response_json.success ~= 1 then
		return
	end

	-- get raw datacenters from game
	local datacenters_raw = {}
	local count, pops = get_pops()

	for i=1, count do
		local pop = pops[i-1]

		local id = get_pop_name(pop)
		local info = {
			i = i,
			id = id
		}

		if response_json.pops[id] ~= nil then
			local json_info = response_json.pops[id]
			info.name = json_info.server_region or json_info.desc

			if info.name:find("_") then
				info.name = json_info.desc
			end

			if json_info.country ~= nil then
				info.country_code = json_info.country.short_name
			end

			info.server_region = json_info.server_region
		else
			info.name = id:upper()
		end

		datacenters_raw[id] = info
	end

	-- filter down to perfectworld / non-perfectworld
	local launcher_type = js.get_launcher_type()
	-- launcher_type = "perfectworld"

	for id, info in pairs(datacenters_raw) do
		local json_info = response_json.pops[id]

		if json_info ~= nil then
			if json_info.server_region ~= nil then
				local groups = json_info.groups or {"valve"}
				if launcher_type == "perfectworld" then
					if #groups == 1 and groups[1] == "perfectworld" then
						datacenters[id] = info
					end
				elseif launcher_type == "steam" then
					for i, group in ipairs(groups) do
						if group == "valve" then
							datacenters[id] = info
							break
						end
					end
				end
			end
		end
	end

	update_pings()

	on_datacenters_initialized()
end

local on_paint_ui_init
function on_paint_ui_init()
	if on_paint_ui_init ~= nil and globals.mapname() == nil then
		-- fetch latest sdr config from my server
		xpcall(http.get, client.error_log, "https://sapphyr.us/sdr-data/v1/config", on_http_response)

		-- only do this once
		client.delay_call(0, client.unset_event_callback, "paint_ui", on_paint_ui_init)

		-- ensure we dont do this more than once!!
		on_paint_ui_init = nil
	end
end

client.set_event_callback("paint_ui", on_paint_ui_init)