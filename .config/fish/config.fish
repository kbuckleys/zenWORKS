# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

set -g -x fish_greeting ''

function fish_prompt
    set_color $fish_color_cwd
    printf '%s ' (prompt_pwd)
end

set -g fish_color_valid_path normal

set fish_cursor_replace_one underscore
set fish_cursor_replace underscore
set fish_cursor_external line
set fish_cursor_visual block
set fish_cursor_default beam
set fish_cursor_insert line

set -g fish_color_operator yellow
set -g fish_color_command green
set -g fish_color_normal white
set -g fish_color_comment red
set -g fish_color_param cyan

set -g fish_color_history_current white
set -g fish_color_search_match bryellow
set -g fish_color_redirection blue
set -g fish_color_selection white
set -g fish_color_escape yellow
set -g fish_color_quote magenta
set -g fish_color_match white
set -g fish_color_host white
set -g fish_color_end white
set -g fish_color_error red

alias ls="eza -G --icons"
