#
# ck-setup.ps1 — Standalone ClaudeKit Engineer installer for Windows
# Replicates `ck init -y` without requiring GitHub CLI auth.
# Works from the bundled zip file.
#
# Usage:
#   .\ck-setup.ps1                            # Install to current directory
#   .\ck-setup.ps1 -TargetDir C:\my\project   # Install to specific directory
#   .\ck-setup.ps1 -Global                    # Install to ~\.claude (global)
#
# Note: Run in PowerShell 5.1+ or PowerShell Core 7+
#

param(
    [string]$TargetDir = ".",
    [switch]$Global,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ─── Config ───────────────────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ZipFile = Join-Path $ScriptDir "claudekit-engineer-v2.16.0.zip"
$KitVersion = "v2.16.0"
$KitName = "engineer"
$KitDisplay = "ClaudeKit Engineer"

# ─── Helpers ──────────────────────────────────────────────────────────
function Log-Info  { param([string]$Msg) Write-Host "i " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Log-Ok    { param([string]$Msg) Write-Host "+ " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Log-Warn  { param([string]$Msg) Write-Host "! " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Log-Err   { param([string]$Msg) Write-Host "x " -ForegroundColor Red -NoNewline; Write-Host $Msg }
function Log-Step  { param([string]$Msg) Write-Host ""; Write-Host "| $Msg" -ForegroundColor Cyan }

# ─── Help ─────────────────────────────────────────────────────────────
if ($Help) {
    Write-Host "Usage: .\ck-setup.ps1 [-TargetDir <path>] [-Global] [-Help]"
    Write-Host ""
    Write-Host "  -TargetDir    Project directory (default: current dir)"
    Write-Host "  -Global       Install to ~\.claude (global scope)"
    Write-Host "  -Help         Show this help"
    exit 0
}

# ─── Parse args ───────────────────────────────────────────────────────
if ($Global) {
    $TargetDir = $env:USERPROFILE
}

$TargetDir = (Resolve-Path -Path $TargetDir -ErrorAction SilentlyContinue).Path
if (-not $TargetDir) {
    Log-Err "Target directory does not exist."
    exit 1
}

# ─── Preflight ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "> ClaudeKit Engineer Setup (Offline)" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ZipFile)) {
    Log-Err "Zip file not found: $ZipFile"
    Log-Info "Place claudekit-engineer-v2.16.0.zip in the same directory as this script."
    exit 1
}

Log-Info "Kit: $KitDisplay $KitVersion"
Log-Info "Target: $TargetDir"
if ($Global) {
    Log-Info "Scope: global (~\.claude)"
} else {
    Log-Info "Scope: local (project)"
}

# Check Node.js
$NodeAvailable = $false
try {
    $null = Get-Command node -ErrorAction Stop
    $NodeAvailable = $true
} catch {
    Log-Warn "Node.js not found. Hooks will not work without Node.js >= 18."
}

# ─── Extract ──────────────────────────────────────────────────────────
Log-Step "Extracting"

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ck-setup-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $TempDir)
} catch {
    # Fallback: Expand-Archive (PowerShell 5+)
    try {
        Expand-Archive -Path $ZipFile -DestinationPath $TempDir -Force
    } catch {
        Log-Err "Failed to extract zip: $_"
        exit 1
    }
}

# Check for wrapper directory
$TopItems = Get-ChildItem -Path $TempDir
$ExtractRoot = $TempDir
if ($TopItems.Count -eq 1 -and $TopItems[0].PSIsContainer) {
    $WrapperClaude = Join-Path $TopItems[0].FullName ".claude"
    if (Test-Path $WrapperClaude) {
        Log-Info "Detected wrapper directory, stripping..."
        $ExtractRoot = $TopItems[0].FullName
    }
}

$FileCount = (Get-ChildItem -Path $ExtractRoot -Recurse -File).Count
Log-Ok "Extracted $FileCount files"

# ─── Protected files ─────────────────────────────────────────────────
$ProtectedFiles = @(
    ".claude\.env",
    ".claude\.mcp.json",
    ".claude\settings.json"
)

# ─── Copy files ───────────────────────────────────────────────────────
Log-Step "Installing"

$Copied = 0
$Protected = 0

$AllFiles = Get-ChildItem -Path $ExtractRoot -Recurse -File
foreach ($SrcFile in $AllFiles) {
    $RelPath = $SrcFile.FullName.Substring($ExtractRoot.Length + 1)

    # Skip junk files
    if ($SrcFile.Name -eq ".DS_Store" -or $SrcFile.Name -eq "Thumbs.db") { continue }

    $DstFile = Join-Path $TargetDir $RelPath

    # Check protected
    $IsProtected = $false
    foreach ($pf in $ProtectedFiles) {
        if ($RelPath -eq $pf -and (Test-Path $DstFile)) {
            $IsProtected = $true
            break
        }
    }

    if ($IsProtected) {
        $Protected++
        continue
    }

    # Create directory and copy
    $DstDir = Split-Path -Parent $DstFile
    if (-not (Test-Path $DstDir)) {
        New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
    }
    Copy-Item -Path $SrcFile.FullName -Destination $DstFile -Force
    $Copied++
}

Log-Ok "Installed $Copied file(s)"
if ($Protected -gt 0) {
    Log-Warn "Skipped $Protected protected file(s) (already exist)"
}

# ─── Inject team hooks into settings.json ─────────────────────────────
Log-Step "Configuring hooks"

$SettingsFile = Join-Path $TargetDir ".claude\settings.json"

if ((Test-Path $SettingsFile) -and $NodeAvailable) {
    # Use Node.js for reliable JSON manipulation
    $NodeScript = @'
const fs = require('fs');
const settingsPath = process.argv[1];
const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));

