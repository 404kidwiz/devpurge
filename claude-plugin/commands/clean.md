---
description: Preview, then with your confirmation clear regenerable developer caches
argument-hint: "[module, e.g. node, lang, mac; default all safe caches]"
allowed-tools: Bash(command -v devpurge), Bash(devpurge --all --dry-run), Bash(devpurge --uv --dry-run), Bash(devpurge --node --dry-run), Bash(devpurge --lang --dry-run), Bash(devpurge --mac --dry-run), Bash(devpurge --system --dry-run), Bash(devpurge --browsers --dry-run), Bash(devpurge --installers --dry-run), Bash(devpurge --oldstores --dry-run)
---

Clean regenerable developer caches with the free DevPurge CLI. Follow these steps in order.

1. Run `command -v devpurge`. If it prints nothing, tell the user to install the CLI from
   https://github.com/404kidwiz/devpurge#install-the-cli and stop.
2. Pick exactly one target from this list: `--all`, `--uv`, `--node`, `--lang`, `--mac`, `--system`,
   `--browsers`, `--installers`, `--oldstores`. Use the module the user named in "$ARGUMENTS" only if it
   is one of these words; otherwise use `--all` (caches only: uv, node, lang, mac, system). Never pass
   any other text from the arguments to the command. If the user asks for `--ai`, `--docker` or `--git`,
   say what it removes and that they should run it themselves.
3. Run the preview: `devpurge <target> --dry-run`, written exactly in that order. Show the user what
   would be removed.
4. Ask the user to confirm. Only after they say yes in this conversation, run `devpurge <target>`
   without `--dry-run`. This step is not pre-approved, so Claude Code will also ask for permission.
5. Report what was cleared. Mention that builds and installs may re-download some files.

Never delete paths yourself with `rm`; only DevPurge's own commands do the cleanup.
