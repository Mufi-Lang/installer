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

# Global variables for cleanup
TEMP_DIR=""
BACKUP_DIR=""
INTERRUPTED=0

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
    printf "Usage: %s%s%s {install|update|remove|install-version|list-versions}\n\n" "$BOLD" "$0" "$NC"
    printf "Commands:\n"
    printf "  install              Install latest MufiZ and MufiZUp\n"
    printf "  update               Update to latest version\n"
    printf "  remove               Uninstall MufiZ\n"
    printf "  install-version VER  Install specific version (e.g., 1.2.3 or v1.2.3)\n"
    printf "  list-versions        List available versions\n"
}

print_step() {
    printf "%s==>%s %s%s%s\n" "$BLUE" "$NC" "$BOLD" "$1" "$NC"
}

print_success() {
    printf "%s✓%s %s\n" "$GREEN" "$NC" "$1"
}

print_error() {
    printf "%s✗%s %s\n" "$RED" "$NC" "$1"
}

print_warning() {
    printf "%s⚠%s %s\n" "$YELLOW" "$NC" "$1"
}

# Signal handler for cleanup
cleanup() {
    INTERRUPTED=1
    print_warning "Operation interrupted, cleaning up..."

    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi

    # If we have a backup and the operation was interrupted, offer to restore
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        printf "Restore previous version? [y/N]: "
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS]) restore_backup ;;
            *) remove_backup ;;
        esac
    fi

    exit 1
}

# Set up signal handlers
trap cleanup INT TERM

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

check_dependencies() {
    local missing_deps=""
    for cmd in curl unzip grep sed mktemp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done

    if [ -n "$missing_deps" ]; then
        print_error "Missing dependencies:$missing_deps"
        exit 1
    fi
}

check_process_running() {
    if command -v mufiz >/dev/null 2>&1; then
        if pgrep -f "mufiz" >/dev/null 2>&1; then
            print_warning "MufiZ processes are currently running"
            printf "Continue anyway? [y/N]: "
            read -r response
            case "$response" in
                [yY]|[yY][eE][sS]) ;;
                *) print_error "Operation cancelled"; exit 1 ;;
            esac
        fi
    fi
}

create_temp_dir() {
    TEMP_DIR=$(mktemp -d -t mufiz.XXXXXX) || {
        print_error "Failed to create temporary directory"
        exit 1
    }
}

create_backup() {
    local bin_dir="/usr/local/bin"

    if [ -f "$bin_dir/mufiz" ] || [ -f "$bin_dir/mufizup" ]; then
        print_step "Creating backup of existing installation"
        BACKUP_DIR=$(mktemp -d -t mufiz-backup.XXXXXX) || {
            print_error "Failed to create backup directory"
            exit 1
        }

        if [ -f "$bin_dir/mufiz" ]; then
            cp "$bin_dir/mufiz" "$BACKUP_DIR/" || {
                print_error "Failed to backup mufiz binary"
                exit 1
            }
        fi

        if [ -f "$bin_dir/mufizup" ]; then
            cp "$bin_dir/mufizup" "$BACKUP_DIR/" || {
                print_error "Failed to backup mufizup manager"
                exit 1
            }
        fi

        print_success "Backup created at $BACKUP_DIR"
    fi
}

restore_backup() {
    if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
        print_warning "No backup available to restore"
        return
    fi

    local bin_dir="/usr/local/bin"
    print_step "Restoring from backup"

    if [ -f "$BACKUP_DIR/mufiz" ]; then
        cp "$BACKUP_DIR/mufiz" "$bin_dir/" && chmod +x "$bin_dir/mufiz"
    fi

    if [ -f "$BACKUP_DIR/mufizup" ]; then
        cp "$BACKUP_DIR/mufizup" "$bin_dir/" && chmod +x "$bin_dir/mufizup"
    fi

    remove_backup
    print_success "Previous version restored"
}

remove_backup() {
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        rm -rf "$BACKUP_DIR"
        BACKUP_DIR=""
    fi
}

