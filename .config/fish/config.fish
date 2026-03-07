# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

set fish_greeting ""

function fish_prompt
    printf '%s%s%s ' (set_color green) (prompt_pwd) (set_color normal)
end

set -g fish_color_normal white
set -g fish_color_command green
set -g fish_color_keyword red
set -g fish_color_quote green
set -g fish_color_redirection yellow
set -g fish_color_end green
set -g fish_color_error red
set -g fish_color_param yellow
set -g fish_color_comment fab387
set -g fish_color_selection black --background=white
set -g fish_color_search_match yellow --background=black
set -g fish_color_operator cyan
set -g fish_color_escape cyan
set -g fish_color_valid_path yellow

alias ls='eza -G --icons'
alias hypr='start-hyprland'
