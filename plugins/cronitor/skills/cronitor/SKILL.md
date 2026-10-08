---
name: cronitor
description: Onboard a project, connect, audit, add, investigate, query, and change Cronitor monitoring for cron jobs, background workers, heartbeats, websites, APIs, and MCP servers through the Cronitor MCP server, CronitorCLI, or the REST API. Use when a human mentions Cronitor, asks whether scheduled jobs or endpoints are monitored, wants alerts when a job fails or a site goes down, asks why a monitor is failing, wants failure counts or duration trends, or asks to change monitor, alert, status page, or environment configuration. Includes task recipes, a tool reference, CLI and REST equivalents, the monitor YAML format, and scripts that check the connection path and inventory scheduled work.
license: MIT
metadata:
  version: "1.0.0"
  homepage: https://cronitor.io/docs/agent-quickstart.md
---

# Cronitor

Cronitor monitors cron jobs, background workers, heartbeats, websites, APIs, and MCP servers, and alerts when they fail. This skill tells you how to work with a Cronitor account on a human's behalf: what to read, what to call, what to ask before writing, and how to report the result.

The canonical, always-current version of these recipes is https://cronitor.io/docs/agent-quickstart.md. The copy in `references/recipes.md` is the same text at the time this skill was published.

## When to use

- The human names Cronitor, `cronitor exec`, a ping URL, or the Cronitor MCP server.
- The human asks whether their cron jobs, scheduled tasks, workers, or endpoints are monitored, or asks you to "add monitoring" or set up monitoring for a project.
- The human asks why a monitor is failing, what is failing, or how often something failed or how long it takes.
- The human asks to change a monitor, alert route, notification list, group, environment, status page, issue, or maintenance window in Cronitor.
- You are creating a scheduled job and the account has Cronitor: create a monitor and have the job report to it.

## Start with the user's request

