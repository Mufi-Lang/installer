#!/bin/sh
# Copyright 2024 Mustafif Khan, MoKa Reads. All rights reserved. GPL v2.0 license.
set -e

# ANSI color codes with printf escape sequences
ANSI() {
    printf "\033[%sm" "$1"
}

RED="$(ANSI "31")"
GREEN="$(ANSI "32")"
BLUE="$(ANSI "34")"
YELLOW="$(ANSI "33")"
BOLD="$(ANSI "1")"
NC="$(ANSI "0")"

# Spinner characters for loading animation
spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )

# Function to show spinner
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinner[0]}
        spinner=(${spinner[@]:1} ${spinner[0]})
        printf "\r[%c] $2" "$temp"
        sleep $delay
    done
    printf "\r%s\n" "$3"
}

# Function for pretty printing
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

print_warning() {
    printf "%s!%s %s\n" "$YELLOW" "$NC" "$1"
}

# Function to print banner
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
    printf "\n%sMufiZ Installer%s - The Official Installation Script\n\n" "$BLUE" "$NC"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
    fi
}

# Check for required dependencies
check_dependencies() {
    print_step "Checking system dependencies..."

    local missing_deps=()

    for cmd in curl unzip grep sed; do
        if ! command -v $cmd >/dev/null 2>&1; then
            missing_deps+=($cmd)
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
    fi

    print_success "All dependencies are satisfied"
}

# Function to get system information
get_system_info() {
    print_step "Detecting system information..."

    # Get OS and architecture
    os=$(uname -s)
    arch=$(uname -m)

    # Get distribution info if on Linux
    if [ "$os" = "Linux" ]; then
        if [ -f "/etc/os-release" ]; then
            . /etc/os-release
            distro="$NAME"
            version="$VERSION_ID"
        else
            distro="Unknown"
            version="Unknown"
        fi
    fi

    printf "Operating System: %s%s%s\n" "$BOLD" "$os" "$NC"
    printf "Architecture: %s%s%s\n" "$BOLD" "$arch" "$NC"
    if [ "$os" = "Linux" ]; then
        printf "Distribution: %s%s%s\n" "$BOLD" "$distro" "$NC"
        printf "Version: %s%s%s\n" "$BOLD" "$version" "$NC"
    fi
}

# Function to get target triple
get_target() {
    print_step "Determining target triple..."

    if [ "$OS" = "Windows_NT" ]; then
        target="x86_64-pc-windows-msvc"
    else
        case $(uname -sm) in
            "Darwin x86_64") target="x86_64-apple-darwin" ;;
            "Darwin arm64") target="aarch64-apple-darwin" ;;

            # Linux ARM architectures
            "Linux aarch64")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="aarch64-linux-musl"
                else
                    target="aarch64-linux-gnu"
                fi ;;
            "Linux armv7l")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="arm-linux-musleabihf"
                else
                    target="arm-linux-gnueabihf"
                fi ;;

            # Linux MIPS architectures
            "Linux mips64")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="mips64-linux-musl"
                else
                    target="mips64-linux-gnu"
                fi ;;
            "Linux mips64el")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="mips64el-linux-musl"
                else
                    target="mips64el-linux-gnu"
                fi ;;
            "Linux mipsel")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="mipsel-linux-musl"
                else
                    target="mipsel-linux-gnu"
                fi ;;
            "Linux mips")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="mips-linux-musl"
                else
                    target="mips-linux-gnu"
                fi ;;

            # Linux PowerPC architectures
            "Linux ppc64")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="powerpc64-linux-musl"
                else
                    target="powerpc64-linux-gnu"
                fi ;;
            "Linux ppc")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="powerpc-linux-musl"
                else
                    target="powerpc-linux"
                fi ;;
            "Linux ppc64le")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="powerpc64le-linux-musl"
                else
                    target="powerpc64le-linux-gnu"
                fi ;;

            # Linux RISC-V architectures
            "Linux riscv64")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="riscv64-linux-musl"
                else
                    target="riscv64-linux"
                fi ;;

            # Linux x86 architectures
            "Linux x86_64")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="x86_64-linux-musl"
                else
                    target="x86_64-linux-gnu"
                fi ;;
            "Linux i386" | "Linux i686")
                if [ -f "/etc/os-release" ] && grep -q "ID=alpine" "/etc/os-release"; then
                    target="x86-linux-musl"
                else
                    target="x86-linux-gnu"
                fi ;;

            *) print_error "Unsupported architecture: $(uname -sm)" ;;
        esac
    fi

    printf "Target Triple: %s%s%s\n" "$BOLD" "$target" "$NC"
}

# Function to get latest version from GitHub API
get_latest_version() {
    print_step "Fetching latest version information..."

    # Start the API request in the background
    curl -s https://api.github.com/repos/Mufi-Lang/MufiZ/releases/latest > version.json &
    show_spinner $! "Querying GitHub API..." "GitHub API query complete"

    latest_version=$(grep -o '"tag_name": "v[^"]*' version.json | cut -d'"' -f4)
    if [ -z "$latest_version" ]; then
        print_error "Could not fetch latest version from GitHub"
    fi

    rm version.json
    printf "Latest Version: %s%s%s\n" "$BOLD" "$latest_version" "$NC"
}

# Function to download and install MufiZ
install_mufiz() {
    print_step "Installing MufiZ..."

    version_number=${latest_version#v}
    mufiz_uri="https://github.com/Mufi-Lang/MufiZ/releases/download/${latest_version}/mufiz_${version_number}_${target}.zip"
    bin_dir="/usr/local/bin"
    exe="$bin_dir/mufiz"

    printf "Download URL: %s%s%s\n" "$BOLD" "$mufiz_uri" "$NC"

    # Download with progress bar
    curl --fail --location --progress-bar --output "$exe.zip" "$mufiz_uri"

    # Extract and install
    if command -v unzip >/dev/null; then
        unzip -d "$bin_dir" -o "$exe.zip" > /dev/null 2>&1
    fi

    chmod +x "$exe"
    rm "$exe.zip"

    # Verify installation
    if command -v mufiz >/dev/null 2>&1; then
        print_success "MufiZ version ${version_number} was installed successfully to $exe"
    else
        print_error "Installation failed. Please check the error messages above."
    fi
}

# Main installation process
main() {
    print_banner
    check_root
    check_dependencies
    get_system_info
    get_target
    get_latest_version
    install_mufiz

    printf "\n%sInstallation complete!%s\n" "$GREEN" "$NC"
    printf "Run %smufiz --help%s to get started.\n" "$BOLD" "$NC"
}

# Run the installer
main
