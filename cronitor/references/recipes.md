# Cronitor agent recipes

Use this guide when a human asks you to connect Cronitor, audit monitoring coverage, add monitoring, investigate a failure, query metrics, or change Cronitor configuration. {% .lead %}

Start with the request the human actually made. Do not turn an audit into an implementation, fix a failure during a diagnosis, or enable every applicable Cronitor product.

## Install the Cronitor skill

The Cronitor skill bundles these recipes with a tool reference, CLI and REST equivalents, the monitor YAML format, and helper scripts that check your connection path and inventory scheduled work on the host. Install it once and it stays available across sessions:

```bash
npx skills add cronitorio/agent-skills
```

Claude Code users can alternatively copy the skill folder into `~/.claude/skills/cronitor`.

## Start with the user's request

| The human wants to… | Follow this recipe | Complete when… |
| --- | --- | --- |
| Connect an account | [Connect Cronitor](#connect-cronitor) | A read-only call succeeds against the confirmed organization |
| Understand current coverage | [Audit monitoring](#audit-monitoring) | You report what is covered, what is not, and the evidence for each conclusion |
| Monitor a workload or endpoint | [Add monitoring](#add-monitoring) | Cronitor observes the real workload or performs a successful real probe |
| Understand a failure | [Investigate a failure](#investigate-a-failure) | You explain the evidence, likely cause, and next action without changing state |
| Understand performance, failure counts, or trends | [Query metrics](#query-metrics) | You report the numbers, the time range, and the environment they cover |
| Modify an existing resource | [Change configuration](#change-configuration) | The approved change is saved and read back |

If a request contains several of these tasks, follow only the recipes needed for that request. A specific instruction to implement a named change authorizes that scope. A broad request such as "evaluate our monitoring" or "what should we monitor?" does not authorize remote writes, dependency installation, or runtime changes.

## Rules shared by every recipe

- Examples in this guide use `tool_name(arguments)` notation; they are MCP calls, not shell commands.
- Read the live MCP tool schemas before calling tools. They are authoritative when an example in this guide differs.
- Use read-only discovery before writes and reconcile stable resource keys instead of creating duplicates.
- Ask before expanding beyond the requested scope or creating public status pages or incidents, notification destinations, paid resources, or destructive changes.
- MCP is the control plane, not the telemetry path. Jobs and heartbeats must send telemetry directly from the real runtime. Read [Control plane, not data plane](https://cronitor.io/docs/mcp-server.md#control-plane-not-data-plane).
- Prefer CronitorCLI or a Cronitor SDK to report telemetry. Calling the monitor's telemetry URL directly from the job is a fine fallback. Do not paste the URL into chat or commit it to source control.
- Never send a setup-session ping and claim the workload is monitored. Never deliberately fail a production workload to test alerting.
- Request event messages, invocation output, request headers or bodies, RUM visitor data, and private status-page configuration only when the task requires them.
- Plan-limit errors return an `upgrade_url`. Stop, report the `message`, show the URL, and do not retry with different values.
- Rate-limit errors return `retry_after_seconds`. Wait that long and retry once.
- Report one of three outcomes: `verified`, `configured but unverified`, or `blocked`. Creating a monitor is not by itself verification.

## Connect Cronitor

Pick the connection path in this order and do not ask the human to choose between options that are not available to them:

1. **Already connected.** If Cronitor MCP tools are present in your session, use them. Read the published tool schemas and make one read-only call.
2. **Your client supports MCP** (Claude Code, Claude, Cursor, Codex, VS Code, or another Streamable HTTP client). Add the server `https://cronitor.io/mcp` using the exact steps for that client in [Connect your MCP client](https://cronitor.io/docs/mcp-server.md#connect-your-mcp-client), then let the human complete sign-in and consent in the browser. The connection follows the Cronitor organization they are signed in to. Prefer this path: it needs no key handling.
3. **No MCP support, but you have a shell.** Use [CronitorCLI](https://cronitor.io/docs/using-cronitor-cli.md). If `cronitor status` already succeeds, you are connected. If the CLI is missing or unconfigured, tell the human what installing it does (the install script runs with `sudo`) and ask before installing. After approval, install it and have the human provide the SDK Integration key through an environment variable or `cronitor configure`, never pasted into the conversation. Where the key lives is described in the MCP doc's [SDK Integration key section](https://cronitor.io/docs/mcp-server.md#use-the-existing-sdk-integration-key).
4. **Neither is possible.** Report `blocked`, link the client setup section, and continue any repository-only work. Do not fall back to a credential pasted in chat.

Never ask the human to paste an OAuth token, API key, ping key, or password into the conversation.

Once connected, confirm the organization with a compact inventory:

```text
get_status({})
list_environments({})
list_notification_lists({})
list_monitors({"page_size": 25})
```

Over CronitorCLI the same discovery is:

```bash
cronitor status
cronitor monitor list
cronitor environment list
cronitor notification list
```

The CLI and the [REST API](https://cronitor.io/docs/api.md) expose the same resources as the MCP tools. Request summary fields first and paginate only when the task needs the remaining resources.

**Done when:** a read-only call succeeds and the organization is unambiguous.

**If blocked:** report `blocked`, name the path you tried and why it failed, and state that remote account inspection or changes remain incomplete.

## Audit monitoring

An audit is read-only unless the human separately asks you to implement its recommendations.

Inspect the actual execution boundaries in the repository and deployment configuration:

- schedulers, cron entries, systemd or Windows tasks, application workers, Kubernetes CronJobs, and scheduled GitHub Actions;
- bounded jobs, long-running useful-work checkpoints, public endpoints, ports, certificates, and browser applications;
- existing Cronitor packages, monitor keys, secret references, environments, notification lists, groups, checks, sites, and status pages.

Inspect the boundary that runs, not merely the repository's dominant language. A shell command in a Python repository is often a CronitorCLI integration; a Python function invoked by a thin launcher may be better instrumented with the Python SDK.

Use the account rollup and inventory from the connection recipe. Search by stable key, tag, group, or workload name when matching code to existing resources:

```text
search_monitors({"query": "nightly-backup"})
get_monitor({"key": "nightly-backup", "with_status": true})
```

To capture the whole account at once, `export_monitors({})` returns one Cronitor YAML document containing every monitor, in the same format `cronitor sync` consumes. Commit it when the human wants monitoring as code.

Report the audit in this form:

```text
Covered
- <workload or endpoint>: <Cronitor resource and evidence>

Gaps
- <workload or endpoint>: <failure Cronitor cannot currently detect>

Uncertain
- <missing repository, runtime, account, or environment evidence>

Recommended next change
- <smallest change that detects the most important uncovered failure>
```

Do not equate a configured monitor with coverage. For jobs and heartbeats, look for evidence that the real runtime sends telemetry. For checks, confirm that Cronitor is probing the intended target and assertions.

**Done when:** every conclusion is tied to repository, deployment, or Cronitor evidence, and recommendations are clearly separated from changes actually made.

**If blocked:** report the observable portion of the audit and list the missing access or evidence. Do not guess that an unobservable runtime is covered.

## Add monitoring

Choose the monitor that proves the outcome the human cares about:

| Evidence required | Use | Read next |
| --- | --- | --- |
| A bounded task started, completed or failed, and how long it took | Job monitor with CronitorCLI or an SDK | [Job monitoring](https://cronitor.io/docs/cron-job-monitoring.md) |
| A process, device, or loop reached a recurring useful checkpoint | Heartbeat monitor | [Heartbeat monitoring](https://cronitor.io/docs/heartbeat-monitoring.md) |
| A website, API, port, certificate, or MCP server works from outside its failure domain | Uptime check | [Uptime monitoring](https://cronitor.io/docs/uptime-monitoring.md) |
| Real browser traffic, JavaScript errors, performance, and Web Vitals | Site / RUM | [RUM quickstart](https://cronitor.io/docs/rum-quickstart.md) |
| Health and incidents must be communicated to other people | Status page | [Status pages](https://cronitor.io/docs/status-pages.md) |

Before writing, find matching resources and the effective alert route:

```text
search_monitors({"query": "job:nightly-backup"})
get_notification_list({"key": "on-call"})
```

For a broad request, present the exact proposal and obtain approval:

```text
Workload:
Existing resource:
Create or update:
Stable key:
Schedule, timezone, and grace:
Environment:
Alert recipients:
Runtime or probe change:
How the job reports:
Verification:
Rollback:
```

Do not ask again when the human already approved this exact scope. Ask when discovery materially changes it.

Use `setup_monitor` to create one monitor from a human description; it upserts by stable key. Use `create_monitors` for bulk creation or when the human supplies the exact monitor shape. `setup_monitor` accepts `timezone` (an IANA name such as `America/New_York`) for cron schedules. Ask for it when the schedule is a cron expression and the human's timezone is not UTC; Cronitor otherwise evaluates the expression in UTC.

### Example: scheduled command

After the scope is approved, create or reconcile the job monitor:

```text
setup_monitor({
  "type": "job",
  "key": "nightly-backup",
  "schedule": "0 2 * * *",
  "timezone": "America/New_York",
  "grace_seconds": 900,
  "notify": ["on-call"],
  "tags": ["production", "backup"]
})
```

Have the real scheduler command report to the monitor. CronitorCLI is the preferred integration for a shell command; start without uploading stdout or stderr:

```bash
cronitor exec --no-stdout nightly-backup /usr/local/bin/nightly-backup
```

CronitorCLI preserves start, completion, failure, duration, and exit status. It still sends the command string, so move secrets out of command arguments. Read [CronitorCLI safe use](https://cronitor.io/docs/using-cronitor-cli.md#safe-use). When neither the CLI nor an SDK fits the runtime, calling the returned telemetry URL directly from the job with `state=run` and then `state=complete` or `state=fail` is a fine fallback.

After one safe real run:

```text
get_status({"key": "nightly-backup"})
```

Confirm the event came from the intended runtime and environment, not the setup session.

### Example: useful-work heartbeat

```text
setup_monitor({
  "type": "heartbeat",
  "key": "queue-consumer",
  "schedule": "every 5 minutes",
  "grace_seconds": 120,
  "notify": ["on-call"]
})
```

Have the consumer report to the monitor, through an SDK or by calling the telemetry URL, only after it completes useful work. A separate timer that pings while the consumer is stuck proves the wrong thing. Verify with `get_status({"key": "queue-consumer"})` after a real checkpoint.

### Example: external API check

```text
setup_monitor({
  "type": "check",
  "key": "api-health",
  "url": "https://api.example.com/health",
  "schedule": "every 1 minute",
  "assertions": [
    "response.code = 200",
    "response.body contains ok",
    "response.time < 2s"
  ],
  "tags": ["production", "api"]
})
```

Cronitor performs the probe, so no runtime ping is required. Read the monitor back and observe one successful real probe. For MCP endpoints, use the request shape in the [MCP monitoring guide](https://cronitor.io/guides/monitor-mcp-servers).

Use the integration native to the real execution boundary. See [SDKs and integrations](https://cronitor.io/docs/sdks.md), [safe Kubernetes rollout](https://cronitor.io/guides/monitoring-kubernetes-cron-jobs#safe-agent-rollout), and the [Cronitor GitHub Action](https://github.com/cronitorio/monitor-github-actions). Reuse the repository's package manager and lockfile, preserve return values and exit status, and do not enable automatic discovery beyond the approved scope.

**Done when:** the saved resource matches the proposal and Cronitor has observed one safe real event, checkpoint, probe, or pageview from the intended integration path.

**If blocked:** report `configured but unverified` when configuration is saved but a real observation is unavailable. Report `blocked` when you cannot change the real runtime or configure the real target. Never manufacture verification.

## Connect an alert destination

Creating a notification destination requires explicit approval. Discover first, then write.

1. Call `list_integrations({})`. Reuse a matching channel if one already exists.
2. Key-based services: `create_integration({"service": "discord", "name": "#alerts", "fields": {"key": "<webhook URL supplied by the human>"}})`. Never echo the key.
3. Slack or PagerDuty: `connect_integration({"service": "slack"})`, hand over `authorize_url`, then `check_integration_connection({"token": "…"})`. Do not open the URL yourself.
4. Attach by label: first `get_notification_list({"key": "default"})`. Merge the new destination into the existing `notifications` map — do not replace the map, or omitted channels are cleared. Then `update_notification_list({"key": "default", "notifications": <merged>})` and `get_notification_list({"key": "default"})` again.

Read [Integrations](https://cronitor.io/docs/integrations.md) and [MCP server integrations](https://cronitor.io/docs/mcp-server.md#integrations). Do not ask the human to paste provider tokens or webhook secrets into the conversation.

**Done when:** the connect status is `complete` (or the key-based create succeeded) and the notification list reads back the label.

**If blocked:** report `configured but unverified` while the session is `pending`; report `blocked` on `expired` or `failed`.

## Investigate a failure

Diagnosis is read-only. Do not pause, unpause, edit, resolve, or delete anything unless the human separately asks for that change.

For an account-wide question, start with:

```text
list_failing_monitors({})
```

`list_failing_monitors` and `get_status` cover the organization's default environment unless you pass `env`. When the human names an environment ("what's failing in staging?"), pass it as a key or name:

```text
list_failing_monitors({"env": "staging"})
```

For a named monitor, start compactly:

```text
get_status({"key": "nightly-backup"})
get_monitor({"key": "nightly-backup", "with_status": true})
```

Request events or invocations only when the compact status does not answer the question and the user-approved task needs that data:

```text
get_monitor({
  "key": "nightly-backup",
  "with_status": true,
  "with_events": true,
  "with_invocations": true
})
```

Compare Cronitor's saved schedule, timezone, rules, latest event, and alert reason with the real scheduler and runtime behavior. Distinguish observed facts from inference. A failing monitor can indicate a real workload failure, incorrect schedule, missing telemetry, wrong environment, or stale configuration.

**Done when:** you report the failure evidence, the most likely cause with confidence and alternatives, and the smallest next action. No remote state has changed.

**If blocked:** identify the missing event, runtime, scheduler, environment, or permission evidence. Do not clear the failure with a ping or configuration change.

## Query metrics

Metrics questions are read-only. Use `get_aggregates` for totals over a range and `get_metrics` for trends over time. Both select monitors by key, group, tag, or type, and both accept a named `time` range (`24h`, `3d`, `7d`, `14d`, `30d`, `90d`, `180d`, `365d`, `today`, or `yesterday`) or explicit `start` and `end` unix timestamps.

"How many times did nightly-import fail last week?" is a totals question:

```text
get_aggregates({"monitors": ["nightly-import"], "time": "7d"})
```

The result contains per-monitor, per-environment (per-region for checks) totals: `run_count`, `complete_count`, `fail_count`, `tick_count`, `alert_count`, `duration_mean`, `downtime_seconds`, `uptime`, and a derived `success_rate`.

"Is nightly-import getting slower?" is a trend question. `fields` is required; ask only for the series you need:

```text
get_metrics({"monitors": ["nightly-import"], "time": "30d", "fields": ["duration_p90", "fail_count"]})
```

For "which of my jobs" questions, select by group, tag, or type instead of listing keys, for example `get_aggregates({"tags": ["production"], "types": ["job"], "time": "24h"})`, then rank the per-monitor results.

Always state the time range and the environment the numbers cover; pass `env` when the human names one. Aggregates and metric series are the only analytics available through MCP: row-level output such as individual run logs or invocation output is not, so point the human to the monitor's dashboard page when they need it.

**Done when:** you report the requested numbers with the range, environment, and monitor selection they cover, and clearly separate observed values from interpretation.

**If blocked:** report an empty result as "no data for this selection and range" rather than zero failures. Report `blocked` when the monitors, group, tag, or environment cannot be resolved or the range is outside the supported window.

## Change configuration

Find and read the existing resource before updating it:

```text
get_monitor({"key": "nightly-backup", "with_status": true})
```

Show the requested delta and its alerting effect. Omit fields that should remain unchanged; explicit empty relationship arrays may clear existing relationships. Preserve the stable key.

For example, after approval to extend the grace period:

```text
update_monitor({"key": "nightly-backup", "grace_seconds": 1200})
get_monitor({"key": "nightly-backup", "with_status": true})
```

Use the live schema for other resource families. Creating notification destinations, publishing status pages or incidents, changing effective recipients, and destructive operations require explicit approval unless the human's request already names that exact action and scope.

**Done when:** the saved resource is read back, the requested fields match, unrelated fields remain intact, and the effective alerting impact is reported.

**If blocked:** report the rejected field, permission, plan limit, ambiguous target, or missing approval. Do not replace an update with delete-and-recreate.

## Report the outcome

Finish with a compact, auditable summary:

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

Use `verified` only when Cronitor independently observed the failure-detection path the human asked for. For topics not linked above, use the [complete agent-readable documentation index](https://cronitor.io/docs/index.md).