get_latest_version() {
    local version
    version=$(curl -s --max-time 30 https://api.github.com/repos/Mufi-Lang/MufiZ/releases/latest |
    grep -o '"tag_name": "v[^"]*' | cut -d'"' -f4) || {
        print_error "Failed to fetch latest version from GitHub"
        exit 1
    }

    if [ -z "$version" ]; then
        print_error "Could not determine latest version"
        exit 1
    fi

    echo "$version"
}

validate_version_format() {
    local version="$1"

    # Remove 'v' prefix if present
    version="${version#v}"

    # Check if version matches semantic versioning pattern
    if ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$'; then
        return 1
    fi

    echo "$version"
}

check_version_exists() {
    local version="$1"
    local api_url="https://api.github.com/repos/Mufi-Lang/MufiZ/releases"

    # Add 'v' prefix if not present
    if ! echo "$version" | grep -q '^v'; then
        version="v$version"
    fi

    local exists
    exists=$(curl -s --max-time 30 "$api_url" | grep -o "\"tag_name\": \"$version\"" | head -1) || {
        print_error "Failed to check version availability"
        exit 1
    }

    if [ -z "$exists" ]; then
        return 1
    fi

    return 0
}

get_available_versions() {
    local api_url="https://api.github.com/repos/Mufi-Lang/MufiZ/releases"

    curl -s --max-time 30 "$api_url" | \
    grep -o '"tag_name": "v[^"]*"' | \
    cut -d'"' -f4 | \
    sort -V || {
        print_error "Failed to fetch available versions"
        exit 1
    }
}

get_current_version() {
    if command -v mufiz >/dev/null 2>&1; then
        local version
        version=$(mufiz --version 2>/dev/null | cut -d' ' -f2) || echo "unknown"
        echo "$version"
    else
        echo "not_installed"
    fi
}

get_target() {
    if [ "$OS" = "Windows_NT" ]; then
        echo "x86_64-windows"
        return
    fi

    case $(uname -sm) in
        "Darwin x86_64") echo "x86_64-macos" ;;
        "Darwin arm64") echo "aarch64-macos" ;;
        "Linux aarch64")
            if grep -q "ID=alpine" "/etc/os-release" 2>/dev/null; then
                echo "aarch64-linux-musl"
            else
                echo "aarch64-linux"
            fi ;;
        "Linux armv6l") echo "arm-linux-gnueabihf" ;;
        "Linux armv7l") echo "arm-linux-gnueabihf" ;;
        "Linux s390x") echo "s390x-linux" ;;
        "Linux ppc64le") echo "powerpc64le-linux" ;;
        "Linux riscv64") echo "riscv64-linux" ;;
        *)
            if grep -q "ID=alpine" "/etc/os-release" 2>/dev/null; then
                echo "x86_64-linux-musl"
            else
                echo "x86_64-linux"
            fi ;;
    esac
}

validate_download() {
    local file="$1"

    # Check if file exists and is not empty
    if [ ! -f "$file" ] || [ ! -s "$file" ]; then
        print_error "Downloaded file is missing or empty"
        return 1
    fi

    # Check if it's a valid zip file
    if ! unzip -t "$file" >/dev/null 2>&1; then
        print_error "Downloaded file is not a valid zip archive"
        return 1
    fi

    return 0
}

download_with_retry() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        print_step "Downloading (attempt $((retry + 1))/$max_retries)"

        if curl --fail --location --progress-bar --max-time 300 \
               --output "$output" "$url" 2>/dev/null; then
            if validate_download "$output"; then
                return 0
            fi
            rm -f "$output"
        fi

        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            print_warning "Download failed, retrying in 2 seconds..."
            sleep 2
        fi
    done

    print_error "Failed to download after $max_retries attempts"
    return 1
}

