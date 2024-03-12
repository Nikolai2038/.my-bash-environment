#!/bin/bash

# ----------------------------------------
# Settings
# ----------------------------------------
# From 1 to 9 - The number of decimals for the command execution time
export accuracy=2

# Connection timeout for checking internet connection before autoupdate
export CHECK_CONNECTION_TIMEOUT=0.3

# Directory with scripts
DIRECTORY_WITH_SCRIPTS="${HOME}/.my-bash-environment"
# Path to ".bashrc"
BASHRC_FILE="${HOME}/.bashrc"
# Repository with these scripts
REPOSITORY_URL="https://github.com/Nikolai2038/.my-bash-environment.git"
# Postfix to add in the end of lines in ".bashrc"
N2038_POSTFIX=" # n2038 .my-bash-environment"
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

# ----------------------------------------
# From Debian .bashrc
# ----------------------------------------
# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
export HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
export HISTSIZE=1000
export HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize
# ----------------------------------------

sed_escape() {
  echo "$@" | sed -e 's/[]\/$*.^;|{}()[]/\\&/g' || return "$?"
  return 0
}

export my_prefix=""

echo_if_messages() {
  if [ "${N2038_DISABLE_BASH_ENVIRONMENT_MESSAGES:-1}" = "0" ]; then
    echo "${@}"
  fi
}

# Executed immediately after running the command
function_to_execute_before_command() {
  if [ "${is_command_executing}" = "0" ]; then
    is_command_executing=1
    timestamp_start_seconds_parts="$(get_seconds_parts)"
  fi
}
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

get_execution_time() {
  local timestamp_end_seconds_parts
  timestamp_end_seconds_parts="$(get_seconds_parts)"
  local seconds_parts="$((timestamp_end_seconds_parts - timestamp_start_seconds_parts))"

  # DEBUG:
  # echo "timestamp_end_seconds_parts: ${timestamp_end_seconds_parts}" >&2
  # echo "timestamp_start_seconds_parts: ${timestamp_start_seconds_parts}" >&2
  # echo "seconds_parts: ${seconds_parts}" >&2

  local seconds="$((seconds_parts / accuracy_tens))"
  local milliseconds="$((seconds_parts - seconds * accuracy_tens))"

  local time_to_print
  time_to_print="${seconds}.$(printf "%0${accuracy}d" "${milliseconds#0}")"

  my_echo_en "[${time_to_print}]─"
}
export_function_for_sh get_execution_time

# We do not display information about the execution of the last command for the very first output in the session
export is_first_command=-1
alias clear="is_first_command=-1; clear"
alias reset="is_first_command=-1; reset"

is_command_executing=0

get_seconds_parts() {
  date +"%s %N" | sed -E "s/^([0-9]+) ([0-9]{0,${accuracy}})[0-9]*\$/\1\2/" || return "$?"
  return 0
}
export_function_for_sh get_seconds_parts

echo_if_messages "${my_prefix}Nikolai's .my-bash-environment v.0.3.1" >&2

# ========================================
# Autoupdate
# ========================================
# We save errors status, so we can print them after "clear"
was_autoupdate_failed=0
was_installation_failed=0

postfix_escaped="$(sed_escape "${N2038_POSTFIX}")"

using_script_path=""
# Check if ".bashrc" contains command to source main script
if [ -f "${BASHRC_FILE}" ]; then
  using_script_path="$(sed -En "s/^source[[:blank:]]+\"?([^[:blank:]\"]+?)\"?[[:blank:]]*?${postfix_escaped}\$/\\1/p" "${BASHRC_FILE}")"
fi

# If not - add this line
if [ -z "${using_script_path}" ]; then
  # shellcheck disable=2016
  using_script_path='${HOME}/.my-bash-environment/main.sh'

  # Install it
  echo "
N2038_DISABLE_BASH_ENVIRONMENT_AUTOUPDATE=0
N2038_DISABLE_BASH_ENVIRONMENT_CLEAR=1
N2038_DISABLE_BASH_ENVIRONMENT_MESSAGES=1
source \"${using_script_path}\" ${N2038_POSTFIX}" >> "${BASHRC_FILE}" || was_installation_failed=1
  echo_if_messages "\"${BASHRC_FILE}\" successfully updated!" >&2
fi

check_connection() {
  curl --fail --silent --show-error --max-time "${CHECK_CONNECTION_TIMEOUT}" https://github.com/Nikolai2038/.my-bash-environment.git > /dev/null
  return "$?"
}

get_directory_hash() {
  local directory
  directory="$1" && { shift || true; }

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
  local temp_dir
  temp_dir="$1" && { shift || true; }

  # If can't connect - skip autoupdate
  if ! check_connection; then
    echo_if_messages "${my_prefix}Connection failed - autoupdate will not be executed." >&2
    return 1
  fi

  local hash_current
  hash_current="$(get_directory_hash "${DIRECTORY_WITH_SCRIPTS}")" || return "$?"

  # Update this file itself (will be applied in next session)
  # TODO: Make external updater to update this script in this session
  if [ "${N2038_DISABLE_BASH_ENVIRONMENT_MESSAGES:-1}" = "0" ]; then
    git clone "${REPOSITORY_URL}" "${temp_dir}" || return "$?"
  else
    git clone "${REPOSITORY_URL}" "${temp_dir}" > /dev/null 2>&1 || return "$?"
  fi
  rm -rf "${temp_dir}/.git" || return "$?"

  local hash_new
  hash_new="$(get_directory_hash "${temp_dir}")" || return "$?"

  # If there are file changes
  if [ "${hash_new}" != "${hash_current}" ]; then
    echo_if_messages "Updating \"${DIRECTORY_WITH_SCRIPTS}\" from \"${REPOSITORY_URL}\"..." >&2
    rm -rf "${DIRECTORY_WITH_SCRIPTS}" || return "$?"
    mv --no-target-directory "${temp_dir}" "${DIRECTORY_WITH_SCRIPTS}" || return "$?"
    echo_if_messages "\"${DIRECTORY_WITH_SCRIPTS}\" successfully updated!" >&2
  else
    echo_if_messages "${my_prefix}No updates available." >&2
  fi

  return 0
}

if [ "${N2038_DISABLE_BASH_ENVIRONMENT_AUTOUPDATE:-0}" = "0" ]; then
  # We check the script directory - if it has GIT, we assume, it is development, and we will not update the file to not override local changes
  if ! { git -C "${DIRECTORY_WITH_SCRIPTS}" remote -v | head -n 1 | grep "${REPOSITORY_URL}"; } > /dev/null 2>&1; then
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

echo_if_messages "${my_prefix}Welcome, $(get_username)!" >&2

if [ "${N2038_DISABLE_BASH_ENVIRONMENT_CLEAR:-1}" = "0" ]; then
  # We clear only the first shell
  if [ "$(get_process_depth)" = "${PS_TREE_MINUS}" ]; then
    clear
  fi
fi

if [ "${was_installation_failed}" = "1" ]; then
  echo "${my_prefix}Failed to install \"${using_script_path}\" in \"${BASHRC_FILE}\"." >&2
fi

if [ "${was_autoupdate_failed}" = "1" ]; then
  echo "${my_prefix}Failed to update \"${using_script_path}\" - autoupdate skipped." >&2
fi
