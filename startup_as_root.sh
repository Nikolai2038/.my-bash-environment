#!/bin/sh

date >> /home/nikolai/TESTED.txt

DIRECTORY_WITH_THIS_SCRIPT="$(dirname "$0")"

# Execute each file in "./startup.d/"
if [ -d "${DIRECTORY_WITH_THIS_SCRIPT}/startup_as_root.d" ]; then
  for file in "${DIRECTORY_WITH_THIS_SCRIPT}/startup_as_root.d"/*; do
    if [ -r "${file}" ]; then
      "${file}"
    fi
  done
  unset file
fi
