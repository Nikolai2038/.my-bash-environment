#!/bin/sh

# ----------------------------------------
# Settings
# ----------------------------------------
export EDITOR=vim

# We need "\[" and "\]" to help bash understand, that it is colors (otherwise bash will break when we navigate in commands history).
# But we add them in get_function_definition_with_colors_replaced.
export _C_TEXT="\033[38;5;02m"
export _C_ERROR="\033[38;5;01m"
export _C_SUCCESS="\033[38;5;02m"
export _C_BORDER_USUAL="\033[38;5;27m"
export _C_BORDER_ROOT="\033[38;5;90m"
export _C_RESET='\e[0m'

# From 1 to 9 - The number of decimals for the command execution time
export accuracy=2

export PS_TREE_MINUS=9

DIRECTORY_WITH_THIS_SCRIPT="${HOME}/.my-bash-environment"
# ----------------------------------------

# ----------------------------------------
# Calculations
# ----------------------------------------
# We need to calculate this via loop, because in sh operator "**" does not exist
export accuracy_tens=1
i=0
while [ "${i}" -lt "${accuracy}" ]; do
  accuracy_tens="$((accuracy_tens * 10))"
  i="$((i + 1))"
done
# ----------------------------------------

# Code to execute when starting "sh"
export eval_code_for_sh=""

if pstree --version 2> /dev/null; then
  export IS_PSTREE=1
else
  export IS_PSTREE=0
  echo 'Command "pstree" not found! It is needed to show shell depth level is "PS1". Try "sudo apt-get install -y psmisc" to install it.' >&2
fi

