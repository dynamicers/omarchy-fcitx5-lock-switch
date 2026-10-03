#!/usr/bin/env bash

# Run as an Omarchy shell service. Omarchy logs lock-requested before creating
# the secure surface and logs unlocked after releasing it. Following those
# events avoids repeatedly launching an IPC client while the desktop is idle.

last_locked=false
was_active=false
previous_input_method=

remote() {
  timeout 2s fcitx5-remote "$@" 2>/dev/null
}

input_state() {
  remote || true
}

log_state() {
  logger -t omarchy-fcitx5-lock-switch -- "$1 fcitx_state=$(input_state)" 2>/dev/null || true
}

lock_started() {
  [[ $last_locked == true ]] && return
  last_locked=true
  was_active=false
  previous_input_method=

  if [[ $(input_state) == 2 ]]; then
    was_active=true
    previous_input_method=$(remote -n)
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

  # This event is the switching point verified with the lock input context.
  if [[ $(input_state) == 2 ]]; then
    remote -c >/dev/null
  fi
  log_state "lock-secure"
}

lock_ended() {
  [[ $last_locked == false ]] && return
  if [[ $was_active == true ]]; then
    remote -o >/dev/null
    if [[ -n $previous_input_method ]]; then
      remote -s "$previous_input_method" >/dev/null
    fi
  fi
  was_active=false
  previous_input_method=
  last_locked=false
  log_state "unlocked"
}

check_current_lock() {
  local status phase
  status=$(timeout 2s omarchy-shell -q lock status 2>/dev/null) || return
  phase=$(jq -er '
    if .secure == true then "secure"
    elif .requested == true then "requested"
    elif .locked == false then "unlocked"
    else empty end
  ' <<<"$status" 2>/dev/null) || return
  case $phase in
    secure) lock_ready ;;
    requested) lock_started ;;
    unlocked) lock_ended ;;
  esac
}

journal_pid=
journal_fd=
cleanup() {
  [[ -z $journal_pid ]] || kill "$journal_pid" 2>/dev/null || true
  [[ -z $journal_pid ]] || wait "$journal_pid" 2>/dev/null || true
  if [[ -n $journal_fd ]]; then
    exec {journal_fd}<&-
    journal_fd=
  fi
}
trap cleanup EXIT
trap 'exit 0' TERM INT

while :; do
  # Start the subscriber before reconciling state. journalctl has no readiness
  # handshake, so this reduces but does not eliminate the startup event gap.
  coproc LOCK_LOG {
    exec journalctl --user --follow --lines=0 --output=cat \
      SYSLOG_IDENTIFIER=omarchy-shell 2>/dev/null
  }
  journal_pid=$LOCK_LOG_PID
  # Bash may unset LOCK_LOG when the process exits. Keep our own descriptor
  # so EOF remains readable even if journalctl exits during the state query.
  if ! exec {journal_fd}<&"${LOCK_LOG[0]}"; then
    cleanup
    journal_pid=
    sleep 1
    continue
  fi
  check_current_lock

  while IFS= read -r event <&"$journal_fd"; do
    case $event in
      *"omarchy lock "*" lock-requested") lock_started ;;
      *"omarchy lock "*" secure=true") lock_ready ;;
      *"omarchy lock "*" unlocked") lock_ended ;;
    esac
  done

  cleanup
  journal_pid=
  sleep 1
done
