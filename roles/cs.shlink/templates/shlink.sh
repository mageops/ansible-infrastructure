#!/usr/bin/env sh

###
# This is a wrapper to conveniently use shlink cli from outside the container
###

/usr/bin/podman exec \
    --interactive \
    --tty \
        "{{ shlink_container_name }}" \
            shlink "$@"

code=$?

if [ $code -ne 0 ] ; then
    if [ $code -eq 125 ] ; then
        echo -e "" >&2
        echo -e "-> Before running this command ensure shlink systemd service is running!" >&2
        echo -e "-> Current shlink service status: \n\n$(systemctl status shlink 2>&1 || true)" >&2
    fi

    exit $code
fi