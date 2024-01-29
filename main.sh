#!/bin/bash

# ----------------------------------------
# Settings
# ----------------------------------------
export EDITOR=vim

# We need "\[" and "\]" to help bash understand, that it is colors (otherwise bash will break when we navigate in commands history).
# But we add them in get_function_definition_with_colors_replaced.
export C_TEXT="\033[38;5;02m"
export C_ERROR="\033[38;5;01m"
export C_SUCCESS="\033[38;5;02m"
export C_BORDER_USUAL="\033[38;5;27m"
export C_BORDER_ROOT="\033[38;5;90m"

# From 1 to 9 - The number of decimals for the command execution time
export accuracy=2
# ----------------------------------------

# ----------------------------------------
# Calculations
# ----------------------------------------
export C_RESET
C_RESET="$(tput sgr0)"

if [ "$(id --user "${USER}")" = "0" ]; then
  export is_root=1
  export sudo_prefix=""
else
  export is_root=0
  export sudo_prefix="sudo "
fi

# Different color for root
if [ "${is_root}" = "1" ]; then
  export C_BORDER="${C_BORDER_ROOT}"
else
  export C_BORDER="${C_BORDER_USUAL}"
fi

# We need to calculate this in bash, because in sh (if we go to it) operator "**" does not exist
export accuracy_tens="$((10 ** accuracy))"

functions_to_use=""

# Must not use export here!
current_shell=""
# We make function to find shell name
get_current_shell () {
  if [ -z "${current_shell}" ]; then
    current_shell="$(/bin/ps -p $$ -o 'comm=')"
  fi

  echo "${current_shell}"
  return 0
}
# Because "sh" can't export functions, we use variables
export get_current_shell_script
get_current_shell_script="$(typeset -f get_current_shell)"
functions_to_use="${functions_to_use}${get_current_shell_script};"
# Update function body (we replaced colors' variables with their values)
eval "${get_current_shell_script}"
# ----------------------------------------

# ----------------------------------------
# From Debian .bashrc
# ----------------------------------------
# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize
# ----------------------------------------

sed_escape() {
    echo "$@" | sed -e 's/[]\/$*.^;|{}()[]/\\&/g' || return "$?"
    return 0
}

# We must specify colors in PS1 variable (or they won't work inside script inside PS1)
get_function_definition_with_colors_replaced() {
  local function_name="$1" && { shift || true; }

  local open_brace_script='$(if [ "$(get_current_shell)" = "bash" ]; then echo "\["; fi)'
  local close_brace_script='$(if [ "$(get_current_shell)" = "bash" ]; then echo "\]"; fi)'

  typeset -f "${function_name}" | \
    sed -E "s/$(sed_escape "\${C_TEXT}")/$(sed_escape "${open_brace_script}${C_TEXT}${close_brace_script}")/g" | \
    sed -E "s/$(sed_escape "\${C_ERROR}")/$(sed_escape "${open_brace_script}${C_ERROR}${close_brace_script}")/g" | \
    sed -E "s/$(sed_escape "\${C_SUCCESS}")/$(sed_escape "${open_brace_script}${C_SUCCESS}${close_brace_script}")/g" | \
    sed -E "s/$(sed_escape "\${C_BORDER}")/$(sed_escape "${open_brace_script}${C_BORDER}${close_brace_script}")/g" | \
    sed -E "s/$(sed_escape "\${C_RESET}")/$(sed_escape "${open_brace_script}${C_RESET}${close_brace_script}")/g" || return "$?"
  return 0
}
# Because "sh" can't export functions, we use variables
export get_function_definition_with_colors_replaced_script
get_function_definition_with_colors_replaced_script="$(typeset -f get_function_definition_with_colors_replaced)"
functions_to_use="${functions_to_use}${get_function_definition_with_colors_replaced_script};"
# Update function body (we replaced colors' variables with their values)
eval "${get_function_definition_with_colors_replaced_script}"

# For some reason, "echo" in "sh" does not recognize "-e" option, so we do not use it
my_echo_en() {
  local shell
  shell="$(get_current_shell)"

  if [ "${shell}" = "sh" ]; then
    echo -n "$@"
  else
    echo -en "$@"
  fi
}
# Because "sh" can't export functions, we use variables
export my_echo_en_script
my_echo_en_script="$(get_function_definition_with_colors_replaced my_echo_en)"
functions_to_use="${functions_to_use}${my_echo_en_script};"
# Update function body (we replaced colors' variables with their values)
eval "${my_echo_en_script}"

