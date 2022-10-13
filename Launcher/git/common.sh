
function check_git_installed() {
    if mbox_exec brew ls --versions git; then
        echo "git installed."
    else
        mbox_print_error "git is not installed."
        return 1
    fi
    path=$(which git)
    if [[ $? != 0 ]]; then
        mbox_print_error "git command not find."
        return 1
    fi
    if [[ "${path}" != "$(brew --prefix)/"* ]]; then
        mbox_print_error "git is '${path}', it maybe override the brew. Please check 'brew doctor'."
        return 1
    fi
}

function check_git_version() {
    local version=$(git --version | cut -d " " -f 3)
    echo "Git Version: ${version}"

    vercomp "$version" "2.37.0"
    if [[ $? != 2 ]]; then
        echo "Git Version is OK."
        return 0
    fi

    echo "Git Version is outdated."
    return 1
}
