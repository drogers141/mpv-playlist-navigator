-- exports a playlist manager "object"

-- handles:
-- iterating over the playlist of files
-- formatting either a regular list or circular buffer depending on how long
--   the list is
-- does not handle the OSD
-- does not keep a private copy of the playlist - just minimal state

local utils = require("mp.utils")

local settings = {
    -- number of lines displayed
    num_lines = 10,

    -- display line prefixes
    playing_str = "->",
    cursor_str = ">"
}

--
local playlist = {
    -- index in playlist of video that was playing when this was constructed
    pos = 0,
    -- playlist length
    len = 0,
    -- cursor iterates through playlist - bidirectional
    cursor = 0,
    -- active manager - ie don't reset cursor
    active = false
}
-- sync member variables to the values of their mirrored properties
function playlist:update()
    self.pos = mp.get_property_number('playlist-pos', 0)
    self.len = mp.get_property_number('playlist-count', 0)
end

function playlist:increment()
    self:print()
    self.cursor = (self.cursor + 1) % self.len
end

function playlist:decrement()
    self.cursor = self.cursor - 1
    if self.cursor == -1 then
        self.cursor = self.len - 1
    end
end

function playlist:print()
    print("playlist: pos="..self.pos..", len="..self.len..", cursor="..self.cursor)
end

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

-- returns list of strings
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
-- returns returns list of strings
function playlist:long_list_display_lines(_playlist)
    local display_files = {}
    local first = self.cursor - settings.num_lines / 2
    if settings.num_lines % 2 == 0 then
        first = first + 1
    end
    --        print("first="..first..", first + settings.num_lines="..(first + settings.num_lines))
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
        --            print("i="..i..", index="..index)
        --            print("#display_files="..#display_files)
    end
    return display_files
end

-- returns multiline string
function playlist:format_lines(_playlist)
    print("format_lines - pl:")
    self:print()
    local display_files = {}
    if self.len <= settings.num_lines then
        display_files = self:short_list_display_lines(_playlist)
    else
        display_files = self:long_list_display_lines(_playlist)
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

return playlist
