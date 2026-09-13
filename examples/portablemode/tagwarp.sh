#!/bin/bash

set -eu

# Get the directory of this script.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
SOURCE_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Set the config file that has mods dir set to the portable dir.
export TW_MODS_CONFIG_FILE="$SOURCE_DIR"/modportablemode/config/TagWarp.conf
# Prevent mod builder from caching locally.
export TW_MODS_CACHE_DIR="$SOURCE_DIR"/modportablemode/cache

# Prevent Qt from caching locally.
export QML_DISABLE_DISK_CACHE=1
export QT_DISABLE_SHADER_DISK_CACHE=1

# Change dir because the portable config file has relative path for the mods dir.
cd "$SOURCE_DIR"

# Launch the latest AppImage in this directory.
exec "$(ls ./TagWarp-*-alpha-x86_64.AppImage | tail -n1)"
