# terminal/tmux

一套开箱可用的 tmux 配置：

* **状态栏**每秒刷新，左侧显示内存 / swap、CPU 负载、磁盘占用；
* **Alt 系列快捷键**（不用前缀键）管 pane 的切换、换位、缩放；
* **`prefix + c`** 新建窗口时自动把窗口分成左 25% + 中间 50%（上下 30/70）+ 右 25%；
* 鼠标直接可用（选中、滚动、拖边框），历史缓冲 5000 行。

配置本体是 `tmux.conf`，由 wtool 软链到 `~/.tmux.conf` —— 也就是**装完之后 tmux
默认就读它**，不需要 `-f` 指定。

> 本仓库是 wtool 的子项目：**装、卸都由 wtool 按 `wtool.xml` 的声明完成**。
> 本仓库没有（也不需要）手工跑的 `install.sh` / `uninstall.sh`。

## 安装

一句话：`wtool install terminal/tmux`。

下载与安装的**唯一入口**在 GitHub 上：

> **[wtool-base/README.md](https://github.com/allinkernel/wtool/blob/main/README.md)**

（URL 由清单 `.repo/manifests/default.xml` 里的 remote `ssh://git@github.com/`
+ 项目名 `allinkernel/wtool.git` + 默认 revision `main` 拼出，不是猜的。）

`wtool install` 按 `wtool.xml` 的声明做两件事：

1. 把 `tmux.conf` 软链到 `~/.tmux.conf`；
2. 往 `~/.zshrc` / `~/.bashrc` 各注入一个受管块，分别 source `env.zsh` / `env.bash`。

`wtool uninstall terminal/tmux` 把这两件事逐条撤销。

## 功能说明

### 文件

| 文件 | 作用 |
|---|---|
| `tmux.conf` | 配置本体；wtool 软链到 `~/.tmux.conf` |
| `env.zsh` / `env.bash` | 两个 shell 各一份、**内容等价**；被 rc 里的 wtool 块 source |
| `bin/*.sh` | 状态栏脚本（cpu / mem / disk / net），由 `tmux.conf` 的 `#()` 调用 |
| `wtool.xml` | 清单：1 个 `~/.tmux.conf` 链接 + zsh / bash 两份 env |
| `tests/env_test.sh` | env 两份等价的测试 |

### shell 集成

`env.zsh` 与 `env.bash` 做同样三件事：

| 名字 | 值 / 行为 |
|---|---|
| `WTOOL_TMUX_DIR` | 导出为 `$WTOOL_PROJECT_DIR`（wtool 给的项目稳定地址） |
| `tmux-wtool` | 别名：`command tmux -f "$WTOOL_TMUX_DIR/tmux.conf"` —— 强制用本项目配置 |
| 单独 source 时的兜底 | `WTOOL_PROJECT_DIR` 没设就取 `$HOME/.wtool/wtool-work-dir/links/terminal/tmux` |

### 快捷键功能

**前缀键是 tmux 默认的 `Ctrl-b`** —— 本配置没有改 `prefix`（`tmux show-options -g prefix`
实测仍是 `C-b`）。下表的「前缀」列：`—` 表示**不用前缀**（`bind-key -n`，根表直接生效），
`prefix` 表示要先按 `Ctrl-b` 再按该键。

#### 一、本配置改动的键（逐条对照 `tmux.conf`）

| # | 按键 | 前缀 | 干什么 | 备注 |
|---|---|---|---|---|
| 1 | `Alt+h` | — | 焦点切到左边 pane | **仅当当前 pane 不在最左边**（配置用 `if-shell` 判断 `pane_at_left`） |
| 2 | `Alt+j` | — | 焦点切到下边 pane | 仅当不在最下边（`pane_at_bottom`） |
| 3 | `Alt+k` | — | 焦点切到上边 pane | 仅当不在最上边（`pane_at_top`） |
| 4 | `Alt+l` | — | 焦点切到右边 pane | 仅当不在最右边（`pane_at_right`） |
| 5 | `Alt+H` | — | 把当前 pane 与**左边**的 pane 交换位置 | `swap-pane -s '{left-of}'` |
| 6 | `Alt+J` | — | 与**下边**的 pane 交换位置 | `swap-pane -s '{down-of}'` |
| 7 | `Alt+K` | — | 与**上边**的 pane 交换位置 | `swap-pane -s '{up-of}'` |
| 8 | `Alt+L` | — | 与**右边**的 pane 交换位置 | `swap-pane -s '{right-of}'` |
| 9 | `Alt+Ctrl+h` | — | 当前 pane 向**左**扩 5 格 | `resize-pane -L 5` |
| 10 | `Alt+Ctrl+j` | — | 向**下**扩 5 格 | `resize-pane -D 5` |
| 11 | `Alt+Ctrl+k` | — | 向**上**扩 5 格 | `resize-pane -U 5` |
| 12 | `Alt+Ctrl+l` | — | 向**右**扩 5 格 | `resize-pane -R 5` |
| 13 | `Ctrl-b` `c` | prefix | 新建窗口，**并立刻自动分成 4 个 pane**（布局见下） | 覆盖 tmux 默认的 `c`（默认只新建一个 pane） |
| 14 | `Ctrl-b` `%` | prefix | 左右分屏，**新 pane 继承当前 pane 的工作目录** | 覆盖默认 `%`（默认不继承目录） |
| 15 | `Ctrl-b` `"` | prefix | 上下分屏，**新 pane 继承当前 pane 的工作目录** | 覆盖默认 `"`（默认不继承目录） |
| 16 | `Ctrl-b` `Space` | prefix | **解绑**（原默认动作是 `next-layout`，切换 pane 布局） | `unbind Space` |
| 17 | `Ctrl-b` `Escape` | prefix | **解绑** | `unbind-key Escape`；配置注释写的是"Esc+hjkl 也会切换 panel，这在使用 vim 时会导致问题"。⚠️ 本机 tmux 3.4 的**默认前缀表里本来就没有 `Escape`**（`tmux list-keys -T prefix` 实测），所以这一条在当前版本**不改变任何行为** |

> 数一下：`tmux.conf` 里一共 **17 条**键位声明 —— 12 条 `bind-key -n`（Alt 系列）
> + 3 条 `bind-key`（`c` / `%` / `"`）+ 2 条解绑（`unbind Space` / `unbind-key Escape`）。

> ⚠️ **分支提示（把 `main` 合进 `ds_dev` 之后请删掉这一段）**：`ds_dev` 是从更早的提交
> 拉出来的，**还没有** `main` 上的 `4d36585`（"新增快捷键"）—— 所以上面第 **13 / 14 / 15**
> 条（`prefix + c` / `%` / `"`）在 `ds_dev` 当前的 `tmux.conf` 里**还不存在**，只在 `main` 上。
> 本节是按 `main` 的内容写的；`ds_dev` 现在只有 14 条（少这 3 条）。

#### 第 13 条的自动分屏布局（实测）

`prefix + c` 一个键跑完这一串：`new-window` → 左右切 25% → 选左 → 再插一栏 33% →
选右 → 上下切 70% → 选下。配置注释的原话是"**左右各占25%，中间50%。中间上下分别30%和70%**"。

在 200×50 的窗口里实测（`tmux list-panes` 读出的真实几何）：

| pane | 位置 | 尺寸 | 占比 |
|---|---|---|---|
| 1 | 最左 | 49×50 | 宽 ≈25% |
| 2 | 中间**上** | 99×14 | 宽 ≈50%、高 ≈30% |
| 3 | 中间**下** | 99×35 | 宽 ≈50%、高 ≈70% |
| 4 | 最右 | 50×50 | 宽 ≈25% |

新窗口的每个 pane 的工作目录都继承"按下 `c` 时"所在 pane 的目录
（每条 `split-window` 都带 `-c "#{pane_current_path}"`）。

#### 二、没被本配置改动的部分（保持 tmux 默认）

* **前缀键**：仍是 `Ctrl-b`（`prefix2` 未设）。
* **复制模式**：配置**没有**设置 `mode-keys`，也没有改 `copy-mode` 的键位 → 保持 tmux
  默认（`prefix + [` 进入复制模式）。
* 上表之外的默认键位都还在（`prefix + d` detach、`prefix + x` 关 pane、`prefix + z` 放大等）。

### 状态栏

| 设置 | 值 | 效果 |
|---|---|---|
| `status-interval` | `1` | 每秒刷新一次（tmux 默认 15 秒） |
| `status-justify` | `centre` | 窗口列表居中（默认靠左） |
| `status-left` | 三个脚本串联 | 见下 |
| `status-left-style` | `bg=magenta fg=black` | 左半段配色 |
| `status-left-length` | `90` | 左半段最大宽度 |
| `status-right-style` | `bg=yellow` | 右半段配色。**只设了颜色**：`status-right` 内容没有设 → 保持 tmux 默认（`"#{=21:pane_title}" %H:%M %d-%b-%y`） |
| `window-status-current-style` | `bg=blue, fg=white` | 当前窗口标签：蓝底白字 |
| `window-status-style` | `fg=black` | 其他窗口标签：黑字 |
| `window-status-separator` | `\|` | 窗口之间用竖线分隔（默认空格） |

`status-left` 依次调用三个脚本（按 `$HOME/.wtool/wtool-work-dir/links/terminal/tmux/bin/`
这个稳定地址找，所以仓库搬到哪都不用改配置）：

| 顺序 | 脚本 | 输出 |
|---|---|---|
| 1 | `bin/mem.sh` | `[M:<空闲内存> S:<空闲swap>]`，读 `free --si -h` |
| 2 | `bin/cpu.sh` | `[C:<1分钟负载>%]`，读 `/proc/loadavg` |
| 3 | `bin/disk.sh` | 磁盘占用；条目总长 > 40 字节时只印简写 |

> ⚠️ `bin/net.sh`（网速）**存在，但 `tmux.conf` 里没有任何地方引用它** ——
> 状态栏只挂了 mem / cpu / disk 三个。原 `readme.md` 也写着"我打算放弃"。

### 选项设置

| 设置 | 值 | tmux 默认 | 效果 |
|---|---|---|---|
| `base-index` | `1` | `0` | 窗口编号从 1 开始 |
| `pane-base-index` | `1` | `0` | pane 编号从 1 开始 |
| `renumber-windows` | `on` | `off` | 关掉窗口后自动重排编号 |
| `history-limit` | `5000` | `2000` | 每个 pane 的滚动缓冲行数 |
| `mouse` | `on` | `off` | 鼠标可用；按住 `Shift` 可临时恢复终端原本的鼠标行为 |
| `default-terminal` | `screen-256color` | `tmux-256color` | 声明支持 256 色 |
| `escape-time` | `50` | `500` | Esc 的等待时间 50ms（vim 里 Esc 更跟手） |

## 已知问题

保持原样迁移、未改动：

| 问题 | 说明 |
|---|---|
| `bin/disk.sh` 的 `while read` 在管道子 shell 里跑 | `msg` / `brief_msg` 的赋值出不了子 shell，最终输出可能是 `[]`。原 mytool 版本就有，迁移时故意没改以免混入行为变更 |
| `bin/net.sh` 硬编码网卡名 `ens33` | 原作者注释已说明"部分机器不生效"；而且它没被 `tmux.conf` 引用 |
| `bin/disk.sh` / `mem.sh` / `net.sh` 的 shebang 是 `/usr/bin/zsh` | 依赖 zsh 存在；不需要可以改 `#!/bin/bash` |
| 原 `readme.md` 写着"`process.sh` 用来计算 cpu 占用率的方法，在 wsl1 上不会生效" | **仓库里没有 `process.sh`**（`git ls-files` 只有 cpu / disk / mem / net 四个脚本）。现在的 `bin/cpu.sh` 读 `/proc/loadavg`，是否在 wsl1 上生效**未核实** |

## 测试

```sh
bash tests/env_test.sh     # 5 条：env.zsh / env.bash 给出同样的变量和别名
                           # 没装 zsh 就只测 bash
```

## 迁移历史

从 `~/source/mytool/tmux`（原 `wsw_tmux`）迁移过来，**本项目同时是 wtool 迁移的第一个演示样例**。

| 原 mytool | 现在 | 原因 |
|---|---|---|
| `wsw_env.sh` 用 `get_this_dir` 算路径 | `env.zsh` / `env.bash` 直接用 `$WTOOL_PROJECT_DIR` | 加载器已经算好了，不再需要方言相关的路径魔法 |
| source 时 `echo "WSW_TMUX_CONF_DIR is ..."` | 去掉了 | env 文件不该有副作用（会被 source 多次） |
| `wsw.tmux.conf` 里用 `$WSW_TMUX_CONF_DIR` | `$HOME/.wtool/wtool-work-dir/links/terminal/tmux/bin/*.sh` | 稳定路径，不依赖 tmux server 的环境变量快照 |
| 靠 `install_all.sh` 复制安装 | 只有软链 + rc 块（wtool 做） | 改一处即生效，不再有"两份都要改"的问题 |
