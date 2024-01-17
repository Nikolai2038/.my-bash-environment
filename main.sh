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

if [ -d "/mnt/wsl-original" ]; then
  is_wsl=1
else
  is_wsl=0
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

# Auto-color for "less"
if ! source-highlight --version &> /dev/null; then
  # shellcheck disable=2086
  ${sudo_prefix}apt-get install -y source-highlight
fi
lesspipe_script="$(find /usr -name 'src-hilite-lesspipe.sh' -type f 2> /dev/null | head -n 1)"
export LESSOPEN="| ${lesspipe_script} %s"
export LESS=' -R '

# ========================================
# Autoupdate
# ========================================
INSTALL_DIRECTORY_PATH="${HOME}/.my-bash-environment"

function autoupdate() {
  local was_autoupdate_failed=0

  if [ -z "${DISABLE_BASH_ENVIRONMENT_AUTOUPDATE}" ]; then
    # If not development
    if ! { git -C "${INSTALL_DIRECTORY_PATH}" remote -v | head -n 1 | grep 'https://github.com/Nikolai2038/.my-bash-environment.git'; } &> /dev/null; then
      mkdir --parents "${INSTALL_DIRECTORY_PATH}"

      local install_directory_backup_path="${INSTALL_DIRECTORY_PATH}.backup"
      mv "${INSTALL_DIRECTORY_PATH}" "${install_directory_backup_path}" || return "$?"
      # Clone all files and remove GIT info
      git clone https://github.com/Nikolai2038/.my-bash-environment.git "${INSTALL_DIRECTORY_PATH}" && rm -rf "${INSTALL_DIRECTORY_PATH}/.git*" || was_autoupdate_failed=1

      if ((was_autoupdate_failed)); then
        # Restore old files
        if [ -d "${install_directory_backup_path}" ]; then
          if [ -d "${INSTALL_DIRECTORY_PATH}" ]; then
            rm -rf "${INSTALL_DIRECTORY_PATH}" || return "$?"
          fi
          mv "${install_directory_backup_path}" "${INSTALL_DIRECTORY_PATH}" || return "$?"
        fi
      else
        # Delete old files
        rm -rf "${install_directory_backup_path}" || return "$?"
      fi
    fi
  fi

  return "${was_autoupdate_failed}"
}
autoupdate && was_autoupdate_failed=0 || was_autoupdate_failed=1

# ----------------------------------------
# Delete old update method
# TODO: Remove in the future
# ----------------------------------------
# shellcheck disable=2016
if grep '^source "${HOME}/.my-bash-environment/main.sh"$' "${HOME}/.bashrc" &> /dev/null; then
  sed -Ei '/source "\$\{HOME\}\/.my-bash-environment\/main.sh"/d' ~/.bashrc
fi
# ----------------------------------------

# ----------------------------------------
# Execute "startup.sh" script on startup (as root)
# ----------------------------------------
function update_startup_task_for_root() {
  # Because we use ".my-bash-environment" from user dir, we do not run this as "root"
  if ((is_root)); then
    return 0
  fi

  local crontab_file="/var/spool/cron/crontabs/root"
  local crontab_content="@reboot root sh ${INSTALL_DIRECTORY_PATH}/startup_as_root.sh"
  echo "Checking \"${crontab_file}\"..." >&2
  if ! sudo grep "^${crontab_content}\$" "${crontab_file}" &> /dev/null; then
    echo "Updating \"${crontab_file}\"..." >&2
    local command="echo \"${crontab_content}\" >> \"${crontab_file}\""
    if ((is_root)); then
      eval "${command}"
    else
      sudo su root -c "${command}"
    fi
    echo "\"${crontab_file}\" updated!" >&2
  else
    echo "\"${crontab_file}\" is already configured!" >&2
  fi
  echo "Current tasks:" >&2
  sudo crontab -l -u root >&2
}
# ----------------------------------------

# ----------------------------------------
# Execute this script on terminal session start
# ----------------------------------------
function update_main_script_for_root() {
  # Because we use ".my-bash-environment" from user dir, we do not run this as "root"
  if ((is_root)); then
    return 0
  fi

  local bashrc_content="source ${INSTALL_DIRECTORY_PATH}/main.sh"

  local bashrc_file="/root/.bashrc"
  echo "Checking \"${bashrc_file}\"..." >&2
  if ! grep "^${bashrc_content}\$" "${bashrc_file}" &> /dev/null; then
    echo "Updating \"${bashrc_file}\"..." >&2
    sudo su root -c "echo \"${bashrc_content}\" >> \"${bashrc_file}\""
    echo "\"${bashrc_file}\" updated!" >&2
  else
    echo "\"${bashrc_file}\" is already configured!" >&2
  fi

  update_startup_task_for_root || return "$?"
}

