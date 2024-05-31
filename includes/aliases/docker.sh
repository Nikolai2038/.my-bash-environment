#!/bin/bash

# ----------------------------------------
# Docker aliases
# ----------------------------------------
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Networks}}\t{{.Ports}}"'
alias dpsa='dps --all'
alias dc='docker-compose'
alias dcu='docker-compose up --detach --wait'
alias dcd='docker-compose down'
alias dcb='docker-compose build'
alias dcstart='docker-compose start'
alias dcstop='docker-compose stop'
alias dcr='docker-compose restart'
alias dcbu='dcb && dcu'
alias dcbd='dcb && dcd'
alias dcdu='dcd && dcu'
alias dcbdu='dcb && dcd && dcu'
alias dcl='docker-compose logs'
unalias dce > /dev/null 2>&1
dce() {
  docker-compose exec -it "$@" bash
  return 0
}
unalias dcec > /dev/null 2>&1
dcec() {
  container_name="${1}" && { shift || true; }
  docker-compose exec -it "${container_name}" bash -c "$*"
  return 0
}
unalias di > /dev/null 2>&1
di() {
  info=$(docker image list --format "${_C_SUCCESS}{{.Repository}}${_C_TEXT}:${_C_BORDER_USUAL}{{.Tag}}${_C_TEXT} ({{.Size}})${_C_RESET}" --filter "dangling=false" | grep -v '<none>' | sort)
  my_echo_en "${info}" | less -R
  return 0
}
# ----------------------------------------
