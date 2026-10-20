# terminal/tmux

一套开箱可用的 tmux 配置：

* **状态栏**每秒刷新，左侧显示内存 / swap、CPU 负载、磁盘占用；
* **Alt 系列快捷键**（不用前缀键）管 pane 的切换、换位、缩放；
* **`prefix + c`** 新建窗口时自动把窗口分成左 25% + 中间 50%（上下 30/70）+ 右 25%；
* 鼠标直接可用（选中、滚动、拖边框），历史缓冲 5000 行。

配置本体是 `tmux.conf`。装完之后**敲 `tmux` 就是这份配置** —— 靠 `env.zsh` / `env.bash`
里的包装函数 `tmux() { command tmux -f "$WTOOL_HOME/wtool/terminal/tmux/tmux.conf" "$@"; }`。
（ADR-0045 的新链接模型里 `$HOME` **不再有** wtool 建的软链，原先那条 `~/.tmux.conf`
已经删掉 —— 见「shell 集成」和「已知问题」。）

> 本仓库是 wtool 的子项目：**装、卸都由 wtool 按 `wtool.xml` 的声明完成**。
> 本仓库没有（也不需要）手工跑的 `install.sh` / `uninstall.sh`。

## 安装

一句话：`wtool install terminal/tmux`。

下载与安装的**唯一入口**在 GitHub 上：