if (!settings.hooks) settings.hooks = {};

const teamHooks = {
  TaskCompleted: {
    hooks: [{
      type: 'command',
      command: 'node "$CLAUDE_PROJECT_DIR/.claude/hooks/task-completed-handler.cjs"'
    }]
  },
  TeammateIdle: {
    hooks: [{
      type: 'command',
      command: 'node "$CLAUDE_PROJECT_DIR/.claude/hooks/teammate-idle-handler.cjs"'
    }]
  }
};

let injected = 0;
for (const [event, config] of Object.entries(teamHooks)) {
  if (!settings.hooks[event]) {
    settings.hooks[event] = [config];
    injected++;
    console.log('  Injected ' + event + ' hook');
  } else {
    const existing = JSON.stringify(settings.hooks[event]);
    if (!existing.includes(config.hooks[0].command)) {
      settings.hooks[event].push(config);
      injected++;
      console.log('  Injected ' + event + ' hook');
    } else {
      console.log('  ' + event + ' hook already present');
    }
  }
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
if (injected > 0) console.log('+ Team hooks injected successfully');
else console.log('i Team hooks already configured');
'@

    $TempScript = Join-Path ([System.IO.Path]::GetTempPath()) "ck-hooks-inject.cjs"
    Set-Content -Path $TempScript -Value $NodeScript -Encoding UTF8
    node $TempScript $SettingsFile
    Remove-Item $TempScript -Force -ErrorAction SilentlyContinue
}
elseif (-not (Test-Path $SettingsFile)) {
    Log-Warn "settings.json not found - skipping hook injection"
}
elseif (-not $NodeAvailable) {
    Log-Warn "Node.js not available - skipping hook injection"
}

# ─── Write metadata.json ─────────────────────────────────────────────
Log-Step "Writing metadata"

$MetadataFile = Join-Path $TargetDir ".claude\metadata.json"

if ($NodeAvailable) {
    $MetaScript = @"
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const targetDir = process.argv[1];
const metaPath = process.argv[2];
const version = process.argv[3];
const now = new Date().toISOString();

const claudeDir = path.join(targetDir, '.claude');
const files = [];

function walkDir(dir, base) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relPath = path.relative(base, fullPath).replace(/\\\\/g, '/');
    if (entry.isDirectory()) {
      if (entry.name === '.git' || entry.name === 'node_modules') continue;
      walkDir(fullPath, base);
    } else {
      const content = fs.readFileSync(fullPath);
      const checksum = crypto.createHash('sha256').update(content).digest('hex');
      files.push({ path: relPath, checksum, ownership: 'user', installedVersion: version, installedAt: now });
    }
  }
}
walkDir(claudeDir, claudeDir);

let metadata = {};
if (fs.existsSync(metaPath)) {
  try { metadata = JSON.parse(fs.readFileSync(metaPath, 'utf8')); } catch {}
}
if (!metadata.kits) metadata.kits = {};
metadata.kits['engineer'] = { version, installedAt: now, files };

fs.writeFileSync(metaPath, JSON.stringify(metadata, null, 2) + '\n');
console.log('Tracked ' + files.length + ' files in metadata.json');
"@

    $TempMeta = Join-Path ([System.IO.Path]::GetTempPath()) "ck-meta-gen.cjs"
    Set-Content -Path $TempMeta -Value $MetaScript -Encoding UTF8
    node $TempMeta $TargetDir $MetadataFile $KitVersion
    Remove-Item $TempMeta -Force -ErrorAction SilentlyContinue
    Log-Ok "Metadata written"
}
else {
    Log-Warn "Node.js not available - skipping metadata generation"
}

# ─── Skills dependencies hint ────────────────────────────────────────
$SkillsInstall = Join-Path $TargetDir ".claude\skills\install.sh"
if (Test-Path $SkillsInstall) {
    Log-Step "Skills dependencies"
    Log-Info "To install skill dependencies (requires bash/WSL):"
    Write-Host "  cd $TargetDir\.claude\skills && bash install.sh"
    Write-Host ""
}

# ─── Cleanup temp ────────────────────────────────────────────────────
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

# ─── Summary ──────────────────────────────────────────────────────────
Write-Host ""
Log-Ok "Project initialized successfully at $TargetDir"
Write-Host ""
Write-Host "  Initialization complete:" -ForegroundColor Green
Write-Host ""
Write-Host "  Your project has been initialized with $KitDisplay $KitVersion."
Write-Host "  Protected files (.env, etc.) were not modified."
Write-Host ""

# Post-install hints
$EnvFile = Join-Path $TargetDir ".claude\.env"
$EnvExample = Join-Path $TargetDir ".claude\.env.example"
if (-not (Test-Path $EnvFile) -and (Test-Path $EnvExample)) {
    Log-Info "Next: copy .claude\.env.example .claude\.env  (then add your API keys)"
}

$McpFile = Join-Path $TargetDir ".claude\.mcp.json"
$McpExample = Join-Path $TargetDir ".claude\.mcp.json.example"
if (-not (Test-Path $McpFile) -and (Test-Path $McpExample)) {
    Log-Info "Next: copy .claude\.mcp.json.example .claude\.mcp.json"
}
