#!/usr/bin/env bash
# sync_musiclib_to_westmidlands2.sh
#
# Run this ON westmidlands2 to PULL MUSIC_LIB from AfricaServer (Windows+Cygwin sshd) to local backup.
#
# Designed to "BOOM first time":
# - Uses sudo (so destination perms never block rsync)
# - Uses explicit SSH key + known_hosts from /home/royw/.ssh (so sudo/root doesn't break SSH auth)
# - Dry-run by default (safe)
# - Optional --live and optional --delete
#
# Usage:
#   ./sync_musiclib_to_westmidlands2.sh              # dry-run (default)
#   ./sync_musiclib_to_westmidlands2.sh --live       # do it for real (no deletions)
#   ./sync_musiclib_to_westmidlands2.sh --live --delete   # mirror incl. deletions (careful)
#
# Optional overrides:
#   --remote 192.168.5.55
#   --user rwillia
#   --source /cygdrive/m/MUSIC_LIB
#   --dest /mnt/sound/backups/MUSIC_LIB
#   --key /home/royw/.ssh/id_ed25519
#
# Notes:
# - Source is Cygwin path: /cygdrive/m/MUSIC_LIB
# - --delete affects ONLY the LOCAL destination (westmidlands2), never AfricaServer.

set -euo pipefail

############################
# Defaults (edit if needed)
############################
REMOTE_HOST="${REMOTE_HOST:-192.168.5.55}"
REMOTE_USER="${REMOTE_USER:-rwillia}"
REMOTE_SOURCE_DIR="${REMOTE_SOURCE_DIR:-/cygdrive/m/MUSIC_LIB}"
LOCAL_DEST_DIR="${LOCAL_DEST_DIR:-/mnt/sound/backups/MUSIC_LIB}"

# Use your *user* key + known_hosts even when running under sudo.
SSH_KEY="${SSH_KEY:-/home/royw/.ssh/id_ed25519}"
KNOWN_HOSTS="${KNOWN_HOSTS:-/home/royw/.ssh/known_hosts}"

# SSH options (safe defaults)
SSH_BASE_OPTS="${SSH_BASE_OPTS:--o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new}"

# Logging
LOG_DIR="${LOG_DIR:-/var/log/rsync_musiclib}"
VERBOSE=1

############################
# Flags
############################
DO_LIVE=0
DO_DELETE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--live] [--delete] [--quiet]
                        [--remote HOST] [--user USER]
                        [--source PATH] [--dest PATH]
                        [--key PATH] [--known-hosts PATH]

Defaults:
  --remote     $REMOTE_HOST
  --user       $REMOTE_USER
  --source     $REMOTE_SOURCE_DIR
  --dest       $LOCAL_DEST_DIR
  --key        $SSH_KEY
  --known-hosts $KNOWN_HOSTS

Examples:
  $(basename "$0")
  $(basename "$0") --live
  $(basename "$0") --live --delete
  $(basename "$0") --remote 192.168.5.55 --user rwillia
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) DO_LIVE=1; shift ;;
    --delete) DO_DELETE=1; shift ;;
    --quiet) VERBOSE=0; shift ;;
    --remote) REMOTE_HOST="$2"; shift 2 ;;
    --user) REMOTE_USER="$2"; shift 2 ;;
    --source) REMOTE_SOURCE_DIR="$2"; shift 2 ;;
    --dest) LOCAL_DEST_DIR="$2"; shift 2 ;;
    --key) SSH_KEY="$2"; shift 2 ;;
    --known-hosts) KNOWN_HOSTS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 2 ;;
  esac
done

############################
# Guardrails
############################
if [[ -z "${LOCAL_DEST_DIR// }" || "$LOCAL_DEST_DIR" == "/" ]]; then
  echo "ERROR: LOCAL_DEST_DIR looks unsafe: '$LOCAL_DEST_DIR'"
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  echo "ERROR: SSH key not found: $SSH_KEY"
  exit 1
fi

