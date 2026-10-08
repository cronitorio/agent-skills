# Cronitor agent recipes

Recipes for AI agents working on Cronitor monitoring for a human. Find the request in the table below.

All docs: https://cronitor.io/llms.txt. Start with the request the human actually made. Do not turn an audit into an implementation, fix a failure during a diagnosis, or enable every applicable Cronitor product.

## Install the Cronitor skill

The Cronitor skill bundles these recipes with a tool reference, CLI equivalents, and helper scripts. Install it once:

```bash
npx skills add cronitorio/agent-skills
```

Claude Code and Codex users can install the Cronitor plugin instead, which adds the skill and the [MCP server](https://cronitor.io/docs/mcp-server.md) together. In Claude Code:

```bash
claude plugin marketplace add cronitorio/agent-skills
claude plugin install cronitor@cronitor
```

In Codex:

```bash
codex plugin marketplace add cronitorio/agent-skills
codex plugin add cronitor@cronitor
```

Or copy the skill folder into `~/.claude/skills/cronitor`.

## Start with the user's request

| The human wants to… | Follow this recipe | Complete when… |
| --- | --- | --- |
| Set up monitoring for a project | [Onboard a project](#onboard-a-project) | Every resource the human approved is verified, or marked configured but unverified with the step that remains |
| Sign up or connect an account | [Connect Cronitor](#connect-cronitor) | A read-only call succeeds against the confirmed organization |
| Understand current coverage | [Audit monitoring](#audit-monitoring) | You report what is covered, what is not, and the evidence for each conclusion |
| Monitor a workload or endpoint | [Add monitoring](#add-monitoring) | Cronitor observes the real workload or performs a successful real probe |
| Send alerts to Slack, Teams, or another channel | [Connect an alert destination](#connect-an-alert-destination) | The destination is on the notification list and reads back |
| Understand a failure | [Investigate a failure](#investigate-a-failure) | You explain the evidence, likely cause, and next action without changing state |
| Understand performance, failure counts, or trends | [Query metrics](#query-metrics) | You report the numbers, the time range, and the environment they cover |
| Modify an existing resource | [Change configuration](#change-configuration) | The approved change is saved and read back |

If a request contains several of these tasks, follow only the recipes needed for that request. A specific instruction to implement a named change authorizes that scope. A broad request such as "evaluate our monitoring" or "what should we monitor?" does not authorize remote writes, dependency installation, or runtime changes. The [Onboard a project](#onboard-a-project) recipe gets its authority from the human's approval of its proposal, not from the opening request.

## Rules shared by every recipe

- Examples in this guide use `tool_name(arguments)` notation; they are MCP calls, not shell commands.
- Read the live MCP tool schemas before calling tools. They are authoritative when an example in this guide differs.
- Use read-only discovery before writes and reconcile stable resource keys instead of creating duplicates.
- Ask before expanding beyond the requested scope or creating public status pages or incidents, notification destinations, paid resources, or destructive changes.
- MCP is the control plane, not the telemetry path. Jobs and heartbeats must send telemetry directly from the real runtime. Read [Control plane, not data plane](https://cronitor.io/docs/mcp-server.md#control-plane-not-data-plane).
- Prefer CronitorCLI or a Cronitor SDK to report telemetry; calling the monitor's telemetry URL from the job is a fine fallback. The telemetry URL contains a telemetry-only key and is not a secret.
- CronitorCLI and the SDKs read `CRONITOR_API_KEY`. `CRONITOR_API_KEY` must be the SDK Integration key. A host where the human ran `cronitor auth login` needs no key. Otherwise, ask the human to add it to the runtime's secret store, copied from Settings → API Keys → SDK Integration. Never ask for the value in chat or commit it.
- Never send a setup-session ping and claim the workload is monitored. Never deliberately fail a production workload to test alerting.
- Request event messages, invocation output, request headers or bodies, RUM visitor data, and private status-page configuration only when the task requires them.
- Plan-limit errors return an `upgrade_url`. Stop, report the `message`, show the URL, and do not retry with different values.
- Rate-limit errors return `retry_after_seconds`. Wait that long and retry once.
- Report one of three outcomes: `verified`, `configured but unverified`, or `blocked`. Creating a monitor is not by itself verification.

## Onboard a project

Use this recipe when the human wants to start monitoring a project, for example right after they connect a new account, or when a team adds another repository. Onboarding is a conversation. You find what can be monitored, the human decides what to monitor, then you set it up. Do not create resources or change code before the human approves the proposal in step 4.

### 1. Connect

Follow [Connect Cronitor](#connect-cronitor).

### 2. Discover

Discovery is read-only. In the repository, look for:

- scheduled work, such as crontab files, systemd timers, Kubernetes CronJob manifests, scheduled GitHub Actions, Vercel or Cloudflare cron configuration, Celery beat, Sidekiq, the Laravel scheduler, Airflow DAGs, node-cron, and APScheduler. These are examples, not a complete list. Anything that runs on a schedule or at a regular interval is a candidate, whatever system starts it;
- long-running workers and queue consumers;
- public URLs and health routes in deploy configuration, environment examples, and the README;
- a web frontend root layout, for the web analytics snippet;
- existing Cronitor packages, monitor keys, and environment variables.

In Cronitor, call `get_setup_context({})`, `get_status({})`, `list_notification_lists({})`, and `get_integration_services({})`. `get_setup_context` returns plan limits so the proposal fits the plan. If `get_status` reports "No monitors yet.", there is nothing to reconcile. Otherwise match what you found against existing monitors with `search_monitors` before you propose anything new. The default notification list emails the person who signed up, so a new monitor alerts someone from the start.

### 3. Report and ask

Send one message in this form. Give every question a default so the human can reply "use the defaults".

```markdown
Found in this repository
- <workload or URL>: <evidence> → <suggested monitor>

Not visible from this repository
- Scheduled work on servers, Windows machines, or clusters that this repository does not define.

Questions
1. Monitor everything listed above? (default: yes)
2. Do you run scheduled jobs outside this repository: Linux cron, Windows Task Scheduler, Kubernetes CronJobs, or another scheduler? (default: no)
3. Uptime checks for <URLs>? (default: yes, every 5 minutes)
4. Web analytics and performance monitoring for <frontend>? (default: yes)
5. A status page? (default: no)
6. Alerts go to <signup email>. Also send them to Slack, Teams, Discord, or another channel? (default: email only)
7. Environment and timezone for cron schedules? (default: production, the account's timezone from `get_setup_context`)
```

Always ask question 2, even when you found scheduled work in the repository. Schedulers on servers, Windows machines, and clusters are often defined outside the application repository. Omit question 4 when there is no web frontend. Offer only the alert channels that `get_integration_services` marks available. If your client has a structured question tool, use it.

For each scheduler the human names in question 2, say which integration fits and what they must run on that host: CronitorCLI and `cronitor sync` for Linux cron and Windows Task Scheduler, the Cronitor Kubernetes agent for CronJobs, and the [Cronitor GitHub Action](https://github.com/cronitorio/monitor-github-actions) for workflows. For any other scheduler, choose between CronitorCLI, a Cronitor SDK, and the telemetry URL as described in [Add monitoring](#add-monitoring).

### 4. Propose

Show one table with a row per resource: resource, type, how it reports, alert route, repository change, and any step the human must run. Ask for one approval. That approval authorizes everything in the table and nothing else. Ask again if the plan changes.

### 5. Act

Create resources with MCP. Instrument code with CronitorCLI or the repository's Cronitor SDK, following [Add monitoring](#add-monitoring). For hosts outside the repository, give the human the exact commands to run. Connect alert channels with [Connect an alert destination](#connect-an-alert-destination).

### 6. Verify and report

Confirm each resource with a real event or probe, then [report the outcome](#report-the-outcome). Mark anything that waits on a deploy or a host step as `configured but unverified`, and tell the human which event will confirm it.

**Done when:** every approved resource is `verified`, or `configured but unverified` with the remaining human step named.

**If blocked:** report the resources that were created, the ones that were not, and why. Do not leave half the proposal applied without saying so.

## Connect Cronitor

Pick the connection path in this order and do not ask the human to choose between options that are not available to them:

1. **Already connected.** If Cronitor MCP tools are present in your session, use them. Read the published tool schemas and make one read-only call.
2. **Your client supports MCP** (Claude Code, Claude, Cursor, Codex, VS Code, or another Streamable HTTP client). Add the server `https://cronitor.io/mcp` using the exact steps for that client in [Connect your MCP client](https://cronitor.io/docs/mcp-server.md#connect-your-mcp-client), then let the human sign in or create an account in the same browser flow. The connection follows their current Cronitor organization. Prefer this path: it needs no key handling. If the Cronitor tools do not appear after the server is added, ask the human to sign in from the client's MCP panel (`/mcp` in Claude Code and Codex) or to start a new session, then continue.
3. **No MCP support, but you have a shell.** Use [CronitorCLI](https://cronitor.io/docs/using-cronitor-cli.md). First try a read-only call such as `cronitor monitor list`; reuse working credentials. If installation or an update is needed, explain the change and obtain approval unless already authorized, then run one command. With `sudo`: `curl -fsSL 'https://cronitor.io/install-linux?sudo=1' | sh`. Already root, including a container or CI image running as root: `curl -fsSL 'https://cronitor.io/install-linux' | sh`. Installing to `/usr/bin` needs root or sudo; if you are neither, ask the human instead of running the installer. macOS and other options: [Installation](https://cronitor.io/docs/using-cronitor-cli.md#installation). Then sign in as described below.
4. **Neither is possible.** Report `blocked`, link the client setup section, and continue any repository-only work. Do not fall back to a credential pasted in chat.

Never ask the human to paste an OAuth token, API key, or password into the conversation.

### CLI signup and login

`cronitor auth login` signs in or creates an account in the browser; `cronitor signup` is the same command. It needs CronitorCLI 33.7 or later. Pass `--timeout 30m` so the CLI waits long enough for a relayed link (CronitorCLI 33.8 and earlier default to 5 minutes). Use `--no-browser` only when the browser is on another machine: the human runs `cronitor auth login --no-browser --timeout 30m` in a terminal they control and pastes the callback URL into that prompt, never into chat. Once you open the link, finish signing in within about 5 minutes. Restarting login invalidates the previous URL, so leave that command running. Confirm with `cronitor auth status`.

Login installs a persistent machine credential owned by the organization. Explain that before starting, reuse the existing config path, and do not replace a credential without approval. Keep it for later work: `cronitor auth logout` stops every job that uses it, so never run it as cleanup. Read-only users receive telemetry-only access. Full steps and config ownership: [Authentication](https://cronitor.io/docs/using-cronitor-cli.md#authentication). CI and containers can supply `CRONITOR_API_KEY` from a secret manager instead.

Once connected, confirm the organization with a compact inventory:

```text
get_status({})
list_environments({})
list_notification_lists({})
list_monitors({"detail": "summary", "page_size": 25})
```

Over CronitorCLI the same discovery is `cronitor status`, `cronitor monitor list`, `cronitor environment list`, and `cronitor notification list`.

The CLI and [REST API](https://cronitor.io/docs/api.md) expose the same resources. Use `detail: "summary"` on monitor and issue lists; paginate only when needed.

**Done when:** a read-only call succeeds and the organization is unambiguous.

**If blocked:** report `blocked`, name the path you tried and why it failed, and state that remote account inspection or changes remain incomplete.

## Audit monitoring

An audit is read-only unless the human separately asks you to implement its recommendations.

Inspect the same execution boundaries as [Onboard a project](#2-discover), plus secret references, groups, and existing checks, sites, and status pages. Inspect the boundary that runs, not merely the repository's dominant language. A shell command in a Python repository is often a CronitorCLI integration; a Python function invoked by a thin launcher may be better instrumented with the Python SDK.

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
get_notification_list({"key": "default"})
```

For a broad request, propose the change and get approval first: the workload, the resource to create or update and its stable key, schedule, timezone, and grace, environment, alert recipients, the runtime or probe change, how it will be verified, and how to roll it back. Do not ask again when the human already approved this exact scope; ask when discovery materially changes it.

Use `setup_monitor` to create one monitor from a human description; it upserts by stable key. Use `create_monitors` for bulk creation or when the human supplies the exact monitor shape. If either result has `monitor_quota`, the plan limit disabled the listed monitors; tell the human. `setup_monitor` accepts `timezone` (an IANA name such as `America/New_York`) for cron schedules. Ask for it when the schedule is a cron expression and the human's timezone differs from the account's timezone, which Cronitor otherwise uses.

### Example: scheduled command

After the scope is approved, create or reconcile the job monitor:

```text
setup_monitor({
  "type": "job",
  "key": "nightly-backup",
  "schedule": "0 2 * * *",
  "timezone": "America/New_York",
  "grace_seconds": 900,
  "notify": ["default"],
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
  "notify": ["default"]
})
```

Have the consumer report to the monitor, through an SDK or by calling the telemetry URL, only after it completes useful work. A separate timer that pings while the consumer is stuck proves the wrong thing. Verify with `get_status({"key": "queue-consumer"})` after a real checkpoint.

### Example: external API check

```text
setup_monitor({
  "type": "check",
  "key": "api-health",
  "url": "https://api.example.com/health",
  "schedule": "every 5 minutes",
  "assertions": [
    "response.code = 200",
    "response.body contains ok",
    "response.time < 2s"
  ],
  "tags": ["production", "api"]
})
```

Cronitor performs the probe. Read the monitor back and observe a successful real probe. Use `describe_monitor_assertions` for assertion syntax and the [MCP monitoring guide](https://cronitor.io/guides/monitor-mcp-servers) for MCP endpoints.

### Example: web analytics and performance monitoring

Create the site and add the tracking snippet from its response to the `<head>` of the frontend's root layout. If the frontend is a Next.js app or is bundled with npm, use the [Next.js or NPM package](https://cronitor.io/docs/rum-quickstart.md#nextjs) with the site's client key instead:

```text
create_site({"name": "Example web app", "origin_allowlist": ["https://example.com"]})
```

The snippet holds the site's client key, which is meant for browsers and is not a secret. If the site sets a Content Security Policy, allow `https://rum.cronitor.io` in `script-src` and `connect-src`. After the change is deployed and a person visits the site, confirm pageviews:

```text
query_site({"site": "<site key>", "type": "aggregation", "time": "1h"})
```

Automated browsers do not verify the install. Until a real visit arrives, report `configured but unverified`. Use `describe_site_query` for metrics, filters, and date boundaries. See the [RUM quickstart](https://cronitor.io/docs/rum-quickstart.md).

### Example: status page

Create the page with a hosted subdomain, then add a component for each monitor the human chose. Keep `autopublish` off so monitor failures do not publish incidents until the human decides they should:

```text
create_status_page({"name": "Example Status", "hosted_subdomain": "example-status"})
create_status_page_component({"statuspage": "<status page key>", "monitor": "api-health", "autopublish": false})
get_status_page({"key": "<status page key>"})
```

The page is served at `https://<hosted_subdomain>.cronitorstatus.com`. Give the human the URL to open, and confirm it shows only the approved components. A public page is visible to anyone, so ask before creating one unless the human already approved it. Publishing an incident is a separate step: `create_issue` with `statuspages` set. See [Status pages](https://cronitor.io/docs/status-pages.md).

Use the integration native to the real execution boundary. See [SDKs and integrations](https://cronitor.io/docs/sdks.md), [safe Kubernetes rollout](https://cronitor.io/guides/monitoring-kubernetes-cron-jobs#safe-agent-rollout), and the [Cronitor GitHub Action](https://github.com/cronitorio/monitor-github-actions). Reuse the repository's package manager and lockfile, preserve return values and exit status, and do not enable automatic discovery beyond the approved scope.

**Done when:** the saved resource matches the proposal and Cronitor has observed one safe real event, checkpoint, probe, or pageview from the intended integration path.

**If blocked:** report `configured but unverified` when configuration is saved but a real observation is unavailable. Report `blocked` when you cannot change the real runtime or configure the real target. Never manufacture verification.

## Connect an alert destination

Creating a notification destination requires explicit approval. In [Onboard a project](#onboard-a-project), the approved proposal covers it. Discover first, then write.

1. Call `list_integrations({})` and reuse a matching destination. Call `get_integration_services({})` and offer only services marked `available`. Unavailable services return `plan_required`.
2. Slack or PagerDuty: call `connect_integration({"service": "slack", "add_to": ["default"]})` and give the human the `authorize_url`. Do not open it yourself. Poll `check_integration_connection` every `poll_interval` seconds until the status is `complete`, `failed`, or `expired`. The link expires after 15 minutes.
3. Services that take an API key or webhook URL: `create_integration({"service": "discord", "name": "#alerts", "fields": {"key": "<webhook URL supplied by the human>"}, "add_to": ["default"]})`. Never echo the value. If the human prefers not to share it with you, they can run `cronitor connect discord --add-to default` in their own terminal instead.
4. Telegram: `create_integration` returns `link_required`. Send the human to the [Telegram guide](https://cronitor.io/docs/using-telegram-with-cronitor.md), or have them run `cronitor connect telegram`.
5. `add_to` keeps the list's other destinations. To attach an existing destination instead, the key is the integration's `service` and the value is the integration's `label`. Read the list, keep every channel already on it, add the new one, then read it back. The `notifications` map you send replaces the old one. A webhook reads back as its `identifier` rather than its label; keep that value as it is.

```text
get_notification_list({"key": "default"})
update_notification_list({"key": "default", "notifications": {"emails": ["owner@example.com"], "slack": ["#alerts"]}})
get_notification_list({"key": "default"})
```

Read [Integrations](https://cronitor.io/docs/integrations.md) and [MCP server integrations](https://cronitor.io/docs/mcp-server.md#integrations). Do not ask the human to paste provider tokens or webhook secrets into the conversation.

**Done when:** the connect status is `complete` (or the create succeeded) and `added_to` or a read-back shows the destination on the list.

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
get_monitor({"key": "nightly-backup", "with_status": true, "with_events": true, "with_invocations": true})
```

Compare Cronitor's saved schedule, timezone, rules, latest event, and alert reason with the real scheduler and runtime, and separate observed facts from inference. A failing monitor can mean a real failure, a wrong schedule or environment, missing telemetry, or stale configuration.

**Done when:** you report the failure evidence, the most likely cause with confidence and alternatives, and the smallest next action. No remote state has changed.

**If blocked:** identify the missing event, runtime, scheduler, environment, or permission evidence. Do not clear the failure with a ping or configuration change.

## Query metrics

Metrics questions are read-only. Use `get_aggregates` for totals over a range and `get_metrics` for trends over time. Both select monitors by key, group, tag, or type, and both accept a named `time` range (`24h`, `3d`, `7d`, `14d`, `30d`, `90d`, `180d`, `365d`, `today`, or `yesterday`) or explicit `start` and `end` unix timestamps.

"How many times did nightly-import fail last week?" is a totals question:

```text
get_aggregates({"monitors": ["nightly-import"], "time": "7d"})
```

The result contains per-monitor, per-environment (per-region for checks) totals: `run_count`, `complete_count`, `fail_count`, `tick_count`, `alert_count`, `duration_mean`, `downtime_seconds`, `uptime`, and a derived `success_rate`.

For trends, pass exactly one of `fields` (built-ins), `metric` (custom), or `metric_names` (discover custom names):

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
