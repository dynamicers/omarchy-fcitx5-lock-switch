# Omarchy 锁屏 Rime 英文输入插件

简体中文 | [English](README.md)

锁屏时临时停用 Fcitx5 输入法，让密码栏位使用键盘输入；解锁后恢复锁屏前的输入法。如果锁屏前输入法已经停用，解锁后仍保持停用。本插件是独立的 Omarchy shell service 插件，不修改 Omarchy 自带的锁屏插件或 Rime 配置。

## 背景

Omarchy 的锁屏画面是 Quickshell 的 session lock surface，不是普通应用窗口。实测中，锁屏时 Fcitx5 仍把焦点识别为锁屏前的 `foot` 窗口，因此 Rime 的 `app_options` 无法用独立的锁屏 app ID 指定 `ascii_mode`。锁屏密码栏位也没有让这台机器上的 Fcitx5 自动切换到键盘输入法。

## 安装与使用

系统需要 Omarchy 的 Quickshell 锁屏服务、Fcitx5，以及可用的 `fcitx5-remote` 和 `journalctl`。将下面的地址替换为发布后的 Git 仓库地址，再安装并启用：

```bash
omarchy plugin add 'https://github.com/你的用户名/omarchy-rime-lock.git' --enable
```

本机已有该仓库时，在仓库根目录通过 Git 的 `file://` 地址安装：

```bash
omarchy plugin add "file://$PWD" --enable
```

安装后，照常使用 Omarchy 菜单、快捷键或闲置锁屏；插件会自动处理。检查插件状态：

```bash
omarchy plugin list --json | jq '.[] | select(.id == "rime.lock-ascii")'
```

插件服务会保持加载。更新时先停用旧服务，更新代码后再启用：

```bash
omarchy plugin disable rime.lock-ascii
omarchy plugin update rime.lock-ascii
omarchy plugin enable rime.lock-ascii
```

移除插件：

```bash
omarchy plugin remove rime.lock-ascii
```

## 设计思路

插件订阅 Omarchy shell 写入用户 journal 的三种锁屏消息，不持续轮询：

1. `lock-requested`：记录 Fcitx5 在锁屏前是否启用，以及当前输入法名称；此时不切换输入法。
2. `secure=true`：锁屏画面已经建立自己的输入上下文。若 Fcitx5 处于启用状态，调用 `fcitx5-remote -c`，让密码栏位使用键盘输入。
3. `unlocked`：仅当锁屏前输入法处于启用状态时，调用 `fcitx5-remote -o` 并恢复原输入法。

插件在启动或 journal 重新连接时还会查询一次当前锁屏状态。如果插件在锁屏**之后**才启动，它无法得知锁屏前使用的输入法，因此会关闭锁屏中的输入法，但不会在解锁后猜测要恢复什么。

诊断最近的切换结果：

```bash
journalctl --user -b -t rime-lock-ascii -n 20 --no-pager
```

此方案依赖 Omarchy 锁屏服务输出的日志文字。如果未来 Omarchy 改动这些消息，插件需要更新。`secure=true` 发生在锁屏画面建立之后，切换可能略晚于画面出现。插件只处理 Omarchy 的锁屏，不处理其他锁屏程序。
