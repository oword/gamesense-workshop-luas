local get_prop         = entity.get_prop
local ui_get           = ui.get
local sqrt, sin, cos   = math.sqrt, math.sin, math.cos
local get_local_player = entity.get_local_player
local get_all_players  = entity.get_players
local get_player_name  = entity.get_player_name
local get_screen_size  = client.screen_size
local text             = renderer.text
local deg2rad          = math.rad

local fov_cos      = cos(deg2rad(10))
local show_threats = ui.new_checkbox("VISUALS", "Other ESP", "Show threats")

local function vec3_normalize(x, y, z)
	local len = sqrt(x * x + y * y + z * z)
	if len == 0 then
		return 0, 0, 0
	end
	local r = 1 / len
	return x*r, y*r, z*r
end

local function vec3_dot(ax, ay, az, bx, by, bz)
	return ax*bx + ay*by + az*bz
end

local function angle_to_vec(pitch, yaw)
	local p, y = deg2rad(pitch), deg2rad(yaw)
	local sp, cp, sy, cy = sin(p), cos(p), sin(y), cos(y)
	return cp*cy, cp*sy, -sp
end

local function aiming_at_me(ent, lx, ly, lz)
	local pitch, yaw = get_prop(ent, "m_angEyeAngles")
	if pitch == nil then
		return false
	end

	local ex, ey, ez = angle_to_vec(pitch, yaw)
	local px, py, pz = get_prop(ent, "m_vecOrigin")
	if px == nil then
		return false
	end

	local dx, dy, dz = vec3_normalize(lx-px, ly-py, lz-pz)
	return vec3_dot(dx, dy, dz, ex, ey, ez) > fov_cos
end

local function check_threats()
	local entindex = get_local_player()
	if entindex == nil then
		return false, nil
	end

	local lx, ly, lz = get_prop(entindex, "m_vecOrigin")
	if lx == nil then
		return false, nil
	end

	local players = get_all_players(true)
	for i=1, #players do
		entindex = players[i]
		if aiming_at_me(entindex, lx, ly, lz) then
			return true, get_player_name(entindex) or "An enemy"
		end
	end

	return false, nil
end

local function on_paint()
	local found, name = check_threats()
	if found then
		local sw, sh = get_screen_size()
		text(sw / 2, sh - 100, 255, 255, 50, 255, "c+", 0, name, " is aiming in your direction")
	end
end

local function toggle_callback(item)
	if ui_get(item) then
		client.set_event_callback("paint", on_paint)
	else
		client.unset_event_callback("paint", on_paint)
	end
end

ui.set_callback(show_threats, toggle_callback)