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

# shellcheck disable=3044
if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
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
fi

PS_TREE_MINUS=9
if pstree --version 2> /dev/null; then
  export IS_PSTREE=1
else
  export IS_PSTREE=0
  echo 'Command "pstree" not found! It is needed to show shell tree in "PS1". Try "sudo apt-get install -y psmisc" to install it.' >&2
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

# For some reason, "echo" in "sh" does not recognize "-e" option, so we do not use it
my_echo_en() {
  if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
    # shellcheck disable=SC3037
    echo -en "$@"
  else
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
alias gp="git push"
unalias gacp > /dev/null 2>&1
gacp() {
  gac "${@}" || return "$?"
  gp || return "$?"
  return 0
}
# ========================================

export my_prefix=""

echo_if_messages() {
  if [ "${N2038_DISABLE_BASH_ENVIRONMENT_MESSAGES:-1}" = "0" ]; then
    echo "${@}"
  fi
}

echo_if_messages "${my_prefix}Nikolai's .my-bash-environment v.0.3.0" >&2

# ========================================
# Autoupdate
# ========================================
if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
  # We save errors status, so we can print them after "clear"
  was_autoupdate_failed=0
  was_installation_failed=0

  repository_url="https://github.com/Nikolai2038/.my-bash-environment.git"
  bashrc_file="${HOME}/.bashrc"
  postfix=" # n2038 .my-bash-environment"
  postfix_escaped="$(sed_escape "${postfix}")"

  # shellcheck disable=3028,3054
  this_script_path="$(realpath "${BASH_SOURCE[0]}")"

  using_script_path="$(sed -En "s/^source[[:blank:]]+\"?([^[:blank:]\"]+?)\"?[[:blank:]]*?${postfix_escaped}\$/\\1/p" "${bashrc_file}")"

  # If the script is not installed
  if [ -z "${using_script_path}" ]; then
    # This script will be the one to be used.
    # We also replace user's home path with variable to make it more mobile.:wq
    # shellcheck disable=2016,3060
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
    directory="$1" && { shift || true; }

    if [ ! -d "${directory}" ]; then
      echo ""
      return 0
    fi

    # We check file permissions too
    files="$(find "${directory}" -type f | LC_ALL=C sort)" || return "$?"
    if [ -n "${files}" ]; then
      echo "${files}" | xargs -I {} sh -c '{ ls -al {} | cut -d " " -f 1; cat {}; }' | sha256sum || return "$?"
    else
      echo ""
    fi
    return 0
  }

  autoupdate() {
    temp_dir="$1" && { shift || true; }

    # DEBUG:
    # echo "Current hash..." >&2

    hash_current="$(get_directory_hash "${using_dir_path}")" || return "$?"

    # DEBUG:
    # echo "Cloning..." >&2

    # Update this file itself (will be applied in next session)
    # TODO: Make external updater to update this script in this session
    if [ "${N2038_DISABLE_BASH_ENVIRONMENT_MESSAGES:-1}" = "0" ]; then
      git clone "${repository_url}" "${temp_dir}" || return "$?"
    else
      git clone "${repository_url}" "${temp_dir}" > /dev/null 2>&1 || return "$?"
    fi
    rm -rf "${temp_dir}/.git" || return "$?"

    # DEBUG:
    # echo "New hash..." >&2

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
    if ! { git -C "${using_dir_path}" remote -v | head -n 1 | grep "${repository_url}"; } > /dev/null 2>&1; then
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
