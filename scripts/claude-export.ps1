# Pack Claude Code workflows + memory from this Windows machine into one archive.
# Usage (PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\claude-export.ps1 [-OutDir <folder>]
# Output: claude-backup-YYYYMMDD-HHmm.tar.gz (or .zip if tar.exe is missing)
param([string]$OutDir = (Get-Location).Path)
$ErrorActionPreference = 'Stop'

function Write-Utf8([string]$Path, [string]$Text) {
  [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding $false))
}

$Src = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
if (-not (Test-Path $Src)) { throw "Not found: $Src" }
$Stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$Stage = Join-Path ([IO.Path]::GetTempPath()) ("claude-export-" + [guid]::NewGuid())
$Root  = Join-Path $Stage 'claude'
New-Item -ItemType Directory -Path $Root -Force | Out-Null

try {
  # 1. Workflows, settings, memory. Skip sessions, transcripts, caches, credentials.
  $items = 'CLAUDE.md','settings.json','keybindings.json','skills','commands','agents',
           'output-styles','hooks','plugins\installed_plugins.json','plugins\known_marketplaces.json'
  foreach ($p in $items) {
    $from = Join-Path $Src $p
    if (Test-Path $from) {
      $to = Join-Path $Root $p
      New-Item -ItemType Directory -Path (Split-Path $to) -Force | Out-Null
      Copy-Item $from $to -Recurse -Force
      Write-Host "[OK] $p"
    }
  }

  # 2. Auto memory: projects\<project>\memory
  $memProjects = @()
  $projDir = Join-Path $Src 'projects'
  if (Test-Path $projDir) {
    foreach ($d in Get-ChildItem $projDir -Directory) {
      $mem = Join-Path $d.FullName 'memory'
      if (Test-Path $mem) {
        $to = Join-Path $Root "projects\$($d.Name)\memory"
        New-Item -ItemType Directory -Path (Split-Path $to) -Force | Out-Null
        Copy-Item $mem $to -Recurse -Force
        $memProjects += $d.Name
        Write-Host "[OK] projects\$($d.Name)\memory"
      }
    }
  }
  if ($memProjects.Count) { Write-Utf8 (Join-Path $Stage 'memory-projects.txt') (($memProjects -join "`n") + "`n") }

  # 3. MCP servers from %USERPROFILE%\.claude.json (user + per-project)
  $cfgPath = Join-Path $env:USERPROFILE '.claude.json'
  if (Test-Path $cfgPath) {
    try {
      $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $user = if ($cfg.mcpServers) { $cfg.mcpServers } else { New-Object PSObject }
      $projects = New-Object PSObject
      if ($cfg.projects) {
        foreach ($prop in $cfg.projects.PSObject.Properties) {
          $s = $prop.Value.mcpServers
          if ($s -and @($s.PSObject.Properties).Count -gt 0) {
            $projects | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $s
          }
        }
      }
      $out = New-Object PSObject -Property @{ user = $user; projects = $projects }
      Write-Utf8 (Join-Path $Stage 'mcp-servers.json') ($out | ConvertTo-Json -Depth 100)
      Write-Host ("[OK] MCP servers: {0} user, {1} project(s)" -f @($user.PSObject.Properties).Count, @($projects.PSObject.Properties).Count)
    } catch {
      Write-Warning "Could not read MCP servers from $cfgPath : $($_.Exception.Message)"
    }
  }

  # 4. Secret scan
  Write-Host "`n== Possible secrets inside the archive (keep the file private) =="
  $pattern = '(api[_-]?key|token|secret|password|bearer|sk-[A-Za-z0-9]{10,}|ghp_[A-Za-z0-9]{10,})'
  $hits = Get-ChildItem $Stage -Recurse -File | Where-Object { Select-String -Path $_.FullName -Pattern $pattern -Quiet }
  if ($hits) { $hits | ForEach-Object { Write-Host ("  " + $_.FullName.Substring($Stage.Length + 1)) } }
  else { Write-Host "(none found)" }

  # 5. Archive: tar.gz (same format as the bash scripts) or zip as fallback
  if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
    $Out = Join-Path $OutDir "claude-backup-$Stamp.tar.gz"
    & tar.exe -czf $Out -C $Stage .
    if ($LASTEXITCODE) { throw "tar.exe failed ($LASTEXITCODE)" }
  } else {
    $Out = Join-Path $OutDir "claude-backup-$Stamp.zip"
    Compress-Archive -Path (Join-Path $Stage '*') -DestinationPath $Out -Force
  }
  Write-Host "`nCreated: $Out"
}
finally {
  Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
}
