#!/bin/bash

n2038_init() {
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
  _C_RESET="$(printf '\E(B\E[m')"

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

  my_function_export() {
    function_name="$1" && { shift || true; }

    variable_name="${function_name}_EXPORT"

    if [ -n "$(eval "echo \"\${${variable_name}}\"")" ]; then
      # If variable with function body exists - execute it
      eval "\${${variable_name}}" || return "$?"
    else
      # If variable with function body does not exists - we create it

      function_body="$(typeset -f "${function_name}")"
      function_body="${function_body//'\'/'\\'}"
      function_body="${function_body//'"'/'\"'}"
      function_body="${function_body//'$'/'\$'}"

      eval "export ${variable_name}=\"${function_body}\""
    fi
  }
  function_name=my_function_export
  variable_name="${function_name}_EXPORT"
  if [ -n "$(eval "echo \"\${${variable_name}}\"")" ]; then
    # If variable with function body exists - execute it
    eval "\${${variable_name}}" || return "$?"
  else
    # If variable with function body does not exists - we create it
    function_body="$(typeset -f "${function_name}")"
    function_body="${function_body//'\'/'\\'}"
    function_body="${function_body//'"'/'\"'}"
    function_body="${function_body//'$'/'\$'}"

    eval "export ${variable_name}=\"${function_body}\""
  fi

  sed_escape() {
    echo "$@" | sed -e 's/[]\/$*.^;|{}()[]/\\&/g' || return "$?"
    return 0
  }
  my_function_export sed_escape

  # Prints current shell name
  get_current_shell() {
    echo "$0" | sed 's/[^a-z]//g' || return "$?"
    return 0
  }
  my_function_export get_current_shell

  get_process_depth() {
    # Head to hide sub pipelines.
    # Remember, that "wc" command also counts.
    pstree --ascii --long --show-parents --hide-threads --arguments $$ | wc -l || return "$?"
    return 0
  }
  my_function_export get_process_depth

  # We make function to find shell name
  check_if_shell_changed() {
    if [ -z "${current_shell}" ]; then
      current_shell="$(get_current_shell)" || return "$?"
      if [ "${current_shell}" = "bash" ]; then
        # Braces "\[" and "\]" are required, so "bash" can understand, that this is colors and not output.
        # If we do not use them, the shell will break when we try to navigate in commands' history.
        export C_TEXT="\[${_C_TEXT}\]"
        export C_ERROR="\[${_C_ERROR}\]"
        export C_SUCCESS="\[${_C_SUCCESS}\]"
        export C_BORDER_USUAL="\[${_C_BORDER_USUAL}\]"
        export C_BORDER_ROOT="\[${_C_BORDER_ROOT}\]"
        export C_RESET="\[${_C_RESET}\]"
      else
        # "sh" does not have commands' history, and braces will result in just text, so we don't use them here
        export C_TEXT="${_C_TEXT}"
        export C_ERROR="${_C_ERROR}"
        export C_SUCCESS="${_C_SUCCESS}"
        export C_BORDER_USUAL="${_C_BORDER_USUAL}"
        export C_BORDER_ROOT="${_C_BORDER_ROOT}"
        export C_RESET="${_C_RESET}"
      fi
    fi

    return 0
  }
  my_function_export check_if_shell_changed
}
# For subshells, we don't need to initialize these variables twice
if [ -z "${n2038_is_initialized}" ]; then
  n2038_init
  export n2038_is_initialized=1
fi

# Different color for root
if [ "$(id --user "${USER}")" = "0" ]; then
  export sudo_prefix=""
  export C_BORDER="${C_BORDER_ROOT}"
else
  export sudo_prefix="sudo "
  export C_BORDER="${C_BORDER_USUAL}"
fi

# Must not use export here!
current_shell=""
check_if_shell_changed || return "$?"

ps1_function() {
  check_if_shell_changed

  echo '$ '
  #  echo -e "${C_SUCCESS}$ ${C_RESET}"
}

ps2_function() {
  echo "> "
  #  echo -e "${C_SUCCESS}> ${C_RESET}"
}

PS1='$(ps1_function)'
PS2='$(ps2_function)'