| The human wants to… | Follow this recipe | Complete when… |
| --- | --- | --- |
| Set up monitoring for a project | [Onboard a project](#onboard-a-project) | Every resource the human approved is verified, or marked configured but unverified with the step that remains |
| Connect an account | [Connect Cronitor](#connect-cronitor) | A read-only call succeeds against the confirmed organization |
| Understand current coverage | [Audit monitoring](#audit-monitoring) | You report what is covered, what is not, and the evidence for each conclusion |
| Monitor a workload or endpoint | [Add monitoring](#add-monitoring) | Cronitor observes the real workload or performs a successful real probe |
| Send alerts to Slack, Teams, or another channel | [Connect an alert destination](#connect-an-alert-destination) | The destination is on the notification list and reads back |
| Understand a failure | [Investigate a failure](#investigate-a-failure) | You explain the evidence, likely cause, and next action without changing state |
| Understand performance, failure counts, or trends | [Query metrics](#query-metrics) | You report the numbers, the time range, and the environment they cover |
| Modify an existing resource | [Change configuration](#change-configuration) | The approved change is saved and read back |

Follow only the recipes the request needs. A specific instruction to implement a named change authorizes that scope. A broad request such as "evaluate our monitoring" does not authorize remote writes, dependency installation, or runtime changes. [Onboard a project](#onboard-a-project) gets its authority from the human's approval of its proposal.

## Rules shared by every recipe

- Examples use `tool_name(arguments)` notation; they are MCP calls, not shell commands.
- Read the live MCP tool schemas before calling tools. They are authoritative when an example differs. `references/mcp-tools.md` lists every tool and its scope.
- Use read-only discovery before writes and reconcile stable resource keys instead of creating duplicates.
- Ask before expanding beyond the requested scope or creating public status pages or incidents, notification destinations, paid resources, or destructive changes.
- MCP is the control plane, not the telemetry path. Jobs and heartbeats must send telemetry directly from the real runtime.
- Prefer CronitorCLI or a Cronitor SDK to report telemetry. Calling the monitor's telemetry URL directly from the job is a fine fallback. The telemetry URL contains a telemetry-only key and is not a secret. You can show it to the human and use it in code or configuration.
- CronitorCLI and the SDKs read `CRONITOR_API_KEY`. `CRONITOR_API_KEY` must be the SDK Integration key; it covers both monitor management and telemetry. On a host where the human ran `cronitor auth login`, the CLI already has a credential. Otherwise, tell the human to add `CRONITOR_API_KEY` to the runtime's secret store, such as the server environment, a Kubernetes secret, or CI secrets, with the value from Settings → API Keys → SDK Integration. Do not ask for the value in chat or commit it.
- Never send a setup-session ping and claim the workload is monitored. Never deliberately fail a production workload to test alerting.
- Request event messages, invocation output, request headers or bodies, RUM visitor data, and private status-page configuration only when the task requires them.
- Plan-limit errors return an `upgrade_url`. Stop, report the `message`, show the URL, and do not retry with different values.
- Rate-limit errors return `retry_after_seconds`. Wait that long and retry once.
- Report one of three outcomes: `verified`, `configured but unverified`, or `blocked`. Creating a monitor is not by itself verification.

## Connection triage

Run `scripts/doctor.sh` first. It reports, without printing secrets, whether the `cronitor` CLI is installed and which organization it is signed in to, whether `CRONITOR_API_KEY` is set, whether https://cronitor.io/mcp is reachable, and which path to use. Then pick the first path that is available:

1. **Already connected.** Cronitor MCP tools are present in the session: read their schemas and make one read-only call.
2. **The client supports MCP** (Claude Code, Claude, Cursor, Codex, VS Code, other Streamable HTTP clients). Add `https://cronitor.io/mcp` with the client-specific steps at https://cronitor.io/docs/mcp-server.md#connect-your-mcp-client and let the human sign in or create an account in the same browser flow. Prefer this path: no key handling.
3. **No MCP support, but a shell.** Use CronitorCLI. Try `cronitor monitor list` first and reuse working credentials. If installation or an update is needed, explain the change and obtain approval unless already authorized. With sudo: `curl -fsSL 'https://cronitor.io/install-linux?sudo=1' | sh`. Already root, including a container or CI image running as root: `curl -fsSL 'https://cronitor.io/install-linux' | sh`. Installing to `/usr/bin` needs root or sudo; if you are neither, ask the human instead of running the installer. macOS and other options: https://cronitor.io/docs/using-cronitor-cli.md#installation. Sign in with `cronitor auth login` (same command for signup). Pass `--timeout 30m` so the CLI waits long enough for a relayed link. Use `--no-browser` only when the browser is on another machine. Once you open the link, finish signing in within about 5 minutes. Restarting login invalidates the previous URL. Follow `references/recipes.md#cli-signup-and-login`. `cronitor signup` is an alias. Explicit keys supplied through a secret manager remain supported for CI and containers. `references/cli-equivalents.md` maps each MCP tool to its CLI command.
4. **Only an API key.** The REST API: send the key as the HTTP Basic auth username against `https://cronitor.io/api/...`; the same reference lists endpoints.

Never ask the human to paste an OAuth token, API key, or password into the conversation. If none of these paths is available, report `blocked` and say what remains incomplete.

## Onboard a project

A conversation: you find what can be monitored, the human decides, then you set it up. No writes before the human approves the proposal. Connect, then discover read-only: scheduled work (run `scripts/find-schedulers.sh`, and treat anything that runs on a schedule as a candidate even if the script does not know its system), workers, public URLs and health routes, a web frontend layout, and existing Cronitor usage; call `get_setup_context({})`, `get_status({})`, `list_notification_lists({})`, and `get_integration_services({})`. Report what you found and what you cannot see, then ask in one message with a default for each question: what to monitor, whether they run scheduled jobs outside this repository (always ask), uptime checks, web analytics, a status page, alert channels the plan allows, and environment and timezone. Propose one table, get one approval, act, then verify each resource or mark it `configured but unverified` with the remaining step.

Full recipe and the question template: `references/recipes.md#onboard-a-project`.

## Connect an alert destination

Requires approval. `list_integrations({})` first and reuse a match. Slack and PagerDuty: `connect_integration`, hand the human the `authorize_url`, poll `check_integration_connection`. Other services: `create_integration` with the value the human supplies; never echo it. Then merge the new label into the notification list with `get_notification_list` and `update_notification_list`; do not replace the map.

Full recipe: `references/recipes.md#connect-an-alert-destination`.

## Connect Cronitor

For CLI login, reuse the intended config or choose a writable config owned by the intended OS user. Explain persistent unattended access before starting. Use ordinary `auth login` when CLI and browser are on the same computer. Pass `--timeout 30m` so the CLI waits long enough for a relayed link. Use `--no-browser` only when the browser is on another machine: the human runs `auth login --no-browser --timeout 30m` in a terminal they can access directly, signs in through the printed authorization URL, then pastes the full localhost callback URL into the CLI's hidden prompt, even if the browser shows a connection error. Once you open the link, finish signing in within about 5 minutes. Restarting login invalidates the previous URL. Keep the command running. Never ask for callback URLs, authorization codes, PKCE verifiers, or tokens in chat or recorded tool arguments. If the human cannot access the terminal prompt, report the blocker. Run `cronitor auth status` after success. Do not replace existing credentials or run `auth logout` as automatic cleanup: logout revokes access for jobs using that key. Read-only users receive telemetry-only CLI credentials; report that limitation when the task needs resource management.

Confirm the selected organization with a compact read-only inventory: `get_status({})`, `list_environments({})`, `list_notification_lists({})`, `list_monitors({"detail": "summary", "page_size": 25})`. Without MCP, the same calls are `cronitor status`, `cronitor monitor list`, `cronitor environment list`, and `cronitor notification list`. Use summary mode for monitor and issue lists and paginate only when needed.

Done when a read-only call succeeds and the organization is unambiguous. Full recipe: `references/recipes.md#connect-cronitor`.

## Audit monitoring

Read-only unless the human separately asks you to implement recommendations. Run `scripts/find-schedulers.sh` to inventory crontabs, Kubernetes CronJobs, scheduled GitHub Actions, Celery beat, Sidekiq-cron, whenever, systemd timers, Laravel, Vercel and Cloudflare Workers crons, Serverless Framework, Render, Heroku Scheduler, Spring `@Scheduled`, Hangfire, Quartz, Go robfig/cron, and BullMQ, then match each boundary that actually runs against Cronitor with `search_monitors` and `get_monitor`. `export_monitors({})` returns every monitor as one YAML document (`references/monitor-yaml.md`). Report Covered, Gaps, Uncertain, and Recommended next change, each tied to evidence. A configured monitor is not coverage until the real runtime is seen sending telemetry.

Full recipe: `references/recipes.md#audit-monitoring`.

## Add monitoring

Choose the monitor that proves the outcome the human cares about: job (bounded task lifecycle, via CronitorCLI or an SDK), heartbeat (recurring useful-work checkpoint), check (Cronitor probes a URL, port, certificate, or MCP server), site (RUM), or status page. Discover first (`search_monitors`, `get_notification_list`), present the proposal for a broad request, then `setup_monitor` for one monitor from a description or `create_monitors` for bulk or exact shapes. Pass `timezone` when a cron schedule is not UTC. Wire the real scheduler command (`cronitor exec --no-stdout <key> <command>`) or SDK, then verify with `get_status({"key": ...})` after one safe real run.

Full recipe and worked examples for a scheduled command, a heartbeat, and an API check: `references/recipes.md#add-monitoring`. Alert destinations: `references/recipes.md#connect-an-alert-destination`.

## Investigate a failure

Read-only. Start with `list_failing_monitors({})` for the account or `get_status({"key": ...})` plus `get_monitor({"key": ..., "with_status": true})` for one monitor. Pass `env` when the human names an environment, for example `list_failing_monitors({"env": "staging"})`. Expand to events and invocations only when the compact status does not answer the question. Compare the saved schedule, timezone, and rules with the real scheduler; separate observed facts from inference. Do not pause, edit, resolve, or ping to clear the failure.

Full recipe: `references/recipes.md#investigate-a-failure`.

## Query metrics

Read-only. `get_aggregates({"monitors": ["nightly-import"], "time": "7d"})` answers totals questions (runs, failures, success rate, duration mean, uptime). `get_metrics({"monitors": [...], "time": "30d", "fields": ["duration_p90", "fail_count"]})` answers trends. Pass exactly one of `fields` (built-ins), `metric` (custom), or `metric_names` (discover custom names). Select by `groups`, `tags`, or `types` for "which of my jobs" questions. Use `describe_site_query` for RUM analytics. Always state the range and environment. Row-level run logs are not available through MCP.

Full recipe: `references/recipes.md#query-metrics`.

## Change configuration

Read the resource first (`get_monitor`), show the delta and its alerting effect, then `update_monitor` with only the fields that change and read it back. Omitted fields are preserved; explicit empty relationship arrays clear relationships. Creating notification destinations, publishing status pages or incidents, changing effective recipients, and destructive operations need explicit approval. Never replace an update with delete-and-recreate.

Full recipe: `references/recipes.md#change-configuration`.

## Report the outcome

```text
Result: verified | configured but unverified | blocked

Resources reused, created, or changed:
Runtime or probe integration:
Verification evidence:
Effective alert recipients:
Secrets handled:
Rollback:
Remaining human step:
```

Use `verified` only when Cronitor independently observed the failure-detection path the human asked for.

## References

- `references/recipes.md`: the full agent quick start.
- `references/mcp-tools.md`: every MCP tool, its purpose, and the API-key scope it needs.
- `references/cli-equivalents.md`: task to MCP tool to CLI command to REST endpoint.
- `references/monitor-yaml.md`: the YAML format `cronitor sync` and `export_monitors` use.
- `scripts/doctor.sh`: connection-path check. `scripts/find-schedulers.sh`: scheduled-work inventory.
- Docs index for agents: https://cronitor.io/llms.txt
