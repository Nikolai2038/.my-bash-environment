#!/bin/bash

# ----------------------------------------
# ls aliases
# ----------------------------------------
# 1. Detailed list
unalias lls > /dev/null 2>&1
lls() {
  # We use "sed" to remove "total".
  # shellcheck disable=SC2012
  ls -F --group-directories-first --color -l --human-readable --time-style=long-iso "${@}" | sed -E '/^(total|итого)/d' || return "$?"
  return 0
}

# 2. Detailed list with hidden files
alias llas="lls --almost-all"
alias llsa="llas"

# 3. Simple list
unalias ll > /dev/null 2>&1
ll() {
  # We don't use "-1" from "ls" because it does not show us where links are pointing.
  # Instead, we use "cut".
  # We use "tr" to remove duplicate spaces - for "cut" to work properly.
  lls "${@}" | tr -s '[:blank:]' | cut -d ' ' -f 8- || return "$?"
  return 0
}

# 4. Simple list with hidden files
alias lla="ll --almost-all"

# 5. Simple list without hidden files (Markdown format)
unalias llm > /dev/null 2>&1
llm() {
  # shellcheck disable=2016
  ll "${@}" | sed -E 's/^(.*)$/- `\1`;/' || return "$?"
  return 0
}

# 6. Simple list with hidden files (Markdown format)
alias llam="llm --almost-all"
alias llma="llam"
# ----------------------------------------
