# CLI and REST equivalents

The hosted MCP tools, CronitorCLI, and the REST API expose the same account resources. Use whichever path is available (see the connection triage in `SKILL.md`). Sources: https://cronitor.io/docs/using-cronitor-cli.md and https://cronitor.io/docs/api.md.

REST requests use HTTP Basic auth with the API key as the username and an empty password: `curl https://cronitor.io/api/monitors -u "$CRONITOR_API_KEY:"`. Send `Cronitor-Version: 2025-11-28` for the current schema. CronitorCLI reads `CRONITOR_API_KEY` from the environment; never pass a literal key as `--api-key`. The installed command's `cronitor <resource> <operation> --help` is authoritative for its version.

## Discovery and status

| Task | MCP tool | CronitorCLI | REST |
|------|----------|-------------|------|
| Account status rollup | `get_status({})` | `cronitor status` | `GET /api/monitors` |
| One monitor's status | `get_status({"key": K})` | `cronitor monitor get K --with-status` | `GET /api/monitors/K` |
| Currently failing monitors | `list_failing_monitors({})` | `cronitor monitor list --with-status` (filter by state) | `GET /api/monitors?state=failing` |
| List monitors | `list_monitors({...})` | `cronitor monitor list [--type job] [--env production]` | `GET /api/monitors` |
| Search monitors | `search_monitors({"query": Q})` | `cronitor monitor search Q` | `GET /api/monitors?search=Q` |
| Get one monitor | `get_monitor({"key": K})` | `cronitor monitor get K [--with-events] [--with-invocations]` | `GET /api/monitors/K` |
| Export monitors as YAML | `export_monitors({})` | `cronitor monitor export [--format yaml] [--output monitors.yaml]` | `GET /api/monitors?format=yaml` |
| List environments | `list_environments({})` | `cronitor environment list` | `GET /api/environments` |
| List notification lists | `list_notification_lists({})` | `cronitor notification list` | `GET /api/notifications` |
| List groups | `list_groups({})` | `cronitor group list [--with-status]` | `GET /api/groups` |
| List alert destinations | `list_integrations({})` | (dashboard or API) | `GET /api/integrations` |

## Monitors

| Task | MCP tool | CronitorCLI | REST |
|------|----------|-------------|------|
| Create one monitor from a description | `setup_monitor({...})` | `cronitor monitor create --data '{...}'` | `POST /api/monitors` |
| Create or upsert many monitors | `create_monitors({"monitors": [...]})` | `cronitor monitor create --file monitors.yaml` | `PUT /api/monitors` (JSON or YAML body) |
| Update a monitor | `update_monitor({"key": K, ...})` | `cronitor monitor update K --data '{...}'` | `PUT /api/monitors/K` |
| Delete monitors | `delete_monitors({"keys": [...]})` | `cronitor monitor delete K` | `DELETE /api/monitors/K` |
| Clone a monitor | `clone_monitor({...})` | `cronitor monitor clone K` | `POST /api/monitors/clone` |
| Pause / unpause | `pause_monitor({"key": K, "hours": H})`, `unpause_monitor({"key": K})` | `cronitor monitor pause K [H]`, `cronitor monitor unpause K` | `GET /api/monitors/K/pause/H`, `GET /api/monitors/K/pause/0` |
| Import local cron jobs | (not available; runs on the host) | `cronitor sync [--dry-run]` | `PUT /api/monitors` with YAML |
| Wrap a scheduled command | (not available; runs on the host) | `cronitor exec --no-stdout K <command>` | Telemetry API `GET https://cronitor.link/p/:pingKey/K?state=run|complete|fail` |
| Send a heartbeat ping | (never through MCP) | `cronitor ping K` | `GET https://cronitor.link/p/:pingKey/K` |

## Metrics

