#!/bin/bash

set -e

# If already done then nothing to do anymore
if [ -f '/var/mageops-pip-packages-fixed.lock' ] ; then
   echo "Already fixed here, nothing to do" >&2
   exit
fi

# This is a one-time script to be executed (semi-)manually in case some python
# packages were installed through PIP instead of Yum causing problems.
# Once we fix provisioning not to ever use global PIP installs then
# this issue should be hopefully gone forever.

set -x

# Clean downloaded packages in case there are some corrupted files
# - happened to me once or twice (download must've been interrupted) /FS
yum -y clean packages

# The `-t` switch causes dnf/yum to be more tolerant of errors - I had problems
# with urllib so keep this flag!

# - Uninstall MySQL-Python as it's being deprecated and all
#   ansible modules we use support PyMySQL already.
# - Uninstall pyOpenSSL as cryptography is used directly now
#   and actually the mere presence of pyOpenSSL causes problemls
#   with some ansible modules.
# - `docker` package is being deprecated and causes problems with
#   new ansible, `docker-py` is the preferr3ed package now.
pip uninstall --yes MySQL-python || true
pip uninstall --yes pyOpenSSL || true
pip uninstall --yes docker || true
yum -y -t remove \
    MySQL-python \
    pyOpenSSL

# Reinstallation of urllib often fails with an error like this:
#
# Error unpacking rpm package python-urllib3-1.10.2-7.el7.noarch
# error: unpacking of archive failed on file /usr/lib/python2.7/site-packages/urllib3/packages/ssl_match_hostname: cpio: rename
#   Installing : python-chardet-2.2.1-3.el7.noarch
# error: python-urllib3-1.10.2-7.el7.noarch: install failed
#
# ...so we have to treat it in a special way:
pip uninstall --yes urllib3 || true
yum -y -t remove python-urllib3 || true
yum -y install python-urllib3

# Reinstall known python modules which might've been replaced with versions
# from PIP causing incompatiblities and provisioning errors.
yum -y -t reinstall \
    python2-cryptography \
    python2-PyMySQL \
    python-paramiko \
    python-docker-py \
    python-docker-pycreds \
    python-requests \
    python-six \
    python-idna \
    python-chardet \
    python-cffi \
    python-ipaddress \
    python-pycparser \
    python-enum34

set +x

# Try to find any corrupted yum packages for python modules
# and reinstall them.
dnf list --installed | sort | grep '^py' | while read PKG ; do
    PKG=$(echo "$PKG" | cut -d' ' -f1)

    if ! yum verify-rpm "$PKG" >/dev/null 2>&1 ; then
        echo "- Package $PKG files are corrupted, reinstalling!" >&2
        yum -y -t reinstall $PKG
    else
        echo "+ Package $PKG verified OK"
    fi
done

# Create lockfile indicating that the fixed was performed
date > /var/mageops-pip-packages-fixed.lock