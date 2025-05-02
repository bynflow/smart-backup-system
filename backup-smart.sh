#!/usr/bin/env bash
set -euo pipefail

# ========================================
# backup-smart.sh
#  – smart incremental backup + versioning
#    (modified & deleted) with auto-cleanup
# ========================================

# --- Prerequisites check (point 1) ---
for cmd in rclone date grep; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: '$cmd' not found. Please install it before running this script." >&2
    exit 1
  }
done

# --- Configuration example ---
declare -A SOURCES=(
  [projects]="/path/to/projects" # e.g
  [keepass]="/path/to/keepass" # e.g
  [notes]="/path/to/notes" # e.g
)
REMOTE="remote:backup"
HISTORY_BASE="history"
WORKING="working"
MODIFIED="modified"
DELETED="deleted"
RETENTION_DAYS=90  # e.g. 90

LOG_DIR="$HOME/.local/logs"
LOG_FILE="$LOG_DIR/backup-smart.log"
DATE="$(date +%F)"

# Optional excludes for user — uncomment & edit if needed. E.g.:
# EXCLUDES=(
#   "--exclude=.venv/**"
#   "--exclude=node_modules/**"
#   "--exclude=*.pyc"
# )

mkdir -p "$LOG_DIR"

# --- Logging function ---
log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" >> "$LOG_FILE"
}

# --- Log rotation ---
LOG_ROTATION_DAYS=7      # rotate logs older than 7 days
ROTATED_RETENTION_DAYS=30  # remove rotated .old files older than 30 days

if [ -f "$LOG_FILE" ] && find "$LOG_FILE" -mtime +"$LOG_ROTATION_DAYS" -print -quit | grep -q .; then
  mv "$LOG_FILE" "$LOG_FILE.$(date +%F).old"
  touch "$LOG_FILE"
  log "Rotated log older than $LOG_ROTATION_DAYS days"
fi

find "$LOG_DIR" -type f -name 'backup-smart.log.*.old' -mtime +"$ROTATED_RETENTION_DAYS" -delete

log "=== STARTING backup-smart ($DATE) ==="

# --- 1) Sync each source, backing up overwritten/deleted into working folder ---
for NAME in "${!SOURCES[@]}"; do
  SRC="${SOURCES[$NAME]}"
  log "Syncing source '$NAME'"
  rclone sync \
    "$SRC" \
    "$REMOTE/$NAME" \
    --backup-dir="$REMOTE/$HISTORY_BASE/$WORKING/$DATE/$NAME" \
    "${EXCLUDES[@]:-}" \
    --log-file="$LOG_FILE" \
    --log-level INFO
done

# --- 2) Process working backups, split into modified vs deleted ---
log "Processing working backups for date $DATE..."
for NAME in "${!SOURCES[@]}"; do
  SRC="${SOURCES[$NAME]}"
  BACKUP_SUBDIR="$REMOTE/$HISTORY_BASE/$WORKING/$DATE/$NAME"

  mapfile -t FILES < <(rclone lsf "$BACKUP_SUBDIR" --recursive | grep -v '/$' || true)
  [[ ${#FILES[@]} -eq 0 ]] && continue

  for FILE in "${FILES[@]}"; do
    local_path="$SRC/$FILE"
    if [[ -e "$local_path" ]]; then
      TYPE="$MODIFIED"
    else
      TYPE="$DELETED"
    fi

    target_dir="$REMOTE/$HISTORY_BASE/$TYPE/$DATE/$NAME/$(dirname "$FILE")"
    target_path="$REMOTE/$HISTORY_BASE/$TYPE/$DATE/$NAME/$FILE"

    rclone mkdir "$target_dir" --log-file="$LOG_FILE" --log-level INFO
    rclone moveto \
      "$BACKUP_SUBDIR/$FILE" \
      "$target_path" \
      --log-file="$LOG_FILE" \
      --log-level INFO

    log "  → [$TYPE] $NAME/$FILE"
  done
done

# --- 3) Cleanup temporary working folder ---
rclone purge "$REMOTE/$HISTORY_BASE/$WORKING/$DATE" \
  --log-file="$LOG_FILE" \
  --log-level INFO
log "Removed working folder for $DATE"

# --- 4) Purge history older than retention ---
log "Cleaning up history older than $RETENTION_DAYS days..."
cutoff="$(date -d "$RETENTION_DAYS days ago" +%F)"
for TYPE in "$MODIFIED" "$DELETED"; do
  BASEDIR="$REMOTE/$HISTORY_BASE/$TYPE"
  mapfile -t DIRS < <(rclone lsf "$BASEDIR" --dirs-only | sed 's:/$::' || true)
  for D in "${DIRS[@]}"; do
    if [[ "$D" < "$cutoff" ]]; then
      log "  → purging $TYPE/$D"
      rclone purge "$BASEDIR/$D" --log-file="$LOG_FILE" --log-level INFO
    fi
  done
done

log "=== backup-smart completed ==="


