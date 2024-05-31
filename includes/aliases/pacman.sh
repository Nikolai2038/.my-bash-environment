#!/bin/bash

# ----------------------------------------
# Pacman aliases
# ----------------------------------------
# Update packages
# shellcheck disable=2139
alias pu="${sudo_prefix}pacman -Syy"

# Install packages
# shellcheck disable=2139
alias pi="${sudo_prefix}pacman -Sy --noconfirm --needed"

# Remove packages
# "pr" command exists (convert text files for printing), but I don't use it.
# shellcheck disable=2139
alias pr="${sudo_prefix}pacman -Runs --noconfirm"
# ----------------------------------------
