#!/usr/bin/env bash

set -eu

if [[ $# -ne 2 ]] ; then
  echo -e "What:  MageOps Mount WatchDog"
  echo -e "Why:   Detect and attempt to fix a crashed FUSE mount"
  echo -e "How:   $0 fix|remount /path/to/mountpoint"
  exit 1
fi

KILLTIMEOUT="5s"
PROGNAME="$(basename "$0")"

SUBCOMMAND="$1"
MOUNTPOINT="$(realpath --canonicalize-missing "$2")"

mount-watchdog::log() {
  local LEVEL="$1"; shift
  echo "[${SUBCOMMAND}] [${LEVEL}] [${MOUNTPOINT}] $@"
}

mount-watchdog::is_mounted() {
  findmnt --kernel --all /var/www/magento/shared/pub/media >/dev/null
}

mount-watchdog::is_usable() {
  mountpoint -q "${MOUNTPOINT}" && \
  stat "${MOUNTPOINT}" 2>&1 >/dev/null
}

mount-watchdog::is_defined() {
  findmnt --fstab >/dev/null "${MOUNTPOINT}"
}

mount-watchdog::get_source() {
  findmnt --fstab --first-only --noheadings --output SOURCE "${MOUNTPOINT}"
}

mount-watchdog::unmount() {
  ( mount-watchdog::log "INFO" "Attempting NORMAL unmount"  ;   umount    "${MOUNTPOINT}" ) || \
  ( mount-watchdog::log "INFO" "Attempting FORCED unmount"  ;   umount -f "${MOUNTPOINT}" ) || \
  ( mount-watchdog::log "INFO" "Attempting LAZY unmount"    ;   umount -l "${MOUNTPOINT}" ) && \
  ( mount-watchdog::log "INFO" "Unmounted successfully" )
}

mount-watchdog::mount() {
  if mount "${MOUNTPOINT}" 2>&1 >/dev/null ; then
    mount-watchdog::log "INFO" "Remounted successfully"
  else
    mount-watchdog::log "CRITICAL" "Remount failed" >&2
    return 3
  fi
}

mount-watchdog::kill() {
  local PATTERN="$(mount-watchdog::get_source | sed 's/#\+/.*/g').*${MOUNTPOINT}"
  
  mount-watchdog::log "INFO" "Attempting to kill fuse processes matching '$PATTERN'"

  if ! pkill -f "$PATTERN" --echo 2>/dev/null ; then
    mount-watchdog::log "NOTICE" "No process found to be killed"
    return 1
  else
    mount-watchdog::log "INFO" "Sent SIGTERM, waiting for ${KILLTIMEOUT} for termination"
    sleep "${KILLTIMEOUT}"

    if pgrep -f "$PATTERN" 2>&1 >/dev/null ; then
      mount-watchdog::log "INFO" "Process still running, sending SIGKILL"
      pkill -SIGKILL -f "$PATTERN" --echo 2>/dev/null
    fi
  fi
}

mount-watchdog::remount() {
  mount-watchdog::unmount || mount-watchdog::kill || true
  mount-watchdog::mount
}

mount-watchdog::fix() {
  if ! mount-watchdog::is_mounted ; then
    mount-watchdog::log "INFO" "Not mounted"
    mount-watchdog::mount
  else
    if ! mount-watchdog::is_usable ; then
      mount-watchdog::log "NOTICE" "Mounted but unusable"

      if ! mount-watchdog::unmount ; then
        mount-watchdog::log "WARNING" "Unmounting failed" >&2

        if mount-watchdog::kill ; then
          mount-watchdog::log "NOTICE" "Attempting one more unmount after successfull kill" >&2
          mount-watchdog::unmount
        fi
      fi

      mount-watchdog::mount
    else
      mount-watchdog::log "INFO" "Mountpoint is present and usable" 
    fi
  fi
}

if ! mount-watchdog::is_defined ; then
  mount-watchdog::log "CRITICAL" "Mount not defined in fstab" >&2
  exit 2
fi

"mount-watchdog::${SUBCOMMAND}"




