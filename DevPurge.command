#!/bin/bash
set -e
cd "$(dirname "$0")"
if [ -d "DevPurge.app" ]; then
  open DevPurge.app
else
  exec bash bin/devpurge --gui
fi
