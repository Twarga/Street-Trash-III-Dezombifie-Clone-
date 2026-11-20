#!/usr/bin/env bash
set -euo pipefail
cd /home/tlab/projects/street_trash_dezombifier
exec /home/tlab/godot462/Godot_v4.6.2-stable_linux.x86_64 --path /home/tlab/projects/street_trash_dezombifier "$@"
