-- exports a playlist manager "object"

-- handles:
-- iterating over the playlist of files
-- formatting either a regular list or circular buffer depending on how long
--   the list is
-- filtering the list by search
-- does not handle the OSD

local utils = require("mp.utils")

local settings = {
    -- number of lines displayed
    num_lines = 10,

    -- display line prefixes
    playing_str = "->",
    cursor_str = ">"
}

-- this object is exported
local playlist = {
    -- index in playlist of currently playing video
    -- assume this is updated before display, including scrolling
    pos = 0,
    -- playlist length
    len = 0,
    -- cursor iterates through playlist - bidirectional
    cursor = 0,
    -- active manager - ie don't reset cursor
    active = false,
    -- the actual playlist
    files = {}
}

function playlist:init()
    self:update()
    self.files = self:get_playlist()
end

-- sync member variables to the values of their mirrored properties
function playlist:update()
    self.pos = mp.get_property_number('playlist-pos', 0)
    self.len = mp.get_property_number('playlist-count', 0)
end

-- cursor movements

function playlist:increment()
    self.cursor = (self.cursor + 1) % self.len
end

function playlist:decrement()
    self.cursor = self.cursor - 1
    if self.cursor == -1 then
        self.cursor = self.len - 1
    end
end

function playlist:print()
    print(string.format("playlist: pos=%s, len=%s, cursor=%s",
            self.pos, self.len, self.cursor))
end

-- get the actual playlist from mpv as an array - 0-based
function playlist:get_playlist()
    local pl = {}
    for i=0, self.len-1, 1
    do
        local l_path, l_file = utils.split_path(mp.get_property('playlist/'..i..'/filename'))
        pl[i] = l_file
    end
    return pl
end

-- functions to prepare output
-- note - the playlist array is 0-based, but lua arrays are usually 1-based
-- so my display arrays are 1-based

-- returns array of strings
function playlist:short_list_display_lines(_playlist)
    local display_files = {}
    for i = 0, #_playlist do
        display_files[i+1] = _playlist[i]
        if i == self.pos then
            display_files[i+1] = settings.playing_str..display_files[i+1]
        end
        if i == self.cursor then
            display_files[i+1] = settings.cursor_str..display_files[i+1]
        end
    end
    return display_files
end

-- handles circular buffer display
-- returns array of strings
function playlist:long_list_display_lines(_playlist)
    local display_files = {}
    local first = self.cursor - settings.num_lines / 2
    if settings.num_lines % 2 == 0 then
        first = first + 1
    end
    local index = 0
    for i = first, first + settings.num_lines - 1 do
        if i < 0 then
            index = #_playlist + 1 + i
        elseif i > #_playlist then
            index = i - (#_playlist + 1)
        else
            index = i
        end
        display_files[#display_files+1] = _playlist[index]
        if index == self.pos then
            display_files[#display_files] = settings.playing_str..display_files[#display_files]
        end
        if index == self.cursor then
            display_files[#display_files] = settings.cursor_str..display_files[#display_files]
        end
    end
    return display_files
end

-- returns multiline string
function playlist:format_lines(_playlist)
    local display_files = {}
    if self.len <= settings.num_lines then
        display_files = self:short_list_display_lines(_playlist)
    else
        display_files = self:long_list_display_lines(_playlist)
    end
    local output = display_files[1]
    for i = 2, #display_files do
        output = output.."\n"..display_files[i]
    end
    return output
end

-- Convert to case insensitive pattern for searching
-- "xyz = %d+ or %% end" --> "[xX][yY][zZ] = %d+ [oO][rR] %% [eE][nN][dD]"
-- not sure if it can handle all corner cases of patterns
-- https://stackoverflow.com/questions/11401890/case-insensitive-lua-pattern-matching
function case_insensitive_pattern(pattern)

    -- find an optional '%' (group 1) followed by any character (group 2)
    local p = pattern:gsub("(%%?)(.)", function(percent, letter)

        if percent ~= "" or not letter:match("%a") then
            -- if the '%' matched, or `letter` is not a letter, return "as is"
            return percent .. letter
        else
            -- else, return a case-insensitive character class of the matched letter
            return string.format("[%s%s]", letter:lower(), letter:upper())
        end

    end)

    return p
end

-- returns 0-based array of {index, filepath} for each file in the playlist
-- where index is the index of the filepath in the playlist
-- search_term - a lua pattern - not quite regexp, but ., *, +, and ? work the same
-- escape with % rather than \
-- matches are case-insensitive
function playlist:filtered_playlist(search_term)
    case_insensitive_term = case_insensitive_pattern(search_term)
    filtered = {}
    f_index = 0
    for i=0, #self.files do
        local filename = self.files[i]
        m = string.match(filename, case_insensitive_term)
        if m and #m > 0 then
            local row = {i, filename}
            filtered[f_index] = row
            f_index = f_index + 1
        end
    end
    return filtered
end

return playlist
