#!/bin/bash

# ----------------------------------------
# Settings
# ----------------------------------------
export EDITOR=vim

# TODO: Maybe find different approach
if [ "$(whoami)" == "root" ]; then
  is_root=1
  sudo_prefix=""
else
  is_root=0
  sudo_prefix="sudo "
fi

# Different color for root
if [ "${is_root}" -eq 1 ]; then
  C_BORDER="\[\033[38;5;90m\]"
else
  C_BORDER="\[\033[38;5;27m\]"
fi

C_TEXT="\[\033[38;5;02m\]"
C_RESET="\[$(tput sgr0)\]"
C_ERROR="\[\033[38;5;01m\]"
C_SUCCESS="\[\033[38;5;02m\]"

# From 1 to 9 - Количество знаков после запятой для времени выполнения команды
accuracy=2
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

# Не отображаем информацию о выполнении прошлой команды для самого первого вывода в сессии
is_first_command=-1
alias clear="is_first_command=-1; clear"
alias reset="is_first_command=-1; reset"

is_command_executing=0

function get_seconds_parts() {
  local seconds
  seconds="$(date +%s)" || return "$?"

  local extra_second_parts
  extra_second_parts="$(date +%N)" || return "$?"

  # Remove zeros (to avoid "printf: invalid octal number" error) with sed (because it does not always work with "${extra_second_parts#0}")
  extra_second_parts="$(echo "${extra_second_parts}" | sed -En 's/^[0]*([0-9]+?)$/\1/p')" || return "$?"

  extra_second_parts="$(printf '%09d' "${extra_second_parts}")" || return "$?"
  extra_second_parts="${extra_second_parts:0:accuracy}" || return "$?"

  echo "${seconds}${extra_second_parts}"

  return 0
}

# Выполняется сразу после запуска команды
trap '
    if [ "${is_command_executing}" == "0" ]; then
        is_command_executing=1;
        timestamp_start_seconds_parts="$(get_seconds_parts)";
    fi
' DEBUG

# Выполняется перед выводом PS1
export PROMPT_COMMAND='
    if [ "${is_first_command}" == "-1" ]; then
        is_first_command=1;
    else
        is_first_command=0;
    fi;
    is_command_executing=0;
'

