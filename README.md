# Rime Lock ASCII for Omarchy

This independent Omarchy shell plugin switches Fcitx5 to its keyboard mode
when Omarchy requests a lock. When the session is unlocked, it reactivates the
input method that was active before the lock. If Fcitx5 was already inactive,
the plugin leaves it inactive after unlock.

The plugin follows the Omarchy shell's `lock-requested`, `secure=true`, and
`unlocked` journal events, so it covers both manual and idle locks made through
Omarchy. It switches input once when locking starts and again after the lock
screen gets its own input context. It
checks the current lock state once when it starts or reconnects. It does not
change Rime's configuration or handle a lock started by another locker. The
Omarchy lock service currently waits about 500 ms between the request and the
session-lock surface. Switching on `secure=true` may happen just after the
surface appears.

## Install

Clone this repository with Omarchy's plugin installer, then enable it:

```bash
omarchy plugin add <git-repository-url> --enable
```

For a local checkout, a `file://` Git URL also works:

```bash
omarchy plugin add file:///home/tom/Work/omarchy/omarchy-rime-lock --enable
```

Omarchy warns before enabling third-party plugins because they run inside the
shell process. Review `Service.qml` and `monitor.sh` before installation.

## Remove

```bash
omarchy plugin remove rime.lock-ascii
```

## Requirements

Omarchy with the Quickshell lock service and `fcitx5-remote` on `PATH`.
