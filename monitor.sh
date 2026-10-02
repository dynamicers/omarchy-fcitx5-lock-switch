#!/usr/bin/env bash

# Run as an Omarchy shell service. Omarchy logs lock-requested before creating
# the secure surface and logs unlocked after releasing it. Following those
# events avoids repeatedly launching an IPC client while the desktop is idle.

last_locked=false
changed_input_method=false
previous_input_method=

lock_started() {
  [[ $last_locked == true ]] && return
  last_locked=true
  changed_input_method=false
  previous_input_method=

  if [[ $(fcitx5-remote 2>/dev/null) == 2 ]]; then
    previous_input_method=$(fcitx5-remote -n 2>/dev/null)
    if fcitx5-remote -c >/dev/null 2>&1; then
      changed_input_method=true
    fi
  fi
}

lock_ended() {
  [[ $last_locked == false ]] && return
  if [[ $changed_input_method == true ]]; then
    fcitx5-remote -o >/dev/null 2>&1
    if [[ -n $previous_input_method ]]; then
      fcitx5-remote -s "$previous_input_method" >/dev/null 2>&1
    fi
  fi
  changed_input_method=false
  previous_input_method=
  last_locked=false
}

check_current_lock() {
  case $(omarchy-shell -q lock isLocked 2>/dev/null) in
    true) lock_started ;;
    false) lock_ended ;;
  esac
}

journal_pid=
cleanup() {
  [[ -z $journal_pid ]] || kill "$journal_pid" 2>/dev/null || true
}
trap cleanup EXIT

while :; do
  # Subscribe first, then read the current state. This closes the gap between
  # checking the state and receiving the next journal event.
  coproc LOCK_LOG {
    journalctl --user --follow --lines=0 --output=cat \
      SYSLOG_IDENTIFIER=omarchy-shell 2>/dev/null
  }
  journal_pid=$LOCK_LOG_PID
  check_current_lock

  while IFS= read -r event <&"${LOCK_LOG[0]}"; do
    case $event in
      *"omarchy lock "*" lock-requested") lock_started ;;
      *"omarchy lock "*" unlocked") lock_ended ;;
    esac
  done

  cleanup
  wait "$journal_pid" 2>/dev/null || true
  journal_pid=
  sleep 1
done