if [[ ! -f "$KNOWN_HOSTS" ]]; then
  echo "WARNING: known_hosts not found: $KNOWN_HOSTS"
  echo "         SSH will create it (StrictHostKeyChecking=accept-new)."
fi

# Ensure log dir exists (root-owned is fine)
sudo mkdir -p "$LOG_DIR"
TS="$(date +'%Y%m%d_%H%M%S')"
LOG_FILE="$LOG_DIR/rsync_musiclib_${TS}.log"

REMOTE_SPEC="${REMOTE_USER}@${REMOTE_HOST}"
SRC="${REMOTE_SOURCE_DIR%/}/"
DST="${LOCAL_DEST_DIR%/}/"

# Build ssh command for rsync. Use user's key + known_hosts even under sudo.
SSH_CMD="ssh -i $SSH_KEY -o UserKnownHostsFile=$KNOWN_HOSTS $SSH_BASE_OPTS"

############################
# rsync options
############################
RSYNC_OPTS=(
  -rt
  --modify-window=2
  --stats
  --itemize-changes
  --partial
  --partial-dir=.rsync-partial
  --safe-links
  --no-owner
  --no-group
)

# Excludes (as per your working run)
EXCLUDES=(
  --exclude "98_LEGACY_ARCHIVE/M_ROOT_OLD/EMAIL_ARCHIVE/**"
  --exclude "98_LEGACY_ARCHIVE/M_ROOT_OLD/**/Inetpub/**"
)

if [[ $DO_LIVE -eq 0 ]]; then
  RSYNC_OPTS+=(--dry-run)
fi

if [[ $DO_DELETE -eq 1 ]]; then
  RSYNC_OPTS+=(--delete --delete-delay)
fi

# Verbosity
if [[ $VERBOSE -eq 1 ]]; then
  RSYNC_OPTS+=(-vh)
fi

############################
# Pre-flight checks
############################
echo "==== sync_musiclib_to_westmidlands2 (PULL) ====" | sudo tee -a "$LOG_FILE" >/dev/null
{
  echo "Time:        $(date)"
  echo "Mode:        $([[ $DO_LIVE -eq 1 ]] && echo 'LIVE' || echo 'DRY-RUN (no changes)')"
  echo "Delete:      $([[ $DO_DELETE -eq 1 ]] && echo 'ON (mirror deletions on westmidlands2)' || echo 'OFF')"
  echo "Remote:      $REMOTE_SPEC"
  echo "Remote src:  $SRC"
  echo "Local dest:  $DST"
  echo "SSH key:     $SSH_KEY"
  echo "Known hosts: $KNOWN_HOSTS"
  echo "Log:         $LOG_FILE"
  echo
} | sudo tee -a "$LOG_FILE" >/dev/null

# Ensure destination exists
sudo mkdir -p "$DST"

# Check remote dir exists (fast failure if wrong)
echo "Checking remote source exists..." | sudo tee -a "$LOG_FILE" >/dev/null
$SSH_CMD "$REMOTE_SPEC" "test -d '$REMOTE_SOURCE_DIR'" || {
  echo "ERROR: Remote source dir not found: $REMOTE_SPEC:$REMOTE_SOURCE_DIR" | sudo tee -a "$LOG_FILE" >/dev/null
  exit 1
}

############################
# Run rsync
############################
echo "Running rsync..." | sudo tee -a "$LOG_FILE" >/dev/null
set +e
sudo rsync "${RSYNC_OPTS[@]}" "${EXCLUDES[@]}" -e "$SSH_CMD" \
  "${REMOTE_SPEC}:${SRC}" "${DST}" 2>&1 | sudo tee -a "$LOG_FILE"
RC=${PIPESTATUS[0]}
set -e

echo | sudo tee -a "$LOG_FILE" >/dev/null
echo "rsync_exit=$RC" | sudo tee -a "$LOG_FILE" >/dev/null

# Print exit code to console as well
echo "rsync_exit=$RC"

if [[ $RC -ne 0 ]]; then
  echo "NOTE: rsync returned non-zero. See log: $LOG_FILE"
  exit $RC
fi

echo "Done."

