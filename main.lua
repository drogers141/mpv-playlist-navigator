-- OSD Playlist Navigator
-- see keybindings at bottom for behavior

-- Notes
-- line sizing
-- the font-size property of the osd scales to the osd resolution dynamically
-- with a font-size of 35 and a 10 line display, all video sizes can generally
-- show all 10 lines - but the method of scrolling for lists > settings.num_lines
-- ensures no matter what you can always see the cursor
--
-- search mode - like vim - search results list replaces playlist in viewer
-- can select video - thus exiting player
-- or can use the 'handle_exit_key' (ESC) to return to the regular playlist
-- search playlist scrolls like regular playlist

--local utils = require('mp.utils')
local search = require('search_entry')
local pl = require('playlist')

local settings = {
    -- essentially infinity
    osd_duration_seconds = 600,
}

-- properties manager
-- hold custom properties - save defaults
-- invocations at bottom of file
local prop_mgr = {
    properties = {
        osd_font_size = 35,
        osd_color = "#FFFFFF",
        osd_border_size = 2,
        osd_border_color = "#E0404040", --"#000000"
        osd_back_color = "#E0404040"
    },
    defaults = {
        -- commented out are nil by default - (not available to lua yet?)
        osd_font_size = mp.get_property_number("osd-font-size"),
        osd_color = "#CCFFFFFF",   --mp.get_property("osd-color"),
        osd_border_size = mp.get_property_number("osd-border-size"),
        osd_border_color = "#CC000000",   --mp.get_property("osd-border-color"),
        osd_back_color = "#00FFFFFF"    --mp.get_property("osd-back-color")
    }
}

