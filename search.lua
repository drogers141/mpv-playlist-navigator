-- Handles search mode where the user can enter a string and navigate the filtered results

local search = {}

-- user entered search string
search.input_string = ""

-- entry into search mode
-- input search term
function search.enter_input_mode()
    add_search_keybindings()
    remove_search_keybindings()
end


function search.show_input(duration)
    input_line = "Search: "..search.input_string
    mp.osd_message(output, (tonumber(duration) or settings.osd_duration_seconds))
end

function handle_search_enter()

end

function handle_search_escape()

end

function handle_backspace()

end

function handle_input(char)

end

local SEARCH_BINDINGS = {}

function add_search_keybindings()
    local bindings = {
        {'BS', handle_backspace},
        {'ENTER', handle_search_enter},
        {'ESC', handle_search_escape},
        {'SPACE', function() handle_input(' ') end}
    }
    local input_chars = "abcdefghijklmnopqrstuvwxyz-_."
    for ch in input_chars:gmatch"." do
        bindings[#bindings + 1] = {ch, function() handle_input(ch) end}
    end
    for i, binding in ipairs(bindings) do
        local key = binding[1]
        local func = binding[2]
        local name = '__search_binding_' .. i
        SEARCH_BINDINGS[#SEARCH_BINDINGS + 1] = name
        mp.add_forced_key_binding(key, name, func, "repeatable")
        print("Added binding: "..name)
    end
end

function remove_search_keybindings()
    for i, key_name in ipairs(SEARCH_BINDINGS) do
        mp.remove_key_binding(key_name)
        print("removed binding: "..key_name)
    end
end




return search
