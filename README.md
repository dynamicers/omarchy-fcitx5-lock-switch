# omarchy-fcitx5-lock-switch

简体中文 | [English](README.md)

此 Omarchy shell 插件在锁屏时停用 Fcitx5。
解锁后，插件恢复锁屏前已启用的输入法。
如果锁屏前 Fcitx5 已停用，插件不会在解锁后启用它。

项目名和插件 ID 均为 `omarchy-fcitx5-lock-switch`。

## 用途

Fcitx5 可以在每个新输入上下文中默认启用输入法。
此插件在锁屏期间禁用 Fcitx5，使用直接键盘输入。

## 依赖

- Omarchy：使用 Quickshell 锁屏服务，并提供 `lock status` IPC 命令。
- Fcitx5：提供 `fcitx5-remote`。
- Bash、`journalctl`、`logger`、`jq` 和 GNU `timeout`。

测试使用的 Omarchy 版本为 4.0.4。

## 安装

将 `OWNER` 替换为仓库所有者的名称：

```bash
omarchy plugin add https://github.com/dynamicers/omarchy-fcitx5-lock-switch.git --enable
```

安装本地 Git 仓库时，在仓库根目录执行：

```bash
omarchy plugin add "file://$PWD" --enable
```

## 使用

使用 Omarchy 的锁屏命令、快捷键或闲置计时器锁屏。
插件会自动切换输入法。

查看已安装的插件：

```bash
omarchy plugin list
```

查看插件最近的日志：

```bash
journalctl --user -b -t omarchy-fcitx5-lock-switch -n 20 --no-pager
```

## 更新

在屏幕未锁定时执行：

```bash
omarchy plugin disable omarchy-fcitx5-lock-switch
omarchy plugin update omarchy-fcitx5-lock-switch
omarchy plugin enable omarchy-fcitx5-lock-switch
```

停用插件会停止监控进程。
启用插件会加载更新后的服务。

## 移除

在屏幕未锁定时执行：

```bash
omarchy plugin remove omarchy-fcitx5-lock-switch
```

## 工作流程

| 锁屏消息 | 插件操作 |
| --- | --- |
| `lock-requested` | 保存 Fcitx5 的启用状态和已选输入法。 |
| `secure=true` | 停用锁屏输入上下文中的 Fcitx5。 |
| `unlocked` | 如果锁屏前输入法已启用，则恢复保存的输入法。 |

监控进程从用户 journal 读取这些消息。
插件不定时轮询锁屏状态。
插件在启动和 journal 重新连接时各查询一次 `lock status`。
查询结果区分锁屏请求和已建立的锁屏。
每次 Fcitx5 或 shell IPC 调用最多等待两秒。

Omarchy 提供锁屏状态查询和内部 QML 信号。
第三方插件 API 未开放锁屏服务，也未提供锁屏事件订阅。
因此，此插件通过 journal 接收事件。
接口核查结果和源码位置见[锁屏接口说明](docs/lock-interface.md)。

## 限制

- Omarchy 更新可能改变 journal 消息文字。
- 启动或 journal 重新连接期间可能遗漏消息。
- 如果插件在锁屏建立后启动，它无法获得锁屏前的状态。
  插件会停用 Fcitx5，但不会在解锁后恢复未知状态。
- 插件在锁屏建立后切换输入法，可能有短暂延迟。
- Fcitx5 故障或焦点变化可能导致切换失败。
- 插件仅处理 Omarchy 锁屏。

## 验证修改

在仓库根目录执行：

```bash
bash tests/monitor.bash
omarchy plugin validate "$PWD"
```

测试脚本通过模拟锁屏事件检查输入状态变化。
测试脚本不验证实际锁屏界面。
