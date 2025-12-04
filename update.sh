#!/bin/bash
# Author: James A. Chambers - https://jamesachambers.com/
# More information at https://jamesachambers.com/raspberry-pi-minecraft-server-script-with-startup-service/
# GitHub Repository: https://github.com/maxonary/RPi-Minecraft-Server
# Updates Paper Minecraft server to the latest build

# Set path variable
USERPATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games"
PathLength=${#USERPATH}
if [[ "$PathLength" -gt 12 ]]; then
    PATH="$USERPATH"
else
    echo "Unable to set path variable.  You likely need an updated version of SetupMinecraft.sh from GitHub!"
fi

# Check to make sure we aren't running as root
if [[ $(id -u) = 0 ]]; then
   echo "This script is not meant to run as root or sudo.  Please run as a normal user with ./update.sh.  Exiting..."
   exit 1
fi

# Switch to server directory
cd /home/pi/minecraft/

# Update paperclip.jar
echo "Updating to most recent paperclip version ..."

# Check if we should use the latest Minecraft version or stick with current
USE_LATEST_VERSION=false
if [ -f ".use_latest_minecraft_version" ]; then
    USE_LATEST_VERSION=true
    echo "Auto-update to latest Minecraft version is enabled"
fi

# Detect Minecraft version
MINECRAFT_VERSION=""

# If auto-update is enabled, get the latest available version
if [ "$USE_LATEST_VERSION" = true ]; then
    if command -v jq &> /dev/null; then
        USER_AGENT="RPi-Minecraft-Server/1.0 (https://github.com/maxonary/RPi-Minecraft-Server)"
        # Get latest stable version (filter out pre-releases like 1.21.11-pre5)
        # This gets the first version that matches the pattern X.Y.Z (no pre-release suffixes)
        LATEST_VERSION=$(curl -s -H "User-Agent: $USER_AGENT" "https://fill.papermc.io/v3/projects/paper" | \
            jq -r '.versions | to_entries | map(.value[0]) | map(select(. | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))) | .[0] // empty')
        if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "null" ]; then
            MINECRAFT_VERSION="$LATEST_VERSION"
            echo "Latest stable Minecraft version: $MINECRAFT_VERSION"
            # Update the version file
            echo "$MINECRAFT_VERSION" > .minecraft_version
        else
            echo "Warning: Could not fetch latest stable version, falling back to saved version"
            USE_LATEST_VERSION=false
        fi
    else
        echo "Warning: jq not available, cannot auto-detect latest version. Falling back to saved version."
        USE_LATEST_VERSION=false
    fi
fi

# Method 1: Try to read from version file (created by SetupMinecraft.sh)
if [ -z "$MINECRAFT_VERSION" ] && [ -f ".minecraft_version" ]; then
    MINECRAFT_VERSION=$(cat .minecraft_version | tr -d '[:space:]')
    echo "Found Minecraft version from .minecraft_version: $MINECRAFT_VERSION"
fi

# Method 2: Try to detect from existing paperclip.jar filename
if [ -z "$MINECRAFT_VERSION" ] && [ -f "paperclip.jar" ]; then
    # Check if there are any paper-*.jar files that might have version in name
    PAPER_FILE=$(ls paper-*.jar 2>/dev/null | head -1)
    if [ -n "$PAPER_FILE" ]; then
        # Extract version from filename like paper-1.21.3-45.jar
        MINECRAFT_VERSION=$(echo "$PAPER_FILE" | sed -n 's/paper-\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
        if [ -n "$MINECRAFT_VERSION" ]; then
            echo "Detected Minecraft version from JAR filename: $MINECRAFT_VERSION"
        fi
    fi
fi

# Method 3: If still not found, ask the user
if [ -z "$MINECRAFT_VERSION" ]; then
    echo "Could not automatically detect Minecraft version."
    echo "Please enter the Minecraft version you want to use (e.g., 1.21.3):"
    read -p "Minecraft Version: " MINECRAFT_VERSION
    # Save it for future use
    echo "$MINECRAFT_VERSION" > .minecraft_version
    echo "Saved version to .minecraft_version for future use"
fi

# Validate version format (basic check)
if ! [[ "$MINECRAFT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version format. Expected format: X.Y.Z (e.g., 1.21.3)"
    echo "Skipping Paper update..."
    exit 1
fi

# Test internet connectivity first
if ! curl -s -H "User-Agent: RPi-Minecraft-Server/1.0 (https://github.com/maxonary/RPi-Minecraft-Server)" https://papermc.io/ -o /dev/null; then
    echo "Unable to connect to update website (internet connection may be down).  Skipping update ..."
    exit 1
fi

# Check if jq is available (required for new API)
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Paper update requires jq for the new API."
    echo "Install with: sudo apt-get install jq"
    exit 1
fi

# Use new PaperMC Downloads Service API v3
# Documentation: https://docs.papermc.io/misc/downloads-service/
USER_AGENT="RPi-Minecraft-Server/1.0 (https://github.com/maxonary/RPi-Minecraft-Server)"

# Get builds for the specified version
BuildJSON=$(curl -s -H "User-Agent: $USER_AGENT" "https://fill.papermc.io/v3/projects/paper/versions/$MINECRAFT_VERSION/builds")

# Check if the API returned an error
if echo "$BuildJSON" | jq -e '.ok == false' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$BuildJSON" | jq -r '.message // "Unknown error"')
    echo "Error from PaperMC API: $ERROR_MSG"
    echo "Version $MINECRAFT_VERSION may not be available."
    exit 1
fi

# Get the download URL for the latest stable build
PAPERMC_URL=$(echo "$BuildJSON" | jq -r 'first(.[] | select(.channel == "STABLE") | .downloads."server:default".url) // "null"')

if [ "$PAPERMC_URL" = "null" ] || [ -z "$PAPERMC_URL" ]; then
    echo "No stable build found for version $MINECRAFT_VERSION"
    # Try to get latest build (even if experimental) as fallback
    PAPERMC_URL=$(echo "$BuildJSON" | jq -r 'first(.[] | .downloads."server:default".url) // "null"')
    
    if [ "$PAPERMC_URL" != "null" ] && [ -n "$PAPERMC_URL" ]; then
        echo "Warning: Using experimental build (not recommended for production)"
    else
        echo "No builds available for version $MINECRAFT_VERSION."
        exit 1
    fi
fi

# Get build number for display
BUILD_NUMBER=$(echo "$BuildJSON" | jq -r 'first(.[] | select(.channel == "STABLE") | .id) // first(.[] | .id) // "unknown"')
echo "Latest Paper build found: $BUILD_NUMBER for Minecraft $MINECRAFT_VERSION"

# Download the Paper server JAR
curl -H "User-Agent: $USER_AGENT" -H "Accept-Encoding: identity" -L -o paperclip.jar "$PAPERMC_URL"

# Verify download was successful
if [ ! -f "paperclip.jar" ] || [ ! -s "paperclip.jar" ]; then
    echo "Error: Failed to download Paper server JAR file."
    exit 1
fi

echo "Successfully updated Paper to build $BUILD_NUMBER for Minecraft $MINECRAFT_VERSION"
