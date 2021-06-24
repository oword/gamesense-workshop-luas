local trailData = {};
local function clearTrails ()
	trailData = {};
end

local enable = ui.new_checkbox("LUA", "a", "Enable Trails");
local segmentEXP = ui.new_slider("LUA", "a", 'Trail Segment Expiration', 1, 100, 10, true, 's', 0.1);
local trailType = ui.new_combobox("LUA", "a", 'Trail Type', 'Line', 'Advanced Line', 'Rect');
local colorType = ui.new_combobox("LUA", "a", 'Trail Color Type', 'Static', 'Chroma', 'Gradient Chroma');
local staticColorValue = ui.new_color_picker("LUA", "a", 'Trail Color', 246, 34, 34, 255);
local chromaSpeedMultiplier = ui.new_slider("LUA", "a", 'Trail Chroma Speed Multiplier', 1, 100, 1, true, '%', 0.1);
local lineSize = ui.new_slider("LUA", "a", 'Line Size', 1, 100, 1, true);
local rectW = ui.new_slider("LUA", "a", 'Rect Width', 1, 100, 1, true);
local rectH = ui.new_slider("LUA", "a", 'Rect Height', 1, 100, 1, true);
local trailXWidth = ui.new_slider("LUA", "a", 'Trail X Width', 1, 100, 1, true);
local trailYWidth = ui.new_slider("LUA", "a", 'Trail Y Width', 1, 100, 1, true);
ui.new_button("LUA", "a", "Clear Trail Data", clearTrails)

local Vector3 = require('vector');

local function getFadeRGB(seed, speed)
	local r = math.floor(math.sin((globals.realtime() + seed) * speed) * 127 + 128)
	local g = math.floor(math.sin((globals.realtime() + seed) * speed + 2) * 127 + 128)
	local b = math.floor(math.sin((globals.realtime() + seed) * speed + 4) * 127 + 128)
	return r, g, b;
end

client.set_event_callback('paint', function()
	local colorType = ui.get(colorType);
	local trailType = ui.get(trailType);
	ui.set_visible(staticColorValue, colorType == 'Static');
	ui.set_visible(chromaSpeedMultiplier, colorType ~= 'Static');
	ui.set_visible(trailXWidth, trailType == 'Advanced Line');
	ui.set_visible(trailYWidth, trailType == 'Advanced Line');
	ui.set_visible(lineSize, trailType == 'Line');
	ui.set_visible(rectW, trailType == 'Rect');
	ui.set_visible(rectH, trailType == 'Rect');
	local lp = entity.get_local_player();
	if (entity.is_alive(lp) and ui.get(enable)) then
		local curTime = globals.curtime();
		local curOrigin = Vector3(entity.get_prop(lp, "m_vecOrigin"));
		if (trailData.lastOrigin == nil) then
			trailData.lastOrigin = curOrigin;
		end
		local dist = curOrigin:dist(trailData.lastOrigin);
		if (trailData.trailSegments == nil) then
			trailData.trailSegments = {};
		end
		if (dist ~= 0) then
			local x, y, z = entity.get_prop(lp, "m_vecOrigin");
			local trailSegment = { pos = curOrigin, exp = curTime + ui.get(segmentEXP) * 0.1, x = x, y = y, z = z };
			table.insert(trailData.trailSegments, trailSegment);
		end
		trailData.lastOrigin = curOrigin;
		for i = #trailData.trailSegments, 1, -1 do
			if (trailData.trailSegments[i].exp < curTime) then
				table.remove(trailData.trailSegments, i);
			end
		end
		for i, segment in ipairs(trailData.trailSegments) do
			local x, y = renderer.world_to_screen(segment.x, segment.y, segment.z)
			local seed = 0;
			if (colorType == 'Gradient Chroma') then
				seed = i;
			end
			if (x ~= nil and y ~= nil) then
				local r, g, b = getFadeRGB(seed, ui.get(chromaSpeedMultiplier) * 0.1);
				if (colorType == 'Static') then
					r, g, b = ui.get(staticColorValue);
				end
				if (trailType == 'Line' or trailType == 'Advanced Line') then
					if (i < #trailData.trailSegments) then
						local segment2 = trailData.trailSegments[i + 1]
						local x2, y2 = renderer.world_to_screen(segment2.x, segment2.y, segment2.z)
						if (x2 ~= nil and y2 ~= nil) then
							if (trailType == 'Advanced Line') then
								for i = 1, ui.get(trailXWidth) do
									renderer.line(x + i, y, x2 + i, y2, r, g, b, 255);
								end
								for i = 1, ui.get(trailYWidth) do
									renderer.line(x, y + i, x2, y2 + i, r, g, b, 255);
								end
							else
								for i = 1, ui.get(lineSize) do
									renderer.line(x + i, y + i, x2 + i, y2 + i, r, g, b, 255);
								end
							end
						end
					end
				else
					-- 255  - (segment.exp - curTime) * 500
					renderer.rectangle(x, y, ui.get(rectW), ui.get(rectH), r, g, b, 255);
				end
			end
		end
	end
end)

client.set_event_callback("round_start", clearTrails);