function update_main_script_for_user() {
  # Because we use ".my-bash-environment" from user dir, we do not run this as "root"
  if ((is_root)); then
    return 0
  fi

  local bashrc_content="source ${INSTALL_DIRECTORY_PATH}/main.sh"

  local bashrc_file="${HOME}/.bashrc"
  echo "Checking \"${bashrc_file}\"..." >&2
  if ! grep "^${bashrc_content}\$" "${bashrc_file}" &> /dev/null; then
    echo "Updating \"${bashrc_file}\"..." >&2
    echo "${bashrc_content}" >> "${bashrc_file}"
    echo "\"${bashrc_file}\" updated!" >&2

    # Because we need "root" rights to just check, we execute this only once (when ".bashrc" is updated) or by hand (using function name)
    update_main_script_for_root
  else
    echo "\"${bashrc_file}\" is already configured!" >&2
  fi
}
update_main_script_for_user
# ----------------------------------------
# ========================================

# TODO: Maybe find different approach
if [ "${DISPLAY}" = ":10.0" ]; then
  is_xrdp=1
else
  is_xrdp=0
fi

if [ "$(hostname)" = "NIKOLAI-LAPTOP" ]; then
  is_laptop=1
else
  is_laptop=0
fi

# Apply on WSL
if [ "${is_wsl}" = "1" ]; then
  # Make sure we run this command only one time in user session
  # Is dbus-daemon is launched in the session, this command will print processes
  if ! busctl list --user > /dev/null; then
    # Fix warnings in graphic apps
    dbus-daemon --session --address=$DBUS_SESSION_BUS_ADDRESS --nofork --nopidfile --syslog-only &
  fi

  # Fix locale
  . /etc/default/locale
# Apply only on laptop with non-root user
elif [ "${is_root}" = "0" ] && [ "${is_laptop}" = "1" ]; then
  # Check, if connected via xrdp - do not use scaling
  if [ "${is_xrdp}" = "1" ]; then
    scale="1.0"
  # If not connected via xrdp and not ssh - use scaling
  elif [ -n "${DISPLAY}" ]; then
    scale="1.5"
  fi

  gsettings set org.gnome.desktop.interface text-scaling-factor "${scale}"

  # For Qt apps (Telegram, for example)
  export QT_AUTO_SCREEN_SET_FACTOR=0
  export QT_SCALE_FACTOR="${scale}"
fi

#function get_file_hash() {
#  sha256sum "${1}" | cut -d ' ' -f 1 || return "${?}"
#  return 0
#}
#
#function update_profile_directory() {
#  local profile_directory_path="${INSTALL_DIRECTORY_PATH}/profile.d"
#  local profile_directory_backup_path="${profile_directory_path}.backup"
#  mkdir --parents "${profile_directory_backup_path}" || return "$?"
#  local profile_directory_target_path="/etc/profile.d"
#
#  local profile_file_path
#  for profile_file_path in "${profile_directory_path}"/*; do
#    local profile_file_name
#    profile_file_name="$(basename "${profile_file_path}")" || return "$?"
#
#    local profile_file_backup_path="${profile_directory_backup_path}/${profile_file_name}"
#
#    local needs_update=0
#
#    if [ -f "${profile_file_backup_path}" ]; then
#      local profile_file_hash
#      profile_file_hash="$(get_file_hash "${profile_file_path}")" || return "$?"
#      local profile_file_backup_hash
#      profile_file_backup_hash="$(get_file_hash "${profile_file_backup_path}")" || return "$?"
#
#      if [ "${profile_file_hash}" != "${profile_file_backup_hash}" ]; then
#        needs_update=1
#      fi
#    else
#      needs_update=1
#    fi
#
#    if [ "${needs_update}" = "1" ]; then
#      local profile_file_target_path="${profile_directory_target_path}/${profile_file_name}"
#      echo "Updating ${profile_directory_target_path}..." >&2
#      # Update file
#      sudo cp "${profile_file_path}" "${profile_file_target_path}" || return "$?"
#      # Save current file for backup
#      sudo cp "${profile_file_target_path}" "${profile_file_backup_path}" || return "$?"
#    fi
#  done
#}
#update_profile_directory

# TODO: Maybe not needed
## For some reason, switching keyboard layout stop working at some point when connected via xrdp.
## But if we change GNOME Tweaks settings, it will be fixed.
## So here we change keyboard setting to empty value and then restore it.
#if [ "${is_xrdp}" = "1" ]; then
#  options="$(gsettings get org.gnome.desktop.input-sources xkb-options)"
#  gsettings set org.gnome.desktop.input-sources xkb-options "[]"
#  gsettings set org.gnome.desktop.input-sources xkb-options "${options}"
#fi

# clear

if [ "${was_autoupdate_failed}" = "1" ]; then
  echo "Failed to update ~/.my-bash-environment/main.sh - autoupdate skipped." >&2
fi

# This must be last command in this file
is_first_command=-1
