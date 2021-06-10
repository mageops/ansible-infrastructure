#!/usr/bin/env bash
set -euo pipefail

EFS_MOUNTPOINT="{{ aws_efs_logs_efs_dir }}"
LOG_TARGET_PATH="$EFS_MOUNTPOINT/$( hostname )"

if ! [ -d "$EFS_MOUNTPOINT" ];then
    echo "Mount point does not exist!"
    exit 2
fi

if [ -L "/var/log" ];then
    echo "/var/log is already symlinked"
    exit 0
fi

if [ -e "$LOG_TARGET_PATH" ];then
    LOG_RENAME_TO="$LOG_TARGET_PATH-moved-$(date -Iseconds)"
    echo "Found existing log target dir, renaming to $LOG_RENAME_TO"
    mv "$LOG_TARGET_PATH" "$LOG_RENAME_TO"
fi

echo "Moving logs to EFS"
mv /var/log "$LOG_TARGET_PATH"
mkdir /var/log

# After reboot we will start logging on local filesystem again, we need to restore files structure to make sure nothing will crash

echo "Recreating directories in local log"
find "$LOG_TARGET_PATH" -type d -printf '%P\n' \
    | xargs -I '{}' sh -c "mkdir '/var/log/{}' && chmod -v --reference='$LOG_TARGET_PATH/{}' '/var/log/{}' && chown -v --reference='$LOG_TARGET_PATH/{}' '/var/log/{}'"

echo "Recreate files in local log"
find "$LOG_TARGET_PATH" -type f -printf '%P\n' \
    | grep -v -E '(\-|\.)[0-9]+(\.log|\.json)?(\.gz|\.zstd|.zst)?$' \
    | xargs -I '{}' sh -c "touch '/var/log/{}' && chmod -v --reference='$LOG_TARGET_PATH/{}' '/var/log/{}' && chown -v --reference='$LOG_TARGET_PATH/{}' '/var/log/{}'"

mount -o bind,nonempty --make-private "$LOG_TARGET_PATH" /var/log
