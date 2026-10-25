#!/bin/sh
# Parses all scripts headlessly and prints script errors.
cd "$(dirname "$0")" && godot --headless --import 2>&1 | grep -A1 -E "SCRIPT ERROR|ERROR:" | head -40