| Task | MCP tool | CronitorCLI | REST |
|------|----------|-------------|------|
| Totals over a range | `get_aggregates({"monitors": [K], "time": "7d"})` | `cronitor metric aggregate --monitor K --time 7d` | `GET /api/aggregates?monitor=K&time=7d` |
| Time series | `get_metrics({"monitors": [K], "time": "30d", "fields": ["duration_p90"]})` | `cronitor metric get --monitor K --time 30d --field duration_p90` | `GET /api/metrics?monitor=K&time=30d&field=duration_p90` |

## Alerting and organization

| Task | MCP tool | CronitorCLI | REST |
|------|----------|-------------|------|
| Get / update a notification list | `get_notification_list`, `update_notification_list` | `cronitor notification get K`, `cronitor notification update K --data '{...}'` | `GET`/`PUT /api/notifications/K` |
| Create a notification list | `create_notification_list` | `cronitor notification create --data '{...}'` | `POST /api/notifications` |
| Create a key-based alert destination | `create_integration({"service": S, "name": N, "fields": {...}})` | (dashboard or API) | `POST /api/integrations` |
| Connect Slack or PagerDuty | `connect_integration`, `check_integration_connection` | (browser flow) | `POST /api/integrations/connect` |
| Delete an alert destination | `delete_integration({"service": S, "label": L})` | (dashboard or API) | `DELETE /api/integrations?service=S&label=L` |
| Groups | `list_groups`, `get_group`, `create_group`, `update_group`, `delete_group`, `pause_group`, `resume_group` | `cronitor group <list|get|create|update|delete|pause|resume>` | `/api/groups[/K]` |
| Environments | `list_environments`, `get_environment`, `create_environment`, `update_environment`, `delete_environment` | `cronitor environment <list|get|create|update|delete>` | `/api/environments[/K]` |

## Incidents and status

| Task | MCP tool | CronitorCLI | REST |
|------|----------|-------------|------|
| Issues | `list_issues`, `get_issue`, `create_issue`, `update_issue`, `resolve_issue`, `delete_issue`, `bulk_update_issues` | `cronitor issue <list|get|create|update|resolve|delete|bulk>` | `/api/issues[/K]` |
| Maintenance windows | `list_maintenance_windows`, `get_maintenance_window`, `create_maintenance_window`, `update_maintenance_window`, `delete_maintenance_window` | `cronitor maintenance <list|get|create|update|delete>` | `/api/maintenance_windows[/K]` |
| Status pages | `list_status_pages`, `get_status_page`, `create_status_page`, `update_status_page`, `delete_status_page` | `cronitor statuspage <list|get|create|update|delete>` | `/api/statuspages[/K]` |
| Status-page components | `list_status_page_components`, `create_status_page_component`, `update_status_page_component`, `delete_status_page_component` | `cronitor statuspage component <list|create|update|delete> --statuspage K` | `/api/statuspage_components[/K]` |

## Real User Monitoring

| Task | MCP tool | CronitorCLI | REST |
|------|----------|-------------|------|
| Sites | `list_sites`, `get_site`, `create_site`, `update_site`, `delete_site` | `cronitor site <list|get|create|update|delete>` | `/api/sites[/K]` |
| Query analytics | `query_site({...})` | `cronitor site query --site K ...` | `POST /api/sites/query` |
| JavaScript errors | `list_site_errors`, `get_site_error` | `cronitor site errors --site K` | see https://cronitor.io/docs/sites-api.md |

Per-resource REST documentation: https://cronitor.io/docs/monitors-api.md, https://cronitor.io/docs/metrics-api.md, https://cronitor.io/docs/groups-api.md, https://cronitor.io/docs/notifications-api.md, https://cronitor.io/docs/integrations-api.md, https://cronitor.io/docs/environments-api.md, https://cronitor.io/docs/issues-api.md, https://cronitor.io/docs/maintenance-windows-api.md, https://cronitor.io/docs/statuspages-api.md, https://cronitor.io/docs/sites-api.md, https://cronitor.io/docs/telemetry-api.md.
