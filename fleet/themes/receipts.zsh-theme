# receipts.zsh-theme — a prompt that knows whether the tree is proven.
# Works inside oh-my-zsh (custom/themes) AND standalone plain zsh 5.9.
# Segment contract:
#   [lane] branch ✚?  ●(green|red from .pin-last)  path >
# The ● is the wow: your prompt carries the last pin verdict with you.

fleet_prompt_lane() {
  local root
  root=$(fleet_lane_root 2>/dev/null) || return 0
  print -n -r -- "%F{cyan}[${root:t}]%f "
}

fleet_prompt_pin() {
  local root
  root=$(fleet_lane_root 2>/dev/null) || return 0
  local last="$root/.pin-last"
  [[ -r "$last" ]] || return 0
  local v="${$(<"$last")}"
  case "$v" in
    PASS*) print -n -r -- "%F{green}●%f " ;;
    *)     print -n -r -- "%F{red}●%f " ;;
  esac
}

setopt PROMPT_SUBST
PROMPT='$(fleet_prompt_lane)$(fleet_prompt_pin)%F{blue}%~%f %(?.%F{green}.%F{red})❯%f '
RPROMPT='%F{yellow}$(git branch --show-current 2>/dev/null)%f'
