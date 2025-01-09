#!/bin/sh
# Copyright 2024 Mustafif Khan, MoKa Reads. All rights reserved. GPL v2.0 license.
set -e

ANSI() {
    printf "\033[%sm" "$1"
}

RED="$(ANSI "31")"
GREEN="$(ANSI "32")"
BLUE="$(ANSI "34")"
YELLOW="$(ANSI "33")"
BOLD="$(ANSI "1")"
NC="$(ANSI "0")"

print_banner() {
    clear
    cat << "EOF"
 __  ___       ______ _  ____
|  \/  |      |  ___(_)/_   |
| .  . |_   _ | |_  | |  /  /
| |\/| | | | ||  _| | | /  /
| |  | | |_| || |   | |/  /__
\_|  |_/\__,_|\_|   |_/____/

EOF
    printf "\n%sMufiZ Manager%s - Install, Update, Remove\n\n" "$BLUE" "$NC"
}

print_usage() {
    printf "Usage: %s%s%s {install|update|remove}\n\n" "$BOLD" "$0" "$NC"
    printf "Commands:\n"
    printf "  install    Install MufiZ and MufiZUp\n"
    printf "  update     Update to latest version\n"
    printf "  remove     Uninstall MufiZ\n"
}

print_step() {
    printf "%s==>%s %s%s%s\n" "$BLUE" "$NC" "$BOLD" "$1" "$NC"
}

print_success() {
    printf "%s✓%s %s\n" "$GREEN" "$NC" "$1"
}

print_error() {
    printf "%s✗%s %s\n" "$RED" "$NC" "$1"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
    fi
}

check_dependencies() {
    local missing_deps=()
    for cmd in curl unzip grep sed; do
        if ! command -v $cmd >/dev/null 2>&1; then
            missing_deps+=($cmd)
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
    fi
}

get_latest_version() {
    curl -s https://api.github.com/repos/Mufi-Lang/MufiZ/releases/latest |
    grep -o '"tag_name": "v[^"]*' | cut -d'"' -f4
}

get_current_version() {
    if command -v mufiz >/dev/null 2>&1; then
        mufiz --version | cut -d' ' -f2
    else
        echo "not_installed"
    fi
}

get_target() {
    if [ "$OS" = "Windows_NT" ]; then
        echo "x86_64-pc-windows-msvc"
        return
    fi

    case $(uname -sm) in
        "Darwin x86_64") echo "x86_64-apple-darwin" ;;
        "Darwin arm64") echo "aarch64-apple-darwin" ;;
        "Linux aarch64")
            if grep -q "ID=alpine" "/etc/os-release" 2>/dev/null; then
                echo "aarch64-linux-musl"
            else
                echo "aarch64-linux-gnu"
            fi ;;
        # [Additional architecture cases remain the same...]
        *)
            if grep -q "ID=alpine" "/etc/os-release" 2>/dev/null; then
                echo "x86_64-linux-musl"
            else
                echo "x86_64-linux-gnu"
            fi ;;
    esac
}

install_mufiz() {
    local version="$1"
    local target="$(get_target)"
    local bin_dir="/usr/local/bin"
    local exe="$bin_dir/mufiz"
    local manager="$bin_dir/mufizup"

    local uri="https://github.com/Mufi-Lang/MufiZ/releases/download/v${version}/mufiz_${version}_${target}.zip"

    print_step "Downloading MufiZ v${version}"
    curl --fail --location --progress-bar --output "$exe.zip" "$uri"

    print_step "Installing MufiZ"
    unzip -d "$bin_dir" -o "$exe.zip" > /dev/null 2>&1
    chmod +x "$exe"
    rm "$exe.zip"

    print_step "Installing mufizup manager"
    cp "$0" "$manager"
    chmod +x "$manager"

    print_success "MufiZ v${version} and mufizup installed successfully"
}

remove_mufiz() {
    local bin_dir="/usr/local/bin"
    local exe="$bin_dir/mufiz"
    local manager="$bin_dir/mufizup"

    if [ -f "$exe" ]; then
        rm "$exe"
        print_success "MufiZ removed successfully"
    else
        print_error "MufiZ is not installed"
    fi
}

cmd_install() {
    print_step "Installing MufiZ"
    check_dependencies
    local latest_version="$(get_latest_version)"
    install_mufiz "${latest_version#v}"
}

cmd_update() {
    print_step "Checking for updates"
    check_dependencies

    local current_version="$(get_current_version)"
    local latest_version="$(get_latest_version)"

    if [ "$current_version" = "not_installed" ]; then
        print_error "MufiZ is not installed"
    fi

    if [ "v$current_version" = "$latest_version" ]; then
        print_success "MufiZ is already up to date (v${current_version})"
        exit 0
    fi

    print_step "Updating from v${current_version} to ${latest_version}"
    install_mufiz "${latest_version#v}"
}

cmd_remove() {
    print_step "Removing MufiZ"
    remove_mufiz
}

main() {
    print_banner
    check_root

    case "$1" in
        "install") cmd_install ;;
        "update") cmd_update ;;
        "remove") cmd_remove ;;
        *) print_usage; exit 1 ;;
    esac
}

main "$@"
