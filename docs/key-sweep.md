# Leaked-key sweep (DevPurge Pro): plan

## Why
Agent tools save API keys in plain config files, and those files get copied, synced and read by
other tools. A breach of one tool (for example the OpenCode incident) exposes every key it could
read. The sweep tells you which keys sit where, so you can rotate them.

## What it does (first slice, `devpurge --key-sweep [--json]`)
| Step | Behaviour |
| --- | --- |
| Where | `~/.codex`, `~/.claude`, `~/.config/opencode`, `~/.local/share/opencode`, `~/.cursor`, `~/.config/aider`, `~/.aider*`, `~/.env*`, and `.env`, `.env.*`, `.envrc` files up to 4 levels deep in the agent roots (`~/Desktop/404 Projects`, `~/Projects`, `~/Developer`, `~/code`, `~/src`, `~/dev`, `~/repos`, or `DEVPURGE_AGENT_ROOTS`) |
| Skipped | session/transcript/history folders, caches, logs, worktrees, extensions, plugins, `node_modules` and other dependency folders, `.git`, files over 1 MiB, non-text files, symlinks, and `.env` templates (`.example`, `.sample`, `.template`, `.dist`). The skipped count is reported |
| How | Reads each file in-process and matches provider key patterns line by line |
| Output | provider, file, line, masked value (first 4 + last 2 characters; values under 12 characters show 2). Never the full value, never the line text |
| Providers | OpenAI, Anthropic, Google/Gemini, xAI, OpenRouter, Groq, Mistral (by variable name), AWS (access key id, secret by variable name), GitHub tokens, Stripe, Cloudflare (by variable name) |
| Guidance | Rotation steps and the official key page per provider, plus a spend-cap reminder. The spend-cap note is guidance only: DevPurge can't see account settings |
| Exit code | 0 nothing found, 1 keys found |

## Guarantees
- Report only. Nothing is deleted, moved or edited.
- No network. Found keys are never sent to any provider or service; we never call provider APIs to
  check whether a key is live or capped. Tests run the sweep with sockets disabled.
- Full values exist only in memory while a line is matched. They are not printed, logged, cached or
  written to disk, including in `--json`. Tests assert that no full key, and no inner part of one,
  appears in any output.

## Known limits
- Transcripts and session histories are skipped for speed and size, though they can contain pasted
  keys. A later slice could scan them with a size budget.
- Mistral and Cloudflare keys have no fixed prefix, so they are found only next to their usual
  variable names. Generic `API_KEY=` values are not reported.
- Masking keeps the provider prefix visible (for example `sk-p…IJ`), which is enough to find the key
  in a dashboard but not to use it.

## Next slices (not built)
1. Optional transcript scan with a size budget (`--include-history`).
2. Mac app: show findings with "Open dashboard" buttons. Gating plan: scan free, rotation checklist
   and history scan licensed.
3. Leak guard integration: block commits and deploys that include files where the sweep found keys.

## Rotation links (official dashboards)
| Provider | Keys | Spend limits |
| --- | --- | --- |
| OpenAI | https://platform.openai.com/api-keys | https://platform.openai.com/settings/organization/limits |
| Anthropic | https://console.anthropic.com/settings/keys | https://console.anthropic.com/settings/limits |
| Google/Gemini | https://aistudio.google.com/app/apikey | https://console.cloud.google.com/apis/credentials (restrict key; budgets in Cloud Billing) |
| xAI | https://console.x.ai | team spending limit in the console |
| OpenRouter | https://openrouter.ai/settings/keys | per-key credit limit on the same page |
| Groq | https://console.groq.com/keys | console limits |
| Mistral | https://console.mistral.ai/api-keys | workspace limits |
| AWS | https://console.aws.amazon.com/iam/home#/security_credentials | AWS Budgets |
| GitHub | https://github.com/settings/tokens | n/a (use fine-grained tokens with expiry) |
| Stripe | https://dashboard.stripe.com/apikeys | n/a (use restricted keys) |
| Cloudflare | https://dash.cloudflare.com/profile/api-tokens | n/a (scope tokens) |

Checked Oct 18, 2026: all of these load or redirect to a login page. platform.openai.com, console.x.ai
and dash.cloudflare.com answer automated requests with 403 (bot protection) and load normally in a browser.