install_mufiz() {
    local version="$1"
    local target
    local bin_dir="/usr/local/bin"
    local temp_exe="$TEMP_DIR/mufiz"
    local temp_zip="$TEMP_DIR/mufiz.zip"

    target=$(get_target)
    local uri="https://github.com/Mufi-Lang/MufiZ/releases/download/v${version}/mufiz_${version}_${target}.zip"

    print_step "Downloading MufiZ v${version} for ${target}"
    download_with_retry "$uri" "$temp_zip" || exit 1

    print_step "Extracting MufiZ"
    if ! unzip -j "$temp_zip" -d "$TEMP_DIR" >/dev/null 2>&1; then
        print_error "Failed to extract MufiZ"
        exit 1
    fi

    # Find the extracted binary (might have different name patterns)
    local extracted_binary=""
    for binary in "$TEMP_DIR/mufiz" "$TEMP_DIR"/mufiz*; do
        if [ -f "$binary" ] && [ -x "$binary" ]; then
            extracted_binary="$binary"
            break
        fi
    done

    if [ -z "$extracted_binary" ]; then
        print_error "Could not find MufiZ binary in extracted files"
        exit 1
    fi

    # Test the binary
    print_step "Validating MufiZ binary"
    if ! "$extracted_binary" --version >/dev/null 2>&1; then
        print_error "Downloaded MufiZ binary is not functional"
        exit 1
    fi

    # Atomic installation using mv
    print_step "Installing MufiZ to $bin_dir"
    if ! mv "$extracted_binary" "$bin_dir/mufiz"; then
        print_error "Failed to install MufiZ binary"
        exit 1
    fi

    chmod +x "$bin_dir/mufiz" || {
        print_error "Failed to set executable permissions"
        exit 1
    }

    print_step "Installing mufizup manager"
    local script_path="$0"
    local target_path="$bin_dir/mufizup"

    # Get absolute path - works on both macOS and Linux
    if command -v realpath >/dev/null 2>&1; then
        script_path=$(realpath "$0")
    elif [ -x "$0" ]; then
        # If $0 is executable, get its directory and name
        script_dir=$(cd "$(dirname "$0")" && pwd)
        script_name=$(basename "$0")
        script_path="$script_dir/$script_name"
    fi

    # Check if source and destination are the same file
    if [ "$script_path" = "$target_path" ]; then
        print_success "mufizup manager already installed"
    else
        if ! cp "$script_path" "$target_path"; then
            print_error "Failed to install mufizup manager"
            # Don't exit here as main binary is installed
            print_warning "MufiZ installed but mufizup manager installation failed"
            return 0
        fi
        chmod +x "$target_path" || {
            print_warning "Failed to set executable permissions for mufizup"
        }
        print_success "mufizup manager installed"
    fi

    print_success "MufiZ v${version} installation completed"
}

remove_mufiz() {
    local bin_dir="/usr/local/bin"
    local removed_something=0

    if [ -f "$bin_dir/mufiz" ]; then
        if rm "$bin_dir/mufiz" 2>/dev/null; then
            print_success "MufiZ binary removed"
            removed_something=1
        else
            print_error "Failed to remove MufiZ binary (check permissions)"
            exit 1
        fi
    fi

    if [ -f "$bin_dir/mufizup" ]; then
        if rm "$bin_dir/mufizup" 2>/dev/null; then
            print_success "mufizup manager removed"
            removed_something=1
        else
            print_warning "Failed to remove mufizup manager"
        fi
    fi

    if [ $removed_something -eq 0 ]; then
        print_warning "MufiZ was not installed or already removed"
    else
        print_success "MufiZ uninstallation completed"
    fi
}

cmd_install() {
    print_step "Installing MufiZ"
    check_dependencies
    check_process_running
    create_temp_dir

    local current_version
    current_version=$(get_current_version)
    if [ "$current_version" != "not_installed" ]; then
        create_backup
    fi

    local latest_version
    latest_version=$(get_latest_version)

    if install_mufiz "${latest_version#v}"; then
        remove_backup
        print_success "Installation completed successfully"
    else
        if [ "$current_version" != "not_installed" ]; then
            restore_backup
        fi
        exit 1
    fi
}

