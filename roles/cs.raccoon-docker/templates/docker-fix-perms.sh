#!/usr/bin/env bash

set -e

# First try to touch each of the dirs as Magento user -
# because Docker for Mac (osxfs) changes the permissions
# to the first user which has actually accessed the files.

APP_USER="{{ magento_user }}"
APP_GROUP="{{ magento_group }}"
APP_UID="$(id -u $APP_USER)"
APP_GID="$(id -g $APP_USER)"

APP_ROOT_DIR="{{ mageops_app_web_dir }}"
APP_DIRS="$(sudo -u $APP_USER find $APP_ROOT_DIR -maxdepth 1 -type d)"

echo "Settings: $APP_USER:$APP_GROUP ($(id -u $APP_USER):$(id -g $APP_GROUP))"

for APP_DIR in $APP_DIRS ; do
    # Touch it as magento (see above)
    sudo -u $APP_USER touch $APP_DIR &>/dev/null || true

    APP_DIR_UID="$(stat -c%u "$APP_DIR")"
    APP_DIR_GID="$(stat -c%g "$APP_DIR")"

    DOCKER_VOL_USER="$APP_USER-d$APP_DIR_UID"
    DOCKER_VOL_GROUP="$APP_USER-d$APP_DIR_GID"

    if [ "$APP_DIR_UID" == "0" ] ; then
        echo "Directory $APP_DIR is owned by root! It will not work, skipping..."
        continue
    fi

    if [ "$APP_DIR_UID" == "$APP_UID" ] || [ "$APP_DIR_GID" == "$APP_GID" ] ; then
        echo "Directory $APP_DIR is already owner by $APP_USER, skipping..."
        continue
    fi

    stat "$APP_DIR" -c"Processing directory: %N - %U:%G (%u:%g)"

    if ! getent group $APP_DIR_GID &>/dev/null ; then
        echo "Adding group: $DOCKER_VOL_GROUP ($APP_DIR_GID)"
        groupadd -g "$APP_DIR_GID" "$DOCKER_VOL_GROUP"
    fi

    if ! id -u $APP_DIR_UID &>/dev/null ; then
        echo "Adding user: $DOCKER_VOL_USER ($APP_DIR_UID)"
        useradd -u "$APP_DIR_UID" -g "$APP_DIR_GID" -m "$DOCKER_VOL_USER"
    fi

    echo "Adding: $APP_USER to $DOCKER_VOL_GROUP group"
    usermod -a -G "$DOCKER_VOL_GROUP" "$APP_USER"

    echo "Adding: $APP_USER to nginx group"
    usermod -a -G "$DOCKER_VOL_GROUP" nginx
done