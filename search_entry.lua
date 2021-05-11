-- Handles search entry input

-- Search is case insensitive
-- Search term can contain any characters from AVAILABLE_INPUT_CHARS below
-- essentially this is an osd prompt dialog

-- table to be exported
local search = {
    -- function to call when user finishes entering input
    finished_callback = nil
}

-- characters handled for inputting search
AVAILABLE_INPUT_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ012345689-_.*%?+[]()"

local settings = {
    osd_duration_seconds = 600
}
-- user entered search string
search.input_string = ""

-- entry into search mode
-- input search term
function search:enter_input_mode(callback)
    self.finished_callback = callback
    add_search_keybindings()
    self:show_input()
end


function search:show_input(duration)
    input_line = "Search: "..self.input_string
    mp.osd_message(input_line, (tonumber(duration) or settings.osd_duration_seconds))
end

function handle_search_enter()
    remove_search_keybindings()
    search.finished_callback()
end

function handle_search_escape()
    remove_search_keybindings()
end

function handle_backspace()
    if search.input_string == "" then
        return
    end
    search.input_string = string.sub(search.input_string, 1, -2)
    search:show_input()
end

function handle_input(char)
    search.input_string = search.input_string..char
    search:show_input()
end

local SEARCH_BINDINGS = {}

function add_search_keybindings()
    local bindings = {
        {'BS', handle_backspace},
        {'ENTER', handle_search_enter},
        {'ESC', handle_search_escape},
        {'SPACE', function() handle_input(' ') end}
    }
    for ch in AVAILABLE_INPUT_CHARS:gmatch"." do
        bindings[#bindings + 1] = {ch, function() handle_input(ch) end}
    end
    for i, binding in ipairs(bindings) do
        local key = binding[1]
        local func = binding[2]
        local name = '__search_binding_' .. i
        SEARCH_BINDINGS[#SEARCH_BINDINGS + 1] = name
        mp.add_forced_key_binding(key, name, func, "repeatable")
    end
end

function remove_search_keybindings()
    for i, key_name in ipairs(SEARCH_BINDINGS) do
        mp.remove_key_binding(key_name)
    end
end




return search
