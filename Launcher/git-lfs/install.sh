#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

mbox_print_title Checking git-lfs
if mbox_exec brew ls --versions git-lfs; then
    echo "git-lfs installed, skip!"
else
    mbox_print_title Installing git-lfs
    mbox_exe brew install git-lfs
    mbox_exe git lfs install
fi