is_first_shell() {
  if ! pstree --version 2> /dev/null; then
    echo 0
    return 0
  fi

  # Number of last processes to ignore
  local level="${1}" && { shift || true; }

  local was_sh=0
  # Remove minimum last 5 processes: subshell, function call, subshell, "pstree" and "head".
  # Also remove spaces, so we can iterate over processes
  local tree_as_string
  tree_as_string="$(pstree -aps $$ | head -n -"${level}" | tr -d '[:blank:]')"
  local line
  for line in ${tree_as_string}; do
    local name
    name=$(echo "${line}" | sed -En 's/^[^a-zA-Z]*?([a-zA-Z]+)[^a-zA-Z]+?.*?$/\1/p')

    # We will find a first process, which ends with "sh" - we assume it is our first shell
    if echo "${name}" | grep -e '^.*sh$' > /dev/null; then
      if [ "${was_sh}" = "1" ]; then
        echo 0
        return 0
      fi
      was_sh=1
    fi
  done

  echo 1
  return 0
}
# Because "sh" can't export functions, we use variables
export is_first_shell_script
is_first_shell_script="$(get_function_definition_with_colors_replaced is_first_shell)"
functions_to_use="${functions_to_use}${is_first_shell_script};"
# Update function body (we replaced colors' variables with their values)
eval "${is_first_shell_script}"

# We do not display information about the execution of the last command for the very first output in the session
export is_first_command=-1
alias clear="is_first_command=-1; clear"
alias reset="is_first_command=-1; reset"

is_command_executing=0

get_seconds_parts() {
  local seconds
  seconds="$(date +%s)" || return "$?"

  local extra_second_parts
  extra_second_parts="$(date +%N)" || return "$?"
  # DEBUG:
  # echo "1 extra_second_parts: '${extra_second_parts}'" >&2

  # Remove leading zeros (to avoid "printf: invalid octal number" error)
  extra_second_parts="${extra_second_parts#"${extra_second_parts%%[!0]*}"}"
  # DEBUG:
  # echo "2 extra_second_parts: '${extra_second_parts}'" >&2

  extra_second_parts="$(printf '%09d' "${extra_second_parts}")" || return "$?"
  # DEBUG:
  # echo "3 extra_second_parts: '${extra_second_parts}'" >&2

  # Method 1: This method does not work in "sh" (but we don't calculate time there)
  extra_second_parts="${extra_second_parts:0:accuracy}" || return "$?"
  # Method 2: This method works in "sh" (but we don't calculate time there), but for some reason, it does not work in "su -"
  # extra_second_parts="$(echo "${extra_second_parts}" | sed -En "s/^(.{${accuracy}}).*\$/\1/p")"
  # DEBUG:
  # echo "4 extra_second_parts: '${extra_second_parts}'" >&2

  echo "${seconds}${extra_second_parts}"

  return 0
}
# Because "sh" can't export functions, we use variables
export get_seconds_parts_script
get_seconds_parts_script="$(get_function_definition_with_colors_replaced get_seconds_parts)"
functions_to_use="${functions_to_use}${get_seconds_parts_script};"
# Update function body (we replaced colors' variables with their values)
eval "${get_seconds_parts_script}"

# Executed immediately after running the command
function_to_execute_before_command() {
  if [ "${is_command_executing}" = "0" ]; then
    is_command_executing=1
    timestamp_start_seconds_parts="$(get_seconds_parts)"
  fi
}
# Because "sh" can't export functions, we use variables
export function_to_execute_before_command_script
function_to_execute_before_command_script="$(get_function_definition_with_colors_replaced function_to_execute_before_command)"
functions_to_use="${functions_to_use}${function_to_execute_before_command_script};"
# Update function body (we replaced colors' variables with their values)
eval "${function_to_execute_before_command_script}"
# Works only for "bash", so we ignore this functional later
trap function_to_execute_before_command DEBUG

# Executed before the PS1 output
function_to_execute_after_command() {
  if [ "${is_first_command}" = "-1" ]; then
    is_first_command=1
  else
    is_first_command=0
  fi
  is_command_executing=0
}
# PROMPT_COMMAND is available only in "bash"
export PROMPT_COMMAND="function_to_execute_after_command"

