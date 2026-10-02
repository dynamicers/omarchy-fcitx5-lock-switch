#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
monitor_pid=
cleanup() {
  [[ -z $monitor_pid ]] || kill "$monitor_pid" 2>/dev/null || true
  rm -rf "$test_dir"
}
trap cleanup EXIT

mkdir -p "$test_dir/bin"
export RIME_LOCK_TEST_DIR="$test_dir"
export PATH="$test_dir/bin:$PATH"

cat >"$test_dir/bin/omarchy-shell" <<'EOF'
#!/usr/bin/env bash
cat "$RIME_LOCK_TEST_DIR/locked"
EOF

cat >"$test_dir/bin/fcitx5-remote" <<'EOF'
#!/usr/bin/env bash
case "${1-}" in
  -n) cat "$RIME_LOCK_TEST_DIR/method" ;;
  -c) echo inactive >"$RIME_LOCK_TEST_DIR/state"; echo deactivate >>"$RIME_LOCK_TEST_DIR/actions" ;;
  -o) echo active >"$RIME_LOCK_TEST_DIR/state"; echo activate >>"$RIME_LOCK_TEST_DIR/actions" ;;
  -s) echo "$2" >"$RIME_LOCK_TEST_DIR/method"; echo "select:$2" >>"$RIME_LOCK_TEST_DIR/actions" ;;
  *) case "$(cat "$RIME_LOCK_TEST_DIR/state")" in active) echo 2 ;; inactive) echo 1 ;; esac ;;
esac
EOF
chmod +x "$test_dir/bin/omarchy-shell" "$test_dir/bin/fcitx5-remote"

wait_for_state() {
  local expected=$1
  for (( attempt = 0; attempt < 30; attempt++ )); do
    [[ $(cat "$test_dir/state") == "$expected" ]] && return 0
    sleep 0.1
  done
  echo "Timed out waiting for $expected" >&2
  exit 1
}

echo false >"$test_dir/locked"
echo active >"$test_dir/state"
echo rime >"$test_dir/method"
: >"$test_dir/actions"
bash "$repo_dir/monitor.sh" &
monitor_pid=$!
sleep 0.2

echo true >"$test_dir/locked"
wait_for_state inactive
echo false >"$test_dir/locked"
wait_for_state active
grep -qx deactivate <(sed -n '1p' "$test_dir/actions")
grep -qx activate <(sed -n '2p' "$test_dir/actions")
grep -qx 'select:rime' <(sed -n '3p' "$test_dir/actions")

# Preserve a user-selected inactive state across a later lock cycle.
echo inactive >"$test_dir/state"
: >"$test_dir/actions"
sleep 0.2
echo true >"$test_dir/locked"
sleep 0.3
echo false >"$test_dir/locked"
sleep 0.3
[[ $(cat "$test_dir/state") == inactive ]]
[[ ! -s $test_dir/actions ]]

echo "monitor: passed"
