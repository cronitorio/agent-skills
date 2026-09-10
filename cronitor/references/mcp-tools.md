# Cronitor MCP tool reference

Generated from the MCP tool registry in the Cronitor repository with
`./bin/dev-manage render_agent_skill`. Do not edit by hand; regenerate when
tools change. The live `tools/list` response is authoritative for field-level
schemas.

67 tools. Scope is the API-key scope the tool requires; with OAuth, read tools
are available to every role and write tools require a role that can edit that
resource family.

| Tool | Purpose | API-key scope |
|------|---------|---------------|
| `get_status` | Get an account status rollup or the current status of one monitor, in the default environment unless env is given. | `monitor:read` |
| `list_failing_monitors` | List monitors that are currently failing, in the default environment unless env is given. | `monitor:read` |
| `setup_monitor` | Create or update ONE heartbeat, job, or check monitor from a human description, by stable key. Accepts human schedules like 'every 30 minutes', applies presets, checks plan limits, and returns the ping URL. Prefer this over create_monitors unless you already have exact API-shaped monitor objects or need to create many at once. | `monitor:write` |
| `list_monitors` | List, filter, search, sort, and paginate monitors, matching `cronitor monitor list`. | `monitor:read` |
| `search_monitors` | Search monitors with Cronitor's scoped query syntax, matching `cronitor monitor search`. | `monitor:read` |
| `get_monitor` | Get one monitor by key, matching `cronitor monitor get`. | `monitor:read` |
| `create_monitors` | Create one or more monitors from exact API-shaped monitor objects (all Monitor API fields), matching `cronitor monitor create`; bulk input uses the API's idempotent upsert. For a single monitor from a human description prefer setup_monitor. | `monitor:write` |
| `update_monitor` | Update one monitor by key while preserving omitted API fields, matching `cronitor monitor update`. | `monitor:write` |
| `delete_monitors` | Delete one or more monitors by key, matching `cronitor monitor delete`. | `monitor:write` |
| `export_monitors` | Export every matching monitor as Cronitor YAML, matching `cronitor monitor export`. | `monitor:read` |
| `clone_monitor` | Clone a monitor and optionally give the clone a new name, matching `cronitor monitor clone`. | `monitor:write` |
| `pause_monitor` | Pause a monitor indefinitely or for a fixed number of hours, matching `cronitor monitor pause`. | `monitor:write` |
| `unpause_monitor` | Resume alerting for a paused monitor, matching `cronitor monitor unpause`. | `monitor:write` |
| `get_metrics` | Answer trend questions like 'how has p90 duration changed this month'. Returns time series for the requested fields, per monitor per environment (or per region for checks), matching `cronitor metric get`. Requires at least one of monitors, groups, tags, or types. | `monitor:read` |
| `get_aggregates` | Answer questions like 'how many times did the nightly import fail last week' or 'which checks had the worst success rate'. Returns totals for the range per monitor per environment (or per region for checks): run_count, complete_count, fail_count, tick_count, alert_count, event_count, duration_mean, downtime_seconds, uptime, and a derived success_rate, matching `cronitor metric aggregate`. Requires at least one of monitors, groups, tags, or types. | `monitor:read` |
| `list_status_pages` | List status pages with optional status and component expansions, matching `cronitor statuspage list`. | `statuspage:read` |
| `get_status_page` | Get one status page by key, matching `cronitor statuspage get`. | `statuspage:read` |
| `create_status_page` | Create a status page, matching `cronitor statuspage create`. | `statuspage:write` |
| `update_status_page` | Update supplied status-page fields by key, matching `cronitor statuspage update`. | `statuspage:write` |
| `delete_status_page` | Delete one status page by key, matching `cronitor statuspage delete`. | `statuspage:write` |
| `list_status_page_components` | List components, optionally filtered to one status page, matching `cronitor statuspage component list`. | `statuspage:read` |
| `create_status_page_component` | Add a monitor, group, or custom component to a status page, matching `cronitor statuspage component create`. | `statuspage:write` |
| `update_status_page_component` | Update supplied component fields or relationships, matching `cronitor statuspage component update`. | `statuspage:write` |
| `delete_status_page_component` | Delete one component by key, matching `cronitor statuspage component delete`. | `statuspage:write` |
| `list_issues` | List, filter, search, sort, and paginate issues, matching `cronitor issue list`. | `issue:read` |
| `get_issue` | Get one issue by key with optional relationship expansions, matching `cronitor issue get`. | `issue:read` |
| `create_issue` | Create an issue, optionally publishing it to status pages, matching `cronitor issue create`. | `issue:write` |
| `update_issue` | Update supplied issue fields by key, matching `cronitor issue update`. Relationship and update arrays use DRF replacement semantics. | `issue:write` |
| `resolve_issue` | Resolve one issue through the DRF bulk state-change pathway, matching `cronitor issue resolve`. | `issue:write` |
| `delete_issue` | Delete one issue by key, matching `cronitor issue delete`. | `issue:write` |
| `bulk_update_issues` | Delete, change state, or assign multiple issues, matching `cronitor issue bulk`. | `issue:write` |
| `list_notification_lists` | List notification lists, matching `cronitor notification list`. | `monitor:read` |
| `get_notification_list` | Get one notification list by key, matching `cronitor notification get`. | `monitor:read` |
| `create_notification_list` | Create a notification list, matching `cronitor notification create`. | `monitor:write` |
| `update_notification_list` | Update supplied notification-list fields by key, matching `cronitor notification update`. | `monitor:write` |
| `delete_notification_list` | Delete one notification list by key; the default list cannot be deleted. | `monitor:write` |
| `list_groups` | List monitor groups, matching `cronitor group list`. | `monitor:read` |
| `get_group` | Get one group by key, matching `cronitor group get`. | `monitor:read` |
| `create_group` | Create a group and optionally assign monitors, matching `cronitor group create`. | `monitor:write` |
| `update_group` | Update a group's name or complete ordered monitor membership, matching `cronitor group update`. | `monitor:write` |
| `delete_group` | Delete one group by key, matching `cronitor group delete`. | `monitor:write` |
| `pause_group` | Pause every monitor in a group for a fixed number of hours, matching `cronitor group pause`. | `monitor:write` |
| `resume_group` | Resume every paused monitor in a group, matching `cronitor group resume`. | `monitor:write` |
| `list_environments` | List environments, matching `cronitor environment list`. | `monitor:read` |
| `get_environment` | Get one environment by key, matching `cronitor environment get`. | `monitor:read` |
| `create_environment` | Create an environment, matching `cronitor environment create`. | `monitor:write` |
| `update_environment` | Update an environment's name or alerting behavior, matching `cronitor environment update`. | `monitor:write` |
| `delete_environment` | Delete one non-default environment by key, matching `cronitor environment delete`. | `monitor:write` |
| `list_maintenance_windows` | List and filter maintenance windows, matching `cronitor maintenance list`. | `issue:read` |
| `get_maintenance_window` | Get one maintenance window by key, matching `cronitor maintenance get`. | `issue:read` |
| `create_maintenance_window` | Schedule a maintenance window, matching `cronitor maintenance create`. | `issue:write` |
| `update_maintenance_window` | Update supplied maintenance-window fields by key, matching `cronitor maintenance update`. | `issue:write` |
| `delete_maintenance_window` | Delete one maintenance window by key, matching `cronitor maintenance delete`. | `issue:write` |
| `list_sites` | List Real User Monitoring sites, matching `cronitor site list`. | `site:read` |
| `get_site` | Get one RUM site by key, matching `cronitor site get`. | `site:read` |
| `create_site` | Create a Real User Monitoring site, matching `cronitor site create`. | `site:write` |
| `update_site` | Update supplied RUM site settings by key, matching `cronitor site update`. | `site:write` |
| `delete_site` | Delete one RUM site by key, matching `cronitor site delete`. | `site:write` |
| `query_site` | Query RUM aggregations, breakdowns, time series, or error groups, matching `cronitor site query`. | `site:read` |
| `list_site_errors` | List JavaScript errors, optionally for one site, matching `cronitor site error list`. | `site:read` |
| `get_site_error` | Get one JavaScript error by key, matching `cronitor site error get`. | `site:read` |
| `list_integrations` | List alert destinations on the account. Does not include the service catalogue. | `integration:read` |
| `get_integration_services` | Return the integration catalogue and whether each service is available on the current plan. | `integration:read` |
| `create_integration` | Create a key-based alert destination. Slack and PagerDuty require connect_integration instead. Never echo field values. Per-service fields: slack: none; pagerduty: none; datadog-on-call: webhook_url, api_key, oncall_team; opsgenie: key; victorops: key; microsoft-teams: key; discord: key; telegram: type; gchat: key; larksuite: key; webhook: key. | `integration:write` |
| `connect_integration` | Start a browser connection for Slack or PagerDuty. Hand the authorize_url to the human. | `integration:write` |
| `check_integration_connection` | Poll a connect session started by connect_integration until it is complete, failed, or expired. | `integration:read` |
| `delete_integration` | Soft-delete one integration by service and label. In-use destinations return 409 unless force is true. | `integration:write` |
