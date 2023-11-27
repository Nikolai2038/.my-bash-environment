#!/bin/bash

# Exit on error
set -e

# ----------------------------------------
# Settings
# ----------------------------------------
export EDITOR=vim

# TODO: Maybe find different approach
if [ "$(whoami)" == "root" ]; then
    is_root=1
else
    is_root=0
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
    extra_second_parts="${extra_second_parts:0:${accuracy}}" || return "$?"

    echo "${seconds}${extra_second_parts}"

    return 0
}

# Выполняется сразу после запуска команды
trap "
    if [ \"\${is_command_executing}\" == \"0\" ]; then
        is_command_executing=1;
        timestamp_start_seconds_parts=\"\$(get_seconds_parts)\";
    fi
" DEBUG

# Выполняется перед выводом PS1
export PROMPT_COMMAND="
    if [ \"\${is_first_command}\" == \"-1\" ]; then
        is_first_command=1;
    else
        is_first_command=0;
    fi;
    is_command_executing=0;
"

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

alias ll="ls -l -v --group-directories-first --human-readable --time-style=long-iso --color"
alias lla="ll --almost-all"
alias apt="apt-get"

# Use as alias but without space
function examples() {
    less -R <<< "$(curl "https://cheat.sh/${*}")" || return "$?"
    return 0
}

# APT aliases
alias au="sudo apt update && sudo apt dist-upgrade -y"
function ai() {
    sudo apt-get update || return "$?"
    sudo apt-get install -y "$@" || return "$?"
    sudo apt-get autoremove -y || return "$?"
    return 0
}
function ar() {
    sudo apt-get remove -y "$@" || return "$?"
    sudo apt-get autoremove -y || return "$?"
    return 0
}

# GIT aliases
alias gs="git status"
alias gc="git add . && git commit -m"

clear

# Do not exit on errors in session
set +e
