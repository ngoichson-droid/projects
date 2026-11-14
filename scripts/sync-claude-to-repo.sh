#!/usr/bin/env bash
# Copy Claude Code workflows and memory from THIS machine into the repo,
# so cloud sessions (and other machines) load them after a git push.
# Usage: run from the repo root on your main machine:
#   bash scripts/sync-claude-to-repo.sh [path-to-old-project]
set -euo pipefail

SRC="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
REPO="$(git rev-parse --show-toplevel)"
DST="$REPO/.claude"
OLD_PROJECT="${1:-}"   # optional: project folder whose memory you want to bring over

mkdir -p "$DST"/{skills,commands,agents,memory}

copy_dir() {  # copy_dir <from> <to>
  if [ -d "$1" ]; then
    cp -R "$1"/. "$2"/
    echo "✓ $1 -> ${2#$REPO/}"
  fi
}

# 1. Workflows: skills, slash commands, subagents
copy_dir "$SRC/skills"   "$DST/skills"
copy_dir "$SRC/commands" "$DST/commands"
copy_dir "$SRC/agents"   "$DST/agents"

# 2. User-level memory (~/.claude/CLAUDE.md is NOT loaded in the cloud)
if [ -f "$SRC/CLAUDE.md" ]; then
  cp "$SRC/CLAUDE.md" "$DST/memory/user-CLAUDE.md"
  echo "✓ ~/.claude/CLAUDE.md -> .claude/memory/user-CLAUDE.md"
fi

# 3. Auto memory (~/.claude/projects/<project>/memory/*.md)
if [ -d "$SRC/projects" ]; then
  for mem in "$SRC"/projects/*/memory; do
    [ -d "$mem" ] || continue
    name="$(basename "$(dirname "$mem")")"
    if [ -n "$OLD_PROJECT" ]; then
      want="$(cd "$OLD_PROJECT" && pwd | sed 's#[^A-Za-z0-9]#-#g')"
      [ "$name" = "$want" ] || continue
    fi
    mkdir -p "$DST/memory/auto/$name"
    cp -R "$mem"/. "$DST/memory/auto/$name"/
    echo "✓ auto memory $name -> .claude/memory/auto/$name"
  done
fi

# 4. Settings (permissions, hooks, enabled plugins). Saved for review, NOT applied.
if [ -f "$SRC/settings.json" ]; then
  cp "$SRC/settings.json" "$DST/settings.from-local.json"
  echo "✓ settings.json -> .claude/settings.from-local.json (review, then rename to settings.json)"
fi

# 5. MCP servers configured locally (~/.claude.json -> mcpServers)
if [ -f "$HOME/.claude.json" ] && command -v python3 >/dev/null; then
  python3 - "$HOME/.claude.json" "$REPO/.mcp.from-local.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
servers = dict(d.get("mcpServers", {}))
for p in d.get("projects", {}).values():
    servers.update(p.get("mcpServers", {}))
if servers:
    json.dump({"mcpServers": servers}, open(sys.argv[2], "w"), indent=2)
    print(f"✓ {len(servers)} MCP server(s) -> .mcp.from-local.json (review, then rename to .mcp.json)")
PY
fi

# 6. Secret scan — do NOT push tokens/keys to git
echo
echo "== Possible secrets (fix before committing) =="
grep -rInE '(api[_-]?key|token|secret|password|bearer|sk-[A-Za-z0-9]{10,}|ghp_[A-Za-z0-9]{10,})' \
  "$DST" "$REPO"/.mcp.from-local.json 2>/dev/null | grep -v '\.gitkeep' || echo "(none found)"
echo
echo "Next: review the files, then: git add -A && git commit -m 'Sync Claude config' && git push"