cmd_install_version() {
    local target_version="$1"

    if [ -z "$target_version" ]; then
        print_error "Version not specified. Usage: $0 install-version <version>"
        print_usage
        exit 1
    fi

    print_step "Installing MufiZ version $target_version"
    check_dependencies
    check_process_running
    create_temp_dir

    # Validate and normalize version format
    local normalized_version
    normalized_version=$(validate_version_format "$target_version") || {
        print_error "Invalid version format: $target_version"
        print_error "Expected format: X.Y.Z (e.g., 1.2.3 or v1.2.3)"
        exit 1
    }

    # Check if version exists
    print_step "Checking if version v$normalized_version exists"
    if ! check_version_exists "$normalized_version"; then
        print_error "Version v$normalized_version does not exist"
        printf "\n%sHint:%s Use '%s list-versions' to see available versions\n" "$YELLOW" "$NC" "$0"
        exit 1
    fi

    local current_version
    current_version=$(get_current_version)
    if [ "$current_version" != "not_installed" ]; then
        if [ "v$current_version" = "v$normalized_version" ]; then
            print_success "MufiZ v$normalized_version is already installed"
            exit 0
        fi
        create_backup
    fi

    if install_mufiz "$normalized_version"; then
        remove_backup
        print_success "MufiZ v$normalized_version installed successfully"
    else
        if [ "$current_version" != "not_installed" ]; then
            restore_backup
        fi
        exit 1
    fi
}

cmd_list_versions() {
    print_step "Fetching available versions"

    local versions
    versions=$(get_available_versions)

    if [ -z "$versions" ]; then
        print_error "No versions found or failed to fetch versions"
        exit 1
    fi

    local current_version
    current_version=$(get_current_version)

    printf "\n%sAvailable MufiZ versions:%s\n" "$BOLD" "$NC"
    printf "%s==================================%s\n" "$BLUE" "$NC"

    echo "$versions" | while read -r version; do
        if [ "$current_version" != "not_installed" ] && [ "v$current_version" = "$version" ]; then
            printf "%s%s%s (currently installed)\n" "$GREEN" "$version" "$NC"
        else
            printf "%s\n" "$version"
        fi
    done

    printf "\n%sUsage:%s\n" "$BOLD" "$NC"
    printf "  %s install-version 1.2.3     # Install version 1.2.3\n" "$0"
    printf "  %s install-version v1.2.3    # Install version 1.2.3 (v prefix optional)\n" "$0"
    printf "\n"
}

cmd_update() {
    print_step "Checking for updates"
    check_dependencies
    check_process_running
    create_temp_dir

    local current_version
    current_version=$(get_current_version)
    if [ "$current_version" = "not_installed" ]; then
        print_error "MufiZ is not installed. Use 'install' command instead."
        exit 1
    fi

    local latest_version
    latest_version=$(get_latest_version)

    if [ "v$current_version" = "$latest_version" ]; then
        print_success "MufiZ is already up to date (v${current_version})"
        exit 0
    fi

    print_step "Updating from v${current_version} to ${latest_version}"
    create_backup

    if install_mufiz "${latest_version#v}"; then
        remove_backup
        print_success "Update completed successfully"
    else
        restore_backup
        exit 1
    fi
}

cmd_remove() {
    print_step "Removing MufiZ"
    check_process_running
    remove_mufiz
}

# Cleanup function for normal exit
normal_cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi

    if [ "$INTERRUPTED" -eq 0 ]; then
        remove_backup
    fi
}

main() {
    print_banner

    case "$1" in
        "install") check_root; cmd_install ;;
        "update") check_root; cmd_update ;;
        "remove") check_root; cmd_remove ;;
        "install-version") check_root; cmd_install_version "$2" ;;
        "list-versions") cmd_list_versions ;;
        *) print_usage; exit 1 ;;
    esac

    normal_cleanup
}

main "$@"
