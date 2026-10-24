#!/usr/bin/env bash
#
# ck-setup.sh — Standalone ClaudeKit Engineer installer
# Replicates `ck init -y` without requiring GitHub CLI auth.
# Works from the bundled zip file.
#
# Usage:
#   ./ck-setup.sh                          # Install to current directory
#   ./ck-setup.sh /path/to/project         # Install to specific directory
#   ./ck-setup.sh --global                 # Install to ~/.claude (global)
#
set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZIP_FILE="$SCRIPT_DIR/claudekit-engineer-v2.16.0.zip"
KIT_VERSION="v2.16.0"
KIT_NAME="engineer"
KIT_DISPLAY="ClaudeKit Engineer"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}i${NC} $1"; }
log_ok()    { echo -e "${GREEN}+${NC} $1"; }
log_warn()  { echo -e "${YELLOW}!${NC} $1"; }
log_err()   { echo -e "${RED}x${NC} $1"; }
log_step()  { echo -e "\n${CYAN}|${NC} ${CYAN}$1${NC}"; }

# ─── Parse args ───────────────────────────────────────────────────────
GLOBAL_MODE=false
TARGET_DIR="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global|-g) GLOBAL_MODE=true; shift ;;
    --help|-h)
      echo "Usage: $0 [--global] [target-directory]"
      echo ""
      echo "  --global, -g    Install to ~/.claude (global scope)"
      echo "  target-dir      Project directory (default: current dir)"
      exit 0
      ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done

if $GLOBAL_MODE; then
  TARGET_DIR="$HOME"
fi

TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
  log_err "Target directory does not exist: $TARGET_DIR"
  exit 1
}

# ─── Preflight ────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}> ClaudeKit Engineer Setup (Offline)${NC}"
echo ""

if [[ ! -f "$ZIP_FILE" ]]; then
  log_err "Zip file not found: $ZIP_FILE"
  log_info "Place claudekit-engineer-v2.16.0.zip in the same directory as this script."
  exit 1
fi

log_info "Kit: $KIT_DISPLAY $KIT_VERSION"
log_info "Target: $TARGET_DIR"
if $GLOBAL_MODE; then
  log_info "Scope: global (~/.claude)"
else
  log_info "Scope: local (project)"
fi

# ─── Check dependencies ──────────────────────────────────────────────
if ! command -v unzip &>/dev/null; then
  log_err "unzip is required but not installed."
  exit 1
fi
if ! command -v node &>/dev/null; then
  log_warn "Node.js not found. Hooks will not work without Node.js >= 18."
fi

# ─── Extract ──────────────────────────────────────────────────────────
log_step "Extracting"

TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

unzip -q -o "$ZIP_FILE" -d "$TEMP_DIR" \
  -x "*.DS_Store" "Thumbs.db" "*.log" "__MACOSX/*"

