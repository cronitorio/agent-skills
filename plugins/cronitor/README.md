# Cronitor plugin

Cronitor monitors cron jobs, background workers, heartbeats, websites, APIs, and MCP servers, and alerts you when they fail. This plugin connects your coding agent to Cronitor so it can set that monitoring up with you.

## What it installs

- **Cronitor MCP server** at `https://cronitor.io/mcp`. Your agent uses it to read and change your Cronitor monitors, checks, sites, status pages, notification lists, and alert integrations. You sign in through your browser with OAuth; no API key is stored in the plugin.
- **Cronitor skill.** Task recipes for onboarding a project, auditing coverage, adding monitoring, investigating failures, querying metrics, and changing configuration, plus a tool reference.

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
