#!/bin/bash
#
# Script to copy Octavi IFR-1 scripts to proper X-Plane directory.
# This is mostly intended for use in a development environment (such as IntelliJ IDEA) to quickly deploy the scripts
# for debugging.
#
# For general setup of the Octavi IFR-1 device, please use the setup.sh script, instead.
#
# ----------------------------------------------------------------------------------------------------
#
# Usage:
# XPLANE_BASE_DIRECTORY={path to your X-Plane install} /bin/bash install.sh
#
# ex: XPLANE_BASE_DIRECTORY=/mnt/simulators/X-Plane\ 12 /bin/bash install.sh
#

# Resolve the directory of this script
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Define the relative path containing Lua scripts (from this script's location)
SOURCE_DIRECTORY="$SCRIPT_DIR/../src"  # Adjust the relative path to the folder containing `.lua` files

# Define the target directory
TARGET_DIRECTORY="$XPLANE_BASE_DIRECTORY/Resources/plugins/FlyWithLua/Scripts"

# Check if the source directory exists
if [[ -d "$SOURCE_DIRECTORY" ]]; then
    # Copy all `.lua` files from the source directory to the target directory
    cp "$SOURCE_DIRECTORY"/*.lua "$TARGET_DIRECTORY"

    # Check if the copy was successful
    if [[ $? -eq 0 ]]; then
        echo "All .lua scripts from '$SOURCE_DIRECTORY' successfully copied to '$TARGET_DIRECTORY'."
    else
        echo "Failed to copy the scripts. Please check permissions or paths."
        exit 1
    fi
else
    echo "Source directory '$SOURCE_DIRECTORY' not found. Please check the path."
    exit 1
fi