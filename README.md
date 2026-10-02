# Rime Lock ASCII for Omarchy

[简体中文](README.zh-CN.md) | English

This independent Omarchy shell plugin switches Fcitx5 to its keyboard mode
when Omarchy's lock screen becomes secure. When the session is unlocked, it
reactivates the input method that was active before the lock. If Fcitx5 was
already inactive, the plugin leaves it inactive after unlock.

The plugin follows the Omarchy shell's `lock-requested`, `secure=true`, and
`unlocked` journal events, so it covers both manual and idle locks made through
Omarchy. It records the input method at `lock-requested` and switches at
`secure=true`, when the lock screen has its own input context. It checks the
current lock state once when it starts or reconnects. It does not change
Rime's configuration or handle a lock started by another locker. The
Omarchy lock service currently waits about 500 ms between the request and the
session-lock surface. Switching on `secure=true` may happen just after the
surface appears.

## Install

Replace the URL with your published Git repository, then install and enable it:

```bash
omarchy plugin add 'https://github.com/YOUR_NAME/omarchy-rime-lock.git' --enable
```

From the root of a local checkout, a `file://` Git URL also works:

```bash
omarchy plugin add "file://$PWD" --enable
```

Omarchy warns before enabling third-party plugins because they run inside the
shell process. Review `Service.qml` and `monitor.sh` before installation.

Because the service stays loaded, disable it before updating and enable it
again afterward to load the new code:

```bash
omarchy plugin disable rime.lock-ascii
omarchy plugin update rime.lock-ascii
omarchy plugin enable rime.lock-ascii
```

## Remove

```bash
omarchy plugin remove rime.lock-ascii
```

## Requirements

Omarchy with the Quickshell lock service and `fcitx5-remote` on `PATH`.
