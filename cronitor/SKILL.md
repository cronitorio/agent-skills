---
name: cronitor
description: Connect, audit, add, investigate, query, and change Cronitor monitoring for cron jobs, background workers, heartbeats, websites, APIs, and MCP servers through the Cronitor MCP server, CronitorCLI, or the REST API. Use when a human mentions Cronitor, asks whether scheduled jobs or endpoints are monitored, wants alerts when a job fails or a site goes down, asks why a monitor is failing, wants failure counts or duration trends, or asks to change monitor, alert, status page, or environment configuration. Includes task recipes, a tool reference, CLI and REST equivalents, the monitor YAML format, and scripts that check the connection path and inventory scheduled work.
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
- The human asks whether their cron jobs, scheduled tasks, workers, or endpoints are monitored, or asks you to "add monitoring".
- The human asks why a monitor is failing, what is failing, or how often something failed or how long it takes.
- The human asks to change a monitor, alert route, notification list, group, environment, status page, issue, or maintenance window in Cronitor.
- You are creating a scheduled job and the account has Cronitor: create a monitor and have the job report to it.

## Start with the user's request

| The human wants to… | Follow this recipe | Complete when… |
| --- | --- | --- |
| Connect an account | [Connect Cronitor](#connect-cronitor) | A read-only call succeeds against the confirmed organization |
| Understand current coverage | [Audit monitoring](#audit-monitoring) | You report what is covered, what is not, and the evidence for each conclusion |
| Monitor a workload or endpoint | [Add monitoring](#add-monitoring) | Cronitor observes the real workload or performs a successful real probe |
| Understand a failure | [Investigate a failure](#investigate-a-failure) | You explain the evidence, likely cause, and next action without changing state |
| Understand performance, failure counts, or trends | [Query metrics](#query-metrics) | You report the numbers, the time range, and the environment they cover |
| Modify an existing resource | [Change configuration](#change-configuration) | The approved change is saved and read back |

Follow only the recipes the request needs. A specific instruction to implement a named change authorizes that scope. A broad request such as "evaluate our monitoring" does not authorize remote writes, dependency installation, or runtime changes.

## Rules shared by every recipe

- Examples use `tool_name(arguments)` notation; they are MCP calls, not shell commands.
- Read the live MCP tool schemas before calling tools. They are authoritative when an example differs. `references/mcp-tools.md` lists every tool and its scope.
- Use read-only discovery before writes and reconcile stable resource keys instead of creating duplicates.
- Ask before expanding beyond the requested scope or creating public status pages or incidents, notification destinations, paid resources, or destructive changes.
- MCP is the control plane, not the telemetry path. Jobs and heartbeats must send telemetry directly from the real runtime.
- Prefer CronitorCLI or a Cronitor SDK to report telemetry. Calling the monitor's telemetry URL directly from the job is a fine fallback. Do not paste the URL into chat or commit it to source control.
- Never send a setup-session ping and claim the workload is monitored. Never deliberately fail a production workload to test alerting.
- Request event messages, invocation output, request headers or bodies, RUM visitor data, and private status-page configuration only when the task requires them.
- Plan-limit errors return an `upgrade_url`. Stop, report the `message`, show the URL, and do not retry with different values.
- Rate-limit errors return `retry_after_seconds`. Wait that long and retry once.
- Report one of three outcomes: `verified`, `configured but unverified`, or `blocked`. Creating a monitor is not by itself verification.

## Connection triage

Run `scripts/doctor.sh` first. It reports, without printing secrets, whether the `cronitor` CLI is installed, whether `CRONITOR_API_KEY` is set, whether https://cronitor.io/mcp is reachable, and which path to use. Then pick the first path that is available:

1. **Already connected.** Cronitor MCP tools are present in the session: read their schemas and make one read-only call.
2. **The client supports MCP** (Claude Code, Claude, Cursor, Codex, VS Code, other Streamable HTTP clients). Add `https://cronitor.io/mcp` with the client-specific steps at https://cronitor.io/docs/mcp-server.md#connect-your-mcp-client and let the human complete sign-in in the browser. Prefer this path: no key handling.
3. **No MCP support, but a shell.** CronitorCLI. If `cronitor status` succeeds you are connected. If the CLI is missing or unconfigured, explain that the install script runs with `sudo` and ask before installing; afterwards the human supplies the SDK Integration key through an environment variable or `cronitor configure`. `references/cli-equivalents.md` maps each MCP tool to its CLI command.
4. **Only an API key.** The REST API: send the key as the HTTP Basic auth username against `https://cronitor.io/api/...`; the same reference lists endpoints.

Never ask the human to paste an OAuth token, API key, ping key, or password into the conversation. If none of these paths is available, report `blocked` and say what remains incomplete.

## Connect Cronitor

Confirm the selected organization with a compact read-only inventory: `get_status({})`, `list_environments({})`, `list_notification_lists({})`, `list_monitors({"page_size": 25})`. Without MCP, the same calls are `cronitor status`, `cronitor monitor list`, `cronitor environment list`, and `cronitor notification list`. Request summary fields first and paginate only when needed.

Done when a read-only call succeeds and the organization is unambiguous. Full recipe: `references/recipes.md#connect-cronitor`.

## Audit monitoring

Read-only unless the human separately asks you to implement recommendations. Run `scripts/find-schedulers.sh` to inventory crontabs, Kubernetes CronJobs, scheduled GitHub Actions, Celery beat, Sidekiq-cron, whenever, and systemd timers, then match each boundary that actually runs against Cronitor with `search_monitors` and `get_monitor`. `export_monitors({})` returns every monitor as one YAML document (`references/monitor-yaml.md`). Report Covered, Gaps, Uncertain, and Recommended next change, each tied to evidence. A configured monitor is not coverage until the real runtime is seen sending telemetry.

Full recipe: `references/recipes.md#audit-monitoring`.

## Add monitoring

Choose the monitor that proves the outcome the human cares about: job (bounded task lifecycle, via CronitorCLI or an SDK), heartbeat (recurring useful-work checkpoint), check (Cronitor probes a URL, port, certificate, or MCP server), site (RUM), or status page. Discover first (`search_monitors`, `get_notification_list`), present the proposal for a broad request, then `setup_monitor` for one monitor from a description or `create_monitors` for bulk or exact shapes. Pass `timezone` when a cron schedule is not UTC. Wire the real scheduler command (`cronitor exec --no-stdout <key> <command>`) or SDK, then verify with `get_status({"key": ...})` after one safe real run.

Full recipe and worked examples for a scheduled command, a heartbeat, and an API check: `references/recipes.md#add-monitoring`. Alert destinations: `references/recipes.md#connect-an-alert-destination`.

## Investigate a failure

Read-only. Start with `list_failing_monitors({})` for the account or `get_status({"key": ...})` plus `get_monitor({"key": ..., "with_status": true})` for one monitor. Pass `env` when the human names an environment, for example `list_failing_monitors({"env": "staging"})`. Expand to events and invocations only when the compact status does not answer the question. Compare the saved schedule, timezone, and rules with the real scheduler; separate observed facts from inference. Do not pause, edit, resolve, or ping to clear the failure.

Full recipe: `references/recipes.md#investigate-a-failure`.

## Query metrics

Read-only. `get_aggregates({"monitors": ["nightly-import"], "time": "7d"})` answers totals questions (runs, failures, success rate, duration percentiles, uptime). `get_metrics({"monitors": [...], "time": "30d", "fields": ["duration_p90", "fail_count"]})` answers trend questions; `fields` is required. Select by `groups`, `tags`, or `types` for "which of my jobs" questions. Always state the time range and environment the numbers cover. Row-level run logs are not available through MCP.

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
