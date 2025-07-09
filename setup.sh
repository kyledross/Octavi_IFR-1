#!/bin/bash
#
# Setup script for Octavi IFR-1
#

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display success messages
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display info messages
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to display warning messages
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to display error messages and exit
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    cleanup
    exit 1
}

# Function to clean up any changes made if an error occurs
cleanup() {
    if [ -n "$CLEANUP_ACTIONS" ]; then
        warning "Cleaning up changes due to error..."
        eval "$CLEANUP_ACTIONS"
        info "Cleanup completed."
    fi
}

# Trap errors and call cleanup
trap 'error "An unexpected error occurred. Exiting."' ERR

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    error "This script must be run with sudo privileges. Please run: sudo $0"
fi

# Get the original user's home directory
ORIGINAL_USER=${SUDO_USER:-$(whoami)}
USER_HOME=$(eval echo "~$ORIGINAL_USER")

info "Running as: $(whoami)"
info "Original user: $ORIGINAL_USER"
info "User home directory: $USER_HOME"

# Welcome message
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}      Octavi IFR-1 Setup Script                  ${NC}"
echo -e "${BLUE}                                                 ${NC}"
echo -e "${BLUE}      This will setup the Octavi IFR-1           ${NC}"
echo -e "${BLUE}      device for use in X-Plane 12.              ${NC}"
echo -e "${BLUE}                                                 ${NC}"
echo -e "${BLUE}      Note: This project is not affiliated       ${NC}"
echo -e "${BLUE}      with, nor supported by, Octavi GmbH.       ${NC}"
echo -e "${BLUE}                                                 ${NC}"
echo -e "${BLUE}      This project is a community effort.        ${NC}"
echo -e "${BLUE}                                                 ${NC}"
echo -e "${BLUE}      For more information on the Octavi         ${NC}"
echo -e "${BLUE}      IFR-1 device, please visit                 ${NC}"
echo -e "${BLUE}      https://www.octavi.net/                    ${NC}"
echo -e "${BLUE}                                                 ${NC}"
echo -e "${BLUE}==================================================${NC}"

# Prompt user to disconnect the device
info "Please ensure the Octavi IFR-1 device is disconnected before proceeding."
read -p "Is the device disconnected? (y/n): " device_disconnected

if [[ ! "$device_disconnected" =~ ^[Yy]$ ]]; then
    error "Please disconnect the device and run the script again."
fi

success "Device check passed."

# Find X-Plane installation
XPLANE_INSTALL_FILE="$USER_HOME/.x-plane/x-plane_install_12.txt"

if [ ! -f "$XPLANE_INSTALL_FILE" ]; then
    error "X-Plane installation file not found at $XPLANE_INSTALL_FILE. Please make sure X-Plane 12 is installed."
fi

info "Finding X-Plane installation..."

# Find the latest X-Plane installation by creation date
XPLANE_ROOT=""
latest_time=0

while IFS= read -r line; do
    if [ -d "$line" ]; then
        dir_time=$(stat -c %Y "$line")
        if [ "$dir_time" -gt "$latest_time" ]; then
            latest_time=$dir_time
            XPLANE_ROOT="$line"
        fi
    fi
done < "$XPLANE_INSTALL_FILE"

if [ -z "$XPLANE_ROOT" ]; then
    error "Could not find a valid X-Plane installation. Please check that X-Plane is installed and try this again."
fi

success "Found X-Plane installation at: $XPLANE_ROOT"

# Check if X-Plane is running
info "Checking if X-Plane is running..."
if ps -ef | grep -v grep | grep -q "[X]-Plane-x86_64"; then
    error "X-Plane is currently running. Please exit X-Plane completely and run this script again."
fi

success "X-Plane is not running."

# Check if FlyWithLua is installed
FLYWITHLUAPATH="$XPLANE_ROOT/Resources/plugins/FlyWithLua/lin_x64/FlyWithLua.xpl"
info "Checking for FlyWithLua installation..."

if [ ! -f "$FLYWITHLUAPATH" ]; then
    warning "FlyWithLua is not installed in X-Plane."
    info "Please install FlyWithLua from: https://github.com/X-Friese/FlyWithLua"
    error "Setup cannot continue without FlyWithLua. Please install it and run this script again."
fi

success "FlyWithLua is installed."

# Handle "please read the manual.lua" file
MANUAL_FILE="$XPLANE_ROOT/Resources/plugins/FlyWithLua/Scripts/please read the manual.lua"
DISABLED_DIR="$XPLANE_ROOT/Resources/plugins/FlyWithLua/Scripts (disabled)"

if [ -f "$MANUAL_FILE" ]; then
    info "Found 'please read the manual.lua'. Moving to disabled scripts directory..."
    
    # Create disabled directory if it doesn't exist
    if [ ! -d "$DISABLED_DIR" ]; then
        mkdir -p "$DISABLED_DIR"
        CLEANUP_ACTIONS="rmdir '$DISABLED_DIR' 2>/dev/null; $CLEANUP_ACTIONS"
    fi
    
    # Move the file
    mv "$MANUAL_FILE" "$DISABLED_DIR/"
    CLEANUP_ACTIONS="mv '$DISABLED_DIR/please read the manual.lua' '$MANUAL_FILE' 2>/dev/null; $CLEANUP_ACTIONS"
    
    success "Moved 'please read the manual.lua' to disabled scripts directory."
fi

# Copy Lua scripts
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SOURCE_DIRECTORY="$SCRIPT_DIR/src"
TARGET_DIRECTORY="$XPLANE_ROOT/Resources/plugins/FlyWithLua/Scripts"

info "Copying Lua scripts to X-Plane..."

# Check if the source directory exists
if [ ! -d "$SOURCE_DIRECTORY" ]; then
    error "Source directory '$SOURCE_DIRECTORY' not found. Please check the path."
fi

# Create a list of copied files for cleanup
COPIED_FILES=()

# Copy all .lua files from the source directory to the target directory
for file in "$SOURCE_DIRECTORY"/*.lua; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        cp "$file" "$TARGET_DIRECTORY/"
        
        if [ $? -eq 0 ]; then
            COPIED_FILES+=("$TARGET_DIRECTORY/$filename")
            CLEANUP_ACTIONS="rm -f '$TARGET_DIRECTORY/$filename'; $CLEANUP_ACTIONS"
        else
            error "Failed to copy $filename. Please check permissions or paths."
        fi
    fi
done

success "All Lua scripts successfully copied to X-Plane."

# Set up udev rules
UDEV_RULE_FILE="/etc/udev/rules.d/99-octavi.rules"
info "Setting up udev rules for Octavi IFR-1 device..."

if [ ! -f "$UDEV_RULE_FILE" ]; then
    echo 'SUBSYSTEM=="hidraw", ATTRS{idProduct}=="e6d6", ATTRS{idVendor}=="04d8", MODE="0777"' > "$UDEV_RULE_FILE"
    CLEANUP_ACTIONS="rm -f '$UDEV_RULE_FILE'; $CLEANUP_ACTIONS"
    success "Created udev rule file: $UDEV_RULE_FILE"
else
    info "Udev rule file already exists: $UDEV_RULE_FILE"
fi

# Reload udev rules
info "Reloading udev rules..."
udevadm control --reload-rules
success "Udev rules reloaded."

# Final success message
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}      Octavi IFR-1 Setup Completed Successfully  ${NC}"
echo -e "${GREEN}==================================================${NC}"
info "You may now connect the Octavi IFR-1 device and start X-Plane."

exit 0