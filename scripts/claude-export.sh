#!/usr/bin/env bash
# Pack Claude Code workflows + memory from this machine into one archive.
# Usage: bash claude-export.sh            -> ./claude-backup-YYYYmmdd-HHMM.tar.gz
set -euo pipefail
SRC="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
OUT="$PWD/claude-backup-$(date +%Y%m%d-%H%M).tar.gz"
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/claude"

[ -d "$SRC" ] || { echo "Not found: $SRC"; exit 1; }
cd "$SRC"
# Workflows, settings, memory. Skip sessions, transcripts, caches, credentials.
for p in CLAUDE.md settings.json keybindings.json skills commands agents output-styles hooks \
         plugins/installed_plugins.json plugins/known_marketplaces.json; do
  [ -e "$p" ] && { mkdir -p "$STAGE/claude/$(dirname "$p")"; cp -R "$p" "$STAGE/claude/$p"; echo "✓ $p"; }
done
for mem in projects/*/memory; do
  [ -d "$mem" ] || continue
  mkdir -p "$STAGE/claude/$(dirname "$mem")"; cp -R "$mem" "$STAGE/claude/$mem"; echo "✓ $mem"
done
for proj in projects/*/; do   # remember original project paths for remapping
  [ -d "$proj/memory" ] && echo "$(basename "$proj")" >> "$STAGE/memory-projects.txt"
done

# MCP servers from ~/.claude.json (user + per-project)
if [ -f "$HOME/.claude.json" ] && command -v python3 >/dev/null; then
  python3 - "$HOME/.claude.json" "$STAGE/mcp-servers.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
out = {"user": d.get("mcpServers", {}),
       "projects": {k: v["mcpServers"] for k, v in d.get("projects", {}).items() if v.get("mcpServers")}}
json.dump(out, open(sys.argv[2], "w"), indent=2)
print(f"✓ MCP servers: {len(out['user'])} user, {len(out['projects'])} project(s)")
PY
fi

echo; echo "== Possible secrets inside the archive (keep the file private) =="
grep -rIlE '(api[_-]?key|token|secret|password|bearer|sk-[A-Za-z0-9]{10,}|ghp_[A-Za-z0-9]{10,})' "$STAGE" \
  | sed "s#$STAGE/##" || echo "(none found)"

tar -czf "$OUT" -C "$STAGE" .
echo; echo "Created: $OUT"