local state = {
    saved_cursor_pos = 0,
    in_search_display = false,
    -- like the playlist from mpv, this will be 0-based
    -- rows are tuple {playlist-index, filename}
    search_filtered_playlist = {},
    search_term = "n/a"
}
function state:print()
    print(string.format(
            "saved_cursor_pos: %s, in_search_display: %s, #search_filtered_playlist: %s, search_term: %s",
            self.saved_cursor_pos, self.in_search_display, #self.search_filtered_playlist, self.search_term))
end

-- entry point for playlist manager
function start_playlist_navigator()
    prop_mgr.set_properties()
    pl:init()
    add_keybindings()
    show_playlist()
end

-- main display
function show_playlist(duration)
    -- debug
    --pl:print()
    --state:print()
    pl:update()
    if pl.len == 0 then
        return
    end

    if pl.active ~= true then
        pl.active = true
        pl.cursor = pl.pos
        -- debug - show active properties
        --prop_mgr.print_defaults()
        --prop_mgr.print_properties()
        --prop_mgr.set_properties()
    end

    output = "Playing: "..mp.get_property('media-title').."\n\n"
    output = output.."Playlist - "..(pl.cursor+1).." / "..pl.len.."        [Enter to load, ESC to quit, / to search]\n"
    output = output..pl:format_lines(pl:get_playlist())
    mp.osd_message(output, (tonumber(duration) or settings.osd_duration_seconds))
end

-- exit from search mode or exit the playlist manager
function handle_exit_key()
    if state.in_search_display then
        pl.cursor = state.saved_cursor_pos
        state.saved_cursor_pos = 0
        state.in_search_display = false
        state.search_filtered_playlist = {}
        state.search_term = "n/a"
        show_playlist()
    else
        exit_playlist_navigator()
    end
end

-- exit the playlist navigator
-- clear the current context
function exit_playlist_navigator()
    mp.osd_message("")
    remove_keybindings()
    prop_mgr.reset_properties()
    pl.active = false
end


function scroll_up()
    pl:increment()
    if state.in_search_display then
        show_search_filtered_playlist()
    else
        show_playlist()
    end
end

function scroll_down()
    pl:decrement()
    if state.in_search_display then
        show_search_filtered_playlist()
    else
        show_playlist()
    end
end

-- remove file from playlist
function remove_file()
    if pl.len == 0 then return end
    mp.commandv("playlist-remove", pl.cursor)
    pl.cursor = pl.cursor - 1
    if pl.cursor < 0 then pl.cursor = 0 end
    -- reload playlist into playlist data structure
    pl:init()
    show_playlist()
end

function handle_enter_key()
    if state.in_search_display then
        -- calculate playlist index
        playlist_index = state.search_filtered_playlist[pl.cursor][1]
        state.in_search_display = false
        load_file(playlist_index)
    else
        load_file(pl.cursor)
    end
end

function show_search_filtered_playlist(duration)
    files_only_array = {}
    -- need 0-based array for line formatting
    for i=0, #state.search_filtered_playlist do
        files_only_array[i] = state.search_filtered_playlist[i][2]
    end
    output = "Files Matching: "..state.search_term.."\n"
    output = output.."[Enter to load file, ESC to return to playlist]\n"
    output = output..pl:format_lines(files_only_array).."\n"
    mp.osd_message(output, (tonumber(duration) or settings.osd_duration_seconds))
end

function on_search_input_done()
    state.in_search_display = true
    -- set up iteration for search results
    state.saved_cursor_pos = pl.cursor
    -- this cursor is just for the ui formatting
    -- the correct index will have to be found if a file is selected
    pl.cursor = 0
    -- prevents gui from showing a false "currently playing" marker
    pl.pos = -1
    state.search_filtered_playlist = pl:filtered_playlist(search.input_string)
    pl.len = #state.search_filtered_playlist + 1
    state.search_term = search.input_string
    for i=0, #state.search_filtered_playlist do
        v = state.search_filtered_playlist[i]
    end
    search.input_string = ""
    show_search_filtered_playlist()
end

function enter_search_input_mode()
    search:enter_input_mode(on_search_input_done)
end

-- load file at playlist_index
-- exits playlist navigator
function load_file(playlist_index)
    mp.commandv("playlist-play-index", playlist_index)
    exit_playlist_navigator()
end

function print_mpv_playlist_props()
    print("Playlist Properties:")
    local playlist_props = {"playlist-pos", "playlist-current-pos",
    "playlist-playing-pos", "playlist-count"}
    for k, v in pairs(playlist_props) do
        print(v, "=>", mp.get_property(v))
    end
    local count = mp.get_property_number("playlist-count")
    print("Playlist subproperties:")
    for i = 0, count-1 do
        local file = "playlist/"..i.."/filename"
        local id = "playlist/"..i.."/id"
        print(file, " = ", mp.get_property(file))
        print(id, " = ", mp.get_property(id))
    end
end

----------------------------------- KEYBINDINGS ----------------------------------------

-- dynamic
-- these bindings are added when showing the playlist and removed after
function add_keybindings()
    mp.add_forced_key_binding('UP', 'scroll_down', scroll_down, "repeatable")
    mp.add_forced_key_binding('k', 'scroll_down2', scroll_down, "repeatable")

    mp.add_forced_key_binding('DOWN', 'scroll_up', scroll_up, "repeatable")
    mp.add_forced_key_binding('j', 'scroll_up2', scroll_up, "repeatable")

    mp.add_forced_key_binding('ENTER', 'handle_enter_key', handle_enter_key)
    mp.add_forced_key_binding('BS', 'remove_file', remove_file)

    mp.add_forced_key_binding('ESC', 'handle_exit_key', handle_exit_key)
    mp.add_forced_key_binding('/', 'enter_search_input_mode', enter_search_input_mode)
    -- uncomment for debug
    --mp.add_forced_key_binding('p','print_mpv_playlist_props', print_mpv_playlist_props)

end

function remove_keybindings()
    mp.remove_key_binding('scroll_down')
    mp.remove_key_binding('scroll_down2')
    mp.remove_key_binding('scroll_up')
    mp.remove_key_binding('scroll_up2')
    mp.remove_key_binding('handle_enter_key')
    mp.remove_key_binding('remove_file')
    mp.remove_key_binding('handle_exit_key')
    mp.remove_key_binding('enter_search_input_mode')
    mp.remove_key_binding('print_mpv_playlist_props')
end

-- static
-- added to mpv when you install the script
mp.add_key_binding('SHIFT+ENTER', 'start_playlist_navigator', start_playlist_navigator)


----------------------------------- DISPLAY PROPERTIES ----------------------------------------

function prop_mgr.set_properties()
    mp.set_property("osd-font-size", prop_mgr.properties.osd_font_size)
    mp.set_property("osd-color", prop_mgr.properties.osd_color)
    mp.set_property("osd-border-size", prop_mgr.properties.osd_border_size)
    mp.set_property("osd-border-color", prop_mgr.properties.osd_border_color)
    mp.set_property("osd-back-color", prop_mgr.properties.osd_back_color)
end
function prop_mgr.reset_properties()
    mp.set_property("osd-font-size", prop_mgr.defaults.osd_font_size)
    mp.set_property("osd-color", prop_mgr.defaults.osd_color)
    mp.set_property("osd-border-size", prop_mgr.defaults.osd_border_size)
    mp.set_property("osd-border-color", prop_mgr.defaults.osd_border_color)
    mp.set_property("osd-back-color", prop_mgr.defaults.osd_back_color)
end
function prop_mgr.print_defaults()
    print("Default Properties:")
    for k,v in pairs(prop_mgr.defaults) do
        print(k, "=>", v)
    end
end
function prop_mgr.print_properties()
    print("Set Properties:")
    for k,v in pairs(prop_mgr.properties) do
        print(k, "=>", v)
    end
end

-- not required - just of interest
function print_osd_properties()
    print("OSD Properties")
    local osd_props = {"osd-width", "osd-height", "osd-par", "osd-sym-cc", "osd-ass-cc", "osd-bar", "osd-bar-align-x",
                       "osd-bar-align-y", "osd-bar-w", "osd-bar-h", "osd-font", "osd-font-size", "osd-color", "osd-border-color",
                       "osd-shadow-color", "osd-back-color", "osd-border-size", "osd-shadow-offset", "osd-spacing", "osd-margin-x",
                       "osd-margin-y", "osd-align-x", "osd-align-y", "osd-blur", "osd-bold", "osd-italic", "osd-justify",
                       "force-rgba-osd-rendering", "osd-level", "osd-duration", "osd-fractions", "osd-scale", "osd-scale-by-window",
                       "term-osd", "term-osd-bar", "term-osd-bar-chars", "osd-playing-msg", "osd-status-msg", "osd-msg1", "osd-msg2",
                       "osd-msg3", "video-osd", "osdlevel",
        -- sub-text properties
                       "sub-text", "subfont-text-scale", "sub-text-font", "sub-text-font-size", "sub-text-color", "sub-text-border-color",
                       "sub-text-shadow-color", "sub-text-back-color", "sub-text-border-size", "sub-text-shadow-offset", "sub-text-spacing",
                       "sub-text-margin-x", "sub-text-margin-y", "sub-text-align-x", "sub-text-align-y", "sub-text-blur", "sub-text-bold",
                       "sub-text-italic"}
    for k, v in pairs(osd_props) do
        print(v, "=>", mp.get_property(v))
    end
end
-- prints at invocation of mpv only (no keybinding needed)
--print_osd_properties()

