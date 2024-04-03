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

DIRECTORY_WITH_THIS_SCRIPT="${HOME}/.my-bash-environment"
# ----------------------------------------

# Code to execute when starting "sh"
export eval_code_for_sh=""

if pstree --version 2> /dev/null; then
  export IS_PSTREE=1
else
  export IS_PSTREE=0
fi

# Creates variable, which contains full function declaration and body.
# This variable will be exported and be available in "sh" ("sh" can't export functions).
export_function_for_sh() {
  function_name="${1}" && { shift || true; }
  variable_name="${function_name}_EXPORT"

  eval "export ${variable_name}"
  eval "${variable_name}=\"\$(typeset -f \"${function_name}\")\"" || return "$?"

  function_body="
    $(eval "
      if [ -n \"\${${variable_name}}\" ]; then
        echo \"\${${variable_name}}\";
      fi;
    ")
  "

  # Because we will trigger grep on function code, we always be getting true here, so we add another condition
  if { echo "${function_body}" | grep "C_" > /dev/null 2>&1; } && [ "${function_name}" != "export_function_for_sh" ]; then
    is_contains_colors=1
  else
    is_contains_colors=0
  fi

  if [ "${is_contains_colors}" = "1" ]; then
    # Functions with colors we need to specify in PS1 itself, otherwise, the colors will not be shown correctly
    eval_code_for_sh="${eval_code_for_sh}
      ${function_body}
    "
  else
    # Other functions we can call directly - to make PS1 command smaller for performance (very little improvement but still)
    eval_code_for_sh="${eval_code_for_sh}
      eval \"\${${variable_name}}\";
    "
  fi
  unset function_name
  return 0
}
export_function_for_sh export_function_for_sh

sed_escape_from() {
  echo "$@" | sed -e 's/[]\/$*.^;|{}()[]/\\&/g' || return "$?"
  return 0
}
export_function_for_sh sed_escape_from

sed_escape_to() {
  echo "$@" | sed -e 's/[\/&]/\\&/g' || return "$?"
  return 0
}
export_function_for_sh sed_escape_to

# Prints current shell name
get_current_shell() {
  echo "$0" | sed -E 's/^(.*[^a-z]+)?([a-z]+)$/\2/' || return "$?"
  return 0
}
export_function_for_sh get_current_shell

get_process_depth() {
  # "pstree" is not available in MINGW, so we don't return any error
  if [ "${IS_PSTREE}" = "0" ]; then
    echo ""
    return 0
  fi

  # Count all processes, which starts with word "[a-z]*sh" - like "bash", "sh" and others
  pstree --ascii --long --show-parents --hide-threads --arguments $$ | sed -En '/^[[:blank:]]*`-[a-z]*sh( .*$|$)/p' | wc -l || return "$?"
  return 0
}
export_function_for_sh get_process_depth

update_shell_info() {
  CURRENT_SHELL_NAME="$(get_current_shell)" || return "$?"

  # If user is root
  # Second condition is for MINGW in Windows - we are checking for admin rights
  if { [ -z "${MSYSTEM}" ] && [ "$(id --user "$(whoami)")" = "0" ]; } || { [ -n "${MSYSTEM}" ] && sfc 2>&1 | tr -d '\0' | grep "SCANNOW" > /dev/null; }; then
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

  git_part=""
  if git status > /dev/null 2>&1; then
    git_part="
├─"

    git_branch_name="$(git branch 2> /dev/null | sed -En 's/^\* (.+)$/\1/p')" || git_branch_name=""
    if [ -z "${git_branch_name}" ]; then
      # When cloned empty repository
      git_branch_name="$(git status | sed -En 's/^On branch (.+)$/\1/p')"
    fi

    parent_repository="$(git rev-parse --show-superproject-working-tree)"
    # If is submodule
    if [ -n "${parent_repository}" ]; then
      parent_git_branch_name="$(git -C "${parent_repository}" branch 2> /dev/null | sed -En 's/^\* (.+)$/\1/p')" || git_branch_name=""

      if [ -n "${parent_git_branch_name}" ]; then
        git_part="${git_part}${C_BORDER}[${C_TEXT}${parent_git_branch_name}${C_BORDER}]─[submodule]─"
      else
        git_part="${git_part}${C_BORDER}[${C_ERROR}???${C_BORDER}]─[submodule]─"
      fi
    fi

    if [ -n "${git_branch_name}" ]; then
      git_part="${git_part}${C_BORDER}[${C_TEXT}${git_branch_name}${C_BORDER}]"
    else
      git_part="${git_part}${C_BORDER}[${C_ERROR}???${C_BORDER}]"
    fi
  fi

  current_shell_name_to_show=""
  if [ -n "${MSYSTEM}" ]; then
    current_shell_name_to_show="${MSYSTEM}"
  else
    current_shell_name_to_show="${CURRENT_SHELL_NAME}"
  fi

  PARENTS_COUNT="$(get_process_depth)"
  pstree_part=""
  if [ -n "${PARENTS_COUNT}" ]; then
    # We use minus 1 for PARENTS_COUNT because this function was called from this function, so one extra parent
    pstree_part="─[$((PARENTS_COUNT - PS_TREE_MINUS - 1))]"
  fi

  # "get_execution_time" available only for "bash", so we ignore error in "sh"
  execution_time="$(get_execution_time 2> /dev/null)" || true

  # We use env instead of "\"-variables because they do not exist in "sh"
  # ${PWD} = \w
  # ${USER} or ${USERNAME} in MINGW = \u
  # $(hostname) = \h
  my_echo_en "${C_BORDER}└─[${error_code_color}$(printf '%03d' "${command_result#0}")${C_BORDER}]─${execution_time}[$(date +'%Y-%m-%d]─[%a]─[%H:%M:%S')]${C_RESET}

${C_BORDER}┌─[$(whoami)@$(hostname):${C_TEXT}${PWD}${C_BORDER}]${git_part}${C_RESET}
${C_BORDER}├${pstree_part}─[${C_TEXT}${current_shell_name_to_show}${C_BORDER}]─${PS_SYMBOL} ${C_RESET}"

  return 0
}
export_function_for_sh ps1_function

ps2_function() {
  update_shell_info || return "$?"
  my_echo_en "${C_BORDER}├─${C_BORDER}> ${C_RESET}"
  return 0
}
export_function_for_sh ps2_function

export PS_TREE_MINUS
# We save parent shell depth
if [ -z "${PS_TREE_MINUS}" ]; then
  PS_TREE_MINUS="$(get_process_depth)"
fi

# shellcheck disable=2089
export PS1="\$(
  command_result=\"\$?\"
  ${eval_code_for_sh}
  ps1_function
)"

export PS2="\$(
  ${eval_code_for_sh}
  ps2_function
)"

# Empty function for AltLinux (because "sh" in it still will use "function_to_execute_after_command" from parent bash terminal)
function_to_execute_after_command() {
  return 0
}

CURRENT_SHELL_NAME="$(get_current_shell)"
if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
  # shellcheck source=./extra_for_bash.sh
  . "${DIRECTORY_WITH_THIS_SCRIPT}/extra_for_bash.sh"
fi

update_shell_info

# For some reason, "sh" in Alt Linux behaves strangely (partly like "bash", but not fully) - so we fix it here
# We need sudo rights, so we need to run this function by hand
fix_alt_linux() {
  file_path="/etc/bashrc.d/bash_completion.sh"
  if [ ! -f "${file_path}" ]; then
    return 0
  fi

  # shellcheck disable=SC2016
  line_from='if [ "x${BASH_VERSION-}" != x -a "x${PS1-}" != x -a "x${BASH_COMPLETION_VERSINFO-}" = x ]; then'
  # shellcheck disable=SC2016
  line_to='if [ "x${BASH_VERSION-}" != x -a "x${PS1-}" != x -a "x${BASH_COMPLETION_VERSINFO-}" = x ] && echo "$0" | sed -E "s/^(.*[^a-z]+)?([a-z]+)\$/\\2/" | grep bash &> /dev/null; then'

  line_from_escaped="$(sed_escape_from "${line_from}")" || return "$?"
  line_to_escaped="$(sed_escape_to "${line_to}")" || return "$?"

  # shellcheck disable=2086
  ${sudo_prefix}sed -Ei "s/^${line_from_escaped}\$/${line_to_escaped}/" "${file_path}" || return "$?"
}

# ========================================
# Aliases
# ========================================
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
  ls -F --group-directories-first --color -l --human-readable --time-style=long-iso "${@}" | sed -E '/^(total|итого)/d' || return "$?"
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
alias gl="git log --graph --oneline --decorate"
alias ga="git add ."
alias gc="git commit -m"
alias gac="ga && gc"
alias gpush="git push"
alias gpull="git pull"

# TODO: Maybe apply that?
# git config --global core.quotepath false

# Docker aliases
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Networks}}\t{{.Ports}}"'
alias dpsa='dps --all'
alias dc='docker-compose'
alias dcu='docker-compose up -d'
alias dcd='docker-compose down'
alias dcb='docker-compose build'
alias dcbdu='dcb && dcd && dcu'

# Other aliases
alias jctl='journalctl --output=short-full --pager-end --no-hostname --boot=0'

# Not all "su" commands have this option, so we check for that
if { su --help | grep 'whitelist-environment'; } > /dev/null 2>&1; then
  # We need PSTREE_MINUS here to not reset depth level
  alias su='su --whitelist-environment=PS_TREE_MINUS'
fi

# To use aliases in sudo too we add alias for it with space
alias sudo="sudo --preserve-env=PS_TREE_MINUS "
# ========================================
