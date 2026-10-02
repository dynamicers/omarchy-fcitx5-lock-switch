#!/usr/bin/env bash

# Run as an Omarchy shell service. The lock IPC changes to "true" when a lock
# is requested, about 500 ms before the secure surface is created.

last_locked=unknown
changed_input_method=false
previous_input_method=

while :; do
  locked=$(omarchy-shell -q lock isLocked 2>/dev/null)

  if [[ $locked == true && $last_locked != true ]]; then
    last_locked=true
    changed_input_method=false
    previous_input_method=

    if [[ $(fcitx5-remote 2>/dev/null) == 2 ]]; then
      previous_input_method=$(fcitx5-remote -n 2>/dev/null)
      if fcitx5-remote -c >/dev/null 2>&1; then
        changed_input_method=true
      fi
    fi
  elif [[ $locked == false && $last_locked == true ]]; then
    if [[ $changed_input_method == true ]]; then
      fcitx5-remote -o >/dev/null 2>&1
      if [[ -n $previous_input_method ]]; then
        fcitx5-remote -s "$previous_input_method" >/dev/null 2>&1
      fi
    fi
    changed_input_method=false
    previous_input_method=
    last_locked=false
  elif [[ $locked == false ]]; then
    last_locked=false
  fi

  # An empty reply means the shell is temporarily unavailable. Keep the last
  # known state so a brief IPC outage cannot trigger a false unlock.
  sleep 0.1
done
