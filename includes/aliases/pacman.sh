#!/bin/bash

# ----------------------------------------
# Pacman aliases
# ----------------------------------------
# Update packages
# Passing two "--refresh" flags will force a refresh of all package databases, even if they appear to be up-to-date.
# shellcheck disable=2139
alias pu="${sudo_prefix}pacman --noconfirm --sync --refresh --refresh --needed --sysupgrade"

# Install packages
# shellcheck disable=2139
alias pi="${sudo_prefix}pacman --noconfirm --sync --refresh --needed"

# Remove packages
# "pr" command exists (convert text files for printing), but I don't use it.
# shellcheck disable=2139
alias pr="${sudo_prefix}pacman --noconfirm --remove --unneeded --nosave --recursive"
# ----------------------------------------