> **[wtool-doc/README.md](https://github.com/allinkernel/wtool-doc/blob/main/README.md)**

（URL 由清单 `.repo/manifests/default.xml` 里的 remote `ssh://git@github.com/`
+ 项目名 `allinkernel/wtool-doc.git` + 默认 revision `main` 拼出，不是猜的：
`sed -n '4,5p' .repo/manifests/default.xml` 就是 `<remote name="github" fetch="ssh://git@github.com/" />`
和 `<default revision="main" remote="github" .../>`。）

> ⚠️ **wtool 的项目只在容器里装 / 测**（用户级规矩，2026-10-04）：本机（WSL）是临时
> 的手工环境，wtool 彻底调通之前**不在本地落地**。要在容器里验证就 `--network=host`
> 挂工作区；**真机上装本项目必须由用户明确同意**，助手不得自行 `wtool install`。

`wtool install` 按 `wtool.xml` 的声明做两件事（**都不往 `$HOME` 里放配置文件**）：

1. 建 **L1 链** `$WTOOL_HOME/wtool/terminal/tmux` → 本仓库这个目录 ——
   `tmux.conf` 与 `bin/*.sh` 就从这条链**直接读源码**，不渲染、不生成、不进 `__output`
   （① 类纯源码项目，ADR-0045 §1.4 / D46）；
2. 把 `env.zsh` / `env.bash` 并进 `$WTOOL_HOME/env.zsh` / `$WTOOL_HOME/env.bash`
   —— rc 里那两行 source 的就是它们，`tmux()` 包装函数随之生效。

`wtool uninstall terminal/tmux` 把这两件事逐条撤销。

装完**新开一个 shell**（或 `source ${WTOOL_HOME}/env.zsh`）再敲 `tmux`；如果本来就有
tmux 会话在跑，先 `tmux kill-server` 一次 —— server 握着的是它**启动那一刻**的环境
和配置（原因见「状态栏」和「已知问题」）。

## 功能说明

### 文件

| 文件 | 作用 |
|---|---|
| `tmux.conf` | 配置本体；由 `tmux()` 包装函数用 `-f` 指定（**不再软链到 `~/.tmux.conf`**） |
| `env.zsh` / `env.bash` | 两个 shell 各一份、**内容等价**；被 `$WTOOL_HOME/env.{zsh,bash}` 里的 wtool 块 source |
| `bin/*.sh` | 状态栏脚本（cpu / mem / disk / net）。**cpu / mem / disk 是 POSIX `#!/bin/sh`**（2026-10-20 重写），由 `tmux.conf` 的 `#()` 按 L1 路径调用；`net.sh` 没被引用 |
| `wtool.xml` | 清单：**只有两份 env 声明** —— ① 类纯源码，没有 `<link>`、没有 `<export_*>` |
| `tests/env_test.sh` | 清单/配置形状 + env 两份等价的测试（同一张表跑两个 shell） |
| `architecture.md` | 这个项目**现在长什么样**（链接形态、两个 shell 的约定）—— 助手看 |
| `BACKLOG.md` | 这个项目"接下来做什么、哪条待拍板"（助手看） |

### shell 集成

`env.zsh` 与 `env.bash` 做同样这几件事：

| 名字 | 值 / 行为 |
|---|---|
| `tmux()` | **包装函数**：`command tmux -f "$WTOOL_HOME/wtool/terminal/tmux/tmux.conf" "$@"` —— 敲 `tmux` 永远用本项目配置（ADR-0045 / D10） |
| `WTOOL_TMUX_DIR` | 导出为 `$WTOOL_PROJECT_DIR`（引擎给的 L1 地址，即 `$WTOOL_HOME/wtool/terminal/tmux`） |
| `tmux-wtool` | 历史遗留的别名：`command tmux -f "$WTOOL_TMUX_DIR/tmux.conf"` —— 有了包装函数之后它和直接敲 `tmux` 等价 |
| `WTOOL_HOME` 校验 | 空 / 目录不在 → 打印"请在 rc 里加 `export WTOOL_HOME=~/.wtool` + `source ${WTOOL_HOME}/env.zsh` 两行"并以非 0 返回，**绝不静默半装**（ADR-0045 / D48） |
| 单独 source 时的兜底 | `WTOOL_PROJECT_DIR` 没设就取 `$WTOOL_HOME/wtool/terminal/tmux` |

> **`tmux()` 只活在 source 过 env 文件的 shell 里**：`cron` / `systemd` / `sh -c`
> 拿不到它（它们也不读 rc）—— 那些地方要自己写全 `tmux -f <conf>`。
> `WTOOL_HOME` 是**你在 rc 里声明**的，不是 env 文件自己猜的（D48）；
> 换目录时只改 rc 里那一行 `export WTOOL_HOME=…`。

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
| 13 | `Ctrl-b` `c` | prefix | 新建窗口，**并立刻自动分成 4 个 pane**（布局见下） | 覆盖 tmux 默认的 `c`（默认只新建一个 pane）。**只在 `main` 上**，`ds_dev` 还没有 —— 见下面的分支提示 |
| 14 | `Ctrl-b` `%` | prefix | 左右分屏，**新 pane 继承当前 pane 的工作目录** | 覆盖默认 `%`（默认不继承目录）。**只在 `main` 上** |
| 15 | `Ctrl-b` `"` | prefix | 上下分屏，**新 pane 继承当前 pane 的工作目录** | 覆盖默认 `"`（默认不继承目录）。**只在 `main` 上** |
| 16 | `Ctrl-b` `Space` | prefix | **解绑**（原默认动作是 `next-layout`，切换 pane 布局） | `unbind Space` |
| 17 | `Ctrl-b` `Escape` | prefix | **解绑** | `unbind-key Escape`；配置注释写的是"Esc+hjkl 也会切换 panel，这在使用 vim 时会导致问题"。⚠️ 本机 tmux 3.4 的**默认前缀表里本来就没有 `Escape`**（`tmux list-keys -T prefix` 实测），所以这一条在当前版本**不改变任何行为** |

> 数一下（核过的两个数）：**`main` 上 17 条**键位声明 —— 12 条 `bind-key -n`（Alt 系列）
> + 3 条 `bind-key`（`c` / `%` / `"`）+ 2 条解绑（`unbind Space` / `unbind-key Escape`）；
> **`ds_dev` 上 14 条** —— 少了第 13 / 14 / 15 那三条。
> 判据：`grep -cE '^(bind|bind-key|unbind|unbind-key)' tmux.conf` → `ds_dev` 14；
> `git show main:tmux.conf | grep -cE '^(bind|bind-key|unbind|unbind-key)'` → 17。

> ⚠️ **分支提示（把 `main` 合进 `ds_dev` 之后请删掉这一段）**：`ds_dev` 是从更早的提交
> 拉出来的，**还没有** `main` 上的 `4d36585`（"新增快捷键"）—— 所以上面第 **13 / 14 / 15**
> 条（`prefix + c` / `%` / `"`）在 `ds_dev` 当前的 `tmux.conf` 里**还不存在**，只在 `main` 上。
> 本节是按 `main` 的内容写的；`ds_dev` 现在只有 14 条（少这 3 条）。
> **别为了对齐 `ds_dev` 把这三行删掉** —— 合并之后它们就是对的（合并不由助手做，用户决定）。

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
| `status-right-style` | `bg=yellow` | 右半段配色。**只设了颜色**：`status-right` 内容没有设 → 保持 tmux 默认。tmux 3.4 的默认值实测是 `#{?window_bigger,[#{window_offset_x}#,#{window_offset_y}] ,}"#{=21:pane_title}" %H:%M %d-%b-%y`（`tmux show-options -g status-right`） |
| `window-status-current-style` | `bg=blue, fg=white` | 当前窗口标签：蓝底白字 |
| `window-status-style` | `fg=black` | 其他窗口标签：黑字 |
| `window-status-separator` | `\|` | 窗口之间用竖线分隔（默认空格） |

`status-left` 依次调用三个脚本（按 L1 路径 `$WTOOL_HOME/wtool/terminal/tmux/bin/` 找 ——
仓库搬到哪、`$WTOOL_HOME` 指到哪，都不用改配置）：

| 顺序 | 脚本 | 输出 |
|---|---|---|
| 1 | `bin/mem.sh` | `[M:<可用内存> S:<可用swap>]`；读 `/proc/meminfo` 的 `MemAvailable`（没有就 `MemFree+Buffers+Cached`）/ `SwapFree`，kB 整数换算成 SI，**绝不输出负数** |
| 2 | `bin/cpu.sh` | `[C:<1 分钟负载 / 在线 CPU 数 × 100>%]`；读 `/proc/loadavg`（单核 load 0.45 → 45%，8 核 → 6%） |
| 3 | `bin/disk.sh` | 块设备白名单（`/dev/sd*`、`nvme*`、`vd*`、`mmcblk*`、`dm-*`、`xvd*`、`mapper/*`）+ WSL 盘符；条目总长 > 40 字节时只印简写；没有匹配 → `[]`；Docker 的 overlay 根 → `[/:<可用>]` |

三个脚本都是 `#!/bin/sh`，**用 `env -i PATH=/usr/bin:/bin` 直接 exec 就能跑**
（tmux 的 `#()` 环境就是这个样子）：不依赖 zsh、不依赖 `free` 的人类可读输出。
判据：`env -i PATH=/usr/bin:/bin bin/mem.sh` → 非空、rc=0（测试里有这一条）。

> **`$WTOOL_HOME` 是怎么到 `#()` 手边的**（2026-10-13 实测，tmux 3.4 + ubuntu:24.04
> 容器，装出来的 conf 走 L1 链加载，当时截屏看到的是 `[M:20G S:68G][C:0.75%][]`；
> 2026-10-20 起 `disk.sh` 在容器里输出 `[/:<可用>]`，不再是 `[]`）：
> ① tmux **读本文件时**就把 `$WTOOL_HOME` 展开写进选项里
> （`tmux show-options -g status-left` 看到的是展开后的绝对路径）；
> ② `#()` 由 **tmux server** fork 出来跑，环境就是 server 启动那一刻的环境。
> ⚠️ 两条都吃 **server 启动时**的环境：老 server（`export WTOOL_HOME` 之前起的）
> 看不到，`tmux kill-server` 重起即恢复；改完本条配置也要重起 server 才会重新读。

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

### 2026-10-20 已修：三个状态栏脚本改成 POSIX sh

| 原问题 | 根因 | 现在的做法 |
|---|---|---|
| `mem.sh` / `disk.sh` 的 shebang 是 `#! /usr/bin/zsh`（`cpu.sh` 连 shebang 都没有） | 装了 wtool 版 zsh 后，宿主 `zsh` 是 `~/.wtool/usr/bin/zsh`（可重定位），`/usr/bin/zsh` **不一定存在**；tmux 的 `#()` 直接 exec 脚本，shebang 找不到 → `not found`（rc=127）。`ubuntu:24.04` 容器里本来就没有 `/usr/bin/zsh`，`env -i PATH=/usr/bin:/bin sh -c 'exec …/mem.sh'` 实测复现 | 三个都 `#!/bin/sh`，只用 POSIX 语法；容器里 `env -i` 直接 exec 通过 |
| `mem.sh` 在 Ubuntu 上打出**负数**（WSL 上正常） | `free --si -h` 给的是**带单位的人类可读数**（`4.1G` / `604M`）；`awk '{printf "%sG",$2-$3}'` 把后缀当没看见，算的是 `4.1-604 = -599.9`。WSL 上 total/used 恰好都在 G 档（`26G-6.5G=19.5`），所以一直没暴露；4 GB 的 Ubuntu 虚拟机 used 是 `604M` 就立刻变负 | 读 `/proc/meminfo` 的 kB 整数；优先 `MemAvailable`，没有就 `MemFree+Buffers+Cached`；夹到 `MemTotal` 以内；算不出来输出 `?`，**永不输出负数** |
| `disk.sh` 的 `while read` 在**管道**里跑 | 原 README 在 `f364365` 里把结论写成"赋值出不了子 shell"是**错的**：zsh 让管道**最后一段在当前 shell 里跑**，所以 zsh 下赋值留得住；换 bash/dash 才变成 `[]` | 先把 `df -P -k` 抓进变量，再用 here-doc 喂 `while`（循环在当前 shell）；全程不解析 `df -h` |
| `disk.sh` 只认 `[C-Z]:\` 和 `/dev/sd[a-z][0-9]` 两种设备 | `/dev/sdd`（WSL 根，没有分区号）、`nvme` / `vd` / `mmcblk` / `dm-*` 都不认；Docker 根是 overlay → `[]` | 设备白名单 + `df -P`（见上面「状态栏」）；没有匹配 → `[]`；Docker 的 overlay 根 → `[/:<可用>]`（判据：没有白名单设备，且 `/` 的 filesystem 是 `overlay`/`overlayfs`） |

仍然保留的两条：

| 问题 | 说明 |
|---|---|
| `bin/net.sh` 硬编码网卡名 `ens33` | 原 `readme.md` 写着"在部分机器上也不会生效，所以我打算放弃"；而且它没被 `tmux.conf` 引用（状态栏只挂 mem / cpu / disk） |
| 原 `readme.md` 写着"`process.sh` 用来计算 cpu 占用率的方法，在 wsl1 上不会生效" | **仓库里没有 `process.sh`**（`git ls-files` 只有 cpu / disk / mem / net 四个脚本）。现在的 `bin/cpu.sh` 读 `/proc/loadavg`；WSL1 未真验 |

新模型带来的三条（2026-10-13 实测记下，都不是"配置写错了"）：

| 现象 | 原因 / 怎么办 |
|---|---|
| **`tmux -f <文件不存在>` 不报错**，静默用 tmux 默认配置 | 实测：`-f` 指向不存在的文件时 server 照起，只是 `status-left` 是默认的 `[name]`。所以 `WTOOL_HOME` 指错会表现成"命令能跑、配置没生效"—— env 文件里那段 `WTOOL_HOME` 校验就是挡这个的 |
| 状态栏里 `$WTOOL_HOME` 展开成**空**（脚本路径变成 `/wtool/terminal/tmux/bin/mem.sh`，跑不起来） | tmux server 启动时环境里没有 `WTOOL_HOME`（老 server，或 rc 里还没加那两行）。`tmux kill-server` 重起，或补上 rc 两行 |
| conf 里**不要**写 `\${VAR}` 或 `${VAR:-默认}` | 实测（tmux 3.4）：`${WTOOL_HOME:-UNSET}` 会让**整行 `set` 失效**、`status-left` 退回 tmux 默认值；`\$WTOOL_HOME` 会把反斜杠留给 `sh`、脚本路径解析不出来。就用 `#(sh -c 'exec "$WTOOL_HOME/…"')` 这一种写法 |

## 测试

```sh
bash tests/env_test.sh     # 92 条（2026-10-20 实测）：清单/配置形状（没有 <link>、
                           # 没有废弃的 wtool-work-dir/links、状态栏走 $WTOOL_HOME）
                           # + env.zsh / env.bash 的变量、tmux() 包装函数、WTOOL_HOME 校验
                           # （**同一张表跑两个 shell**）
                           # + 状态栏三个脚本：env -i / sh -n + dash -n / 合成 meminfo
                           #   （正常、无 MemAvailable、极小、异常大值、负数字段，全都不许负）
                           #   / df 白名单（VM / WSL / overlay / tmpfs / 单文件 bind）
                           # 条数以输出为准；没装 zsh 就只测 bash，没装 dash 就跳过 dash
```

## 迁移历史

从 `~/source/mytool/tmux`（原 `wsw_tmux`）迁移过来，**本项目同时是 wtool 迁移的第一个演示样例**。

| 原 mytool | 现在 | 原因 |
|---|---|---|
| `wsw_env.sh` 用 `get_this_dir` 算路径 | `env.zsh` / `env.bash` 直接用 `$WTOOL_PROJECT_DIR` | 加载器已经算好了，不再需要方言相关的路径魔法 |
| source 时 `echo "WSW_TMUX_CONF_DIR is ..."` | 去掉了 | env 文件不该有副作用（会被 source 多次） |
| `wsw.tmux.conf` 里用 `$WSW_TMUX_CONF_DIR` | `$WTOOL_HOME/wtool/terminal/tmux/bin/*.sh`（L1 路径） | 稳定路径：仓库搬到哪、`$WTOOL_HOME` 指到哪都不用改配置 |
| 靠 `install_all.sh` 复制安装 | 只有 L1 链 + env 块（wtool 做） | 改一处即生效，不再有"两份都要改"的问题 |
| `~/.tmux.conf` 软链（旧模型的三段 `<link>`） | `env.*` 里的 `tmux()` 包装函数（ADR-0045 / D10，2026-10-13） | 新模型 `$HOME` 里不再有 wtool 建的软链；`<link>` 的解析已从引擎删掉（D3） |
| `$HOME/.wtool/wtool-work-dir/links/<项目>` 中转链 | `$WTOOL_HOME/wtool/<项目>` **L1 链**（2026-10-13） | L1/L2 两类链职责分开（ADR-0045 §1.3）；老的中转目录已废弃 |
