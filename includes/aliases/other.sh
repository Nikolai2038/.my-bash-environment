#!/bin/bash

# ----------------------------------------
# Other aliases
# ----------------------------------------
# Use as alias but without space
unalias examples > /dev/null 2>&1
examples() {
  less -R << EOF
$(curl "https://cheat.sh/${*}")
EOF
  return 0
}

# journalctl
alias jctl='journalctl --pager-end --no-hostname --boot=0 --output=short'
alias jctlf='jctl --follow'

# Binary can be called "batcat"
if { { ! bat --help; } && batcat --help; } > /dev/null 2>&1; then
  alias bat="batcat"
fi

# "bat" is colorized "cat", so we use it, if it is installed.
if bat --help > /dev/null 2>&1; then
  alias cat="bat --style='plain' --paging=never --theme='Visual Studio Dark+'"

  # pat pat
  alias pat="cat --paging=always --pager 'less --RAW-CONTROL-CHARS --chop-long-lines +gg'"
  alias pat-wrap="cat --paging=always --pager 'less --RAW-CONTROL-CHARS +gg'"

  alias less="pat"
  alias less-wrap="pat-wrap"
else
  # "+gg" is to scroll to the top (first opening may glitch if this is not applied)
  # One-line mode
  alias less="less --RAW-CONTROL-CHARS --chop-long-lines +gg"
  # Wrap lines
  alias less-wrap="less --RAW-CONTROL-CHARS +gg"
fi

unalias lsblk > /dev/null 2>&1
lsblk() {
  # "command" to avoid recursion.
  # "sed" to add dots for align.
  command lsblk -o name,rm,ro,size,FSTYPE,UUID,mountpoints,label,MODEL | \
    sed -E '
      # Remove trailing spaces
      s/[ ]+$//
      # Replace all spaces with dots
      s/ /·/g
      # Replace leading dots with spaces
      s/([^·])·/\1 /g
      # Replace first dot with space
      s/·([^·])/ \1/g

      # Replace last dot with space
      :trim_before
      s/^([ │]*)·/\1 /
      t trim_before

      # Remove small amounts of dots
      s/([^·])·([^·])/\1 \2/
      s/([^·])··([^·])/\1  \2/
    ' | less
}

# Not all "su" commands have this option, so we check for that
if { su --help | grep 'whitelist-environment'; } > /dev/null 2>&1; then
  # We need PSTREE_MINUS here to not reset depth level
  alias su='su --whitelist-environment=PS_TREE_MINUS'
fi

# TODO: Some problems with that - disabled for now
# # To use aliases in sudo too we add alias for it with space
# alias sudo="sudo --preserve-env=PS_TREE_MINUS "
# ----------------------------------------