# Creates variable, which contains full function declaration and body.
# This variable will be exported and be available in "sh" ("sh" can't export functions).
export_function_for_sh() {
  function_name="${1}" && { shift || true; }
  eval "export ${function_name}_EXPORT"
  eval "${function_name}_EXPORT=\"\$(typeset -f \"${function_name}\")\"" || return "$?"
  eval_code_for_sh="${eval_code_for_sh}
    $(eval "
      if [ -n \"\${${function_name}_EXPORT}\" ]; then
        echo \"\${${function_name}_EXPORT}\";
      fi;
    ")
  "
  unset function_name
  return 0
}
export_function_for_sh export_function_for_sh

sed_escape() {
  echo "$@" | sed -e 's/[]\/$*.^;|{}()[]/\\&/g' || return "$?"
  return 0
}
export_function_for_sh sed_escape

# Prints current shell name
get_current_shell() {
  echo "$0" | sed 's/[^a-z]//g' || return "$?"
  return 0
}
export_function_for_sh get_current_shell

get_process_depth() {
  if [ "${IS_PSTREE}" = "0" ]; then
    echo "${PS_TREE_MINUS}"
    return 0
  fi

  # Head to hide sub pipelines.
  # Remember, that "wc" command also counts.
  pstree --ascii --long --show-parents --hide-threads --arguments $$ | sed -E '/^[[:blank:]]+`-(sudo .+|su .+|su)$/d' | wc -l || return "$?"
  return 0
}
export_function_for_sh get_process_depth

update_shell_info() {
  CURRENT_SHELL_NAME="$(get_current_shell)" || return "$?"

  # If user is root
  if [ "$(id --user "${USER}")" = "0" ]; then
    export _C_BORDER="${_C_BORDER_ROOT}"
    export sudo_prefix=""
    export PS_SYMBOL="#"
  else
    export _C_BORDER="${_C_BORDER_USUAL}"
    export sudo_prefix="sudo "
    export PS_SYMBOL='$'
  fi

  if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
    # Braces "\[" and "\]" are required, so "bash" can understand, that this is colors and not output.
    # If we do not use them, the shell will break when we try to navigate in commands' history.
    C_TEXT="\[${_C_TEXT}\]"
    C_ERROR="\[${_C_ERROR}\]"
    C_SUCCESS="\[${_C_SUCCESS}\]"
    C_BORDER="\[${_C_BORDER}\]"
    C_RESET="\[${_C_RESET}\]"
  else
    # "sh" does not have commands' history, and braces will result in just text, so we don't use them here
    C_TEXT="${_C_TEXT}"
    C_ERROR="${_C_ERROR}"
    C_SUCCESS="${_C_SUCCESS}"
    C_BORDER="${_C_BORDER}"
    C_RESET="${_C_RESET}"
  fi
  return 0
}
export_function_for_sh update_shell_info

my_echo_en() {
  if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
    # shellcheck disable=SC3037
    echo -en "$@"
  else
    # We don't need "-e" in "sh" (and it does not recognize "-e" option anyway), so we do not use it
    # shellcheck disable=SC3037
    echo -n "$@"
  fi
}
export_function_for_sh my_echo_en

ps1_function() {
  update_shell_info || return "$?"

  error_code_color="${C_ERROR}"
  if [ "${command_result}" -eq 0 ]; then
    error_code_color="${C_SUCCESS}"
  fi

  PARENTS_COUNT="$(get_process_depth)"

  # We use env instead of "\"-variables because they do not exist in "sh"
  # ${PWD} = \w
  # ${USER} = \u
  # $(hostname) = \h
  my_echo_en "${C_BORDER}└─[${error_code_color}$(printf '%03d' "${command_result#0}")${C_BORDER}]─[${USER}@$(hostname):${C_TEXT}${PWD}${C_BORDER}]${C_RESET}

${C_BORDER}┌─[$((PARENTS_COUNT - PS_TREE_MINUS))]─[${CURRENT_SHELL_NAME}]─${PS_SYMBOL} ${C_RESET}"

  return 0
}
export_function_for_sh ps1_function

ps2_function() {
  my_echo_en "${C_BORDER}├─${C_BORDER}> ${C_RESET}"
  return 0
}
export_function_for_sh ps2_function

# shellcheck disable=2089
export PS1="\$(
  command_result=\"\$?\"
  ${eval_code_for_sh}
  ps1_function
)"

export PS2='$(
  ps2_function
)'

update_shell_info

# ========================================
# Aliases
# ========================================
# To use aliases in sudo too
alias sudo="sudo "

# We use some functions as aliases.
# But we must unalias functions' names if they exist, because alias has more priority than function.

# ----------------------------------------
# ls aliases
# ----------------------------------------
# 1. Detailed list
unalias lls > /dev/null 2>&1
lls() {
  # We use "sed" to remove "total".
  # shellcheck disable=SC2012
  ls -F --group-directories-first --color -l --human-readable --time-style=long-iso "${@}" | sed '/^(total|всего)/d' || return "$?"
  return 0
}

# 2. Detailed list with hidden files
alias llas="lls --almost-all"
alias llsa="llas"

# 3. Simple list
unalias ll > /dev/null 2>&1
ll() {
  # We don't use "-1" from "ls" because it does not show us where links are pointing.
  # Instead, we use "cut".
  # We use "tr" to remove duplicate spaces - for "cut" to work properly.
  lls "${@}" | tr -s '[:blank:]' | cut -d ' ' -f 8- || return "$?"
  return 0
}

# 4. Simple list with hidden files
alias lla="ll --almost-all"

# 5. Simple list without hidden files (Markdown format)
unalias llm > /dev/null 2>&1
llm() {
  # shellcheck disable=2016
  ll "${@}" | sed -E 's/^(.*)$/- `\1`;/' || return "$?"
  return 0
}

# 6. Simple list with hidden files (Markdown format)
alias llam="llm --almost-all"
alias llma="llam"
# ----------------------------------------

# Use as alias but without space
unalias examples > /dev/null 2>&1
examples() {
  less -R << EOF
$(curl "https://cheat.sh/${*}")
EOF
  return 0
}

# APT aliases
# (This is not working in this script, so we still use "apt-get" everywhere here)
alias apt="apt-get"
# shellcheck disable=2139
alias au="${sudo_prefix}apt-get update && ${sudo_prefix}apt-get dist-upgrade -y && ${sudo_prefix}apt-get autoremove -y"
unalias ai > /dev/null 2>&1
ai() {
  # shellcheck disable=2086
  ${sudo_prefix}apt-get update || return "$?"
  # shellcheck disable=2086
  ${sudo_prefix}apt-get install -y "$@" || return "$?"
  # shellcheck disable=2086
  ${sudo_prefix}apt-get autoremove -y || return "$?"
  return 0
}
unalias ar > /dev/null 2>&1
ar() {
  # shellcheck disable=2086
  ${sudo_prefix}apt-get remove -y "$@" || return "$?"
  # shellcheck disable=2086
  ${sudo_prefix}apt-get autoremove -y || return "$?"
  return 0
}

# GIT aliases
alias gs="git status"
alias gl="git log --pretty=oneline"
alias ga="git add ."
alias gc="git commit -m"
alias gac="ga && gc"
alias gpush="git push"
alias gpull="git pull"

# Docker aliases
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Networks}}\t{{.Ports}}"'
alias dpsa='dps --all'
# ========================================

if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
  # shellcheck source=./extra_for_bash.sh
  . "${DIRECTORY_WITH_THIS_SCRIPT}/extra_for_bash.sh"
fi
