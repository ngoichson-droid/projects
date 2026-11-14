# Restore an archive made by claude-export.ps1 or claude-export.sh on a Windows machine.
# Usage (PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\claude-import.ps1 .\claude-backup-XXXX.tar.gz
param([Parameter(Mandatory = $true)][string]$Archive)
$ErrorActionPreference = 'Stop'

function Write-Utf8([string]$Path, [string]$Text) {
  [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding $false))
}

$Archive = (Resolve-Path $Archive).Path
$Dst = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Stage = Join-Path ([IO.Path]::GetTempPath()) ("claude-import-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $Stage -Force | Out-Null

try {
  # 1. Unpack
  if ($Archive -like '*.zip') {
    Expand-Archive -Path $Archive -DestinationPath $Stage -Force
  } else {
    & tar.exe -xzf $Archive -C $Stage
    if ($LASTEXITCODE) { throw "tar.exe failed ($LASTEXITCODE)" }
  }
  $SrcRoot = Join-Path $Stage 'claude'
  if (-not (Test-Path $SrcRoot)) { throw "Archive has no 'claude' folder: $Archive" }

  # 2. Back up current config, then merge the archive into it
  if (Test-Path $Dst) {
    $bk = "$Dst.bak-$Stamp"
    Copy-Item $Dst $bk -Recurse -Force
    Write-Host "Backup of current config: $bk"
  }
  New-Item -ItemType Directory -Path $Dst -Force | Out-Null
  & robocopy.exe $SrcRoot $Dst /E /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
  Write-Host "[OK] Restored skills, commands, agents, settings, CLAUDE.md, memory into $Dst"

  # 3. Merge MCP servers into %USERPROFILE%\.claude.json (existing entries win)
  $mcpFile = Join-Path $Stage 'mcp-servers.json'
  if (Test-Path $mcpFile) {
    Copy-Item $mcpFile (Join-Path $Dst 'mcp-servers.from-backup.json') -Force
    $cfgPath = Join-Path $env:USERPROFILE '.claude.json'
    try {
      $src = Get-Content $mcpFile -Raw -Encoding UTF8 | ConvertFrom-Json
      if (Test-Path $cfgPath) {
        Copy-Item $cfgPath "$cfgPath.bak-$Stamp" -Force
        $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
      } else {
        $cfg = New-Object PSObject
      }
      if (-not $cfg.mcpServers) {
        $cfg | Add-Member -NotePropertyName mcpServers -NotePropertyValue (New-Object PSObject) -Force
      }
      $groups = @()
      if ($src.user) { $groups += $src.user }
      if ($src.projects) { foreach ($p in $src.projects.PSObject.Properties) { $groups += $p.Value } }
      $added = 0
      foreach ($g in $groups) {
        foreach ($s in $g.PSObject.Properties) {
          if (-not $cfg.mcpServers.PSObject.Properties[$s.Name]) {
            $cfg.mcpServers | Add-Member -NotePropertyName $s.Name -NotePropertyValue $s.Value
            $added++
          }
        }
      }
      Write-Utf8 $cfgPath ($cfg | ConvertTo-Json -Depth 100)
      Write-Host "[OK] Added $added MCP server(s) to $cfgPath"
      Write-Host "     Note: on Windows, servers started with npx/node scripts may need"
      Write-Host "     'cmd /c npx ...' as the command. Check them with: claude mcp list"
    } catch {
      Write-Warning "Could not merge MCP servers: $($_.Exception.Message)"
      Write-Warning "They are saved in $(Join-Path $Dst 'mcp-servers.from-backup.json') to add by hand."
    }
  }

  # 4. Auto memory is stored per project path
  $memList = Join-Path $Stage 'memory-projects.txt'
  if (Test-Path $memList) {
    Write-Host "`nAuto memory came from these project folders:"
    Get-Content $memList | Where-Object { $_ } | ForEach-Object { Write-Host "  - $_" }
    Write-Host "If a project lives at a different path here, rename its folder under"
    Write-Host "$Dst\projects\ to the new path with every non-alphanumeric character"
    Write-Host "replaced by '-' (e.g. C:\Users\me\app -> C--Users-me-app)."
  }

  Write-Host "`nDone. Restart Claude Code. Re-login and re-enter any API keys if needed."
  Write-Host "Hooks in settings.json that call bash scripts need Git Bash or a Windows rewrite."
}
finally {
  Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
}
