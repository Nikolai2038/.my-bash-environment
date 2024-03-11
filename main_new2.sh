#!/bin/sh

# Code to execute when starting "sh"
export eval_code_for_sh=""

sed_escape() {
  echo "$@" | sed -e 's/[]\/$*.^;|{}()[]/\\&/g' || return "$?"
  return 0
}

# Creates variable, which contains full function declaration and body.
# This variable will be exported and be available in "sh" ("sh" can't export functions).
export_function_for_sh() {
  function_name="${1}" && { shift || true; }
  function_name_as="${1:-"${function_name}"}" && { shift || true; }
  is_escape_colors="${1:-"${function_name}"}" && { shift || true; }
  eval "export ${function_name_as}_EXPORT"
  eval "${function_name_as}_EXPORT=\"\$(typeset -f \"${function_name}\")\"" || return "$?"
  if [ "${function_name_as}" != "${function_name}" ]; then
    eval "${function_name_as}_EXPORT=\"\$(echo \"\${${function_name_as}_EXPORT}\" | sed 's/$(sed_escape "${function_name}")/$(sed_escape "${function_name_as}")/')\"" || return "$?"
  fi
  eval_code_for_sh="${eval_code_for_sh}
    $(eval "
      if [ -n \"\${${function_name_as}_EXPORT}\" ]; then
        echo \"\${${function_name_as}_EXPORT}\";
      fi;
    ")
  "
  unset function_name
  return 0
}
export_function_for_sh export_function_for_sh
export_function_for_sh sed_escape

# Prints current shell name
get_current_shell() {
  echo "$0" | sed 's/[^a-z]//g' || return "$?"
  return 0
}
export_function_for_sh get_current_shell

get_process_depth() {
  # Head to hide sub pipelines.
  # Remember, that "wc" command also counts.
  pstree --ascii --long --show-parents --hide-threads --arguments $$ | wc -l || return "$?"
  return 0
}
export_function_for_sh get_process_depth

init() {
  if [ -z "${PARENTS_COUNT_ROOT_SHELL}" ]; then
    export PARENTS_COUNT_ROOT_SHELL
    PARENTS_COUNT_ROOT_SHELL="$(get_process_depth)"
  fi
  PARENTS_COUNT="$(get_process_depth)"
  PARENTS_COUNT="$((PARENTS_COUNT - PARENTS_COUNT_ROOT_SHELL))"

  CURRENT_SHELL_NAME="$(get_current_shell)" || return "$?"

  # ----------------------------------------
  # Settings
  # ----------------------------------------
  export EDITOR=vim

  # We need "\[" and "\]" to help bash understand, that it is colors (otherwise bash will break when we navigate in commands history).
  # But we add them in get_function_definition_with_colors_replaced.
  _C_TEXT="\033[38;5;02m"
  _C_ERROR="\033[38;5;01m"
  _C_SUCCESS="\033[38;5;02m"
  _C_BORDER_USUAL="\033[38;5;27m"
  _C_BORDER_ROOT="\033[38;5;90m"
  _C_RESET='\e[0m'

  # From 1 to 9 - The number of decimals for the command execution time
  export accuracy=2
  # ----------------------------------------

  # ----------------------------------------
  # Calculations
  # ----------------------------------------
  # If user is root
  if [ "$(id --user "${USER}")" = "0" ]; then
    export is_root=1
  else
    export is_root=0
  fi

  if [ "${is_root}" = "1" ]; then
    # Different color for root
    export _C_BORDER="${_C_BORDER_ROOT}"
    export sudo_prefix=""
  else
    export _C_BORDER="${_C_BORDER_USUAL}"
    export sudo_prefix="sudo "
  fi

  # We need to calculate this via loop, because in sh operator "**" does not exist
  export accuracy_tens=1
  i=0
  while [ "${i}" -lt "${accuracy}" ]; do
    accuracy_tens="$((accuracy_tens * 10))"
    i="$((i + 1))"
  done
  # ----------------------------------------

  if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
    echo INIT BASH

    # Braces "\[" and "\]" are required, so "bash" can understand, that this is colors and not output.
    # If we do not use them, the shell will break when we try to navigate in commands' history.
    C_TEXT="\[${_C_TEXT}\]"
    C_ERROR="\[${_C_ERROR}\]"
    C_SUCCESS="\[${_C_SUCCESS}\]"
    C_BORDER_USUAL="\[${_C_BORDER_USUAL}\]"
    C_BORDER_ROOT="\[${_C_BORDER_ROOT}\]"
    C_BORDER="\[${_C_BORDER}\]"
    C_RESET="\[${_C_RESET}\]"

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
  else
    echo INIT SH

    # "sh" does not have commands' history, and braces will result in just text, so we don't use them here
    C_TEXT="${_C_TEXT}"
    C_ERROR="${_C_ERROR}"
    C_SUCCESS="${_C_SUCCESS}"
    C_BORDER_USUAL="${_C_BORDER_USUAL}"
    C_BORDER_ROOT="${_C_BORDER_ROOT}"
    C_BORDER="${_C_BORDER}"
    C_RESET="${_C_RESET}"
  fi
  return 0
}
init
export_function_for_sh init

# For some reason, "echo" in "sh" does not recognize "-e" option, so we do not use it
my_echo_en() {
  if [ "$(get_current_shell)" = "bash" ]; then
    echo -en "$@"
  else
    echo -n "$@"
  fi
}
export_function_for_sh my_echo_en

ps1_function_for_TEMPLATE() {
  init || return "$?"
  my_echo_en "${C_BORDER}${PARENTS_COUNT} ${CURRENT_SHELL_NAME} \$ ${C_RESET}"
  return 0
}
export_function_for_sh ps1_function_for_TEMPLATE ps1_function_for_bash
export_function_for_sh ps1_function_for_TEMPLATE ps1_function_for_sh

ps1_function() {
  if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
    ps1_function_for_bash
  else
    ps1_function_for_sh
  fi
  return 0
}
export_function_for_sh ps1_function

ps2_function_for_TEMPLATE() {
  my_echo_en "${C_BORDER}${PARENTS_COUNT} ${CURRENT_SHELL_NAME} > ${C_RESET}"
  return 0
}
export_function_for_sh ps2_function_for_TEMPLATE ps2_function_for_bash
export_function_for_sh ps2_function_for_TEMPLATE ps2_function_for_sh

ps2_function() {
  if [ "${CURRENT_SHELL_NAME}" = "bash" ]; then
    ps2_function_for_bash
  else
    ps2_function_for_sh
  fi
  return 0
}
export_function_for_sh ps2_function

export PS1="\$(
  ${eval_code_for_sh}
  ps1_function
)"

export PS2='$(
  ps2_function
)'