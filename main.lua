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


local utils = require('mp.utils')
local search = require('search')

local settings = {
    -- essentially infinity
    osd_duration_seconds = 600,

    -- number of lines displayed
    num_lines = 10,

    -- display line prefixes
    playing_str = "->",
    cursor_str = ">",

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


-- playlist context
local pl = {
    -- index in playlist of currently playing video
    pos = 0,
    -- playlist length
    len = 0,
    -- cursor iterates through playlist - bidirectional
    cursor = 0,
    -- active manager - ie don't reset cursor
    active = false,
    -- in search mode - see settings
    search_mode = settings.search_mode_off,

}
-- sync member variables to the values of their mirrored properties
function pl.update()
    pl.pos = mp.get_property_number('playlist-pos', 0)
    pl.len = mp.get_property_number('playlist-count', 0)
end
-- increment cursor
function pl.increment()
    pl.cursor = (pl.cursor + 1) % pl.len
end
-- decrement cursor
function pl.decrement()
    pl.cursor = pl.cursor - 1
    if pl.cursor == -1 then
        pl.cursor = pl.len - 1
    end
end
function pl.print()
    print("playlist context: pos="..pl.pos..", len="..pl.len..", cursor="..pl.cursor)
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


function get_playlist()
    local playlist = {}
    for i=0, pl.len-1, 1
    do
        local l_path, l_file = utils.split_path(mp.get_property('playlist/'..i..'/filename'))
        playlist[i] = l_file
    end
    return playlist
end


-- functions to prepare output
-- note - the playlist array is 0-based, but lua arrays are usually 1-based
-- so my display arrays are 1-based

-- return list of strings
function _short_list_display_lines(playlist)
    local display_files = {}
    for i = 0, #playlist do
        display_files[i+1] = playlist[i]
        if i == pl.pos then
            display_files[i+1] = settings.playing_str..display_files[i+1]
        end
        if i == pl.cursor then
            display_files[i+1] = settings.cursor_str..display_files[i+1]
        end
    end
    return display_files
end

-- handles circular buffer display
-- returns returns list of strings
function _long_list_display_lines(playlist)
    local display_files = {}
    local first = pl.cursor - settings.num_lines / 2
    if settings.num_lines % 2 == 0 then
        first = first + 1
    end
--        print("first="..first..", first + settings.num_lines="..(first + settings.num_lines))
    local index = 0
    for i = first, first + settings.num_lines - 1 do
        if i < 0 then
            index = #playlist + 1 + i
        elseif i > #playlist then
            index = i - (#playlist + 1)
        else
            index = i
        end
        display_files[#display_files+1] = playlist[index]
        if index == pl.pos then
            display_files[#display_files] = settings.playing_str..display_files[#display_files]
        end
        if index == pl.cursor then
            display_files[#display_files] = settings.cursor_str..display_files[#display_files]
        end
--            print("i="..i..", index="..index)
--            print("#display_files="..#display_files)
    end
    return display_files
end

-- returns multiline string
function format_lines(playlist)
--    pl.print()
    local display_files = {}
    if pl.len <= settings.num_lines then
        display_files = _short_list_display_lines(playlist)
    else
        display_files = _long_list_display_lines(playlist)
    end
--    print("display_files:")
--    for i,v in pairs(display_files) do
--        print("display_files["..i.."] = "..v)
--    end
    local output = display_files[1]
    for i = 2, #display_files do
        output = output.."\n"..display_files[i]
    end
    return output
end


-- entry point for playlist manager
-- as well as general display
function show_playlist(duration)
    pl.update()
--    pl.print()
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
    output = output..format_lines(get_playlist())
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
    pl.increment()
    show_playlist()
end

function scroll_down()
    pl.decrement()
    show_playlist()
end

-- remove file from playlist - probably won't use
function remove_file()
    pl.update()
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
    pl.update()
    if pl.len == 0 then return end
    if pl.cursor < pl.pos then
        for x=1,math.abs(pl.cursor-pl.pos),1 do
            mp.commandv("playlist-prev", "weak")
        end
    elseif pl.cursor>pl.pos then
        for x=1,math.abs(pl.cursor-pl.pos),1 do
            mp.commandv("playlist-next", "weak")
        end
    else
        if pl.cursor~=pl.len-1 then
            pl.cursor = pl.cursor + 1
        end
        mp.commandv("playlist-next", "weak")
    end
    exit_playlist()
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
end

-- this is static
mp.add_key_binding('SHIFT+ENTER', 'show_playlist', show_playlist)
