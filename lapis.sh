#!/usr/bin/bash

# the first and only argument to the script for now is the path to Lapis.
# if you wish to avoid passing such an argument, you can edit the following
# variable with the Lapis directory on your system. This will be needed
# for the Gemfile and for the shell entry point (src/main.rb)
LAPIS_DIR=""

if [[ -z "$LAPIS_DIR" ]]; then
    LAPIS_DIR="$1"
fi

BUNDLE_GEMFILE="$LAPIS_DIR/Gemfile" ruby "$LAPIS_DIR/src/main.rb"