ps1_function() {
  local error_code_color="${C_ERROR}"
  if [ "${command_result}" -eq 0 ]; then
    error_code_color="${C_SUCCESS}"
  fi

  local shell
  shell="$(get_current_shell)"

  # If is first command in session
  # Because we can't catch this behavior in "sh", we don't check it there
  if [ "$(is_first_shell 6)" = "1" ] && [ "${is_first_command}" = "1" ] && [ "${shell}" != "sh" ]; then
    my_echo_en "${C_BORDER}  ${C_RESET}"
  else
    my_echo_en "${C_BORDER}└─${C_RESET}"

    # Because \"trap DEBUG\" works only in Bash, we can't calculate time in other shells
    if [ "${shell}" = "bash" ]; then
      local timestamp_end_seconds_parts
      timestamp_end_seconds_parts="$(get_seconds_parts)"
      if [ -z "${timestamp_start_seconds_parts}" ]; then
        timestamp_start_seconds_parts="${timestamp_end_seconds_parts}"
      fi
      local seconds_parts
      seconds_parts="$((timestamp_end_seconds_parts - timestamp_start_seconds_parts))"

      # DEBUG:
      # echo "timestamp_end_seconds_parts: ${timestamp_end_seconds_parts}" >&2
      # echo "timestamp_start_seconds_parts: ${timestamp_start_seconds_parts}" >&2
      # echo "seconds_parts: ${seconds_parts}" >&2

      local seconds="$((seconds_parts / accuracy_tens))"
      local milliseconds="$((seconds_parts - seconds * accuracy_tens))"

      local time_to_print
      time_to_print="${seconds}.$(printf "%0${accuracy}d" "${milliseconds#0}")"

      my_echo_en "${C_BORDER}[${time_to_print}]─${C_RESET}"
    fi

    my_echo_en "${C_BORDER}[${error_code_color}$(printf '%03d' ${command_result#0})${C_BORDER}]─${C_RESET}"
  fi

  # We use env instead of "\"-variables because they do not exist in "sh"
  # ${PWD} = \w
  # ${USER} = \u
  # $(hostname) = \h
  my_echo_en "${C_BORDER}[${USER}@$(hostname):${C_TEXT}${PWD}${C_BORDER}]${C_RESET}"

  if [ -d .git ]; then
    local git_branch_name
    git_branch_name="$(git branch 2> /dev/null | cut -d ' ' -f 2)" || git_branch_name=""

    if [ -n "${git_branch_name}" ]; then
      my_echo_en "${C_BORDER}─${C_BORDER}[${C_TEXT}${git_branch_name}${C_BORDER}]${C_RESET}"
    elif git status &> /dev/null; then
      # TODO: Обработка статуса, когда ветка неизвестна, но репозиторий есть
      my_echo_en "${C_BORDER}─${C_BORDER}[${C_ERROR}???${C_BORDER}]${C_RESET}"
    fi
  fi

  # Extra new line between commands
  echo ''

  echo ''
  my_echo_en "${C_BORDER}┌${C_RESET}"

  if ! pstree --version 2> /dev/null; then
    my_echo_en "${C_BORDER}─[${shell}]${C_RESET}"
  else
    # ----------------------------------------
    # Print shell tree in line
    # ----------------------------------------
    local was_sh=0
    # Remove last 5 processes: subshell, function call, subshell, "pstree" and "head".
    # Also remove spaces, so we can iterate over processes
    local tree_as_string
    tree_as_string="$(pstree -aps $$ | head -n -5 | tr -d '[:blank:]')"
    local line
    for line in ${tree_as_string}; do
      local name
      name=$(echo "${line}" | sed -En 's/^[^a-zA-Z]*?([a-zA-Z]+)[^a-zA-Z]+?.*?$/\1/p')

      # We will find a first process, which ends with "sh" - we assume it is our first shell
      if echo "${name}" | grep -e '^.*sh$' > /dev/null; then
        was_sh=1
      fi

      if [ "${was_sh}" = "1" ]; then
        my_echo_en "${C_BORDER}─[${name}]${C_RESET}"
      fi
    done
  fi
  # ----------------------------------------

  my_echo_en "${C_BORDER}─${C_RESET}"
  # Different symbol for root
  if [ "${is_root}" -eq 1 ]; then
    my_echo_en "${C_BORDER}# ${C_RESET}"
  else
    my_echo_en "${C_BORDER}\$ ${C_RESET}"
  fi
}
# Because "sh" can't export functions, we use variables
export ps1_function_script
ps1_function_script="$(get_function_definition_with_colors_replaced ps1_function)"
functions_to_use="${functions_to_use}${ps1_function_script};"
# Update function body (we replaced colors' variables with their values)
eval "${ps1_function_script}"

ps2_function() {
  local command_result=$?

  local error_code_color
  if [ "${command_result}" -eq 0 ]; then
    error_code_color="${C_SUCCESS}"
  else
    error_code_color="${C_ERROR}"
  fi

  my_echo_en "${C_BORDER}├─${C_BORDER}> ${C_RESET}"
}
# Because "sh" can't export functions, we use variables
export ps2_function_script
ps2_function_script="$(get_function_definition_with_colors_replaced ps2_function)"
functions_to_use="${functions_to_use}${ps2_function_script};"
# Update function body (we replaced colors' variables with their values)
eval "${ps2_function_script}"

export PS1="\$(command_result=\"\$?\"; ${functions_to_use} ps1_function)"
export PS2="\$(${functions_to_use} ps2_function)"

# To use aliases in sudo too
alias sudo="sudo "

# We use some functions as aliases.
# But we must unalias functions' names if they exist, because alias has more priority than function.

# ls aliases.
unalias ll &> /dev/null
ll() {
  # We use "sed" to remove "total".
  # For "total" we check only the beginning of the line because of units after number.
  # shellcheck disable=SC2012
  ls -v -F --group-directories-first --color -l --human-readable --time-style=long-iso "${@}" | sed -E '/^total [0-9]+?.*$/d' || return "$?"
  return 0
}
alias lla="ll --almost-all"
unalias lls &> /dev/null
lls() {
  # We don't use "-1" from "ls" because it does not show us where links are pointing.
  # Instead, we use "cut".
  # We use "tr" to remove duplicate spaces - for "cut" to work properly.
  ll "${@}" | tr -s '[:blank:]' | cut -d ' ' -f 8- || return "$?"
  return 0
}
alias llsa="lls --almost-all"
# Aliases to print list in Markdown format
unalias llsl &> /dev/null
llsl() {
  # shellcheck disable=2016
  lls "${@}" | sed -E 's/^(.*)$/- `\1`/' || return "$?"
  return 0
}
alias llsal="llsl --almost-all"
alias llsla="llsal"

# Use as alias but without space
unalias examples &> /dev/null
examples() {
  less -R <<< "$(curl "https://cheat.sh/${*}")" || return "$?"
  return 0
}

# APT aliases
# (This is not working in this script, so we still use "apt-get" everywhere here)
alias apt="apt-get"
# shellcheck disable=2139
alias au="${sudo_prefix}apt-get update && ${sudo_prefix}apt-get dist-upgrade -y && ${sudo_prefix}apt-get autoremove -y"
unalias ai &> /dev/null
ai() {
  # shellcheck disable=2086
  ${sudo_prefix}apt-get update || return "$?"
  # shellcheck disable=2086
  ${sudo_prefix}apt-get install -y "$@" || return "$?"
  # shellcheck disable=2086
  ${sudo_prefix}apt-get autoremove -y || return "$?"
  return 0
}
unalias ar &> /dev/null
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
alias gp="git push"
unalias gacp &> /dev/null
gacp() {
  gac "${@}" || return "$?"
  gp || return "$?"
  return 0
}

sed_escape() {
  echo "$@" | sed -e 's/[]\/$*.^|()[]/\\&/g' || return "$?"
  return 0
}

export my_prefix=""

echo_if_messages() {
  if [ "${N2038_DISABLE_BASH_ENVIRONMENT_MESSAGES:-1}" = "0" ]; then
    echo "${@}"
  fi
}

echo_if_messages "${my_prefix}Nikolai's .my-bash-environment v.1.0" >&2

# ========================================
# Autoupdate
# ========================================
# We save errors status so we can print them after "clear"
was_autoupdate_failed=0
was_installation_failed=0

repository_url="https://github.com/Nikolai2038/.my-bash-environment.git"
bashrc_file="${HOME}/.bashrc"
postfix=" # n2038 .my-bash-environment"
postfix_escaped="$(sed_escape "${postfix}")"

this_script_path="$(realpath "${BASH_SOURCE[0]}")"

using_script_path="$(sed -En "s/^source[[:blank:]]+\"?([^[:blank:]\"]+?)\"?[[:blank:]]*?${postfix_escaped}\$/\\1/p" "${bashrc_file}")"

