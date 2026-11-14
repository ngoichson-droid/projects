# Claude Code: shared workflows and memory

This repo carries Claude Code skills, commands, agents, settings and memory,
so a cloud session or another machine works the same way as the main one.

| Local (main machine)                      | In this repo                         | Loaded in cloud?            |
|-------------------------------------------|--------------------------------------|-----------------------------|
| `~/.claude/skills/`                       | `.claude/skills/`                    | yes                         |
| `~/.claude/commands/`                     | `.claude/commands/`                  | yes                         |
| `~/.claude/agents/`                       | `.claude/agents/`                    | yes                         |
| `~/.claude/CLAUDE.md`                     | `.claude/memory/user-CLAUDE.md`      | yes, via `CLAUDE.md` import |
| `~/.claude/projects/*/memory/`            | `.claude/memory/auto/`               | yes, once imported          |
| `~/.claude/settings.json`                 | `.claude/settings.json`              | yes, after review           |
| `~/.claude.json` → `mcpServers`           | `.mcp.json`                          | yes, after review           |

## Sync from the main machine
```bash
git clone https://github.com/ngoichson-droid/projects.git && cd projects
bash scripts/sync-claude-to-repo.sh
# review, remove secrets, then commit and push
```
Secrets (API keys, tokens) go in the cloud environment's environment variables, not in git.
