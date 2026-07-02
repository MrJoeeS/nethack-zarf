#!/bin/sh
set -e

HACKDIR=/opt/nethack/games/lib/nethackdir

export PATH="/opt/nethack/games:${PATH}"
export TERM=xterm-256color
export HOME=/var/nethack

# NetHack refuses to start without a readable sysconf when built with SYSCF.
if [ ! -r "${HACKDIR}/sysconf" ]; then
  echo "Missing ${HACKDIR}/sysconf; rebuild the image with an up-to-date Dockerfile." >&2
  exit 1
fi

# Ensure scoreboard and lock files exist and are writable for the runtime user.
for file in record perm logfile xlogfile livelog; do
  if [ ! -e "${HACKDIR}/${file}" ]; then
    : > "${HACKDIR}/${file}"
  fi
  chmod 600 "${HACKDIR}/${file}"
done
chmod 700 "${HACKDIR}/save"

exec ttyd \
  --port 7681 \
  --interface 0.0.0.0 \
  --writable \
  --client-option disableReconnect=true \
  --client-option disableResizeOverlay=true \
  --client-option fontSize=16 \
  --client-option fontFamily=monospace \
  /run-nethack.sh