# If the script is not installed
if [ -z "${using_script_path}" ]; then
  # This script will be the one to be used.
  # We also replace user's home path with variable to make it more mobile.:wq
  # shellcheck disable=2016
  using_script_path="${this_script_path//"${HOME}"/'${HOME}'}"

  # Install it
  echo "
N2038_DISABLE_BASH_ENVIRONMENT_AUTOUPDATE=0
N2038_DISABLE_BASH_ENVIRONMENT_CLEAR=1
N2038_DISABLE_BASH_ENVIRONMENT_MESSAGES=1
source \"${using_script_path}\" ${postfix}" >> "${bashrc_file}" || was_installation_failed=1
  echo_if_messages "\"${bashrc_file}\" successfully updated!" >&2
fi

# To expand "${HOME}"
using_script_path="$(eval "echo \"${using_script_path}\"")"

# DEBUG:
# echo "${my_prefix}Using bashrc: \"${bashrc_file}\"" >&2
# echo "${my_prefix}Using script path: \"${using_script_path}\"" >&2

using_dir_path=""
if [ -n "${using_script_path}" ]; then
  using_dir_path="$(dirname "${using_script_path}")"
fi

get_directory_hash() {
  local directory="$1" && { shift || true; }

  if [ ! -d "${directory}" ]; then
    echo ""
    return 0
  fi

  # We check file permissions too
  local files
  files="$(find "${directory}" -type f | LC_ALL=C sort)" || return "$?"
  if [ -n "${files}" ]; then
    echo "${files}" | xargs -I {} sh -c '{ ls -al {} | cut -d " " -f 1; cat {}; }' | sha256sum || return "$?"
  else
    echo ""
  fi
  return 0
}

