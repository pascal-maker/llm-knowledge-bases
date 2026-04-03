#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# KB Plugin — Obsidian Vault Setup Script
# Installs and configures required Obsidian
# community plugins for the knowledge base.
# ──────────────────────────────────────────────

# ── Usage ────────────────────────────────────
# ./setup.sh /path/to/vault                 # interactive selection
# ./setup.sh /path/to/vault --all           # install everything
# ./setup.sh /path/to/vault --only id1,id2  # install specific plugins
# ./setup.sh --list                         # show available plugins

# ── Plugin Registry ──────────────────────────
# id|repo|description|required
# required=1 means the kb workflows depend on it
# required=0 means recommended but optional
PLUGINS=(
  "dataview|blacksmithgu/obsidian-dataview|Query wiki articles like a database|1"
  "obsidian-git|Vinzent03/obsidian-git|Auto-backup vault to git|1"
  "obsidian-kanban|mgmeyers/obsidian-kanban|Kanban boards for tracking wiki tasks|0"
  "obsidian-outliner|vslinko/obsidian-outliner|Better list editing for article drafts|0"
  "tag-wrangler|pjeby/tag-wrangler|Rename and merge tags across the wiki|0"
  "obsidian-local-images-plus|Sergei-Korneev/obsidian-local-images-plus|Download and store remote images locally|0"
)

# ── Helpers ──────────────────────────────────
list_plugins() {
  echo ""
  echo "Available plugins:"
  echo ""
  local i=1
  for entry in "${PLUGINS[@]}"; do
    IFS='|' read -r id repo desc req <<< "$entry"
    if [ "$req" = "1" ]; then
      printf "  %d. [required]    %-35s %s\n" "$i" "$id" "$desc"
    else
      printf "  %d. [optional]    %-35s %s\n" "$i" "$id" "$desc"
    fi
    ((i++))
  done
  echo ""
}

download_plugin() {
  local id="$1"
  local repo="$2"
  local desc="$3"
  local dest="$PLUGINS_DIR/$id"

  if [ -d "$dest" ] && [ -f "$dest/main.js" ]; then
    echo "  ✓ $id — already installed, skipping"
    return 0
  fi

  mkdir -p "$dest"

  # Get latest version from GitHub releases
  local latest
  latest=$(curl -sL "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*: "\(.*\)".*/\1/')

  if [ -z "$latest" ]; then
    echo "  ✗ $id — could not fetch latest release, skipping"
    rm -rf "$dest"
    return 1
  fi

  local base="https://github.com/$repo/releases/download/$latest"
  local ok=true

  for file in main.js manifest.json; do
    if ! curl -sfL "$base/$file" -o "$dest/$file"; then
      echo "  ✗ $id — failed to download $file"
      ok=false
    fi
  done

  # styles.css is optional
  curl -sfL "$base/styles.css" -o "$dest/styles.css" 2>/dev/null || true

  if [ "$ok" = true ]; then
    echo "  ✓ $id ($latest) — $desc"
  else
    echo "  ✗ $id — installation failed, cleaning up"
    rm -rf "$dest"
    return 1
  fi
}

write_plugin_config() {
  local id="$1"
  local dest="$PLUGINS_DIR/$id/data.json"

  case "$id" in
    dataview)
      cat > "$dest" << 'CONF'
{
  "renderNullAs": "—",
  "warnOnEmptyResult": true,
  "enableDataviewJs": true,
  "enableInlineDataviewJs": true
}
CONF
      ;;
    obsidian-git)
      cat > "$dest" << 'CONF'
{
  "autoSaveInterval": 5,
  "autoPullOnOpen": true,
  "disablePush": false,
  "commitMessage": "vault: auto-backup {{date}}",
  "autoCommitMessage": "vault: auto-backup {{date}}"
}
CONF
      ;;
  esac
}

write_community_plugins_json() {
  local json="["
  local first=true
  for id in "${SELECTED[@]}"; do
    if [ -d "$PLUGINS_DIR/$id" ] && [ -f "$PLUGINS_DIR/$id/main.js" ]; then
      if [ "$first" = true ]; then
        first=false
      else
        json+=","
      fi
      json+="\"$id\""
    fi
  done
  json+="]"
  echo "$json" > "$OBSIDIAN_DIR/community-plugins.json"
}

write_core_plugins() {
  cat > "$OBSIDIAN_DIR/core-plugins.json" << 'CONF'
[
  "file-explorer",
  "global-search",
  "switcher",
  "graph",
  "backlink",
  "outgoing-link",
  "tag-pane",
  "page-preview",
  "note-composer",
  "command-palette",
  "editor-status",
  "bookmarks",
  "outline",
  "word-count",
  "file-recovery"
]
CONF
}

# ── Parse args ───────────────────────────────
if [ "${1:-}" = "--list" ]; then
  list_plugins
  exit 0
fi

VAULT="${1:-}"
MODE="${2:-}"       # --all or --only
ONLY_IDS="${3:-}"   # comma-separated ids for --only

if [ -z "$VAULT" ]; then
  read -rp "Enter Obsidian vault path: " VAULT
fi

VAULT="${VAULT/#\~/$HOME}"

if [ ! -d "$VAULT" ]; then
  echo "Error: directory '$VAULT' does not exist."
  exit 1
fi

OBSIDIAN_DIR="$VAULT/.obsidian"
PLUGINS_DIR="$OBSIDIAN_DIR/plugins"

mkdir -p "$PLUGINS_DIR"

# ── Build selection ──────────────────────────
SELECTED=()

if [ "$MODE" = "--all" ]; then
  for entry in "${PLUGINS[@]}"; do
    IFS='|' read -r id _ _ _ <<< "$entry"
    SELECTED+=("$id")
  done

elif [ "$MODE" = "--only" ]; then
  IFS=',' read -ra SELECTED <<< "$ONLY_IDS"

else
  # Interactive mode
  echo ""
  echo "KB Setup — Plugin Selection"
  echo "Vault: $VAULT"
  echo ""

  for entry in "${PLUGINS[@]}"; do
    IFS='|' read -r id repo desc req <<< "$entry"
    if [ "$req" = "1" ]; then
      echo "  [required] $id — $desc"
      SELECTED+=("$id")
    else
      read -rp "  [optional] $id — $desc (y/n) " answer
      if [[ "$answer" =~ ^[Yy] ]]; then
        SELECTED+=("$id")
      fi
    fi
  done

  echo ""
fi

# ── Install ──────────────────────────────────
echo ""
echo "KB Setup — Installing Obsidian plugins"
echo "Vault: $VAULT"
echo ""

echo "Installing ${#SELECTED[@]} plugin(s)..."
for entry in "${PLUGINS[@]}"; do
  IFS='|' read -r id repo desc req <<< "$entry"
  for sel in "${SELECTED[@]}"; do
    if [ "$sel" = "$id" ]; then
      download_plugin "$id" "$repo" "$desc"
      write_plugin_config "$id"
      break
    fi
  done
done

echo ""
echo "Configuring plugin registry..."
write_community_plugins_json
write_core_plugins

echo ""
echo "Done. Restart Obsidian if it's running."
echo "On first launch, click 'Trust author and enable plugins' when prompted."
echo ""
echo "── Manual step ──────────────────────────────"
echo "Install Obsidian Web Clipper for your browser:"
echo "  Chrome/Edge/Brave: https://chromewebstore.google.com/detail/obsidian-web-clipper/cnjifjpddelmedmihgijeibhnjfabmlf"
echo "  Firefox:           https://addons.mozilla.org/en-US/firefox/addon/web-clipper-obsidian/"
echo "  Safari:            Available in the App Store"
echo ""
