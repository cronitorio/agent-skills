# Cronitor monitor YAML

`cronitor sync`, `cronitor monitor create --file`, `cronitor monitor export`, the MCP tool `export_monitors`, and `PUT /api/monitors` with `Content-Type: application/yaml` all share one document format. Sources: https://cronitor.io/docs/monitors-api.md (YAML Configuration and the attribute list) and https://cronitor.io/docs/using-cronitor-cli.md.

## Shape

The document has one top-level map per monitor type. Each entry is keyed by the monitor's stable `key`; the fields under it are the Monitor API attributes for that monitor.

```yaml
jobs:
  nightly-backup:
    name: Nightly backup
    schedule: "0 2 * * *"
    timezone: America/New_York
    grace_seconds: 900
    assertions:
      - "metric.duration < 15min"
    notify:
      - on-call
    tags:
      - production
      - backup

checks:
  website-homepage:
    schedule: "every 1 min"
    request:
      url: "https://example.com"
      method: "GET"
    assertions:
      - "response.time < 2s"
      - "response.code = 200"
    notify:
      - default

heartbeats:
  queue-consumer:
    schedule: "every 5 min"
    grace_seconds: 120
    assertions:
      - "metric.duration < 30s"
    notify:
      - default
```

Sending the document again with changed fields updates the named monitors in place (upsert by key). Fields you omit from an entry are left as they are on the server when updating through the API; the CLI's `--help` describes its own replacement behavior.

## Fields

| Field | Applies to | Notes |
|-------|------------|-------|
| `name` | all | Display name; defaults to the key. |
| `schedule` | job, heartbeat, check | Cron expression (`0 2 * * *`), interval (`every 5 minutes`), or time of day (`at 14:30`). Checks accept intervals from 30 seconds to 1 hour. The API's current version also accepts a `schedules` array for multiple expressions. |
| `timezone` | job, heartbeat | IANA name used to evaluate cron schedules; defaults to the account timezone or UTC. |
| `grace_seconds` | job, heartbeat | Extra seconds allowed after the expected time before a schedule alert. No effect on checks. |
| `schedule_tolerance` | job, heartbeat | Missed executions to allow before alerting (default 0). |
| `failure_tolerance` | job, heartbeat, check | Failed events or requests to tolerate before alerting (default 0). |
| `assertions` | all | Rule strings such as `metric.duration < 15min`, `response.code = 200`, `response.time < 2s`, `response.body contains ok`. |
| `notify` | all | Array of notification-list keys or prefixed destinations (`email:alerts@example.com`, `slack:#devops`); or a map `{alerts: [...], events: {complete: true}}` for occurrence-based notifications. Omit to use the `default` list. |
| `tags` | all | Free-form strings. |
| `group` | all | Group key. |
| `note` | all | Free text shown with alerts. |
| `paused` | all | `true` disables alerting. |
| `platform` | job, check | Job: `linux cron` (default), `windows`, `kubernetes`, `jvm`, `laravel`, `sidekiq`, `celery`, `node-cron`, and others. Check: `http` (default), `browser`, `tcp`, `udp`. |
| `realert_interval` | all | How long to wait before repeating an alert; default `8 hours`. |
| `request` | check | `url`, `method`, `body`, `headers`, `cookies`, `timeout_seconds` (1-15), `follow_redirects`, `verify_ssl`. |
| `regions` | check | Probe regions; omit for Cronitor's default set. |

## Working with the document

- Export the live account with `export_monitors({})` (MCP), `cronitor monitor export --format yaml --output monitors.yaml` (CLI), or `GET /api/monitors?format=yaml` (REST). Commit the file when the human wants monitoring as code.
- Apply a file with `cronitor monitor create --file monitors.yaml` or `curl -u "$CRONITOR_API_KEY:" -H "Content-Type: application/yaml" -X PUT --data-binary @monitors.yaml https://cronitor.io/api/monitors`. Add `async: true` and an optional `webhook_url` at the top level for very large documents.
- `cronitor sync` discovers the host's crontab (or Windows Task Scheduler), creates job monitors in this format, and rewrites the selected entries to `cronitor exec <key> <command>`. Run `cronitor sync --dry-run` first and get approval before it edits the crontab.
- Exports do not contain ping URLs or API keys. Telemetry credentials live in the runtime environment, not in this file.
