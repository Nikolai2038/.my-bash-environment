#!/bin/bash

# ----------------------------------------
# APT aliases
# ----------------------------------------
# If "apt" is not installed - we create alias for it to "apt-get"
if ! apt --help > /dev/null 2>&1; then
  # (This is not working in this script, so we still use "apt-get" everywhere here)
  alias apt="apt-get"
fi

# Update packages
# shellcheck disable=2139
alias au="${sudo_prefix}apt-get update && ${sudo_prefix}apt-get dist-upgrade -y && ${sudo_prefix}apt-get autoremove -y"

# Install packages
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

# Remove packages
unalias ar > /dev/null 2>&1
ar() {
  # shellcheck disable=2086
  ${sudo_prefix}apt-get remove -y "$@" || return "$?"
  # shellcheck disable=2086
  ${sudo_prefix}apt-get autoremove -y || return "$?"
  return 0
}
# ----------------------------------------
