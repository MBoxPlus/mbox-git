#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"
source "./common.sh"

mbox_print_title Checking git
check_git_installed
if [[ $? != 0 ]]; then
    mbox_print_title Installing git
    mbox_exe brew install git
    mbox_exe brew link --override git
    hash -r

    check_git_installed
    if [[ $? != 0 ]]; then
        exit 1
    fi
fi

mbox_print_title Checking Git Version
check_git_version
if [[ $? != 0 ]]; then
    mbox_exe brew upgrade git

    check_git_version
    if [[ $? != 0 ]]; then
        exit 1
    fi
fi
