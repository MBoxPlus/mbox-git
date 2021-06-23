#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

mbox_print_title Checking git-lfs
if mbox_exec brew ls --versions git-lfs; then
    echo "git-lfs installed."
else
    mbox_print_error "git-lfs is not installed."
    exit 1
fi
