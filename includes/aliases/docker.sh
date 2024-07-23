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
alias dcl='docker-compose logs'
alias dcps='docker-compose ps'

unalias dcbu > /dev/null 2>&1
dcbu() {
  dcb "$@" && dcu "$@"
  return 0
}

unalias dcbd > /dev/null 2>&1
dcbd() {
  dcb "$@" && dcd "$@"
  return 0
}

unalias dcdu > /dev/null 2>&1
dcdu() {
  dcd "$@" && dcu "$@"
  return 0
}

unalias dcbdu > /dev/null 2>&1
dcbdu() {
  dcb "$@" && dcd "$@" && dcu "$@"
  return 0
}

unalias dce > /dev/null 2>&1
dce() {
  docker-compose exec -it "$@"
  return 0
}

unalias di > /dev/null 2>&1
di() {
  info=$(docker image list --format "${_c_success}{{.Repository}}${_c_text}:${_c_border_usual}{{.Tag}}${_c_text} ({{.Size}})${_c_reset}" --filter "dangling=false" | grep -v '<none>' | sort)
  my_echo_en "${info}" | less -R
  return 0
}
# ----------------------------------------
