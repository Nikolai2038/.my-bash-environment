#!/bin/sh

# "/etc/resolv.conf" link remains after working in WSL, so we need to remove it in Debian
if [ -h "/etc/resolv.conf" ] && [ ! -e "/etc/resolv.conf" ]; then
  rm "/etc/resolv.conf"
fi
