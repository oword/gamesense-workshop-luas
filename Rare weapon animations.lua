-- local variables for API functions. any changes to the line below will be lost on re-generation
local bit_band, entity_get_local_player, entity_get_prop, entity_is_alive, entity_set_prop, pairs, ui_get, ui_new_checkbox, ui_new_multiselect, ui_set_visible = bit.band, entity.get_local_player, entity.get_prop, entity.is_alive, entity.set_prop, pairs, ui.get, ui.new_checkbox, ui.new_multiselect, ui.set_visible

local weapons = require "gamesense/csgo_weapons"
local table_clear = require "table.clear"

local function table_map(tbl, func)
	local result = {}
	for key, value in pairs(tbl) do
		result[key] = func(value)
	end
	return result
end

local function table_array_to_keys(tbl)
	local result = {}
	for i=1, #tbl do
		result[tbl[i]] = i
	end
	return result
end

local sequence_overrides = {
	{
		weapon = weapons["weapon_knife_butterfly"],
		overrides = {
			[1] = 0,
			[13] = 15,
			[14] = 15,
		}
	},
	{
		weapon = weapons["weapon_knife_falchion"],
		overrides = {
			[12] = 13,
		}
	},
	{
		weapon = weapons["weapon_knife_ursus"],
		overrides = {
			[0] = 1,
			[14] = 13,
		}
	},
	{
		weapon = weapons["weapon_knife_stiletto"],
		overrides = {
			[13] = 12,
		}
	},
	{
		weapon = weapons["weapon_knife_widowmaker"],
		overrides = {
			[14] = 15,
		}
	},
	{
		weapon = weapons["weapon_knife_skeleton"],
		overrides = {
			[0] = 1,
			[13] = 14,
		}
	},
	{
		weapon = weapons["weapon_knife_canis"],
		overrides = {
			[0] = 1,
			[14] = 13,
		}
	},
	{
		weapon = weapons["weapon_knife_cord"],
		overrides = {
			[0] = 1,
			[14] = 13,
		}
	},
	{
		weapon = weapons["weapon_knife_outdoor"],
		overrides = {
			-- [1] = 0,
			[14] = 13,
		},
		overrides_durations = {
			[1] = 4
		}
	},
	{
		weapon = weapons["weapon_deagle"],
		overrides = {
			[7] = 8,
		}
	},
	{
		weapon = weapons["weapon_revolver"],
		overrides = {
			[3] = 4,
		}
	},
}

local idx_to_overrides = {}

local enabled_reference = ui_new_checkbox("SKINS", "Knife options", "Rare weapon animations")
local active_rare_animations_reference = ui_new_multiselect("SKINS", "Knife options", "\nActive rare animations", table_map(sequence_overrides, function(sequence_override) return sequence_override.name or sequence_override.weapon.name end))
ui_set_visible(active_rare_animations_reference, false)

ui.set_callback(enabled_reference, function()
	ui_set_visible(active_rare_animations_reference, ui_get(enabled_reference))
end)
ui.set_callback(active_rare_animations_reference, function()
	table_clear(idx_to_overrides)

	local active_rare_animations = table_array_to_keys(ui_get(active_rare_animations_reference))
	for i=1, #sequence_overrides do
		local sequence_override = sequence_overrides[i]
		if active_rare_animations[sequence_override.name or sequence_override.weapon.name] ~= nil then
			local idx = sequence_override.weapon.idx
			idx_to_overrides[idx] = idx_to_overrides[idx] or {}

			for key, value in pairs(sequence_override.overrides) do
				idx_to_overrides[idx][key] = value
			end
		end
	end
end)

client.set_event_callback("net_update_start", function()
	if not ui_get(enabled_reference) then return end

	local local_player = entity_get_local_player()
	if local_player == nil or not entity_is_alive(local_player) then return end

	local viewmodel = entity_get_prop(local_player, "m_hViewModel[0]")
	if viewmodel == nil then return end

	local weapon = entity_get_prop(viewmodel, "m_hWeapon")
	if weapon == nil then return end

	local idx = bit_band(entity_get_prop(weapon, "m_iItemDefinitionIndex") or 0, 0xFFFF)
	local sequence_overrides_idx = idx_to_overrides[idx]

	if sequence_overrides_idx ~= nil then
		local sequence = entity_get_prop(viewmodel, "m_nSequence")
		if sequence_overrides_idx[sequence] ~= nil then
			entity_set_prop(viewmodel, "m_nSequence", sequence_overrides_idx[sequence])
		end
	end
end)