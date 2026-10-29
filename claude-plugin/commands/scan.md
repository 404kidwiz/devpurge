---
description: Read-only report of developer cache sizes and what DevPurge could clean
allowed-tools: Bash(devpurge --scan), Bash(devpurge --version), Bash(command -v devpurge)
---

Run `command -v devpurge`. If it prints nothing, tell the user the free DevPurge CLI is not installed,
show the install steps from https://github.com/404kidwiz/devpurge#install-the-cli, and stop.

Otherwise run `devpurge --scan`. It only reads sizes and changes nothing. Summarize the result for
the user: the largest caches, which ones are eligible for cleanup, and the total. Do not run any
cleanup command from this command. Suggest `/devpurge:clean` if they want to free space.
