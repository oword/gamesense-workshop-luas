local function getKeys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        keys[#keys + 1] = k
    end
    return keys
end

--@region animations
local tag_index, tag_reverse = 0, 0;

local animations = {
    ["Static"] = function(clantag)
        return clantag.text;
    end,
    ["Default"] = function(clantag)
        return tag_index == 0 and "\0" or clantag.text:sub(1, tag_index);
    end,
    ["Reverse"] = function(clantag)
        local tag = clantag.text;
        local tag_length = clantag.text:len();
        return tag_reverse <= tag_length and tag:sub(1, tag_index) or (tag_length - tag_index == 0 and "\0" or tag:sub(1, tag_length - tag_index))
    end,
    ["Loop"] = function(clantag)
        local loop_tag = clantag.text;
        for _ = 1, tag_index do
            loop_tag = loop_tag .. loop_tag:sub(1, 1)
            loop_tag = loop_tag:sub(2, loop_tag:len())
        end
        return loop_tag;
    end,
}

---@region UI
local ui = require("gamesense/swift_ui");
local tab, container = "LUA", "A"
local clantags = database.read("sam_clantags") or {};
local clantagChanger = ui.new_combobox(tab, container, "Clantag Changer", 'Create new', table.unpack(getKeys(clantags)));

local newEntry = {
    ui.new_label(tab, container, "Create new clantag:"),
    ui.new_label(tab, container, "Name"),
    name = ui.new_textbox(tab, container, "Name"),
    ui.new_label(tab, container, "Text"),
    text = ui.new_textbox(tab, container, "Text"),
    animation = ui.new_combobox(tab, container, "Animation", getKeys(animations)),
    speed = ui.new_slider(tab, container, "Speed", 0, 100, 30, true, "%")
}

newEntry['create'] = ui.new_button(tab, container, "Create", function()
    local name, text = newEntry.name:get(), newEntry.text:get();
    if (name == '' or text == '') then
        error("Clantag name/text cannot be empty!");
    end

    clantags[newEntry.name:get()] = {
        text = text;
        animation = newEntry.animation:get(),
        speed = newEntry.speed:get()
    };
    client.reload_active_scripts();
end);

clantagChanger:add_children(newEntry, function(self)
    return self:compare("Create new");
end)

clantagChanger:add_children(ui.new_button(tab, container, "Remove", function()
    clantags[clantagChanger:get()] = nil;
    client.reload_active_scripts();
end), function(self)
    return not self:compare("Create new");
end)

client.set_event_callback('shutdown', function()
    database.write('sam_clantags', clantags);
end)

local old_text;
client.set_event_callback("net_update_end", function()
    local tag = clantagChanger:get();
    local clantag = clantags[tag];

    if (tag == "Create new") then
        clantag = {
            text = newEntry.text:get();
            animation = newEntry.animation:get(),
            speed = newEntry.speed:get()
        };
    end

    local animation = animations[clantag.animation];
    local tag_length = clantag.text:len();
    tag_index = math.floor((globals.curtime() * clantag.speed / 10) % tag_length + 1)
    tag_reverse = math.floor((globals.curtime() * clantag.speed / 10) % (tag_length * 2) + 1);
    local text = animation(clantag)

    if (old_text ~= text) then
        client.set_clan_tag(text);
        old_text = text;
    end
end)