-- OSD Playlist Navigator
-- see keybindings for behavior

-- Notes
-- I had to upgrade libass to HEAD to pickup a fix for osd-back-color
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
local search = require('search')
local pl = require('playlist')

local settings = {
    -- essentially infinity
    osd_duration_seconds = 600,

    --- in search mode you can be in one of two states
    ---    inputting a search string
    ---    showing the list of matching playlist entries
    search_mode_input = 2,
    search_mode_list = 1,
    search_mode_off = 0
}

function settings.print()
    print("Settings:")
    for k,v in pairs(settings) do
        print(k, "=>", v)
    end
end

-- properties manager
-- hold custom properties - save defaults
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
-- prints at invocation of mpv only
--print_osd_properties()


-- entry point for playlist manager
-- as well as general display
function show_playlist(duration)
    pl:print()
    pl:update()
    if pl.len == 0 then
        return
    end
    add_keybindings()

    if pl.active ~= true then
        pl.active = true
        pl.cursor = pl.pos
        prop_mgr.print_defaults()
        prop_mgr.print_properties()
        prop_mgr.set_properties()
    end

    output = "Playing: "..mp.get_property('media-title').."\n\n"
    output = output.."Playlist - "..(pl.cursor+1).." / "..pl.len.."        [ESC to quit]\n"
    output = output..pl:format_lines(pl:get_playlist())
    mp.osd_message(output, (tonumber(duration) or settings.osd_duration_seconds))
end

-- exit from search mode or exit the playlist manager
function handle_exit_key()
    print("Exiting ..")
    exit_playlist()
end

-- exit the playlist manager
-- clear the current context
function exit_playlist()
    mp.osd_message("")
    remove_keybindings()
    prop_mgr.reset_properties()
    pl.active = false
end


function scroll_up()
    pl:increment()
    show_playlist()
end

function scroll_down()
    pl:decrement()
    show_playlist()
end

-- remove file from playlist - probably won't use
function remove_file()
    pl:update()
    if pl.len == 0 then return end
    mp.commandv("playlist-remove", pl.cursor)
    if pl.cursor==pl.len-1 then pl.cursor = pl.cursor - 1 end
    showplaylist()
end

-- enter key - ie load a file in general
-- or select a search term when entering input in search mode
function handle_enter_key()
    load_file()
end

-- load file at cursor
-- exits playlist manager
function load_file()
    mp.commandv("playlist-play-index", pl.cursor)
    exit_playlist()
end

function print_mpv_playlist_props()
    print("Playlist Properties:")
    local playlist_props = {"playlist-pos", "playlist-current-pos",
    "playlist-playing-pos", "playlist-count"}
    for k, v in pairs(playlist_props) do
        print(v, "=>", mp.get_property(v))
    end
    local count = mp.get_property_number("playlist-count")
    print("Playlist sub properties:")
    for i = 0, count-1 do
        local file = "playlist/"..i.."/filename"
        local id = "playlist/"..i.."/id"
        print(file, " = ", mp.get_property(file))
        print(id, " = ", mp.get_property(id))
    end
end
-- keybindings

-- these bindings are added when showing the playlist and removed after
function add_keybindings()
    mp.add_forced_key_binding('UP', 'scroll_down', scroll_down, "repeatable")
    mp.add_forced_key_binding('k', 'scroll_down2', scroll_down, "repeatable")

    mp.add_forced_key_binding('DOWN', 'scroll_up', scroll_up, "repeatable")
    mp.add_forced_key_binding('j', 'scroll_up2', scroll_up, "repeatable")

    mp.add_forced_key_binding('ENTER', 'handle_enter_key', handle_enter_key)
    mp.add_forced_key_binding('BS', 'remove_file', remove_file)

    mp.add_forced_key_binding('ESC', 'handle_exit_key', handle_exit_key)
    mp.add_forced_key_binding('/', 'enter_search_input_mode', search.enter_input_mode)
    mp.add_forced_key_binding('p','print_mpv_playlist_props', print_mpv_playlist_props)

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

-- this is static
mp.add_key_binding('SHIFT+ENTER', 'show_playlist', show_playlist)
