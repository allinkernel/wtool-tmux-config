# terminal/tmux

从 `~/source/mytool/tmux`（原 `wsw_tmux`）迁移过来的 tmux 配置。
**本项目同时是 wtool 迁移的第一个演示样例。**

## 安装

```sh
./install.sh          # 需要 wtool-bootstrap（见下）
./uninstall.sh        # 完全回退
```

bootstrap 查找顺序：`$WTOOL_BOOTSTRAP` → 向上 4 层找 `bootstrap/` 或 `wtool-bootstrap/` → `~/.wtool/bootstrap`。
本仓库与 bootstrap 同在 `~/self/wtool/` 下，所以直接就能找到。

> ⚠️ `install.sh` 要求仓库**已提交且工作区干净**（这是"记录版本"的前提）。
> 本项目刚迁移过来、尚未 `git init`，首次试用需要 `./install.sh --force`。
> 提交之后就不需要 `--force` 了。

## 做了什么

| 动作 | 结果 |
|---|---|
| 建中转链接 | `~/.wtool/links/terminal/tmux` → 本仓库 |
| 建软链 | `~/.tmux.conf` → 上述中转链接下的 `tmux.conf` |
| 注入 `~/.zshrc` | 一个受管块，source `env.zsh`（导出 `WTOOL_TMUX_DIR` + `tmux-wtool` 别名） |

`uninstall.sh` 把这三件事**逐条撤销**，`~/.zshrc` 回到安装前的样子。

## 与 mytool 版本的差异

| 原 mytool | 现在 | 原因 |
|---|---|---|
| `wsw_env.sh` 用 `get_this_dir` 算路径 | `env.zsh` 直接用 `$WTOOL_PROJECT_DIR` | 加载器已经算好了，不再需要方言相关的路径魔法 |
| `source` 时 `echo "WSW_TMUX_CONF_DIR is ..."` | 去掉了 | env 文件不该有副作用（会被 source 多次） |
| `wsw.tmux.conf` 里 `$WSW_TMUX_CONF_DIR` | `$HOME/.wtool/links/terminal/tmux/bin/*.sh` | 稳定路径，不依赖 tmux server 的环境变量快照 |
| 靠 install_all.sh 复制/安装 | 只有软链 + rc 块 | 改一处即生效，不再有"两份都要改"的问题 |

## 已知问题（保持原样迁移，未改动）

| 问题 | 说明 |
|---|---|
| `bin/disk.sh` 的 `while read` 在管道子 shell 里跑，`msg`/`brief_msg` 赋值会丢失 | 最终输出可能是 `[]`。原 mytool 版本就有这个 bug，迁移时**故意没改**，以免混入行为变更 |
| `bin/net.sh` 硬编码网卡名 `ens33` | 原作者注释里已说明"部分机器不生效" |
| `bin/mem.sh`/`disk.sh`/`net.sh` 的 shebang 是 `/usr/bin/zsh` | 依赖 zsh 存在；如不需要可改 `#!/bin/bash` |

## 文件

| 文件 | 作用 |
|---|---|
| `wtool.xml` | 清单：1 个 env + 1 个 link，`priority=50` |
| `env.zsh` | 被 `~/.zshrc` 的 wtool 块 source |
| `tmux.conf` | 配置本体，链到 `~/.tmux.conf` |
| `bin/*.sh` | 状态栏脚本（cpu / mem / disk / net） |
| `install.sh` / `uninstall.sh` | bootstrap 存根 |
