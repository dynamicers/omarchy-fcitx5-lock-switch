#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
monitor_pid=
cleanup() {
  [[ -z $monitor_pid ]] || kill "$monitor_pid" 2>/dev/null || true
  exec 3>&- 2>/dev/null || true
  rm -rf "$test_dir"
}
trap cleanup EXIT

mkdir -p "$test_dir/bin"
export RIME_LOCK_TEST_DIR="$test_dir"
export PATH="$test_dir/bin:$PATH"

cat >"$test_dir/bin/omarchy-shell" <<'EOF'
#!/usr/bin/env bash
cat "$RIME_LOCK_TEST_DIR/locked"
echo checked >>"$RIME_LOCK_TEST_DIR/checks"
EOF

cat >"$test_dir/bin/journalctl" <<'EOF'
#!/usr/bin/env bash
cat "$RIME_LOCK_TEST_DIR/events"
EOF

cat >"$test_dir/bin/fcitx5-remote" <<'EOF'
#!/usr/bin/env bash
context=$(cat "$RIME_LOCK_TEST_DIR/context")
state_file="$RIME_LOCK_TEST_DIR/state_$context"
case "${1-}" in
  -n) cat "$RIME_LOCK_TEST_DIR/method" ;;
  -c) echo inactive >"$state_file"; echo "deactivate:$context" >>"$RIME_LOCK_TEST_DIR/actions" ;;
  -o) echo active >"$state_file"; echo "activate:$context" >>"$RIME_LOCK_TEST_DIR/actions" ;;
  -s) echo "$2" >"$RIME_LOCK_TEST_DIR/method"; echo "select:$2" >>"$RIME_LOCK_TEST_DIR/actions" ;;
  *) case "$(cat "$state_file")" in active) echo 2 ;; inactive) echo 1 ;; esac ;;
esac
EOF
cat >"$test_dir/bin/logger" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$RIME_LOCK_TEST_DIR/log"
EOF
chmod +x "$test_dir/bin/omarchy-shell" "$test_dir/bin/fcitx5-remote" "$test_dir/bin/journalctl" "$test_dir/bin/logger"
mkfifo "$test_dir/events"

wait_for_state() {
  local context=$1 expected=$2
  for (( attempt = 0; attempt < 30; attempt++ )); do
    [[ $(cat "$test_dir/state_$context") == "$expected" ]] && return 0
    sleep 0.1
  done
  echo "Timed out waiting for $context to become $expected" >&2
  exit 1
}

wait_for_log() {
  local message=$1
  for (( attempt = 0; attempt < 30; attempt++ )); do
    rg -q -- "$message" "$test_dir/log" && return 0
    sleep 0.1
  done
  echo "Timed out waiting for log: $message" >&2
  exit 1
}

echo false >"$test_dir/locked"
echo foot >"$test_dir/context"
echo active >"$test_dir/state_foot"
echo active >"$test_dir/state_lock"
echo rime >"$test_dir/method"
: >"$test_dir/actions"
: >"$test_dir/log"
: >"$test_dir/checks"
bash "$repo_dir/monitor.sh" &
monitor_pid=$!
exec 3>"$test_dir/events"
for (( attempt = 0; attempt < 30; attempt++ )); do
  [[ -s $test_dir/checks ]] && break
  sleep 0.1
done
[[ -s $test_dir/checks ]]

echo true >"$test_dir/locked"
echo "omarchy lock 2026-10-02T00:00:00Z lock-requested" >&3
wait_for_log lock-requested
[[ $(cat "$test_dir/state_foot") == active ]]
[[ ! -s $test_dir/actions ]]
echo lock >"$test_dir/context"
echo "omarchy lock 2026-10-02T00:00:00Z secure=true" >&3
wait_for_state lock inactive
echo foot >"$test_dir/context"
echo false >"$test_dir/locked"
echo "omarchy lock 2026-10-02T00:00:01Z unlocked" >&3
wait_for_log unlocked
wait_for_state foot active
grep -qx 'deactivate:lock' <(sed -n '1p' "$test_dir/actions")
grep -qx 'activate:foot' <(sed -n '2p' "$test_dir/actions")
grep -qx 'select:rime' <(sed -n '3p' "$test_dir/actions")

# Preserve a user-selected inactive state across a later lock cycle.
echo inactive >"$test_dir/state_foot"
echo active >"$test_dir/state_lock"
: >"$test_dir/actions"
: >"$test_dir/log"
echo true >"$test_dir/locked"
echo "omarchy lock 2026-10-02T00:00:02Z lock-requested" >&3
wait_for_log lock-requested
echo lock >"$test_dir/context"
echo "omarchy lock 2026-10-02T00:00:02Z secure=true" >&3
wait_for_state lock inactive
echo foot >"$test_dir/context"
echo false >"$test_dir/locked"
echo "omarchy lock 2026-10-02T00:00:03Z unlocked" >&3
wait_for_log unlocked
[[ $(cat "$test_dir/state_foot") == inactive ]]
! rg -q '^activate:' "$test_dir/actions"

echo "monitor: passed"