autoupdate() {
  local temp_dir="$1" && { shift || true; }

  # DEBUG:
  # echo "Current hash..." >&2

  local hash_current
  hash_current="$(get_directory_hash "${using_dir_path}")" || return "$?"

  # DEBUG:
  # echo "Cloning..." >&2

  # Update this file itself (will be applied in next session)
  # TODO: Make external updater to update this script in this session
  if [ "${N2038_DISABLE_BASH_ENVIRONMENT_MESSAGES:-1}" = "0" ]; then
    git clone "${repository_url}" "${temp_dir}" || return "$?"
  else
    git clone "${repository_url}" "${temp_dir}" &> /dev/null || return "$?"
  fi
  rm -rf "${temp_dir}/.git" || return "$?"

  # DEBUG:
  # echo "New hash..." >&2

  local hash_new
  hash_new="$(get_directory_hash "${temp_dir}")" || return "$?"

  # If there are file changes
  if [ "${hash_new}" != "${hash_current}" ]; then
    echo_if_messages "Updating \"${using_dir_path}\" from \"${repository_url}\"..." >&2
    rm -rf "${using_dir_path}" || return "$?"
    mv --no-target-directory "${temp_dir}" "${using_dir_path}" || return "$?"
    echo_if_messages "\"${using_dir_path}\" successfully updated!" >&2
  else
    echo_if_messages "${my_prefix}No updates available." >&2
  fi

  return 0
}

if [ "${N2038_DISABLE_BASH_ENVIRONMENT_AUTOUPDATE:-0}" = "0" ]; then
  # We check the script directory - if it has GIT, we assume, it is development, and we will not update the file to not override local changes
  if ! { git -C "${using_dir_path}" remote -v | head -n 1 | grep "${repository_url}"; } &> /dev/null; then
    # Create temp dir
    temp_dir="$(mktemp --directory)" || return "$?"

    autoupdate "${temp_dir}" || was_autoupdate_failed=1

    # Clear temp dir
    if [ -d "${temp_dir}" ]; then
      rm -rf "${temp_dir}"
    fi
  else
    echo_if_messages "${my_prefix}GIT directory found - autoupdate will not be executed." >&2
  fi
else
  echo_if_messages "${my_prefix}Env-variable \"DISABLE_BASH_ENVIRONMENT_AUTOUPDATE\" is set - autoupdate skipped." >&2
fi
# ========================================

echo_if_messages "${my_prefix}Welcome, ${USER}!" >&2

if [ "${N2038_DISABLE_BASH_ENVIRONMENT_CLEAR:-1}" = "0" ]; then
  # We clear only the first shell
  if [ "$(is_first_shell 5)" = "1" ]; then
    clear
  fi
fi

if [ "${was_installation_failed}" = "1" ]; then
  echo "${my_prefix}Failed to install \"${using_script_path}\" in \"${bashrc_file}\"." >&2
fi

if [ "${was_autoupdate_failed}" = "1" ]; then
  echo "${my_prefix}Failed to update \"${using_script_path}\" - autoupdate skipped." >&2
fi

if ! pstree --version 2> /dev/null; then
  echo "Command \"pstree\" not found! It is needed to show shell tree in \"PS1\". Try \"sudo apt-get install -y psmisc\" to install it." >&2
  echo 0
  return 0
fi

# This must be the last command in this file
is_first_command=-1
