#!/bin/bash

# ----------------------------------------
# Pacman and YAY aliases
# ----------------------------------------
# Update packages
# Passing two "--refresh" flags will force a refresh of all package databases, even if they appear to be up-to-date.
# We rebuild the kernel to avoid errors on reboot, if some required packages were updated.
# shellcheck disable=2139
alias pu="${sudo_prefix}pacman --noconfirm --sync --refresh --refresh --needed --sysupgrade && ${sudo_prefix}mkinitcpio -P"
alias yu="yay --noconfirm --sync --refresh --refresh --needed --sysupgrade && ${sudo_prefix}mkinitcpio -P"
alias puyu="${sudo_prefix}pacman --noconfirm --sync --refresh --refresh --needed --sysupgrade && yay --noconfirm --sync --refresh --refresh --needed --sysupgrade && ${sudo_prefix}mkinitcpio -P"

# Install packages.
# Commands with "-hand" needed for removing conflicting packages, when installing other ones.
# shellcheck disable=2139
alias pi-hand="${sudo_prefix}pacman --sync --refresh --needed"
alias yi-hand="yay --sync --refresh --needed"
# With auto confirm
alias pi="pi-hand --noconfirm"
alias yi="yi-hand --noconfirm"

# Remove packages
# "pr" command exists (convert text files for printing), but I don't use it.
# shellcheck disable=2139
alias pr="${sudo_prefix}pacman --noconfirm --remove --unneeded --nosave --recursive"
alias yr="yay --noconfirm --remove --unneeded --nosave --recursive"
# ----------------------------------------
