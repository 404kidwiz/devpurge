---
description: Preview, then with your confirmation clear regenerable developer caches
argument-hint: "[module, e.g. node, lang, mac; default all safe caches]"
allowed-tools: Bash(command -v devpurge), Bash(devpurge --dry-run *), Bash(devpurge * --dry-run)
---

Clean regenerable developer caches with the free DevPurge CLI. Follow these steps in order.

1. Run `command -v devpurge`. If it prints nothing, tell the user to install the CLI from
   https://github.com/404kidwiz/devpurge#install-the-cli and stop.
2. Pick the target: `--$ARGUMENTS` if the user named a module, otherwise `--all`. `--all` covers
   only caches (uv, node, lang, mac, system). Never pick `--ai`, `--docker` or `--git` unless the user
   named it explicitly, and if they did, say what it removes before going further.
3. Run the preview: `devpurge <target> --dry-run`. Show the user what would be removed.
4. Ask the user to confirm. Only after they say yes in this conversation, run `devpurge <target>`
   without `--dry-run`. This step is not pre-approved, so Claude Code will also ask for permission.
5. Report what was cleared. Mention that builds and installs may re-download some files.

Never delete paths yourself with `rm`; only DevPurge's own commands do the cleanup.