# Check if zip has a single wrapper directory
ENTRIES=("$TEMP_DIR"/*)
if [[ ${#ENTRIES[@]} -eq 1 && -d "${ENTRIES[0]}" ]]; then
  # Single wrapper dir — check if it contains .claude
  WRAPPER="${ENTRIES[0]}"
  if [[ -d "$WRAPPER/.claude" ]]; then
    log_info "Detected wrapper directory, stripping..."
    EXTRACT_ROOT="$WRAPPER"
  else
    EXTRACT_ROOT="$TEMP_DIR"
  fi
else
  EXTRACT_ROOT="$TEMP_DIR"
fi

log_ok "Extracted $(find "$EXTRACT_ROOT" -type f | wc -l | tr -d ' ') files"

# ─── Protected files ─────────────────────────────────────────────────
# These files will NOT be overwritten if they already exist
PROTECTED_FILES=(
  ".claude/.env"
  ".claude/.mcp.json"
  ".claude/settings.json"
)

# ─── Copy files ───────────────────────────────────────────────────────
log_step "Installing"

COPIED=0
SKIPPED=0
PROTECTED=0

copy_files() {
  local src_root="$1"
  local dst_root="$2"

  while IFS= read -r -d '' src_file; do
    local rel_path="${src_file#$src_root/}"
    local dst_file="$dst_root/$rel_path"
    local dst_dir="$(dirname "$dst_file")"

    # Check protected
    local is_protected=false
    for pf in "${PROTECTED_FILES[@]}"; do
      if [[ "$rel_path" == "$pf" && -f "$dst_file" ]]; then
        is_protected=true
        break
      fi
    done

    if $is_protected; then
      ((PROTECTED++)) || true
      continue
    fi

    # Create directory and copy
    mkdir -p "$dst_dir"
    cp -f "$src_file" "$dst_file"
    ((COPIED++)) || true

  done < <(find "$src_root" -type f -print0)
}

copy_files "$EXTRACT_ROOT" "$TARGET_DIR"

log_ok "Installed $COPIED file(s)"
if [[ $PROTECTED -gt 0 ]]; then
  log_warn "Skipped $PROTECTED protected file(s) (already exist)"
fi

# ─── Inject team hooks into settings.json ─────────────────────────────
log_step "Configuring hooks"

SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
  # Settings already exists (from zip or pre-existing) — check for team hooks
  if command -v node &>/dev/null; then
    node -e "
const fs = require('fs');
const path = '$SETTINGS_FILE';
const settings = JSON.parse(fs.readFileSync(path, 'utf8'));

if (!settings.hooks) settings.hooks = {};

const teamHooks = {
  TaskCompleted: {
    hooks: [{
      type: 'command',
      command: 'node \"\$CLAUDE_PROJECT_DIR/.claude/hooks/task-completed-handler.cjs\"'
    }]
  },
  TeammateIdle: {
    hooks: [{
      type: 'command',
      command: 'node \"\$CLAUDE_PROJECT_DIR/.claude/hooks/teammate-idle-handler.cjs\"'
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
    // Check if already has this specific hook
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

fs.writeFileSync(path, JSON.stringify(settings, null, 2) + '\n');
if (injected > 0) console.log('+ Team hooks injected successfully');
else console.log('i Team hooks already configured');
" 2>&1 | while IFS= read -r line; do echo -e "${GREEN}${line}${NC}"; done
  else
    log_warn "Node.js not available — skipping hook injection"
  fi
else
  log_warn "settings.json not found — skipping hook injection"
fi

# ─── Write metadata.json ─────────────────────────────────────────────
log_step "Writing metadata"

METADATA_FILE="$TARGET_DIR/.claude/metadata.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

if command -v node &>/dev/null; then
  node -e "
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const targetDir = '$TARGET_DIR';
const claudeDir = path.join(targetDir, '.claude');
const metaPath = '$METADATA_FILE';
const version = '$KIT_VERSION';
const now = '$NOW';

// Build file list with checksums
const files = [];
function walkDir(dir, base) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relPath = path.relative(base, fullPath);
    if (entry.isDirectory()) {
      if (entry.name === '.git' || entry.name === 'node_modules') continue;
      walkDir(fullPath, base);
    } else {
      const content = fs.readFileSync(fullPath);
      const checksum = crypto.createHash('sha256').update(content).digest('hex');
      files.push({
        path: relPath,
        checksum,
        ownership: 'user',
        installedVersion: version,
        installedAt: now
      });
    }
  }
}
walkDir(claudeDir, claudeDir);

// Build or merge metadata
let metadata = {};
if (fs.existsSync(metaPath)) {
  try { metadata = JSON.parse(fs.readFileSync(metaPath, 'utf8')); } catch {}
}

if (!metadata.kits) metadata.kits = {};
metadata.kits['$KIT_NAME'] = {
  version,
  installedAt: now,
  files
};

fs.writeFileSync(metaPath, JSON.stringify(metadata, null, 2) + '\n');
console.log('Tracked ' + files.length + ' files in metadata.json');
"
  log_ok "Metadata written"
else
  log_warn "Node.js not available — skipping metadata generation"
fi

# ─── Make hook scripts executable ─────────────────────────────────────
HOOKS_DIR="$TARGET_DIR/.claude/hooks"
if [[ -d "$HOOKS_DIR" ]]; then
  chmod +x "$HOOKS_DIR"/*.cjs 2>/dev/null || true
fi

# ─── Install Python venv for skills (optional) ───────────────────────
SKILLS_DIR="$TARGET_DIR/.claude/skills"
INSTALL_SCRIPT="$SKILLS_DIR/install.sh"

if [[ -f "$INSTALL_SCRIPT" ]]; then
  log_step "Skills dependencies"
  log_info "Run the following to install skill dependencies:"
  echo "  cd $SKILLS_DIR && bash install.sh"
  echo ""
fi

# ─── Summary ──────────────────────────────────────────────────────────
echo ""
log_ok "Project initialized successfully at $TARGET_DIR"
echo ""
echo -e "  ${GREEN}Initialization complete:${NC}"
echo ""
echo "  Your project has been initialized with $KIT_DISPLAY $KIT_VERSION."
echo "  Protected files (.env, etc.) were not modified."
echo ""

# Post-install hints
if [[ ! -f "$TARGET_DIR/.claude/.env" && -f "$TARGET_DIR/.claude/.env.example" ]]; then
  log_info "Next: cp .claude/.env.example .claude/.env  (then add your API keys)"
fi
if [[ ! -f "$TARGET_DIR/.claude/.mcp.json" && -f "$TARGET_DIR/.claude/.mcp.json.example" ]]; then
  log_info "Next: cp .claude/.mcp.json.example .claude/.mcp.json"
fi
