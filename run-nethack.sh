#!/bin/sh
# Wait for ttyd to apply the browser's fitted terminal size before NetHack
# reads the window dimensions at startup.
delay=0
while [ "$delay" -lt 30 ]; do
  rows=$(stty size 2>/dev/null | awk '{print $1}')
  cols=$(stty size 2>/dev/null | awk '{print $2}')
  if [ -n "$rows" ] && [ -n "$cols" ] && [ "$rows" -ge 24 ] && [ "$cols" -ge 80 ]; then
    break
  fi
  sleep 0.1
  delay=$((delay + 1))
done

exec nethack
