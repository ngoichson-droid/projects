#!/usr/bin/env bash
# Restore an archive made by claude-export.sh on another machine.
# Usage: bash claude-import.sh claude-backup-XXXX.tar.gz
set -euo pipefail
ARCHIVE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
tar -xzf "$ARCHIVE" -C "$STAGE"

# Back up what is there now
if [ -d "$DST" ]; then
  BK="$DST.bak-$(date +%Y%m%d-%H%M%S)"; cp -R "$DST" "$BK"; echo "Backup of current config: $BK"
fi
mkdir -p "$DST"
cp -R "$STAGE/claude/." "$DST/"
echo "✓ Restored skills, commands, agents, settings, CLAUDE.md, memory into $DST"

# Merge MCP servers into ~/.claude.json (user-level; existing entries win)
if [ -f "$STAGE/mcp-servers.json" ] && command -v python3 >/dev/null; then
  python3 - "$STAGE/mcp-servers.json" "$HOME/.claude.json" <<'PY'
import json, os, sys, shutil
src = json.load(open(sys.argv[1])); path = sys.argv[2]
cfg = json.load(open(path)) if os.path.exists(path) else {}
if os.path.exists(path): shutil.copy(path, path + ".bak")
servers = cfg.setdefault("mcpServers", {})
added = 0
for group in [src.get("user", {})] + list(src.get("projects", {}).values()):
    for name, conf in group.items():
        if name not in servers: servers[name] = conf; added += 1
json.dump(cfg, open(path, "w"), indent=2)
print(f"✓ Added {added} MCP server(s) to {path}")
PY
fi

# Auto memory is stored per project path. Show how to remap if paths differ.
if [ -f "$STAGE/memory-projects.txt" ]; then
  echo; echo "Auto memory came from these project folders (path with / replaced by -):"
  sed 's/^/  - /' "$STAGE/memory-projects.txt"
  echo "If a project lives at a different path here, rename the folder under $DST/projects/"
  echo "to the new path with every non-alphanumeric character replaced by '-'."
fi
echo; echo "Done. Restart Claude Code. Re-login and re-enter any API keys if needed."
