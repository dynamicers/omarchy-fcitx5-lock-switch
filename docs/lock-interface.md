# Lock interface review

Reviewed on 2026-10-02 with Omarchy 4.0.4-1.
The installed source is the reference for this plugin.

## Available interfaces

| Interface | Access | Use |
| --- | --- | --- |
| `omarchy-shell -q lock status` | Public IPC query | Read `requested`, `locked`, and `secure`. |
| `omarchy-shell -q lock isLocked` | Public IPC query | Read a combined lock state. |
| `WlSessionLock.secureStateChanged` | Internal QML signal | Notify the built-in lock service when the lock becomes secure. |
| `PluginShellApi` | Third-party plugin API | Access the plugin's own service. It does not expose the lock service. |
| Omarchy hooks | Named script calls | No lock or unlock call exists in the inspected lock paths. |
| User journal | Log stream | Read lock messages. The text is not a stable event contract. |

A query returns the current state.
It does not provide an event subscription.
The internal QML signal belongs to the built-in lock service.
A third-party plugin cannot connect to it through the provided plugin API.

## Source references

- Installed `shell/plugins/lock/Service.qml`: lock signals, journal messages, and IPC commands.
  [Upstream source](https://github.com/omacom/omarchy/blob/master/shell/plugins/lock/Service.qml).
- Installed `shell/services/PluginShellApi.qml`: third-party service access.
  [Upstream source](https://github.com/omacom/omarchy/blob/quattro/shell/services/PluginShellApi.qml).
- Installed `shell/shell.qml`: scoped service lookup and authentication-service isolation.
- Installed `bin/omarchy-system-lock`: lock command; no lock hook call.
- [Hyprland IPC reference](https://wiki.hypr.land/IPC/): no documented lock event in the inspected event list.

Installed paths are relative to `/usr/share/omarchy/`.
Upstream source can differ from the installed version.

## Decision

Keep journal delivery for this independent plugin.
Use the public status query at startup and reconnection.
Do not use the combined `isLocked` value to decide when to deactivate Fcitx5.
That value becomes true before the lock is secure.

Replacing journal delivery requires a public event interface or a different integration design.
Modifying the built-in lock service would add another component to maintain.
Regular status queries would introduce polling.
Neither change is part of this plugin.
