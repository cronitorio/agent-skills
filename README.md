# Cronitor agent skills

Skills that teach coding agents how to work with [Cronitor](https://cronitor.io): connect an account, audit monitoring coverage, add monitors, investigate failures, query metrics, and change configuration. They follow the [Agent Skills](https://agentskills.io) specification and work with Claude Code, Codex, Cursor, and any other agent that supports it.

## Install

```bash
npx skills add cronitorio/agent-skills
```

Claude Code users can instead copy a skill folder to `~/.claude/skills/` (user scope) or `<project>/.claude/skills/` (project scope).

## Skills

| Skill | Purpose |
|-------|---------|
| [`cronitor`](cronitor/) | Task recipes for managing Cronitor through the hosted MCP server, CronitorCLI, or the REST API, with a tool reference, CLI and REST equivalents, the monitor YAML format, and helper scripts |

## How these relate to the rest of Cronitor

- The hosted MCP server at `https://cronitor.io/mcp` supplies the tools. See the [hosted MCP server docs](https://cronitor.io/docs/mcp-server).
- The skill supplies the procedure: what to read, what to call, what to ask before writing, and how to report the result.
- The [agent quick start](https://cronitor.io/docs/agent-quickstart.md) is the always-current source of the recipes, and [llms.txt](https://cronitor.io/llms.txt) is the index that points agents at all of the above.

## Contributing

The skill content is maintained alongside Cronitor's documentation and published here. Open an issue for corrections or requests.
