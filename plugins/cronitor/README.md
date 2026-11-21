# Cronitor plugin

Cronitor monitors cron jobs, background workers, heartbeats, websites, APIs, and MCP servers, and alerts you when they fail. This plugin connects your coding agent to Cronitor so it can set that monitoring up with you.

## What it installs

- **Cronitor MCP server** at `https://cronitor.io/mcp`. Your agent uses it to read and change your Cronitor monitors, checks, sites, status pages, notification lists, and alert integrations. You sign in through your browser with OAuth; no API key is stored in the plugin.
- **Cronitor skill.** Task recipes for onboarding a project, auditing coverage, adding monitoring, investigating failures, querying metrics, and changing configuration, plus a tool reference and two helper scripts.

## What runs on your machine

The skill includes two read-only shell scripts. Your agent runs them only when a recipe calls for it.

- `scripts/doctor.sh` checks whether CronitorCLI is installed, whether `CRONITOR_API_KEY` is set (without printing it), and whether `https://cronitor.io/mcp` is reachable. It makes one HTTPS request to that URL and sends no data.
- `scripts/find-schedulers.sh` lists scheduled work on the host and in the current project, such as crontabs, systemd timers, Kubernetes CronJobs, and scheduled GitHub Actions. It reads local files only and makes no network requests.

Neither script changes anything on your machine.

## Install

Claude Code:

```bash
claude plugin marketplace add cronitorio/agent-skills
claude plugin install cronitor@cronitor
```

Codex:

```bash
codex plugin marketplace add cronitorio/agent-skills
codex plugin add cronitor@cronitor
```

Then sign in to the MCP server from your client (`/mcp` in Claude Code, `codex mcp login cronitor` in Codex) and ask your agent to set up Cronitor monitoring for your project.

## Privacy and support

Your agent sends Cronitor only the requests it makes through the MCP server, under your account. Privacy policy: https://cronitor.io/privacy. Terms: https://cronitor.io/terms. Documentation: https://cronitor.io/docs/agent-quickstart. Support: https://cronitor.io/help.