# shellcheck disable=SC2154
export PS1="\$(
    command_result=\$?;

    if [ \"\${command_result}\" -eq 0 ]; then
        error_code_color='${C_SUCCESS}';
    else
        error_code_color='${C_ERROR}';
    fi;

    # If is first command in session
    if [ \"\${is_first_command}\" == \"1\" ]; then
        echo -n \"${C_BORDER}  ${C_RESET}\";
    else
        timestamp_end_seconds_parts=\"\$(get_seconds_parts)\"
        seconds_parts=\"\$((timestamp_end_seconds_parts - timestamp_start_seconds_parts))\"

        seconds=\"\$((seconds_parts / (10 ** ${accuracy})))\"
        milliseconds=\"\$((seconds_parts -  seconds * (10 ** ${accuracy})))\"

        time_to_print=\"\${seconds}.\$(printf '%0${accuracy}d' \"\${milliseconds#0}\")\"

        echo -n \"${C_BORDER}└─${C_RESET}\";
        echo -n \"${C_BORDER}[\${time_to_print}${C_BORDER}]${C_RESET}\";
        echo -n \"${C_BORDER}─[\${error_code_color}\$(printf '%03d' \${command_result#0})${C_BORDER}]─${C_RESET}\";
    fi;

    echo -n \"${C_BORDER}[\u@\h:${C_TEXT}\w${C_BORDER}]${C_RESET}\";

    git_branch_name=\"\$(git branch 2> /dev/null | cut -d ' ' -f 2)\" || git_branch_name=\"\"

    if [ -n \"\${git_branch_name}\" ]; then
        echo -n \"${C_BORDER}─${C_BORDER}[${C_TEXT}\${git_branch_name}${C_BORDER}]${C_RESET}\";
    elif git status &> /dev/null; then
        # TODO: Обработка статуса, когда ветка неизвестна, но репозиторий есть
        echo -n \"${C_BORDER}─${C_BORDER}[${C_ERROR}???${C_BORDER}]${C_RESET}\";
    fi

    # Extra new line between commands
    echo '';

    echo '';
    echo -n \"${C_BORDER}┌─${C_RESET}\";

    # Different symbol for root
    if [ \"${is_root}\" -eq 1 ]; then
        echo -n \"${C_BORDER}# ${C_RESET}\";
    else
        echo -n \"${C_BORDER}\$ ${C_RESET}\";
    fi
)"
export PS2="\$(
    command_result=\$?;

    if [ \"\${command_result}\" -eq 0 ]; then
        error_code_color='${C_SUCCESS}';
    else
        error_code_color='${C_ERROR}';
    fi;

    echo -n \"${C_BORDER}├─${C_BORDER}> ${C_RESET}\";
)"

# To use aliases in sudo too
alias sudo="sudo "

# We use some functions as aliases.
# But we must unalias functions names if they exists, because alias have more priority than function.

# ls aliases.
unalias ll &> /dev/null
function ll() {
  # We use "sed" to remove "total".
  # For "total" we check only beginning of the line because of units after number.
  ls -v -F --group-directories-first --color -l --human-readable --time-style=long-iso "${@}" | sed -E '/^total [0-9]+?.*$/d' || return "$?"
  return 0
}
alias lla="ll  --almost-all"
unalias lls &> /dev/null
function lls() {
  # We don't use "-1" from "ls" because it does not show us where links are pointing.
  # Instead, we use "cut".
  # We use "tr" to remove duplicate spaces - for "cut" to work properly.
  ll "${@}" | tr -s [:blank:] | cut -d ' ' -f 8- || return "$?"
  return 0
}
alias llsa="lls --almost-all"
# Aliases to print list in Markdown format
unalias llsl &> /dev/null
function llsl() {
  lls "${@}" | sed -E 's/^(.*)$/- `\1`/' || return "$?"
  return 0
}
alias llsal="llsl --almost-all"
alias llsla="llsal"

# Use as alias but without space
unalias examples &> /dev/null
function examples() {
  less -R <<< "$(curl "https://cheat.sh/${*}")" || return "$?"
  return 0
}

# APT aliases
# (This is not working in this script, so we still use "apt-get" everywhere here)
alias apt="apt-get"
# shellcheck disable=2139
alias au="${sudo_prefix}apt-get update && ${sudo_prefix}apt-get dist-upgrade -y && ${sudo_prefix}apt-get autoremove -y"
unalias ai &> /dev/null
function ai() {
  # shellcheck disable=2086
  ${sudo_prefix}apt-get update || return "$?"
  # shellcheck disable=2086
  ${sudo_prefix}apt-get install -y "$@" || return "$?"
  # shellcheck disable=2086
  ${sudo_prefix}apt-get autoremove -y || return "$?"
  return 0
}
unalias ar &> /dev/null
function ar() {
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
function gacp() {
  gac "${@}" || return "$?"
  gp || return "$?"
  return 0
}

# ========================================
# Autoupdate
# ========================================
was_autoupdate_failed=0
if [ -z "${DISABLE_BASH_ENVIRONMENT_AUTOUPDATE}" ]; then
  # If not development
  if ! { git -C "${HOME}/.my-bash-environment" remote -v | head -n 1 | grep 'https://github.com/Nikolai2038/.my-bash-environment.git'; } &> /dev/null; then
    mkdir --parents "${HOME}/.my-bash-environment"
    new_file_content="$(curl --silent https://raw.githubusercontent.com/Nikolai2038/.my-bash-environment/main/main.sh)" || was_autoupdate_failed=1
    if [ "${was_autoupdate_failed}" = "0" ] && [ -n "${new_file_content}" ]; then
      echo "${new_file_content}" > "${HOME}/.my-bash-environment/main.sh" || was_autoupdate_failed=1
    fi
  fi
  # shellcheck disable=2016
  if ! grep '^source "${HOME}/.my-bash-environment/main.sh"$' "${HOME}/.bashrc" &> /dev/null; then
    echo 'source "${HOME}/.my-bash-environment/main.sh"' >> ~/.bashrc
  fi
fi
# ========================================

clear

if [ "${was_autoupdate_failed}" = "1" ]; then
  echo "Failed to update ~/.my-bash-environment/main.sh - autoupdate skipped." >&2
fi

# This must be last command in this file
is_first_command=-1
