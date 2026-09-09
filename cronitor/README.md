# Cronitor agent skill

This folder is the source for the public [cronitorio/agent-skills](https://github.com/cronitorio/agent-skills) repository. It follows the [Agent Skills](https://agentskills.io) specification: `SKILL.md` carries the frontmatter and the routing that an agent reads first, `references/` holds the material it loads on demand, and `scripts/` holds helpers it can run.

## Install

With the skills CLI, from any project:

```bash
npx skills add cronitorio/agent-skills
```

Claude Code users can instead copy this folder to `~/.claude/skills/cronitor` (user scope) or `<project>/.claude/skills/cronitor` (project scope).

## Layout

| Path | Contents |
|------|----------|
| `SKILL.md` | When to use the skill, the request routing table, shared rules, connection triage, and a summary of each recipe |
| `references/recipes.md` | The full agent quick start, identical to https://cronitor.io/docs/agent-quickstart.md at publish time |
| `references/mcp-tools.md` | Every hosted MCP tool with its purpose and API-key scope, generated from the server's tool registry |
| `references/cli-equivalents.md` | Task to MCP tool to CronitorCLI command to REST endpoint |
| `references/monitor-yaml.md` | The YAML document format shared by `cronitor sync`, `export_monitors`, and the Monitors API |
| `scripts/doctor.sh` | Reports which connection path (MCP, CLI, API key) is available without printing secrets |
| `scripts/find-schedulers.sh` | Read-only inventory of crontabs, Kubernetes CronJobs, scheduled GitHub Actions, Celery beat, Sidekiq-cron, whenever, and systemd timers |

## Keeping it current

The recipes are maintained in the Cronitor documentation and copied here verbatim; `references/mcp-tools.md` is regenerated from the MCP tool registry whenever tools change. Publish a new version by bumping `metadata.version` in `SKILL.md` and pushing this folder to the public repository.
