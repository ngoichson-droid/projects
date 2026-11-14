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

## Or: one archive, copied by hand
```bash
bash scripts/claude-export.sh                 # on the main machine -> claude-backup-*.tar.gz
bash scripts/claude-import.sh claude-backup-*.tar.gz   # on the other machine
```
The archive holds skills, commands, agents, settings, CLAUDE.md, auto memory and MCP servers.
It leaves out login credentials, chat history and caches. Keep it private: settings and MCP config can contain keys.
