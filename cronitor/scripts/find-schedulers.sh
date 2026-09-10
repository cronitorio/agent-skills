#!/bin/sh
# Inventory scheduled work on this host and in the current directory tree.
#
# Read-only and best-effort: it never modifies anything, skips what it cannot
# read, and always exits 0. Output is plain text grouped by source so an agent
# can match each scheduler entry against Cronitor monitors.

ROOT=${1:-.}
PRUNE='-name .git -o -name node_modules -o -name vendor -o -name .venv -o -name venv -o -name __pycache__ -o -name dist -o -name build'

section() {
  echo ""
  echo "== $1"
}

# Portable recursive file finder that prunes bulky directories.
find_files() {
  # $1: -name pattern (may contain shell wildcards, quoted by caller)
  find "$ROOT" \( $PRUNE \) -prune -o -type f -name "$1" -print0 2>/dev/null
}

# Same, one path per line, for plain listings.
list_files() {
  find_files "$1" | tr '\0' '\n'
}

echo "Scheduled work inventory (root: $ROOT, host: $(hostname 2>/dev/null || echo unknown))"

# 1. User crontab
section "crontab -l (current user)"
if command -v crontab >/dev/null 2>&1; then
  entries=$(crontab -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$')
  if [ -n "$entries" ]; then
    echo "$entries"
  else
    echo "(no entries or crontab not readable)"
  fi
else
  echo "(crontab command not available)"
fi

# 2. System cron
section "/etc/crontab and /etc/cron.d"
found=0
if [ -r /etc/crontab ]; then
  found=1
  echo "-- /etc/crontab"
  grep -v '^[[:space:]]*#' /etc/crontab 2>/dev/null | grep -v '^[[:space:]]*$'
fi
if [ -d /etc/cron.d ]; then
  for f in /etc/cron.d/*; do
    [ -r "$f" ] || continue
    found=1
    echo "-- $f"
    grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -v '^[[:space:]]*$'
  done
fi
for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
  if [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
    found=1
    echo "-- $d: $(ls -A "$d" 2>/dev/null | tr '\n' ' ')"
  fi
done
[ "$found" -eq 0 ] && echo "(none readable)"

# 3. Kubernetes CronJob manifests
section "Kubernetes CronJob manifests"
k8s=$( { find_files '*.yaml'; find_files '*.yml'; } | xargs -0 grep -I -l 'kind: *CronJob' 2>/dev/null)
if [ -n "$k8s" ]; then
  echo "$k8s" | while IFS= read -r f; do
    names=$(grep -E '^\s*name:' "$f" 2>/dev/null | head -n 1 | sed 's/^[[:space:]]*//')
    schedules=$(grep -E '^\s*schedule:' "$f" 2>/dev/null | sed 's/^[[:space:]]*//' | tr '\n' ';')
    echo "$f  $names  $schedules"
  done
else
  echo "(none found)"
fi

# 4. GitHub Actions workflows with a schedule trigger
section "GitHub Actions workflows with schedule:"
gha=""
for dir in "$ROOT/.github/workflows"; do
  [ -d "$dir" ] || continue
  gha=$(grep -l -E '^\s*schedule:' "$dir"/*.yml "$dir"/*.yaml 2>/dev/null)
done
if [ -n "$gha" ]; then
  echo "$gha" | while IFS= read -r f; do
    crons=$(grep -E 'cron:' "$f" 2>/dev/null | sed 's/^[[:space:]]*-*[[:space:]]*//' | tr '\n' ';')
    echo "$f  $crons"
  done
else
  echo "(none found)"
fi

# 5. Celery beat schedules
section "Celery beat (beat_schedule / CELERYBEAT_SCHEDULE / crontab())"
celery=$(find_files '*.py' | xargs -0 grep -I -l -E 'beat_schedule|CELERYBEAT_SCHEDULE|celery\.schedules' 2>/dev/null)
if [ -n "$celery" ]; then echo "$celery"; else echo "(none found)"; fi

# 6. Sidekiq-cron / sidekiq-scheduler and whenever (Ruby)
section "Sidekiq-cron, sidekiq-scheduler, and whenever (Ruby)"
ruby=$( {
  list_files 'sidekiq.yml'; list_files 'sidekiq_cron.yml'; list_files 'sidekiq_scheduler.yml'; list_files 'schedule.yml'; list_files 'schedule.rb'
} | sort -u)
ruby_code=$(find_files '*.rb' | xargs -0 grep -I -l -E 'Sidekiq::Cron|Sidekiq-Cron|sidekiq-scheduler' 2>/dev/null)
if [ -n "$ruby$ruby_code" ]; then
  [ -n "$ruby" ] && echo "$ruby"
  [ -n "$ruby_code" ] && echo "$ruby_code"
else
  echo "(none found)"
fi

# 7. systemd timers (repo and host)
section "systemd timer units"
timers=$(list_files '*.timer')
if [ -d /etc/systemd/system ]; then
  host_timers=$(ls /etc/systemd/system/*.timer 2>/dev/null)
  timers="$timers
$host_timers"
fi
if command -v systemctl >/dev/null 2>&1; then
  active=$(systemctl list-timers --all --no-pager --no-legend 2>/dev/null | awk '{print $NF" ("$(NF-1)")"}' | sort -u)
  [ -n "$active" ] && timers="$timers
-- systemctl list-timers:
$active"
fi
timers=$(echo "$timers" | grep -v '^$')
if [ -n "$timers" ]; then echo "$timers"; else echo "(none found)"; fi

# 8. Other common scheduler definitions by filename or content
section "Other scheduler hints"
other=$( {
  list_files 'crontab'; list_files '*.cron'; list_files 'Procfile'
  find_files '*.py' | xargs -0 grep -I -l -E 'APScheduler|BackgroundScheduler|schedule\.every\(' 2>/dev/null
  find_files '*.js' | xargs -0 grep -I -l -E 'node-cron|cron\.schedule\(|new CronJob\(' 2>/dev/null
  find_files '*.ts' | xargs -0 grep -I -l -E 'node-cron|cron\.schedule\(|@Cron\(' 2>/dev/null
  find_files '*.php' | xargs -0 grep -I -l -E '->cron\(|->daily\(|->hourly\(|->everyMinute\(' 2>/dev/null
} | sort -u)
if [ -n "$other" ]; then echo "$other"; else echo "(none found)"; fi

# 9. Existing Cronitor integration points
section "Existing Cronitor references"
cron_refs=$( {
  find_files '*' | xargs -0 grep -I -l -E 'cronitor exec|cronitor ping|cronitor\.link|CRONITOR_API_KEY|CRONITOR_PING_API_KEY|import cronitor|require\(.cronitor|cronitorio/' 2>/dev/null
} | sort -u | head -n 50)
if [ -n "$cron_refs" ]; then echo "$cron_refs"; else echo "(none found)"; fi

echo ""
echo "Done. Match each entry above against Cronitor with search_monitors or 'cronitor monitor list'."
exit 0
