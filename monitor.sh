#!/usr/bin/env bash

# Run as an Omarchy shell service. Omarchy logs lock-requested before creating
# the secure surface and logs unlocked after releasing it. Following those
# events avoids repeatedly launching an IPC client while the desktop is idle.

last_locked=false
was_active=false
previous_input_method=

input_state() {
  fcitx5-remote 2>/dev/null || true
}

log_state() {
  logger -t rime-lock-ascii -- "$1 fcitx_state=$(input_state)" 2>/dev/null || true
}

lock_started() {
  [[ $last_locked == true ]] && return
  last_locked=true
  was_active=false
  previous_input_method=

  if [[ $(input_state) == 2 ]]; then
    was_active=true
    previous_input_method=$(fcitx5-remote -n 2>/dev/null)
  fi
  log_state "lock-requested"
}

lock_ready() {
  if [[ $last_locked != true ]]; then
    # The request was missed (for example, this service started mid-lock).
    # There is no reliable pre-lock state to restore in that case.
    last_locked=true
    was_active=false
    previous_input_method=
  fi

  # Switch only after the lock surface has its own input context.
  if [[ $(input_state) == 2 ]]; then
    fcitx5-remote -c >/dev/null 2>&1
  fi
  log_state "lock-secure"
}

lock_ended() {
  [[ $last_locked == false ]] && return
  if [[ $was_active == true ]]; then
    fcitx5-remote -o >/dev/null 2>&1
    if [[ -n $previous_input_method ]]; then
      fcitx5-remote -s "$previous_input_method" >/dev/null 2>&1
    fi
  fi
  was_active=false
  previous_input_method=
  last_locked=false
  log_state "unlocked"
}

check_current_lock() {
  case $(omarchy-shell -q lock isLocked 2>/dev/null) in
    true) lock_ready ;;
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
      *"omarchy lock "*" secure=true") lock_ready ;;
      *"omarchy lock "*" unlocked") lock_ended ;;
    esac
  done

  cleanup
  wait "$journal_pid" 2>/dev/null || true
  journal_pid=
  sleep 1
done
