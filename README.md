# mpv-playlist-navigator
Lightweight MPV media player On Screen Display providing easy navigation over the current playlist. 

## Keybindings

| Key | Action | Notes |
| --- | ------ | ----- |
| <kbd>Shift</kbd> + <kbd>Enter</kbd> | Show the navigator OSD | The only static MPV keybinding |
| <kbd>↓</kbd> | scroll down |
| <kbd>k</kbd> | scroll down |
| <kbd>↑</kbd> | scroll up |
| <kbd>j</kbd> | scroll up |
| <kbd>Enter</kbd> | load file at cursor | Both in normal playlist and search OSD |
| <kbd>Backspace</kbd> | remove file at cursor from playlist |
| <kbd>Escape</kbd> | exit navigator OSD without switching from current playing file |
| <kbd>/</kbd> | Open search OSD | 
| <kbd>Escape</kbd> | Exit search OSD back to Playlist OSD |

## Playlist OSD
![Screenshot](https://drogers141.github.io/mpv-playlist-navigator/playlist-1.jpg)
![Screenshot](https://drogers141.github.io/mpv-playlist-navigator/playlist-2.jpg)

## Search OSD
![Screenshot](https://drogers141.github.io/mpv-playlist-navigator/search-input.jpg)
![Screenshot](https://drogers141.github.io/mpv-playlist-navigator/search-listing-1.jpg)
![Screenshot](https://drogers141.github.io/mpv-playlist-navigator/search-listing-2.jpg)

Search is case-insensitive and uses [lua search patterns](https://www.lua.org/pil/20.2.html).
For basics it is like regular expressions '.' matches any character, and '*' is zero or more
repetitions.  So '.*' and substrings gets you pretty far.

## Installation

Clone repo into your [mpv scripts directory](https://github.com/mpv-player/mpv/wiki/User-Scripts) 
or clone anywhere and symlink it there if your operating system supports it.
